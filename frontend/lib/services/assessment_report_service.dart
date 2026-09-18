import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'age_calculator_service.dart';
import 'auth_service.dart';
import 'email_webhook_service.dart';

class AssessmentReportService {
  static const String _reportsCollection = 'assessment_reports';
  static const String _modelVersion = 'v1.2.0';

  static Future<String> createAssessmentReport({
    required String assessmentType,
    required dynamic childAge,
    required Map<String, double> skillScores,
    required Map<String, String> skillLabels,
    required List<String> assessedActivities,
    required Map<String, dynamic> rawMetrics,
  }) async {
    final AuthUser? user = await AuthService.currentUser();
    if (user == null) {
      throw StateError('No signed-in user found. Please log in again.');
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String childName = (prefs.getString('childName') ?? '').trim();
    final String childGrade = (prefs.getString('childGrade') ?? '').trim();
    if (childName.isEmpty) {
      throw StateError(
        'Child name is missing. Please complete child details before assessment.',
      );
    }
    final ParentQuestionnaireSignals parentSignals =
        await _loadParentQuestionnaireSignals(user.id);

    final ChildAgeResult? ageResult = AgeCalculatorService.getAgeResultFromPrefs(prefs);
    final dynamic displayAge = ageResult?.formattedAge ?? prefs.getString('childAge') ?? childAge;
    final String resolvedType = ageResult?.assessmentType ?? assessmentType;

    final Map<String, dynamic> payload = buildReportPayloadData(
      userId: user.id,
      parentName: user.fullName,
      parentEmail: user.email,
      childName: childName,
      childAge: displayAge,
      childGrade: childGrade,
      assessmentType: resolvedType,
      skillScores: skillScores,
      skillLabels: skillLabels,
      assessedActivities: assessedActivities,
      rawMetrics: rawMetrics,
      parentSignals: parentSignals,
    );

    final Map<String, dynamic> firestorePayload = Map<String, dynamic>.from(payload);
    firestorePayload['createdAt'] = FieldValue.serverTimestamp();

    final docRef =
        await FirebaseFirestore.instance.collection(_reportsCollection).add(firestorePayload);

    await docRef.update(<String, dynamic>{
      'email.status': 'sending',
    });

    final Map<String, dynamic> webhookPayload = Map<String, dynamic>.from(payload);
    webhookPayload['reportId'] = docRef.id;
    webhookPayload['createdAtIso'] = DateTime.now().toUtc().toIso8601String();

    final EmailWebhookResult emailResult =
        await EmailWebhookService.sendAssessmentReport(
      reportPayload: webhookPayload,
    );

    if (emailResult.success) {
      await docRef.update(<String, dynamic>{
        'email.status': 'sent',
        'email.sentAt': FieldValue.serverTimestamp(),
        'email.lastError': null,
        'email.webhookStatusCode': emailResult.statusCode,
        'email.webhookMessage': emailResult.message,
      });
    } else {
      await docRef.update(<String, dynamic>{
        'email.status': 'failed',
        'email.lastError': emailResult.message,
        'email.webhookStatusCode': emailResult.statusCode,
      });
    }
    return docRef.id;
  }

  static Map<String, dynamic> buildReportPayloadData({
    required String userId,
    required String parentName,
    required String parentEmail,
    required String childName,
    required dynamic childAge,
    required String childGrade,
    required String assessmentType,
    required Map<String, double> skillScores,
    required Map<String, String> skillLabels,
    required List<String> assessedActivities,
    required Map<String, dynamic> rawMetrics,
    ParentQuestionnaireSignals parentSignals = const ParentQuestionnaireSignals.unavailable(),
  }) {
    final Map<String, double> normalizedSkills = <String, double>{};
    for (final MapEntry<String, double> entry in skillScores.entries) {
      normalizedSkills[entry.key] = _clampPercent(entry.value);
    }
    final double overall = _clampPercent(_average(normalizedSkills.values.toList()));

    final double completionRate = _safePercent(
      rawMetrics['completedActivities'],
      rawMetrics['totalActivities'],
    );
    final double measuredCoverage = _safePercent(
      rawMetrics['answeredMeasuredActivities'],
      rawMetrics['measuredActivities'],
    );
    final double consistency = _asPercent(rawMetrics['consistencyScore'] ?? 70);
    final double objectiveAccuracy = _asPercent(rawMetrics['objectiveAccuracy'] ?? 60);
    final double durationQuality =
        _durationQuality(rawMetrics['sessionDurationSeconds']);
    final double confidence = _clampPercent(
      (completionRate * 0.28) +
          (measuredCoverage * 0.27) +
          (consistency * 0.2) +
          (objectiveAccuracy * 0.15) +
          (durationQuality * 0.1),
    );

    final Map<String, dynamic> scoreMap = <String, dynamic>{
      ...normalizedSkills,
      'overall': overall,
      'confidence': confidence,
      'dataCoverage': measuredCoverage,
      'attentionPercentage': rawMetrics['attentionPercentage'] != null
          ? _asPercent(rawMetrics['attentionPercentage'])
          : (normalizedSkills['attention'] ?? overall),
    };

    final List<String> orderedSkillKeys = normalizedSkills.keys.toList();

    final Map<String, dynamic> activityLevelDetails = _buildActivityLevelDetails(
      rawMetrics: rawMetrics,
      skillLabels: skillLabels,
    );

    final List<String> insights = _buildInsights(
      normalizedSkills: normalizedSkills,
      skillLabels: skillLabels,
      activityLevelDetails: activityLevelDetails,
      parentSignals: parentSignals,
      assessmentType: assessmentType,
    );
    final List<String> recommendations = _buildRecommendations(
      normalizedSkills: normalizedSkills,
      skillLabels: skillLabels,
      activityLevelDetails: activityLevelDetails,
      parentSignals: parentSignals,
      assessmentType: assessmentType,
    );

    final List<String> strengths = _buildStrengths(
      normalizedSkills: normalizedSkills,
      skillLabels: skillLabels,
      activityLevelDetails: activityLevelDetails,
    );
    final List<String> areasNeedingSupport = _buildAreasNeedingSupport(
      normalizedSkills: normalizedSkills,
      skillLabels: skillLabels,
      activityLevelDetails: activityLevelDetails,
    );

    if (parentSignals.available) {
      if (parentSignals.overallRisk >= 65) {
        insights.add(
          'Parent questionnaire suggests high support need in everyday learning behavior.',
        );
      } else if (parentSignals.overallRisk >= 40) {
        insights.add(
          'Parent questionnaire suggests moderate support need in routine study tasks.',
        );
      } else {
        insights.add(
          'Parent questionnaire indicates relatively low concern in day-to-day learning behavior.',
        );
      }
    }

    final Map<String, dynamic> domainSupportIndicators = _buildDomainSupportIndicators(
      normalizedSkills: normalizedSkills,
      activityLevelDetails: activityLevelDetails,
      parentSignals: parentSignals,
    );

    final List<dynamic>? rawReactionTimes =
        (rawMetrics['reactionTimes'] ?? rawMetrics['responseTimes']) as List<dynamic>?;
    final double? sampleSd = computeSampleSd(rawReactionTimes);

    final bool isAge3to5 = assessmentType == 'age_3_to_5';

    final Map<String, dynamic> howMeasuredPayload = <String, dynamic>{
      'title': 'How This Assessment Was Measured',
      'description':
          'This assessment uses research-supported evaluation methods across gamified activity tasks, camera visual focus tracking, parent observations, and skill progression.',
      'points': <String>[
        'Interactive Game Activities: Children complete engaging tasks measuring accuracy, completion speed, and problem-solving strategies across core learning domains.',
        'Visual Focus Tracking: Real-time camera tracking measures on-screen visual focus without storing video or personal camera data.',
        'Response Speed Consistency: Evaluates how steady a child\'s reaction speed is during timed response activities.',
        if (isAge3to5)
          'Foundational Skill Evaluation: Evaluates performance across age-appropriate skill activities to reflect early learning mastery.'
        else
          '3-Level Skill Progression: Evaluates performance across Level 1 (Foundation), Level 2 (Developing), and Level 3 (Challenge) to reflect complete learning mastery.',
        'Parent Behavioral Signals: Home observations are combined alongside objective activity data to provide a holistic view of learning support needs.',
      ],
    };

    return <String, dynamic>{
      'userId': userId,
      'parentName': parentName,
      'parentEmail': parentEmail,
      'childName': childName,
      'childAge': childAge,
      'childGrade': childGrade,
      'assessmentType': assessmentType,
      'scores': scoreMap,
      'skillLabels': skillLabels,
      'scoredSkillKeys': orderedSkillKeys,
      'assessedActivities': assessedActivities,
      'statusLabel': _statusForOverall(overall),
      'insights': insights,
      'recommendations': recommendations,
      'strengths': strengths,
      'areasNeedingSupport': areasNeedingSupport,
      'rawMetrics': rawMetrics,
      'attentionMetrics': <String, dynamic>{
        'attentionPercentage': rawMetrics['attentionPercentage'] ?? normalizedSkills['attention'] ?? overall,
        'attentiveSeconds': rawMetrics['attentiveSeconds'] ?? 0.0,
        'distractedSeconds': rawMetrics['distractedSeconds'] ?? 0.0,
        'totalAttentionTrackedSeconds': rawMetrics['totalAttentionTrackedSeconds'] ?? 0.0,
        'distractionCount': rawMetrics['distractionCount'] ?? 0,
        'openCvAttentionTracked': rawMetrics['openCvAttentionTracked'] == true,
      },
      'activityLevelDetails': activityLevelDetails,
      'domainSupportIndicators': domainSupportIndicators,
      'accuracyMeta': <String, dynamic>{
        'completionRate': completionRate,
        'measuredCoverage': measuredCoverage,
        'consistencyScore': consistency,
        'objectiveAccuracy': objectiveAccuracy,
        'durationQuality': durationQuality,
        'sdrt': sampleSd,
        'reactionTimeVariabilityText': sampleSd != null
            ? '${sampleSd.toStringAsFixed(0)} ms (Steady response speed)'
            : null,
      },
      'howMeasured': howMeasuredPayload,
      'parentQuestionnaire': <String, dynamic>{
        'available': parentSignals.available,
        'overallRisk': parentSignals.overallRisk,
        'overallSupport': parentSignals.overallSupport,
        'answeredQuestions': parentSignals.answeredQuestions,
        'domainSupportScores': parentSignals.domainSupportScores,
      },
      'modelVersion': _modelVersion,
      'email': <String, dynamic>{
        'provider': 'apps_script_webhook',
        'status': 'queued',
        'queuedAt': null,
        'sentAt': null,
        'lastError': null,
      },
    };
  }

  static String _statusForOverall(double overall) {
    if (overall >= 75) {
      return 'On Track';
    }
    if (overall >= 50) {
      return 'Moderate Support Needed';
    }
    return 'High Support Needed';
  }

  static List<String> _buildStrengths({
    required Map<String, double> normalizedSkills,
    required Map<String, String> skillLabels,
    required Map<String, dynamic> activityLevelDetails,
  }) {
    final List<String> strengths = <String>[];
    final List<Map<String, dynamic>> activityDetails =
        (activityLevelDetails['activityDetails'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    // Identify strong domains without displaying percentage numbers
    for (final MapEntry<String, double> entry in normalizedSkills.entries) {
      final String key = entry.key;
      final String label = skillLabels[key] ?? key;
      final double value = _asPercent(entry.value);

      if (value >= 75) {
        strengths.add('$label — Demonstrates strong performance and well-developed mastery in this area.');
      }
    }

    // High proficiency activities
    final List<Map<String, dynamic>> proficientActivities = activityDetails
        .where((a) => (a['accuracy'] as double) >= 80 && (a['attempts'] as int) > 0)
        .toList();
    if (proficientActivities.isNotEmpty) {
      final String activityNames = proficientActivities.map((a) => a['activityName'] as String).take(3).join(', ');
      strengths.add('High accuracy and strong task execution in: $activityNames.');
    }

    // Low hint usage
    final int totalHints = activityDetails.fold<int>(0, (accumulator, a) => accumulator + ((a['hintsUsed'] as num?)?.toInt() ?? 0));
    if (totalHints <= 3 && activityDetails.isNotEmpty) {
      strengths.add('Independent problem-solving: Completed activities with minimal reliance on hints.');
    }

    if (strengths.length > 4) {
      return strengths.take(4).toList();
    }

    if (strengths.isEmpty) {
      strengths.add('Demonstrates steady engagement and positive participation across assessment activities.');
    }

    return strengths;
  }

  static List<String> _buildAreasNeedingSupport({
    required Map<String, double> normalizedSkills,
    required Map<String, String> skillLabels,
    required Map<String, dynamic> activityLevelDetails,
  }) {
    final List<String> areas = <String>[];
    final List<Map<String, dynamic>> activityDetails =
        (activityLevelDetails['activityDetails'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    // Identify developing/weak domains without displaying percentage numbers
    for (final MapEntry<String, double> entry in normalizedSkills.entries) {
      final String key = entry.key;
      final String label = skillLabels[key] ?? key;
      final double value = _asPercent(entry.value);

      if (value < 50) {
        areas.add('$label — Guided practice and structured activities are recommended to build foundational skills.');
      } else if (value < 65) {
        areas.add('$label — Skills are currently developing; additional practice will help reinforce concepts.');
      }
    }

    // Activities needing attention
    final List<Map<String, dynamic>> weakActivities = activityDetails
        .where((a) => (a['attempts'] as int) > 0 && (a['accuracy'] as double) < 55)
        .toList();
    if (weakActivities.isNotEmpty) {
      final String activityNames = weakActivities.map((a) => a['activityName'] as String).take(3).join(', ');
      areas.add('Specific activities that may benefit from additional practice: $activityNames.');
    }

    // High hint usage
    final int totalHints = activityDetails.fold<int>(0, (accumulator, a) => accumulator + ((a['hintsUsed'] as num?)?.toInt() ?? 0));
    if (totalHints > 8) {
      areas.add('Frequent hint usage — child will benefit from scaffolded instruction and step-by-step guidance.');
    }

    if (areas.length > 5) {
      return areas.take(5).toList();
    }

    if (areas.isEmpty) {
      areas.add('No major areas of concern identified. Continue regular learning routines and monitor progress.');
    }

    return areas;
  }

  static Map<String, dynamic> _buildDomainSupportIndicators({
    required Map<String, double> normalizedSkills,
    required Map<String, dynamic> activityLevelDetails,
    required ParentQuestionnaireSignals parentSignals,
  }) {
    final List<Map<String, dynamic>> activityDetails =
        (activityLevelDetails['activityDetails'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    final Map<String, dynamic> indicators = <String, dynamic>{};

    final List<Map<String, dynamic>> domainConfigs = [
      {
        'key': 'reading_language',
        'label': 'Reading & Language',
        'skills': ['Phonological Awareness', 'Letter-Sound Association', 'Reading Fluency'],
      },
      {
        'key': 'writing_tracing',
        'label': 'Writing & Tracing',
        'skills': ['Letter Construction', 'Fine Motor & Tracing', 'Alphabetical Sequencing'],
      },
      {
        'key': 'math',
        'label': 'Math & Number Sense',
        'skills': ['Number Representation', 'Counting & Quantity'],
      },
      {
        'key': 'attention',
        'label': 'Attention & Focus',
        'skills': ['Sequencing & Focus', 'Visual Discrimination'],
      },
      {
        'key': 'memory',
        'label': 'Memory & Matching',
        'skills': ['Visual Memory & Matching'],
      },
      {
        'key': 'listening',
        'label': 'Listening',
        'skills': ['Auditory Discrimination'],
      },
    ];

    for (final config in domainConfigs) {
      final String key = config['key'] as String;
      final String label = config['label'] as String;
      final List<String> skills = config['skills'] as List<String>;

      final double domainScore = normalizedSkills[key] ?? 100;
      final List<Map<String, dynamic>> domainActivities = activityDetails
          .where((a) => a['domain'] == key)
          .toList();

      final double avgAccuracy = domainActivities.isEmpty
          ? 100
          : domainActivities.map((a) => a['accuracy'] as double).reduce((a, b) => a + b) / domainActivities.length;
      final int maxLevel = domainActivities.isEmpty
          ? 1
          : domainActivities.map((a) => a['selectedLevel'] as int).fold(1, math.max);
      final int level3Count = domainActivities.where((a) => (a['selectedLevel'] as int) == 3).length;

      String supportLevel;
      if (domainScore >= 75) {
        supportLevel = 'On Track';
      } else if (domainScore >= 50) {
        supportLevel = 'Developing';
      } else {
        supportLevel = 'Needs Support';
      }

      String supportColorKey;
      switch (supportLevel) {
        case 'Needs Support':
          supportColorKey = 'red';
          break;
        case 'Developing':
          supportColorKey = 'orange';
          break;
        default:
          supportColorKey = 'green';
      }

      indicators[key] = {
        'label': label,
        'skills': skills,
        'domainScore': _clampPercent(domainScore),
        'averageAccuracy': _clampPercent(avgAccuracy),
        'maxLevelReached': maxLevel,
        'activitiesAtLevel3': level3Count,
        'totalActivities': domainActivities.length,
        'supportLevel': supportLevel,
        'supportColorKey': supportColorKey,
        'activities': domainActivities.map((a) => {
          'activityName': a['activityName'],
          'targetSkill': a['targetSkill'],
          'selectedLevel': a['selectedLevel'],
          'accuracy': a['accuracy'],
          'performanceLevel': a['performanceLevel'],
        }).toList(),
      };
    }

    return indicators;
  }

  static Map<String, dynamic> _buildActivityLevelDetails({
    required Map<String, dynamic> rawMetrics,
    required Map<String, String> skillLabels,
  }) {
    final Map<String, dynamic> adaptiveLearning =
        (rawMetrics['adaptiveLearning'] as Map<String, dynamic>? ?? <String, dynamic>{});

    final Map<String, dynamic> selectedLevels =
        (adaptiveLearning['selectedLevels'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, dynamic> unlockedLevels =
        (adaptiveLearning['unlockedLevels'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, dynamic> accuracy =
        (adaptiveLearning['accuracy'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, dynamic> attempts =
        (adaptiveLearning['attempts'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, dynamic> hintsUsed =
        (adaptiveLearning['hintsUsed'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, dynamic> levelDetailsRaw =
        (adaptiveLearning['levelDetails'] as Map<String, dynamic>? ?? <String, dynamic>{});

    // Unified activity registry for both 3-5 and 6-7 age groups
    final Map<String, Map<String, String>> activityRegistry = {
      // 6-7 Year Activities
      'rhyme': {'domain': 'reading_language', 'name': 'Rhyme-Time Pop', 'skill': 'Phonological Awareness', 'ageGroup': '6_7'},
      'builder': {'domain': 'writing_tracing', 'name': 'Letter Builder', 'skill': 'Letter Construction', 'ageGroup': '6_7'},
      'image': {'domain': 'reading_language', 'name': 'Image-to-Word Snap', 'skill': 'Letter-Sound Association', 'ageGroup': '6_7'},
      'tracing': {'domain': 'writing_tracing', 'name': 'Tracing Practice', 'skill': 'Fine Motor & Tracing', 'ageGroup': '6_7'},
      'numbers': {'domain': 'math', 'name': 'Visual-to-Symbol Table', 'skill': 'Number Representation', 'ageGroup': '6_7'},
      'animals': {'domain': 'math', 'name': 'Animal Counting Corral', 'skill': 'Counting & Quantity', 'ageGroup': '6_7'},
      'dice': {'domain': 'attention', 'name': 'Dice Path Sequencing', 'skill': 'Sequencing & Focus', 'ageGroup': '6_7'},
      'shapes': {'domain': 'attention', 'name': 'Geometric Shape Detective', 'skill': 'Visual Discrimination', 'ageGroup': '6_7'},
      'sorter': {'domain': 'writing_tracing', 'name': 'Letter Sorter', 'skill': 'Alphabetical Sequencing', 'ageGroup': '6_7'},
      'audio': {'domain': 'listening', 'name': 'Audio Explorer', 'skill': 'Auditory Discrimination', 'ageGroup': '6_7'},
      'matching': {'domain': 'memory', 'name': 'Match-Up Forest', 'skill': 'Visual Memory & Matching', 'ageGroup': '6_7'},
      'reading': {'domain': 'reading_language', 'name': 'Reading Rainbow', 'skill': 'Reading Fluency', 'ageGroup': '6_7'},
      // 3-5 Year Activities
      'sound_match': {'domain': 'listening', 'name': 'Sound Match', 'skill': 'Phonemic Awareness', 'ageGroup': '3_5'},
      'rhyme_match': {'domain': 'reading_language', 'name': 'Rhyme Match', 'skill': 'Rhyme Recognition', 'ageGroup': '3_5'},
      'animal_sound': {'domain': 'listening', 'name': 'Animal Sound', 'skill': 'Auditory Discrimination', 'ageGroup': '3_5'},
      'picture_pair': {'domain': 'reading_language', 'name': 'Picture Pair', 'skill': 'Visual-Phonic Matching', 'ageGroup': '3_5'},
      'writing_wizard': {'domain': 'writing_tracing', 'name': 'Writing Wizard', 'skill': 'Letter Construction', 'ageGroup': '3_5'},
      'busy_shapes': {'domain': 'writing_tracing', 'name': 'Busy Shapes', 'skill': 'Shape & Motor Control', 'ageGroup': '3_5'},
      'garden': {'domain': 'writing_tracing', 'name': 'Color Garden', 'skill': 'Fine Motor Coloring', 'ageGroup': '3_5'},
      'missing_letter': {'domain': 'reading_language', 'name': 'Missing Letter', 'skill': 'Alphabet Recognition', 'ageGroup': '3_5'},
      'arrow_tracing': {'domain': 'writing_tracing', 'name': 'Arrow Tracing', 'skill': 'Line & Path Tracing', 'ageGroup': '3_5'},
      'circle_creation': {'domain': 'writing_tracing', 'name': 'Circle Creation', 'skill': 'Circular Motion Control', 'ageGroup': '3_5'},
      'dino_feeding': {'domain': 'attention', 'name': 'Dino Feeding', 'skill': 'Sustained Motor Focus', 'ageGroup': '3_5'},
      'count_objects': {'domain': 'math', 'name': 'Count Objects', 'skill': 'Counting & Quantity', 'ageGroup': '3_5'},
      'find_dots': {'domain': 'math', 'name': 'Find Dots', 'skill': 'Dot Quantity Matching', 'ageGroup': '3_5'},
      'size_choice': {'domain': 'math', 'name': 'Size Comparison', 'skill': 'Size Discrimination', 'ageGroup': '3_5'},
      'sequence_choice': {'domain': 'memory', 'name': 'Number Sequence', 'skill': 'Sequential Number Memory', 'ageGroup': '3_5'},
    };

    final Iterable<String> activeKeys = selectedLevels.isNotEmpty
        ? selectedLevels.keys
        : (accuracy.isNotEmpty ? accuracy.keys : activityRegistry.keys.take(12));

    final List<Map<String, dynamic>> activityDetails = <Map<String, dynamic>>[];

    for (final String activityId in activeKeys) {
      if (!activityRegistry.containsKey(activityId)) continue;
      final Map<String, String> info = activityRegistry[activityId]!;
      final int selectedLevel = (selectedLevels[activityId] as num?)?.toInt() ?? 1;
      final int unlockedLevel = (unlockedLevels[activityId] as num?)?.toInt() ?? 1;
      final double overallAcc = (accuracy[activityId] as num?)?.toDouble() ?? 0.0;
      final int totalAttempts = (attempts[activityId] as num?)?.toInt() ?? 0;
      final int totalHints = (hintsUsed[activityId] as num?)?.toInt() ?? 0;

      final Map<String, dynamic> actLevelDetails =
          (levelDetailsRaw[activityId] as Map<String, dynamic>? ?? <String, dynamic>{});

      final bool is3to5Activity = info['ageGroup'] == '3_5';
      final int maxLvlLoop = is3to5Activity ? 1 : 3;

      int maxLevelReached = 1;
      final List<Map<String, dynamic>> levelsList = <Map<String, dynamic>>[];

      for (int lvl = 1; lvl <= maxLvlLoop; lvl++) {
        final dynamic rawData = actLevelDetails[lvl.toString()];
        final Map<String, dynamic>? lvlData =
            rawData is Map ? Map<String, dynamic>.from(rawData) : null;

        bool levelAttempted = false;
        double levelAcc = 0.0;
        int levelAtt = 0;
        int levelHints = 0;

        if (lvlData != null) {
          levelAttempted = lvlData['attempted'] == true || ((lvlData['attempts'] as num?)?.toInt() ?? 0) > 0;
          levelAcc = (lvlData['accuracy'] as num?)?.toDouble() ?? 0.0;
          levelAtt = (lvlData['attempts'] as num?)?.toInt() ?? 0;
          levelHints = (lvlData['hintsUsed'] as num?)?.toInt() ?? 0;
        } else if (lvl == 1 && totalAttempts > 0) {
          levelAttempted = true;
          levelAcc = overallAcc;
          levelAtt = totalAttempts;
          levelHints = totalHints;
        } else if (lvl <= selectedLevel && totalAttempts > 0) {
          levelAttempted = true;
          levelAcc = overallAcc;
          levelAtt = 1;
          levelHints = 0;
        }

        if (levelAttempted) {
          maxLevelReached = math.max(maxLevelReached, lvl);
        }

        String lvlPerf;
        if (!levelAttempted) {
          lvlPerf = 'Not Assessed';
        } else if (levelAcc >= 80) {
          lvlPerf = 'Proficient';
        } else if (levelAcc >= 50) {
          lvlPerf = 'Developing';
        } else {
          lvlPerf = 'Needs Support';
        }

        levelsList.add({
          'level': lvl,
          'attempted': levelAttempted,
          'accuracy': _clampPercent(levelAcc),
          'attempts': levelAtt,
          'hintsUsed': levelHints,
          'performanceLevel': lvlPerf,
        });
      }
      maxLevelReached = math.max(maxLevelReached, math.max(selectedLevel, unlockedLevel));

      final List<Map<String, dynamic>> attemptedLevels =
          levelsList.where((l) => l['attempted'] == true).toList();

      final double calculatedActivityAccuracy = attemptedLevels.isEmpty
          ? (totalAttempts > 0 ? _clampPercent(overallAcc) : 0.0)
          : attemptedLevels.map((l) => l['accuracy'] as double).reduce((a, b) => a + b) / attemptedLevels.length;

      String overallPerformanceLevel;
      if (totalAttempts == 0 && attemptedLevels.isEmpty) {
        overallPerformanceLevel = 'Not Assessed';
      } else if (calculatedActivityAccuracy >= 80) {
        overallPerformanceLevel = 'Proficient';
      } else if (calculatedActivityAccuracy >= 50) {
        overallPerformanceLevel = 'Developing';
      } else {
        overallPerformanceLevel = 'Needs Support';
      }

      activityDetails.add({
        'activityId': activityId,
        'activityName': info['name'],
        'targetSkill': info['skill'],
        'domain': info['domain'],
        'ageGroup': info['ageGroup'],
        'selectedLevel': selectedLevel,
        'unlockedLevel': unlockedLevel,
        'highestLevelReached': maxLevelReached,
        'accuracy': _clampPercent(calculatedActivityAccuracy),
        'attempts': totalAttempts > 0 ? totalAttempts : attemptedLevels.length,
        'hintsUsed': totalHints,
        'performanceLevel': overallPerformanceLevel,
        'domainLabel': skillLabels[info['domain']] ?? info['domain'],
        'levels': levelsList,
      });
    }

    // Group by domain
    final Map<String, List<Map<String, dynamic>>> domainActivities = <String, List<Map<String, dynamic>>>{};
    for (final detail in activityDetails) {
      final String domain = detail['domain'] as String;
      domainActivities.putIfAbsent(domain, () => <Map<String, dynamic>>[]).add(detail);
    }

    // Compute domain-level summaries
    final Map<String, Map<String, dynamic>> domainSummaries = <String, Map<String, dynamic>>{};
    for (final MapEntry<String, List<Map<String, dynamic>>> domainEntry in domainActivities.entries) {
      final String domain = domainEntry.key;
      final List<Map<String, dynamic>> activities = domainEntry.value;
      final List<Map<String, dynamic>> attempted = activities.where((a) => (a['attempts'] as int) > 0 || (a['performanceLevel'] != 'Not Assessed')).toList();
      final double avgAccuracy = attempted.isEmpty
          ? 0
          : attempted.map((a) => a['accuracy'] as double).reduce((a, b) => a + b) / attempted.length;
      final int maxLevel = activities.map((a) => (a['highestLevelReached'] as int?) ?? 1).fold(1, math.max);
      final int activitiesAtLevel3 = activities.where((a) => ((a['highestLevelReached'] as int?) ?? 1) == 3).length;

      domainSummaries[domain] = {
        'domainLabel': skillLabels[domain] ?? domain,
        'averageAccuracy': _clampPercent(avgAccuracy),
        'maxLevelReached': maxLevel,
        'activitiesAtLevel3': activitiesAtLevel3,
        'totalActivities': activities.length,
        'activities': activities,
      };
    }

    return {
      'activityDetails': activityDetails,
      'domainSummaries': domainSummaries,
    };
  }

  static List<String> _buildInsights({
    required Map<String, double> normalizedSkills,
    required Map<String, String> skillLabels,
    required Map<String, dynamic> activityLevelDetails,
    required ParentQuestionnaireSignals parentSignals,
    required String assessmentType,
  }) {
    final List<String> insights = <String>[];
    final Map<String, dynamic> domainSummaries =
        (activityLevelDetails['domainSummaries'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final List<Map<String, dynamic>> activityDetails =
        (activityLevelDetails['activityDetails'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    final bool isSingleLevel = assessmentType == 'age_3_to_5';

    // Overall domain insights - cleaner wording without percentage repetition
    for (final MapEntry<String, double> entry in normalizedSkills.entries) {
      final String key = entry.key;
      final String label = skillLabels[key] ?? key;
      final double value = _asPercent(entry.value);
      final Map<String, dynamic> domainSummary =
          (domainSummaries[key] as Map<String, dynamic>? ?? <String, dynamic>{});
      final int maxLevel = (domainSummary['maxLevelReached'] as num?)?.toInt() ?? 1;
      final double avgAcc = (domainSummary['averageAccuracy'] as num?)?.toDouble() ?? 0.0;

      if (isSingleLevel) {
        if (value >= 75) {
          insights.add('$label — Strong performance with ${avgAcc.toStringAsFixed(0)}% average accuracy.');
        } else if (value >= 50) {
          insights.add('$label — Developing skills with ${avgAcc.toStringAsFixed(0)}% average accuracy; consider targeted practice.');
        } else {
          insights.add('$label — Needs more practice (average accuracy: ${avgAcc.toStringAsFixed(0)}%).');
        }
      } else {
        if (value >= 75) {
          insights.add('$label — Strong performance. Reached Level $maxLevel with ${avgAcc.toStringAsFixed(0)}% average accuracy.');
        } else if (value >= 50) {
          insights.add('$label — Developing skills. Reached Level $maxLevel with ${avgAcc.toStringAsFixed(0)}% average accuracy; consider targeted practice.');
        } else {
          insights.add('$label — Needs more practice. Max level reached: $maxLevel, average accuracy: ${avgAcc.toStringAsFixed(0)}%.');
        }
      }
    }

    // Activity-specific insights for areas of concern
    final List<Map<String, dynamic>> weakActivities = activityDetails
        .where((a) => (a['attempts'] as int) > 0 && (a['accuracy'] as double) < 50)
        .toList();
    if (weakActivities.isNotEmpty) {
      final String weakNames = weakActivities.map((a) => a['activityName'] as String).join(', ');
      insights.add('Activities needing attention: $weakNames — consider revisiting these with guided support.');
    }

    // Level progression insights - only for multi-level assessments
    if (!isSingleLevel) {
      final List<Map<String, dynamic>> level3Activities = activityDetails
          .where((a) => (a['selectedLevel'] as int) == 3)
          .toList();
      if (level3Activities.isNotEmpty) {
        final String level3Names = level3Activities.map((a) => a['activityName'] as String).join(', ');
        insights.add('Reached Level 3 in: $level3Names.');
      }
    }

    // Hints usage insight
    final int totalHints = activityDetails.fold<int>(0, (accumulator, a) => accumulator + ((a['hintsUsed'] as num?)?.toInt() ?? 0));
    if (totalHints > 8) {
      insights.add('Frequent hint usage ($totalHints hints across activities) — child may benefit from more scaffolded instruction and confidence-building.');
    }

    return insights;
  }

  static List<String> _buildRecommendations({
    required Map<String, double> normalizedSkills,
    required Map<String, String> skillLabels,
    required Map<String, dynamic> activityLevelDetails,
    required ParentQuestionnaireSignals parentSignals,
    required String assessmentType,
  }) {
    final List<String> actions = <String>[];
    final Map<String, dynamic> domainSummaries =
        (activityLevelDetails['domainSummaries'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final bool isSingleLevel = assessmentType == 'age_3_to_5';

    // Sort domains by score (ascending) to prioritize weakest areas
    final List<MapEntry<String, double>> rankedDomains = normalizedSkills.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => a.value.compareTo(b.value));

    for (final MapEntry<String, double> item in rankedDomains.take(4)) {
      final String domain = item.key;
      final String label = skillLabels[domain] ?? domain;
      final double value = _asPercent(item.value);
      final Map<String, dynamic> domainSummary = (domainSummaries[domain] as Map<String, dynamic>? ?? <String, dynamic>{});
      final int maxLevel = (domainSummary['maxLevelReached'] as num?)?.toInt() ?? 1;
      final List<Map<String, dynamic>> activities = (domainSummary['activities'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final List<Map<String, dynamic>> weakActivities = activities.where((a) => (a['accuracy'] as double) < 60).toList();
      final String weakActivityNames = weakActivities.map((a) => a['activityName'] as String).join(', ');
      final String levelLine = isSingleLevel ? '' : '\n• Max level reached: $maxLevel';

      if (value < 50) {
        actions.add('$label: Needs more practice\n• Daily 10-15 min guided practice\n• Focus: ${weakActivityNames.isEmpty ? 'general domain practice' : weakActivityNames}$levelLine');
      } else if (value < 70) {
        actions.add('$label: Developing skill\n• 3-4 structured practice sessions per week\n• Focus: ${weakActivityNames.isEmpty ? 'skill consolidation' : weakActivityNames}$levelLine');
      } else {
        final String enrichmentActivities = activities.where((a) => (a['selectedLevel'] as int) >= 2).map((a) => a['activityName']).join(', ');
        actions.add('$label: On track\n• Maintain current progress with weekly check-ins\n• Continue enrichment: ${enrichmentActivities.isEmpty ? 'current activities' : enrichmentActivities}$levelLine');
      }
    }

    // Cross-domain recommendations based on skill patterns (no diagnostic language)
    final double readingScore = normalizedSkills['reading_language'] ?? 0;
    final double writingScore = normalizedSkills['writing_tracing'] ?? 0;
    final double mathScore = normalizedSkills['math'] ?? 0;
    final double attentionScore = normalizedSkills['attention'] ?? 0;
    final double memoryScore = normalizedSkills['memory'] ?? 0;

    if (readingScore < 55 && writingScore < 55) {
      actions.add('Reading & Writing Support\n• Multi-sensory phonics (letter-sound-tracing)\n• Decodable texts and handwriting practice\n• 4 sessions per week');
    }
    if (mathScore < 55) {
      actions.add('Math Foundations\n• Concrete manipulatives for quantity\n• Number line practice and daily counting\n• Hands-on number games');
    }
    if (attentionScore < 55) {
      actions.add('Attention & Focus\n• Short 2-3 min timed tasks\n• Visual schedules and movement breaks\n• Simple sequencing and sorting games');
    }
    if (memoryScore < 55) {
      actions.add('Memory Support\n• Chunking strategies and visual aids\n• Repeated retrieval practice\n• Matching and sequencing games');
    }


    if (actions.isEmpty) {
      actions.add('Continue regular learning routines and weekly progress checks.');
    }

    return actions;
  }

  /// Computes Sample Standard Deviation for Reaction Time Variability:
  /// SDRT = sqrt( sum( (RT_i - mean)^2 ) / (N - 1) )
  /// Requires N >= 3 valid observations. Returns null if N < 3 or values unavailable.
  static double? computeSampleSd(List<dynamic>? rawTimes) {
    if (rawTimes == null) return null;
    final List<double> validTimes = rawTimes
        .whereType<num>()
        .map((e) => e.toDouble())
        .where((t) => t > 0)
        .toList();
    if (validTimes.length < 3) return null;

    final double mean = validTimes.reduce((a, b) => a + b) / validTimes.length;
    double sumSqDiff = 0.0;
    for (final double t in validTimes) {
      final double diff = t - mean;
      sumSqDiff += diff * diff;
    }
    return math.sqrt(sumSqDiff / (validTimes.length - 1));
  }

  static double _safePercent(dynamic numeratorRaw, dynamic denominatorRaw) {
    final double numerator = _asPercent(numeratorRaw);
    final double denominator = _asPercent(denominatorRaw);
    if (denominator <= 0) {
      return 0;
    }
    return _clampPercent((numerator / denominator) * 100);
  }

  static double _asPercent(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static double _durationQuality(dynamic sessionSecondsRaw) {
    final double sessionSeconds = _asPercent(sessionSecondsRaw);
    if (sessionSeconds <= 0) {
      return 45;
    }
    if (sessionSeconds < 90) {
      return 30;
    }
    if (sessionSeconds < 180) {
      return 55;
    }
    if (sessionSeconds < 360) {
      return 78;
    }
    if (sessionSeconds < 1800) {
      return 88;
    }
    return 72;
  }

  static Future<ParentQuestionnaireSignals> _loadParentQuestionnaireSignals(
    String userId,
  ) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('questionnaire_responses')
          .where('userId', isEqualTo: userId)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) {
        return const ParentQuestionnaireSignals.unavailable();
      }

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
          List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.docs);
      docs.sort((a, b) {
        final Timestamp? aTs = a.data()['timestamp'] as Timestamp?;
        final Timestamp? bTs = b.data()['timestamp'] as Timestamp?;
        return (bTs?.millisecondsSinceEpoch ?? 0)
            .compareTo(aTs?.millisecondsSinceEpoch ?? 0);
      });

      final Map<String, dynamic> latest = docs.first.data();
      final Map<String, dynamic> responsesRaw =
          (latest['responses'] as Map<String, dynamic>? ?? <String, dynamic>{});

      final Map<int, int> responses = <int, int>{};
      responsesRaw.forEach((String key, dynamic value) {
        final int? index = int.tryParse(key);
        final int? score = value is num ? value.toInt() : int.tryParse('$value');
        if (index != null && score != null) {
          responses[index] = score.clamp(0, 3);
        }
      });

      if (responses.isEmpty) {
        return const ParentQuestionnaireSignals.unavailable();
      }

      final double readingRisk = _averageRisk(responses, <int>[3, 4, 5]);
      final double writingRisk = _averageRisk(responses, <int>[6, 7, 8, 9]);
      final double mathRisk = _averageRisk(responses, <int>[10, 11, 12]);
      final double attentionRisk =
          _averageRisk(responses, <int>[13, 14, 15, 16, 17]);
      final double behaviorRisk =
          _averageRisk(responses, <int>[0, 1, 2, 18, 19, 20, 21]);
      final double listeningRisk = _averageRisk(responses, <int>[15, 13, 14]);
      final double memoryRisk = _averageRisk(responses, <int>[15, 14, 17]);
      final double overallRisk = _average(<double>[
        readingRisk,
        writingRisk,
        mathRisk,
        attentionRisk,
        behaviorRisk,
      ]);

      return ParentQuestionnaireSignals(
        available: true,
        overallRisk: _clampPercent(overallRisk),
        overallSupport: _clampPercent(100 - overallRisk),
        answeredQuestions: responses.length,
        domainSupportScores: <String, double>{
          'reading': _clampPercent(100 - readingRisk),
          'writing': _clampPercent(100 - writingRisk),
          'math': _clampPercent(100 - mathRisk),
          'attention': _clampPercent(100 - attentionRisk),
          'behavior': _clampPercent(100 - behaviorRisk),
          'listening': _clampPercent(100 - listeningRisk),
          'memory': _clampPercent(100 - memoryRisk),
        },
      );
    } catch (_) {
      return const ParentQuestionnaireSignals.unavailable();
    }
  }

  static double _averageRisk(Map<int, int> responses, List<int> indices) {
    final List<double> values = <double>[];
    for (final int index in indices) {
      if (responses.containsKey(index)) {
        values.add((responses[index]! / 3) * 100);
      }
    }
    if (values.isEmpty) {
      return 50;
    }
    return _average(values);
  }


  static double _clampPercent(double value) {
    return math.max(0, math.min(100, value)).toDouble();
  }

  static double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final double total = values.fold<double>(0, (double a, double b) => a + b);
    return total / values.length;
  }
}

class ParentQuestionnaireSignals {
  const ParentQuestionnaireSignals({
    required this.available,
    required this.overallRisk,
    required this.overallSupport,
    required this.answeredQuestions,
    required this.domainSupportScores,
  });

  const ParentQuestionnaireSignals.unavailable()
      : available = false,
        overallRisk = 0,
        overallSupport = 0,
        answeredQuestions = 0,
        domainSupportScores = const <String, double>{};

  final bool available;
  final double overallRisk;
  final double overallSupport;
  final int answeredQuestions;
  final Map<String, double> domainSupportScores;
}
