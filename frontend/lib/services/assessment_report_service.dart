import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'email_webhook_service.dart';

class AssessmentReportService {
  static const String _reportsCollection = 'assessment_reports';
  static const String _modelVersion = 'v1.2.0';

  static Future<String> createAssessmentReport({
    required String assessmentType,
    required int childAge,
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

    final Map<String, double> normalizedSkills = <String, double>{};
    for (final MapEntry<String, double> entry in skillScores.entries) {
      final double childScore = _clampPercent(entry.value);
      final double parentSupport = _parentSupportForSkill(
        skillKey: entry.key,
        parentSignals: parentSignals,
      );
      normalizedSkills[entry.key] = parentSignals.available
          ? _clampPercent((childScore * 0.72) + (parentSupport * 0.28))
          : childScore;
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

    // Build detailed activity-level performance data
    final Map<String, dynamic> activityLevelDetails = _buildActivityLevelDetails(
      rawMetrics: rawMetrics,
      skillLabels: skillLabels,
    );

    final List<String> insights = _buildInsights(
      normalizedSkills: normalizedSkills,
      skillLabels: skillLabels,
      activityLevelDetails: activityLevelDetails,
      parentSignals: parentSignals,
    );
    final List<String> recommendations = _buildRecommendations(
      normalizedSkills: normalizedSkills,
      skillLabels: skillLabels,
      activityLevelDetails: activityLevelDetails,
      parentSignals: parentSignals,
    );

    // Build strengths and areas needing support
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

    // Build domain support indicators (replaces disorder risk indicators)
    final Map<String, dynamic> domainSupportIndicators = _buildDomainSupportIndicators(
      normalizedSkills: normalizedSkills,
      activityLevelDetails: activityLevelDetails,
      parentSignals: parentSignals,
    );

    final Map<String, dynamic> payload = <String, dynamic>{
      'userId': user.id,
      'parentName': user.fullName,
      'parentEmail': user.email,
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
      },
      'parentQuestionnaire': <String, dynamic>{
        'available': parentSignals.available,
        'overallRisk': parentSignals.overallRisk,
        'overallSupport': parentSignals.overallSupport,
        'answeredQuestions': parentSignals.answeredQuestions,
        'domainSupportScores': parentSignals.domainSupportScores,
      },
      'modelVersion': _modelVersion,
      'createdAt': FieldValue.serverTimestamp(),
      'email': <String, dynamic>{
        'provider': 'apps_script_webhook',
        'status': 'queued',
        'queuedAt': FieldValue.serverTimestamp(),
        'sentAt': null,
        'lastError': null,
      },
    };

    final docRef =
        await FirebaseFirestore.instance.collection(_reportsCollection).add(payload);

    await docRef.update(<String, dynamic>{
      'email.status': 'sending',
    });

    final Map<String, dynamic> webhookPayload = <String, dynamic>{
      'reportId': docRef.id,
      'userId': user.id,
      'parentName': user.fullName,
      'parentEmail': user.email,
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
      'activityLevelDetails': activityLevelDetails,
      'domainSupportIndicators': domainSupportIndicators,
      'parentQuestionnaire': <String, dynamic>{
        'available': parentSignals.available,
        'overallRisk': parentSignals.overallRisk,
        'overallSupport': parentSignals.overallSupport,
        'answeredQuestions': parentSignals.answeredQuestions,
        'domainSupportScores': parentSignals.domainSupportScores,
      },
      'modelVersion': _modelVersion,
      'createdAtIso': DateTime.now().toUtc().toIso8601String(),
    };

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
    final Map<String, dynamic> domainSummaries =
        (activityLevelDetails['domainSummaries'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final List<Map<String, dynamic>> activityDetails =
        (activityLevelDetails['activityDetails'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    // Find domains with strong performance (overall normalized score >= 75)
    for (final MapEntry<String, double> entry in normalizedSkills.entries) {
      final String key = entry.key;
      final String label = skillLabels[key] ?? key;
      final double value = _asPercent(entry.value);
      final Map<String, dynamic> domainSummary =
          (domainSummaries[key] as Map<String, dynamic>? ?? <String, dynamic>{});
      final int maxLevel = (domainSummary['maxLevelReached'] as num?)?.toInt() ?? 1;
      final double avgAcc = (domainSummary['averageAccuracy'] as num?)?.toDouble() ?? 0.0;

      if (value >= 75) {
        strengths.add('$label — Strong performance (${value.toStringAsFixed(0)}% overall). Reached Level $maxLevel with ${avgAcc.toStringAsFixed(0)}% average accuracy. This skill area is well-developed.');
      }
    }

    // Find activities where child reached highest level AND performed well (accuracy >= 80)
    final List<Map<String, dynamic>> level3Proficient = activityDetails
        .where((a) => (a['selectedLevel'] as int) == 3 && (a['accuracy'] as double) >= 80)
        .toList();
    if (level3Proficient.isNotEmpty) {
      final String activityNames = level3Proficient.map((a) => a['activityName'] as String).join(', ');
      strengths.add('Completed advanced levels with high accuracy in: $activityNames.');
    }

    // Find activities with consistent strong performance (accuracy >= 85, attempts <= 2)
    final List<Map<String, dynamic>> consistentStrong = activityDetails
        .where((a) => (a['accuracy'] as double) >= 85 && (a['attempts'] as int) <= 2)
        .toList();
    if (consistentStrong.isNotEmpty) {
      final String activityNames = consistentStrong.map((a) => a['activityName'] as String).join(', ');
      strengths.add('Consistent accuracy: $activityNames — completed with minimal attempts and high precision.');
    }

    // Low hint usage as a strength
    final int totalHints = activityDetails.fold<int>(0, (accumulator, a) => accumulator + ((a['hintsUsed'] as num?)?.toInt() ?? 0));
    if (totalHints <= 3 && activityDetails.isNotEmpty) {
      strengths.add('Independent problem-solving: Used very few hints ($totalHints total) across activities — shows confidence and self-reliance.');
    }

    // Limit to max 4 strengths
    if (strengths.length > 4) {
      return strengths.take(4).toList();
    }

    if (strengths.isEmpty) {
      strengths.add('The assessment provides a baseline for tracking progress over time. Continued engagement will help identify emerging strengths.');
    }

    return strengths;
  }

  static List<String> _buildAreasNeedingSupport({
    required Map<String, double> normalizedSkills,
    required Map<String, String> skillLabels,
    required Map<String, dynamic> activityLevelDetails,
  }) {
    final List<String> areas = <String>[];
    final Map<String, dynamic> domainSummaries =
        (activityLevelDetails['domainSummaries'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final List<Map<String, dynamic>> activityDetails =
        (activityLevelDetails['activityDetails'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    // Find domains with weaker performance
    for (final MapEntry<String, double> entry in normalizedSkills.entries) {
      final String key = entry.key;
      final String label = skillLabels[key] ?? key;
      final double value = _asPercent(entry.value);
      final Map<String, dynamic> domainSummary =
          (domainSummaries[key] as Map<String, dynamic>? ?? <String, dynamic>{});
      final int maxLevel = (domainSummary['maxLevelReached'] as num?)?.toInt() ?? 1;
      final double avgAcc = (domainSummary['averageAccuracy'] as num?)?.toDouble() ?? 0.0;

      if (value < 50) {
        areas.add('$label — Needs more practice (${value.toStringAsFixed(0)}% overall). Max level reached: $maxLevel. Average accuracy: ${avgAcc.toStringAsFixed(0)}%. Consider more guided practice in this area.');
      } else if (value < 65) {
        areas.add('$label — Developing (${value.toStringAsFixed(0)}% overall). Max level reached: $maxLevel. Average accuracy: ${avgAcc.toStringAsFixed(0)}%. Targeted practice may help strengthen this area.');
      }
    }

    // Find activities with low accuracy (but only if attempted)
    final List<Map<String, dynamic>> weakActivities = activityDetails
        .where((a) => (a['attempts'] as int) > 0 && (a['accuracy'] as double) < 50)
        .toList();
    if (weakActivities.isNotEmpty) {
      final String activityNames = weakActivities.map((a) => a['activityName'] as String).join(', ');
      areas.add('Specific activities needing attention: $activityNames — consider revisiting these at a lower level with guided support.');
    }

    // Find activities where performance dropped at higher levels
    final List<Map<String, dynamic>> levelDrops = activityDetails
        .where((a) => (a['selectedLevel'] as int) >= 2 && (a['accuracy'] as double) < 60)
        .toList();
    if (levelDrops.isNotEmpty) {
      final String activityNames = levelDrops.map((a) => a['activityName'] as String).join(', ');
      areas.add('Difficulty with increased complexity: $activityNames — performance decreased as task difficulty increased. More practice at lower levels recommended before advancing.');
    }

    // High hint usage
    final int totalHints = activityDetails.fold<int>(0, (accumulator, a) => accumulator + ((a['hintsUsed'] as num?)?.toInt() ?? 0));
    if (totalHints > 8) {
      areas.add('Frequent hint usage ($totalHints hints total) — child may benefit from more scaffolded instruction and confidence-building activities.');
    }

    // High attempts with low accuracy
    final List<Map<String, dynamic>> highAttemptsLowAccuracy = activityDetails
        .where((a) => (a['attempts'] as int) > 5 && (a['accuracy'] as double) < 70)
        .toList();
    if (highAttemptsLowAccuracy.isNotEmpty) {
      final String activityNames = highAttemptsLowAccuracy.map((a) => a['activityName'] as String).join(', ');
      areas.add('Repeated attempts with inconsistent results: $activityNames — consider breaking tasks into smaller steps with more guidance.');
    }

    // Limit to max 5 areas
    if (areas.length > 5) {
      return areas.take(5).toList();
    }

    if (areas.isEmpty) {
      areas.add('No significant areas of concern identified. Continue regular learning activities and monitor progress.');
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
        'activities': ['rhyme', 'image', 'reading'],
        'skills': ['Phonological Awareness', 'Letter-Sound Association', 'Reading Fluency'],
      },
      {
        'key': 'writing_tracing',
        'label': 'Writing & Tracing',
        'activities': ['builder', 'tracing', 'sorter'],
        'skills': ['Letter Construction', 'Fine Motor & Tracing', 'Alphabetical Sequencing'],
      },
      {
        'key': 'math',
        'label': 'Math & Number Sense',
        'activities': ['numbers', 'animals'],
        'skills': ['Number Representation', 'Counting & Quantity'],
      },
      {
        'key': 'attention',
        'label': 'Attention & Focus',
        'activities': ['dice', 'shapes'],
        'skills': ['Sequencing & Focus', 'Visual Discrimination'],
      },
      {
        'key': 'memory',
        'label': 'Memory & Matching',
        'activities': ['matching'],
        'skills': ['Visual Memory & Matching'],
      },
      {
        'key': 'listening',
        'label': 'Listening',
        'activities': ['audio'],
        'skills': ['Auditory Discrimination'],
      },
    ];

    for (final config in domainConfigs) {
      final String key = config['key'] as String;
      final String label = config['label'] as String;
      final List<String> activityIds = config['activities'] as List<String>;
      final List<String> skills = config['skills'] as List<String>;

      final double domainScore = normalizedSkills[key] ?? 100;
      final List<Map<String, dynamic>> domainActivities = activityDetails
          .where((a) => activityIds.contains(a['activityId']))
          .toList();

      final double avgAccuracy = domainActivities.isEmpty
          ? 100
          : domainActivities.map((a) => a['accuracy'] as double).reduce((a, b) => a + b) / domainActivities.length;
      final int maxLevel = domainActivities.isEmpty
          ? 1
          : domainActivities.map((a) => a['selectedLevel'] as int).reduce(math.max);
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

      final List<String> observations = <String>[];
      if (domainScore < 60) {
        observations.add('Below-average domain score (${domainScore.toStringAsFixed(0)}%)');
      }
      if (avgAccuracy < 60) {
        observations.add('Low accuracy in activities (${avgAccuracy.toStringAsFixed(0)}%)');
      }
      if (level3Count == 0 && domainActivities.isNotEmpty) {
        observations.add('Did not reach Level 3 in any activity');
      }
      if (maxLevel < 2 && domainActivities.isNotEmpty) {
        observations.add('Maximum level reached: $maxLevel');
      }

      // Parent questionnaire alignment
      if (parentSignals.available) {
        final Map<String, double> parentSupport = parentSignals.domainSupportScores;
        String parentDomainKey = key;
        if (key == 'reading_language') parentDomainKey = 'reading';
        if (key == 'writing_tracing') parentDomainKey = 'writing';
        final double parentSupportScore = parentSupport[parentDomainKey] ?? 100;
        if (parentSupportScore < 60 && domainScore < 60) {
          observations.add('Parent questionnaire also indicates support needed in this area');
        }
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
        'observations': observations,
        'parentSupportScore': parentSignals.available 
            ? _clampPercent(parentSignals.domainSupportScores[key == 'reading_language' ? 'reading' : key == 'writing_tracing' ? 'writing' : key] ?? 100)
            : 0,
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

    // Map activity IDs to their domain and display names
    final Map<String, Map<String, String>> activityInfo = {
      'rhyme': {'domain': 'reading_language', 'name': 'Rhyme-Time Pop', 'skill': 'Phonological Awareness'},
      'builder': {'domain': 'writing_tracing', 'name': 'Letter Builder', 'skill': 'Letter Construction'},
      'image': {'domain': 'reading_language', 'name': 'Image-to-Word Snap', 'skill': 'Letter-Sound Association'},
      'tracing': {'domain': 'writing_tracing', 'name': 'Tracing Practice', 'skill': 'Fine Motor & Tracing'},
      'numbers': {'domain': 'math', 'name': 'Visual-to-Symbol Table', 'skill': 'Number Representation'},
      'animals': {'domain': 'math', 'name': 'Animal Counting Corral', 'skill': 'Counting & Quantity'},
      'dice': {'domain': 'attention', 'name': 'Dice Path Sequencing', 'skill': 'Sequencing & Focus'},
      'shapes': {'domain': 'attention', 'name': 'Geometric Shape Detective', 'skill': 'Visual Discrimination'},
      'sorter': {'domain': 'writing_tracing', 'name': 'Letter Sorter', 'skill': 'Alphabetical Sequencing'},
      'audio': {'domain': 'listening', 'name': 'Audio Explorer', 'skill': 'Auditory Discrimination'},
      'matching': {'domain': 'memory', 'name': 'Match-Up Forest', 'skill': 'Visual Memory & Matching'},
      'reading': {'domain': 'reading_language', 'name': 'Reading Rainbow', 'skill': 'Reading Fluency'},
    };

    final List<Map<String, dynamic>> activityDetails = <Map<String, dynamic>>[];

    for (final MapEntry<String, Map<String, String>> entry in activityInfo.entries) {
      final String activityId = entry.key;
      final Map<String, String> info = entry.value;
      final int selectedLevel = (selectedLevels[activityId] as num?)?.toInt() ?? 1;
      final int unlockedLevel = (unlockedLevels[activityId] as num?)?.toInt() ?? 1;
      final double activityAccuracy = (accuracy[activityId] as num?)?.toDouble() ?? 0.0;
      final int activityAttempts = (attempts[activityId] as num?)?.toInt() ?? 0;
      final int activityHints = (hintsUsed[activityId] as num?)?.toInt() ?? 0;

      String performanceLevel;
      if (activityAccuracy >= 80) {
        performanceLevel = 'Proficient';
      } else if (activityAccuracy >= 50) {
        performanceLevel = 'Developing';
      } else {
        performanceLevel = 'Needs Support';
      }

      activityDetails.add({
        'activityId': activityId,
        'activityName': info['name'],
        'targetSkill': info['skill'],
        'domain': info['domain'],
        'selectedLevel': selectedLevel,
        'unlockedLevel': unlockedLevel,
        'accuracy': _clampPercent(activityAccuracy),
        'attempts': activityAttempts,
        'hintsUsed': activityHints,
        'performanceLevel': performanceLevel,
        'domainLabel': skillLabels[info['domain']] ?? info['domain'],
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
      final double avgAccuracy = activities.isEmpty
          ? 0
          : activities.map((a) => a['accuracy'] as double).reduce((a, b) => a + b) / activities.length;
      final int maxLevel = activities.map((a) => a['selectedLevel'] as int).reduce(math.max);
      final int activitiesAtLevel3 = activities.where((a) => a['selectedLevel'] as int == 3).length;

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
  }) {
    final List<String> insights = <String>[];
    final Map<String, dynamic> domainSummaries =
        (activityLevelDetails['domainSummaries'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final List<Map<String, dynamic>> activityDetails =
        (activityLevelDetails['activityDetails'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    // Overall domain insights - cleaner wording without percentage repetition
    for (final MapEntry<String, double> entry in normalizedSkills.entries) {
      final String key = entry.key;
      final String label = skillLabels[key] ?? key;
      final double value = _asPercent(entry.value);
      final Map<String, dynamic> domainSummary =
          (domainSummaries[key] as Map<String, dynamic>? ?? <String, dynamic>{});
      final int maxLevel = (domainSummary['maxLevelReached'] as num?)?.toInt() ?? 1;
      final double avgAcc = (domainSummary['averageAccuracy'] as num?)?.toDouble() ?? 0.0;

      if (value >= 75) {
        insights.add('$label — Strong performance. Reached Level $maxLevel with ${avgAcc.toStringAsFixed(0)}% average accuracy.');
      } else if (value >= 50) {
        insights.add('$label — Developing skills. Reached Level $maxLevel with ${avgAcc.toStringAsFixed(0)}% average accuracy; consider targeted practice.');
      } else {
        insights.add('$label — Needs more practice. Max level reached: $maxLevel, average accuracy: ${avgAcc.toStringAsFixed(0)}%.');
      }
    }

    // Activity-specific insights for areas of concern
    final List<Map<String, dynamic>> weakActivities = activityDetails
        .where((a) => (a['attempts'] as int) > 0 && (a['accuracy'] as double) < 50)
        .toList();
    if (weakActivities.isNotEmpty) {
      final String weakNames = weakActivities.map((a) => a['activityName'] as String).join(', ');
      insights.add('Activities needing attention: $weakNames — consider revisiting these at a lower level with guided support.');
    }

    // Level progression insights - only mention level reached, not "readiness"
    final List<Map<String, dynamic>> level3Activities = activityDetails
        .where((a) => (a['selectedLevel'] as int) == 3)
        .toList();
    if (level3Activities.isNotEmpty) {
      final String level3Names = level3Activities.map((a) => a['activityName'] as String).join(', ');
      insights.add('Reached Level 3 in: $level3Names.');
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
  }) {
    final List<String> actions = <String>[];
    final Map<String, dynamic> domainSummaries =
        (activityLevelDetails['domainSummaries'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final List<Map<String, dynamic>> activityDetails =
        (activityLevelDetails['activityDetails'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

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

      if (value < 50) {
        actions.add('$label: Needs more practice\n• Daily 10-15 min guided practice\n• Focus: ${weakActivityNames.isEmpty ? 'general domain practice' : weakActivityNames}\n• Max level reached: $maxLevel');
      } else if (value < 70) {
        actions.add('$label: Developing skill\n• 3-4 structured practice sessions per week\n• Focus: ${weakActivityNames.isEmpty ? 'skill consolidation' : weakActivityNames}\n• Max level reached: $maxLevel');
      } else {
        final String enrichmentActivities = activities.where((a) => (a['selectedLevel'] as int) >= 2).map((a) => a['activityName']).join(', ');
        actions.add('$label: On track\n• Maintain current progress with weekly check-ins\n• Continue enrichment: ${enrichmentActivities.isEmpty ? 'current activities' : enrichmentActivities}\n• Max level reached: $maxLevel');
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

    // Parent questionnaire alignment - educational language only
    if (parentSignals.available) {
      final Map<String, double> parentSupport = parentSignals.domainSupportScores;
      final double parentReading = parentSupport['reading'] ?? 100;
      final double parentWriting = parentSupport['writing'] ?? 100;
      final double parentMath = parentSupport['math'] ?? 100;

      if (parentReading < 60 && readingScore < 60) {
        actions.add('Reading: Parent observations and assessment align — consider consulting a reading specialist for further evaluation.');
      }
      if (parentWriting < 60 && writingScore < 60) {
        actions.add('Writing: Parent observations and assessment align — consider occupational therapy evaluation for fine motor skills.');
      }
      if (parentMath < 60 && mathScore < 60) {
        actions.add('Math: Parent observations and assessment align — consider educational evaluation for number sense development.');
      }
    }

    if (actions.isEmpty) {
      actions.add('Continue regular learning routines and weekly progress checks.');
    }

    return actions;
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

  static double _parentSupportForSkill({
    required String skillKey,
    required ParentQuestionnaireSignals parentSignals,
  }) {
    if (!parentSignals.available) {
      return 70;
    }
    final String key = skillKey.toLowerCase();
    final Map<String, double> support = parentSignals.domainSupportScores;

    if (key.contains('math')) {
      return support['math'] ?? parentSignals.overallSupport;
    }
    if (key.contains('listen')) {
      return support['listening'] ?? parentSignals.overallSupport;
    }
    if (key.contains('read')) {
      return support['reading'] ?? parentSignals.overallSupport;
    }
    if (key.contains('writ') || key.contains('motor') || key.contains('tracing')) {
      return support['writing'] ?? parentSignals.overallSupport;
    }
    if (key.contains('attention') || key.contains('focus')) {
      return support['attention'] ?? parentSignals.overallSupport;
    }
    if (key.contains('memory')) {
      return support['memory'] ?? parentSignals.overallSupport;
    }
    return parentSignals.overallSupport;
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
