import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/assessment_report_service.dart';

void main() {
  group('AssessmentReportService Calculations & Logic Tests', () {
    final Map<String, String> skillLabels = {
      'reading_language': 'Reading & Language',
      'writing_tracing': 'Writing & Tracing',
      'math': 'Math & Number Sense',
      'attention': 'Attention & Focus',
      'memory': 'Memory & Matching',
      'listening': 'Listening',
    };

    final List<String> assessedActivities = [
      'Rhyme-Time Pop',
      'Letter Builder',
      'Image-to-Word Snap',
      'Tracing Practice',
      'Visual-to-Symbol Table',
      'Animal Counting Corral',
      'Dice Path Sequencing',
      'Geometric Shape Detective',
      'Letter Sorter',
      'Audio Explorer',
      'Match-Up Forest',
      'Reading Rainbow',
    ];

    test('1. Equal performance across all activities yields equal domain and overall scores', () {
      final skillScores = {
        'reading_language': 80.0,
        'writing_tracing': 80.0,
        'math': 80.0,
        'attention': 80.0,
        'memory': 80.0,
        'listening': 80.0,
      };

      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Test Parent',
        parentEmail: 'parent@test.com',
        childName: 'Alex',
        childAge: 6,
        childGrade: 'Grade 1',
        assessmentType: 'age_6_to_7',
        skillScores: skillScores,
        skillLabels: skillLabels,
        assessedActivities: assessedActivities,
        rawMetrics: {
          'completedActivities': 12,
          'totalActivities': 12,
          'adaptiveLearning': {
            'selectedLevels': {'rhyme': 2, 'builder': 2},
            'accuracy': {'rhyme': 80.0, 'builder': 80.0},
            'attempts': {'rhyme': 10, 'builder': 10},
          }
        },
      );

      final scores = payload['scores'] as Map<String, dynamic>;
      expect(scores['overall'], equals(80.0));
      expect(scores['reading_language'], equals(80.0));
      expect(payload['statusLabel'], equals('On Track'));
    });

    test('2. Overall score is the exact arithmetic mean of active domain scores', () {
      final skillScores = {
        'reading_language': 100.0,
        'writing_tracing': 50.0,
        'math': 75.0,
        'attention': 25.0,
      };

      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Test Parent',
        parentEmail: 'parent@test.com',
        childName: 'Alex',
        childAge: 5,
        childGrade: 'K',
        assessmentType: 'age_3_to_5',
        skillScores: skillScores,
        skillLabels: skillLabels,
        assessedActivities: assessedActivities,
        rawMetrics: {'completedActivities': 4, 'totalActivities': 4},
      );

      final scores = payload['scores'] as Map<String, dynamic>;
      // Mean of 100, 50, 75, 25 = 250 / 4 = 62.5
      expect(scores['overall'], equals(62.5));
    });

    test('3. Mixed activity scores calculate correct domain activity average', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'Sam',
        childAge: 6,
        childGrade: 'Grade 1',
        assessmentType: 'age_6_to_7',
        skillScores: {'reading_language': 75.0},
        skillLabels: skillLabels,
        assessedActivities: ['Rhyme-Time Pop', 'Image-to-Word Snap'],
        rawMetrics: {
          'completedActivities': 2,
          'totalActivities': 12,
          'adaptiveLearning': {
            'selectedLevels': {'rhyme': 1, 'image': 2},
            'accuracy': {'rhyme': 50.0, 'image': 100.0},
            'attempts': {'rhyme': 10, 'image': 10},
          }
        },
      );

      final details = payload['activityLevelDetails'] as Map<String, dynamic>;
      final domainSummaries = details['domainSummaries'] as Map<String, dynamic>;
      final readingSummary = domainSummaries['reading_language'] as Map<String, dynamic>;

      // Mean of 50.0 and 100.0 = 75.0
      expect(readingSummary['averageAccuracy'], equals(75.0));
    });

    test('4. Incomplete assessments and missing activities are handled safely without division by zero', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'Leo',
        childAge: 4,
        childGrade: 'Pre-K',
        assessmentType: 'age_3_to_5',
        skillScores: {'math': 40.0},
        skillLabels: skillLabels,
        assessedActivities: [],
        rawMetrics: {
          'completedActivities': 0,
          'totalActivities': 15,
          'adaptiveLearning': {
            'selectedLevels': <String, dynamic>{},
            'accuracy': <String, dynamic>{},
            'attempts': <String, dynamic>{},
          }
        },
      );

      final scores = payload['scores'] as Map<String, dynamic>;
      expect(scores['overall'], equals(40.0));
      expect(payload['statusLabel'], equals('High Support Needed'));
    });

    test('5. Invalid activity IDs in rawMetrics are filtered safely', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'Mia',
        childAge: 6,
        childGrade: '1st',
        assessmentType: 'age_6_to_7',
        skillScores: {'reading_language': 90.0},
        skillLabels: skillLabels,
        assessedActivities: [],
        rawMetrics: {
          'adaptiveLearning': {
            'selectedLevels': {'rhyme': 1, 'INVALID_ACTIVITY_XYZ': 3},
            'accuracy': {'rhyme': 90.0, 'INVALID_ACTIVITY_XYZ': 10.0},
            'attempts': {'rhyme': 5, 'INVALID_ACTIVITY_XYZ': 5},
          }
        },
      );

      final details = payload['activityLevelDetails'] as Map<String, dynamic>;
      final activityDetails = details['activityDetails'] as List<dynamic>;
      expect(activityDetails.length, equals(1));
      expect(activityDetails.first['activityId'], equals('rhyme'));
    });

    test('6. Zero score and 100% score limits are respected', () {
      final payloadZero = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'ZeroChild',
        childAge: 5,
        childGrade: 'K',
        assessmentType: 'age_3_to_5',
        skillScores: {'math': 0.0, 'memory': 0.0},
        skillLabels: skillLabels,
        assessedActivities: [],
        rawMetrics: {},
      );
      expect((payloadZero['scores'] as Map<String, dynamic>)['overall'], equals(0.0));

      final payloadPerfect = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'PerfectChild',
        childAge: 5,
        childGrade: 'K',
        assessmentType: 'age_3_to_5',
        skillScores: {'math': 100.0, 'memory': 100.0},
        skillLabels: skillLabels,
        assessedActivities: [],
        rawMetrics: {},
      );
      expect((payloadPerfect['scores'] as Map<String, dynamic>)['overall'], equals(100.0));
    });

    test('7. Changing an underlying activity score changes activity accuracy, domain summary, and overall scores dynamically', () {
      Map<String, dynamic> buildWithScore(double rhymeAcc) {
        return AssessmentReportService.buildReportPayloadData(
          userId: 'user_123',
          parentName: 'Parent',
          parentEmail: 'parent@test.com',
          childName: 'DynamicChild',
          childAge: 6,
          childGrade: 'Grade 1',
          assessmentType: 'age_6_to_7',
          skillScores: {'reading_language': rhymeAcc},
          skillLabels: skillLabels,
          assessedActivities: ['Rhyme-Time Pop'],
          rawMetrics: {
            'adaptiveLearning': {
              'selectedLevels': {'rhyme': 1},
              'accuracy': {'rhyme': rhymeAcc},
              'attempts': {'rhyme': 10},
            }
          },
        );
      }

      final payload1 = buildWithScore(40.0);
      final payload2 = buildWithScore(90.0);

      final score1 = (payload1['scores'] as Map<String, dynamic>)['overall'];
      final score2 = (payload2['scores'] as Map<String, dynamic>)['overall'];

      expect(score1, equals(40.0));
      expect(score2, equals(90.0));
      expect(score1 != score2, isTrue);
    });

    test('8. Parent questionnaire signals CANNOT mutate or weight child cognitive scores', () {
      final skillScores = {'math': 80.0, 'reading_language': 70.0};

      final payloadWithoutParent = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'Child',
        childAge: 6,
        childGrade: '1',
        assessmentType: 'age_6_to_7',
        skillScores: skillScores,
        skillLabels: skillLabels,
        assessedActivities: [],
        rawMetrics: {},
        parentSignals: const ParentQuestionnaireSignals.unavailable(),
      );

      final payloadWithExtremeParentRisk = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'Child',
        childAge: 6,
        childGrade: '1',
        assessmentType: 'age_6_to_7',
        skillScores: skillScores,
        skillLabels: skillLabels,
        assessedActivities: [],
        rawMetrics: {},
        parentSignals: const ParentQuestionnaireSignals(
          available: true,
          overallRisk: 95.0, // High risk
          overallSupport: 5.0, // Low support
          answeredQuestions: 15,
          domainSupportScores: {'math': 10.0, 'reading': 10.0},
        ),
      );

      final scores1 = payloadWithoutParent['scores'] as Map<String, dynamic>;
      final scores2 = payloadWithExtremeParentRisk['scores'] as Map<String, dynamic>;

      expect(scores1['overall'], equals(scores2['overall']));
      expect(scores1['math'], equals(scores2['math']));
      expect(scores1['reading_language'], equals(scores2['reading_language']));
    });

    test('9. Visual Attention metrics: Valid gaze data is properly preserved', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'GazeChild',
        childAge: 6,
        childGrade: 'Grade 1',
        assessmentType: 'age_6_to_7',
        skillScores: {'attention': 85.0},
        skillLabels: skillLabels,
        assessedActivities: [],
        rawMetrics: {
          'attentionPercentage': 88.5,
          'attentiveSeconds': 177.0,
          'distractedSeconds': 23.0,
          'totalAttentionTrackedSeconds': 200.0,
          'distractionCount': 2,
          'openCvAttentionTracked': true,
        },
      );

      final attMetrics = payload['attentionMetrics'] as Map<String, dynamic>;
      expect(attMetrics['openCvAttentionTracked'], isTrue);
      expect(attMetrics['attentionPercentage'], equals(88.5));
      expect(attMetrics['attentiveSeconds'], equals(177.0));
      expect(attMetrics['distractionCount'], equals(2));
    });

    test('10. Visual Attention metrics: Missing gaze data sets openCvAttentionTracked to false without fabricated 100% fallback', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'NoGazeChild',
        childAge: 6,
        childGrade: 'Grade 1',
        assessmentType: 'age_6_to_7',
        skillScores: {'attention': 60.0},
        skillLabels: skillLabels,
        assessedActivities: [],
        rawMetrics: {
          'completedActivities': 12,
          'totalActivities': 12,
        },
      );

      final attMetrics = payload['attentionMetrics'] as Map<String, dynamic>;
      expect(attMetrics['openCvAttentionTracked'], isFalse);
      expect(attMetrics['totalAttentionTrackedSeconds'], equals(0.0));
    });

    test('11. Text generation for Strengths and Areas to Practice contains NO percentage values', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'TextCheckChild',
        childAge: 5,
        childGrade: 'K',
        assessmentType: 'age_3_to_5',
        skillScores: {
          'reading_language': 90.0,
          'math': 40.0,
          'writing_tracing': 60.0,
        },
        skillLabels: skillLabels,
        assessedActivities: [],
        rawMetrics: {
          'adaptiveLearning': {
            'selectedLevels': {'rhyme': 1, 'numbers': 1},
            'accuracy': {'rhyme': 90.0, 'numbers': 40.0},
            'attempts': {'rhyme': 10, 'numbers': 10},
            'hintsUsed': {'rhyme': 1, 'numbers': 9},
          }
        },
      );

      final List<String> strengths = List<String>.from(payload['strengths']);
      final List<String> areas = List<String>.from(payload['areasNeedingSupport']);

      final percentRegex = RegExp(r'\d+%');
      for (final item in strengths) {
        expect(percentRegex.hasMatch(item), isFalse, reason: 'Strength item should not contain %: $item');
      }
      for (final item in areas) {
        expect(percentRegex.hasMatch(item), isFalse, reason: 'Area item should not contain %: $item');
      }
    });

    test('12. 6-7 Age Group: Only Level 1 attempted preserves L1 and marks L2/L3 as Not Assessed', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'ChildL1',
        childAge: 6,
        childGrade: 'Grade 1',
        assessmentType: 'age_6_to_7',
        skillScores: {'reading_language': 80.0},
        skillLabels: skillLabels,
        assessedActivities: ['Rhyme-Time Pop'],
        rawMetrics: {
          'completedActivities': 1,
          'totalActivities': 12,
          'adaptiveLearning': {
            'selectedLevels': {'rhyme': 1},
            'unlockedLevels': {'rhyme': 1},
            'accuracy': {'rhyme': 80.0},
            'attempts': {'rhyme': 5},
            'hintsUsed': {'rhyme': 0},
            'levelDetails': {
              'rhyme': {
                '1': {'accuracy': 80.0, 'attempts': 5, 'hintsUsed': 0, 'attempted': true}
              }
            }
          }
        },
      );

      final details = payload['activityLevelDetails'] as Map<String, dynamic>;
      final activityList = details['activityDetails'] as List<dynamic>;
      final rhymeAct = activityList.firstWhere((a) => a['activityId'] == 'rhyme');

      expect(rhymeAct['highestLevelReached'], equals(1));
      expect(rhymeAct['accuracy'], equals(80.0));

      final levels = rhymeAct['levels'] as List<dynamic>;
      expect(levels.length, equals(3));
      expect(levels[0]['attempted'], isTrue);
      expect(levels[0]['accuracy'], equals(80.0));
      expect(levels[1]['attempted'], isFalse);
      expect(levels[1]['performanceLevel'], equals('Not Assessed'));
      expect(levels[2]['attempted'], isFalse);
      expect(levels[2]['performanceLevel'], equals('Not Assessed'));
    });

    test('13. 6-7 Age Group: Levels 1 and 2 attempted preserves both levels and calculates overall activity score', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'ChildL2',
        childAge: 6,
        childGrade: 'Grade 1',
        assessmentType: 'age_6_to_7',
        skillScores: {'reading_language': 80.0},
        skillLabels: skillLabels,
        assessedActivities: ['Rhyme-Time Pop'],
        rawMetrics: {
          'completedActivities': 1,
          'totalActivities': 12,
          'adaptiveLearning': {
            'selectedLevels': {'rhyme': 2},
            'unlockedLevels': {'rhyme': 2},
            'accuracy': {'rhyme': 70.0},
            'attempts': {'rhyme': 10},
            'hintsUsed': {'rhyme': 0},
            'levelDetails': {
              'rhyme': {
                '1': {'accuracy': 90.0, 'attempts': 5, 'hintsUsed': 0, 'attempted': true},
                '2': {'accuracy': 70.0, 'attempts': 5, 'hintsUsed': 0, 'attempted': true}
              }
            }
          }
        },
      );

      final details = payload['activityLevelDetails'] as Map<String, dynamic>;
      final activityList = details['activityDetails'] as List<dynamic>;
      final rhymeAct = activityList.firstWhere((a) => a['activityId'] == 'rhyme');

      expect(rhymeAct['highestLevelReached'], equals(2));
      // Arithmetic mean of L1 (90%) and L2 (70%) = 80%
      expect(rhymeAct['accuracy'], equals(80.0));

      final levels = rhymeAct['levels'] as List<dynamic>;
      expect(levels[0]['attempted'], isTrue);
      expect(levels[0]['accuracy'], equals(90.0));
      expect(levels[1]['attempted'], isTrue);
      expect(levels[1]['accuracy'], equals(70.0));
      expect(levels[2]['attempted'], isFalse);
      expect(levels[2]['performanceLevel'], equals('Not Assessed'));
    });

    test('14. 6-7 Age Group: All 3 levels attempted retains L1, L2, L3 without dropping Level 1', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'ChildL3',
        childAge: 6,
        childGrade: 'Grade 1',
        assessmentType: 'age_6_to_7',
        skillScores: {'reading_language': 80.0},
        skillLabels: skillLabels,
        assessedActivities: ['Rhyme-Time Pop'],
        rawMetrics: {
          'completedActivities': 1,
          'totalActivities': 12,
          'adaptiveLearning': {
            'selectedLevels': {'rhyme': 3},
            'unlockedLevels': {'rhyme': 3},
            'accuracy': {'rhyme': 60.0},
            'attempts': {'rhyme': 15},
            'hintsUsed': {'rhyme': 1},
            'levelDetails': {
              'rhyme': {
                '1': {'accuracy': 90.0, 'attempts': 5, 'hintsUsed': 0, 'attempted': true},
                '2': {'accuracy': 80.0, 'attempts': 5, 'hintsUsed': 0, 'attempted': true},
                '3': {'accuracy': 70.0, 'attempts': 5, 'hintsUsed': 1, 'attempted': true}
              }
            }
          }
        },
      );

      final details = payload['activityLevelDetails'] as Map<String, dynamic>;
      final activityList = details['activityDetails'] as List<dynamic>;
      final rhymeAct = activityList.firstWhere((a) => a['activityId'] == 'rhyme');

      expect(rhymeAct['highestLevelReached'], equals(3));
      // Arithmetic mean of 90, 80, 70 = 80.0
      expect(rhymeAct['accuracy'], equals(80.0));

      final levels = rhymeAct['levels'] as List<dynamic>;
      expect(levels.length, equals(3));
      expect(levels[0]['accuracy'], equals(90.0));
      expect(levels[1]['accuracy'], equals(80.0));
      expect(levels[2]['accuracy'], equals(70.0));
      expect(levels.every((l) => l['attempted'] == true), isTrue);
    });

    test('15. 3-5 Age Group: Level text (Level X / Max level reached) is completely omitted from insights and recommendations', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'Child3to5',
        childAge: 4,
        childGrade: 'Pre-K',
        assessmentType: 'age_3_to_5',
        skillScores: {'reading_language': 80.0, 'math': 50.0},
        skillLabels: skillLabels,
        assessedActivities: ['Rhyme Match', 'Count Objects'],
        rawMetrics: {
          'completedActivities': 2,
          'totalActivities': 15,
          'adaptiveLearning': {
            'selectedLevels': {'rhyme_match': 1, 'count_objects': 1},
            'accuracy': {'rhyme_match': 80.0, 'count_objects': 50.0},
            'attempts': {'rhyme_match': 5, 'count_objects': 5},
          }
        },
      );

      final List<String> recommendations = List<String>.from(payload['recommendations']);
      final List<String> insights = List<String>.from(payload['insights']);

      for (final rec in recommendations) {
        expect(rec.contains('Max level reached:'), isFalse, reason: 'Recommendation should not specify Max level reached for age 3-5: $rec');
      }
      for (final insight in insights) {
        expect(insight.contains('Reached Level'), isFalse, reason: 'Insight should not specify Reached Level for age 3-5: $insight');
        expect(insight.contains('Max level reached:'), isFalse, reason: 'Insight should not specify Max level reached for age 3-5: $insight');
      }
    });

    test('16. Reaction Time Variability (SDRT) calculates sample SD (N-1 formula) for N >= 3 and returns null for N < 3', () {
      // 3 trials: [100, 200, 300] -> mean = 200, diffs = [-100, 0, 100], sumSq = 20000.
      // Sample SD (N-1 = 2): sqrt(20000 / 2) = sqrt(10000) = 100.0.
      final double? sdrt3 = AssessmentReportService.computeSampleSd([100, 200, 300]);
      expect(sdrt3, equals(100.0));

      // 2 trials: N < 3 returns null
      final double? sdrt2 = AssessmentReportService.computeSampleSd([100, 200]);
      expect(sdrt2, isNull);

      // Empty / null list returns null
      final double? sdrtEmpty = AssessmentReportService.computeSampleSd([]);
      expect(sdrtEmpty, isNull);
    });

    test('17. Report payload includes "How this assessment was measured" section payload', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'MeasuredChild',
        childAge: 6,
        childGrade: '1',
        assessmentType: 'age_6_to_7',
        skillScores: {'reading_language': 80.0},
        skillLabels: skillLabels,
        assessedActivities: ['Rhyme-Time Pop'],
        rawMetrics: {'completedActivities': 1, 'totalActivities': 12},
      );

      final howMeasured = payload['howMeasured'] as Map<String, dynamic>?;
      expect(howMeasured, isNotNull);
      expect(howMeasured!['title'], equals('How This Assessment Was Measured'));
      expect((howMeasured['points'] as List).length, greaterThanOrEqualTo(4));
    });

    test('18. Zero medical diagnostic wording assertion across all generated report content', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'SafeChild',
        childAge: 6,
        childGrade: '1',
        assessmentType: 'age_6_to_7',
        skillScores: {
          'reading_language': 30.0,
          'writing_tracing': 40.0,
          'math': 35.0,
          'attention': 25.0,
        },
        skillLabels: skillLabels,
        assessedActivities: ['Rhyme-Time Pop', 'Letter Builder'],
        rawMetrics: {'completedActivities': 2, 'totalActivities': 12},
        parentSignals: const ParentQuestionnaireSignals(
          available: true,
          overallRisk: 80.0,
          overallSupport: 20.0,
          answeredQuestions: 20,
          domainSupportScores: {'math': 20.0, 'reading': 20.0},
        ),
      );

      final String fullContentString = [
        ...payload['insights'] as List,
        ...payload['recommendations'] as List,
        ...payload['strengths'] as List,
        ...payload['areasNeedingSupport'] as List,
        payload['statusLabel'] as String,
        ...((payload['howMeasured'] as Map)['points'] as List),
      ].join(' ').toLowerCase();

      final List<String> prohibitedWords = [
        'dyslexia',
        'dysgraphia',
        'dyscalculia',
        'adhd',
        'diagnosis',
        'disease',
        'clinical risk',
        'disorder',
      ];

      for (final word in prohibitedWords) {
        expect(
          fullContentString.contains(word),
          isFalse,
          reason: 'Generated report content must NOT contain medical diagnostic term: "$word"',
        );
      }
    });

    test('19. Multi-attempt activities reflect exact attempt counts in report output', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'ChildAttempts',
        childAge: 6,
        childGrade: 'Grade 1',
        assessmentType: 'age_6_to_7',
        skillScores: {'reading_language': 80.0},
        skillLabels: skillLabels,
        assessedActivities: ['Rhyme-Time Pop', 'Letter Builder'],
        rawMetrics: {
          'completedActivities': 2,
          'totalActivities': 12,
          'adaptiveLearning': {
            'selectedLevels': {'rhyme': 1, 'builder': 1},
            'unlockedLevels': {'rhyme': 1, 'builder': 1},
            'accuracy': {'rhyme': 75.0, 'builder': 100.0},
            'attempts': {'rhyme': 4, 'builder': 2},
            'hintsUsed': {'rhyme': 0, 'builder': 0},
            'levelDetails': {
              'rhyme': {
                '1': {'accuracy': 75.0, 'attempts': 4, 'hintsUsed': 0, 'attempted': true}
              },
              'builder': {
                '1': {'accuracy': 100.0, 'attempts': 2, 'hintsUsed': 0, 'attempted': true}
              }
            }
          }
        },
      );

      final details = payload['activityLevelDetails'] as Map<String, dynamic>;
      final activityList = details['activityDetails'] as List<dynamic>;
      final rhymeAct = activityList.firstWhere((a) => a['activityId'] == 'rhyme');
      final builderAct = activityList.firstWhere((a) => a['activityId'] == 'builder');

      expect(rhymeAct['attempts'], equals(4));
      expect(builderAct['attempts'], equals(2));
    });

    test('20. 3-5 Age Group: Report logic restricts activity levels to a single level and contains no Level 2/3 or Level 1 labeling', () {
      final payload = AssessmentReportService.buildReportPayloadData(
        userId: 'user_123',
        parentName: 'Parent',
        parentEmail: 'parent@test.com',
        childName: 'LittleLearner',
        childAge: 4,
        childGrade: 'Pre-K',
        assessmentType: 'age_3_to_5',
        skillScores: {'listening': 85.0, 'reading_language': 75.0},
        skillLabels: skillLabels,
        assessedActivities: ['Sound Match', 'Rhyme Match'],
        rawMetrics: {
          'completedActivities': 2,
          'totalActivities': 15,
          'adaptiveLearning': {
            'selectedLevels': {'sound_match': 1, 'rhyme_match': 1},
            'accuracy': {'sound_match': 85.0, 'rhyme_match': 75.0},
            'attempts': {'sound_match': 3, 'rhyme_match': 4},
          }
        },
      );

      final details = payload['activityLevelDetails'] as Map<String, dynamic>;
      final activityList = details['activityDetails'] as List<dynamic>;
      final soundMatchAct = activityList.firstWhere((a) => a['activityId'] == 'sound_match');

      // 3-5 age group activities must have exactly 1 level in levels list
      final levels = soundMatchAct['levels'] as List<dynamic>;
      expect(levels.length, equals(1));
      expect(levels[0]['level'], equals(1));

      // howMeasured payload points for 3-5 age group must not mention 3-Level Skill Progression
      final howMeasured = payload['howMeasured'] as Map<String, dynamic>;
      final points = List<String>.from(howMeasured['points']);
      expect(points.any((p) => p.contains('3-Level Skill Progression')), isFalse);
      expect(points.any((p) => p.contains('Foundational Skill Evaluation')), isTrue);
    });
  });
}
