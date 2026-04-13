import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'email_webhook_service.dart';

class AssessmentReportService {
  static const String _reportsCollection = 'assessment_reports';
  static const String _modelVersion = 'v1.0.0';

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
    };

    final List<String> orderedSkillKeys = normalizedSkills.keys.toList();
    final List<String> insights = _buildInsights(
      normalizedSkills: normalizedSkills,
      skillLabels: skillLabels,
    );
    final List<String> recommendations = _buildRecommendations(
      normalizedSkills: normalizedSkills,
      skillLabels: skillLabels,
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
      'rawMetrics': rawMetrics,
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
      'rawMetrics': rawMetrics,
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

  static List<String> _buildInsights({
    required Map<String, double> normalizedSkills,
    required Map<String, String> skillLabels,
  }) {
    final List<String> insights = <String>[];
    for (final MapEntry<String, double> entry in normalizedSkills.entries) {
      final String key = entry.key;
      final String label = skillLabels[key] ?? key;
      final double value = _asPercent(entry.value);
      if (value >= 75) {
        insights.add('Shows strong $label skills in this assessment.');
      } else if (value >= 50) {
        insights.add('Shows developing $label skills with room to improve.');
      } else {
        insights.add('Needs targeted support in $label activities.');
      }
    }

    return insights;
  }

  static List<String> _buildRecommendations({
    required Map<String, double> normalizedSkills,
    required Map<String, String> skillLabels,
  }) {
    final List<MapEntry<String, double>> ranked = normalizedSkills.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          a.value.compareTo(b.value));

    final List<String> actions = <String>[];
    for (final MapEntry<String, double> item in ranked.take(3)) {
      final String label = skillLabels[item.key] ?? item.key;
      final String lower = label.toLowerCase();
      if (lower.contains('reading') || lower.contains('language')) {
        actions.add('Do 10-minute daily phonics and read-aloud sessions.');
      } else if (lower.contains('writing') || lower.contains('motor')) {
        actions.add('Practice tracing, letter formation, and short copying tasks.');
      } else if (lower.contains('attention') || lower.contains('focus')) {
        actions.add('Use short focused tasks with clear breaks and rewards.');
      } else if (lower.contains('memory')) {
        actions.add('Play recall and sequencing games using pictures and words.');
      } else if (lower.contains('math') || lower.contains('number')) {
        actions.add('Use hands-on counting and pattern games for number confidence.');
      } else if (lower.contains('listening')) {
        actions.add('Do short listen-and-respond games with simple verbal instructions.');
      } else {
        actions.add('Continue guided practice with short daily activities in $label.');
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
