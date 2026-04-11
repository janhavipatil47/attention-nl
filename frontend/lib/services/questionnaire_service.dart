import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestionnaireService {
  static const String _localResponsesKey = 'questionnaire_responses_local';

  static const List<String> questions = [
    'My child gets frustrated when learning something new',
    'My child gives up easily when tasks become difficult',
    'My child needs help to complete age-appropriate tasks',
    'My child has difficulty recognizing or reading words',
    'My child confuses similar-looking letters (b/d, p/q)',
    'My child avoids reading activities',
    'My child’s handwriting is difficult to understand',
    'My child has trouble forming letters correctly',
    'My child takes longer than expected to complete writing tasks',
    'My child avoids writing activities',
    'My child has difficulty understanding basic numbers or counting',
    'My child struggles with simple calculations',
    'My child avoids math-related activities',
    'My child is easily distracted',
    'My child has difficulty staying focused on tasks',
    'My child needs repeated instructions',
    'My child has difficulty sitting still when required',
    'My child acts without thinking',
    'My child gets upset during learning activities',
    'My child shows hesitation or anxiety toward schoolwork',
    'Teachers have expressed concerns about my child’s learning',
    'My child needs close supervision for studies',
  ];

  static const List<String> responseOptions = [
    'Never',
    'Sometimes',
    'Often',
    'Very Often',
  ];

  static const Map<int, int> responseScores = {
    0: 0,
    1: 1,
    2: 2,
    3: 3,
  };

  static int calculateTotalScore(Map<int, int> responses) {
    var totalScore = 0;

    for (final entry in responses.entries) {
      final selectedOption = entry.value;
      final score = responseScores[selectedOption];

      if (score == null) {
        throw ArgumentError.value(
          selectedOption,
          'selectedOption',
          'Each response must be one of 0, 1, 2, or 3.',
        );
      }

      totalScore += score;
    }

    return totalScore;
  }

  static void validateResponses(Map<int, int> responses) {
    if (responses.length != questions.length) {
      throw ArgumentError(
        'All ${questions.length} questions must be answered before submission.',
      );
    }

    for (final entry in responses.entries) {
      if (entry.key < 0 || entry.key >= questions.length) {
        throw ArgumentError.value(
          entry.key,
          'questionIndex',
          'Question index is out of range.',
        );
      }

      if (!responseScores.containsKey(entry.value)) {
        throw ArgumentError.value(
          entry.value,
          'selectedOption',
          'Each response must be one of 0, 1, 2, or 3.',
        );
      }
    }
  }

  static Future<int> submitQuestionnaireResponses({
    required String userId,
    required Map<int, int> responses,
    String? additionalObservations,
  }) async {
    validateResponses(responses);

    final totalScore = calculateTotalScore(responses);
    final firestoreResponses = responses.map(
      (questionIndex, selectedOption) => MapEntry(
        questionIndex.toString(),
        selectedOption,
      ),
    );

    await FirebaseFirestore.instance.collection('questionnaire_responses').add({
      'userId': userId,
      'timestamp': DateTime.now().toUtc(),
      'responses': firestoreResponses,
      'totalScore': totalScore,
      'additionalObservations': additionalObservations?.trim() ?? '',
    });

    return totalScore;
  }

  static Future<int> submitQuestionnaireResponsesLocally({
    required String userId,
    required Map<int, int> responses,
    String? additionalObservations,
  }) async {
    validateResponses(responses);

    final totalScore = calculateTotalScore(responses);
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_localResponsesKey) ?? <String>[];

    final payload = <String, dynamic>{
      'userId': userId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'responses': responses.map(
        (questionIndex, selectedOption) => MapEntry(
          questionIndex.toString(),
          selectedOption,
        ),
      ),
      'totalScore': totalScore,
      'additionalObservations': additionalObservations?.trim() ?? '',
    };

    existing.add(jsonEncode(payload));
    await prefs.setStringList(_localResponsesKey, existing);

    return totalScore;
  }

  static Future<List<Map<String, dynamic>>> loadLocalQuestionnaireResponses() async {
    final prefs = await SharedPreferences.getInstance();
    final storedResponses = prefs.getStringList(_localResponsesKey) ?? <String>[];

    return storedResponses
        .map((encoded) => jsonDecode(encoded) as Map<String, dynamic>)
        .toList();
  }

  static String responseLabelFor(int selectedOption) {
    if (selectedOption < 0 || selectedOption >= responseOptions.length) {
      throw ArgumentError.value(
        selectedOption,
        'selectedOption',
        'Each response must be one of 0, 1, 2, or 3.',
      );
    }

    return responseOptions[selectedOption];
  }
}