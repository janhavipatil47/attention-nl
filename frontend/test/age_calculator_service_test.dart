import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/age_calculator_service.dart';

void main() {
  group('AgeCalculatorService Unit Tests', () {
    final DateTime refDate = DateTime(2026, 9, 18); // Fixed reference date for deterministic testing

    test('Test 1: DOB produces exactly 3 years', () {
      final dob = DateTime(2023, 9, 18);
      final result = AgeCalculatorService.calculateAge(dob, refDate);

      expect(result.years, equals(3));
      expect(result.months, equals(0));
      expect(result.days, equals(0));
      expect(result.formattedAge, equals('3 years'));
      expect(result.assessmentType, equals('age_3_to_5'));
      expect(result.assessmentGroupLabel, equals('3–5 years'));
      expect(result.isAge3To5, isTrue);
    });

    test('Test 2: DOB produces 3 years 6 months (3.5 years)', () {
      final dob = DateTime(2023, 3, 18);
      final result = AgeCalculatorService.calculateAge(dob, refDate);

      expect(result.years, equals(3));
      expect(result.months, equals(6));
      expect(result.formattedAge, equals('3 years 6 months'));
      expect(result.fractionalYears, equals(3.5));
      expect(result.assessmentType, equals('age_3_to_5'));
      expect(result.assessmentGroupLabel, equals('3–5 years'));
    });

    test('Test 3: DOB produces 4 years 6 months (4.5 years)', () {
      final dob = DateTime(2022, 3, 18);
      final result = AgeCalculatorService.calculateAge(dob, refDate);

      expect(result.years, equals(4));
      expect(result.months, equals(6));
      expect(result.formattedAge, equals('4 years 6 months'));
      expect(result.fractionalYears, equals(4.5));
      expect(result.assessmentType, equals('age_3_to_5'));
      expect(result.assessmentGroupLabel, equals('3–5 years'));
    });

    test('Test 4: DOB produces 5 years 6 months (5.5 years)', () {
      final dob = DateTime(2021, 3, 18);
      final result = AgeCalculatorService.calculateAge(dob, refDate);

      expect(result.years, equals(5));
      expect(result.months, equals(6));
      expect(result.formattedAge, equals('5 years 6 months'));
      expect(result.fractionalYears, equals(5.5));
      expect(result.assessmentType, equals('age_3_to_5'));
      expect(result.assessmentGroupLabel, equals('3–5 years'));
    });

    test('Test 5: DOB produces exactly 6 years', () {
      final dob = DateTime(2020, 9, 18);
      final result = AgeCalculatorService.calculateAge(dob, refDate);

      expect(result.years, equals(6));
      expect(result.months, equals(0));
      expect(result.formattedAge, equals('6 years'));
      expect(result.assessmentType, equals('age_6_to_7'));
      expect(result.assessmentGroupLabel, equals('6–7 years'));
      expect(result.isAge6To7, isTrue);
    });

    test('Test 6: DOB produces 6 years 6 months (6.5 years)', () {
      final dob = DateTime(2020, 3, 18);
      final result = AgeCalculatorService.calculateAge(dob, refDate);

      expect(result.years, equals(6));
      expect(result.months, equals(6));
      expect(result.formattedAge, equals('6 years 6 months'));
      expect(result.fractionalYears, equals(6.5));
      expect(result.assessmentType, equals('age_6_to_7'));
      expect(result.assessmentGroupLabel, equals('6–7 years'));
    });

    test('Test 7: DOB produces 7 years', () {
      final dob = DateTime(2019, 9, 18);
      final result = AgeCalculatorService.calculateAge(dob, refDate);

      expect(result.years, equals(7));
      expect(result.months, equals(0));
      expect(result.formattedAge, equals('7 years'));
      expect(result.assessmentType, equals('age_6_to_7'));
      expect(result.assessmentGroupLabel, equals('6–7 years'));
    });

    test('Test 8: Birthday boundary — Birthday is tomorrow (does NOT prematurely increment age)', () {
      final dob = DateTime(2020, 9, 19); // Birthday is tomorrow relative to 2026-09-18
      final result = AgeCalculatorService.calculateAge(dob, refDate);

      expect(result.years, equals(5));
      expect(result.months, equals(11));
      expect(result.days, equals(30));
      expect(result.formattedAge, equals('5 years 11 months'));
      expect(result.assessmentType, equals('age_3_to_5'));

      // Test tomorrow (on birthday)
      final tomorrowResult = AgeCalculatorService.calculateAge(dob, DateTime(2026, 9, 19));
      expect(tomorrowResult.years, equals(6));
      expect(tomorrowResult.months, equals(0));
      expect(tomorrowResult.days, equals(0));
      expect(tomorrowResult.assessmentType, equals('age_6_to_7'));
    });

    test('Test 9: Leap-year date handling (Feb 29 birthday)', () {
      final leapDob = DateTime(2020, 2, 29); // Leap year birth
      final nonLeapResult = AgeCalculatorService.calculateAge(leapDob, DateTime(2025, 2, 28));

      expect(nonLeapResult.years, equals(4));
      expect(nonLeapResult.months, equals(11));

      final march1Result = AgeCalculatorService.calculateAge(leapDob, DateTime(2025, 3, 1));
      expect(march1Result.years, equals(5));
      expect(march1Result.months, equals(0));
    });

    test('Test 10: Future DOB or under 3 years is marked ineligible', () {
      final futureDob = DateTime(2028, 1, 1);
      final result = AgeCalculatorService.calculateAge(futureDob, refDate);

      expect(result.years, equals(0));
      expect(result.formattedAge, equals('0 years'));
      expect(result.assessmentType, equals('ineligible_under_3'));
      expect(result.isEligibleAge, isFalse);
      expect(result.isUnder3, isTrue);
      expect(result.isOver7, isFalse);
    });

    test('Test 11: DOB string parsing helper', () {
      expect(AgeCalculatorService.parseDob('2022-03-15'), equals(DateTime(2022, 3, 15)));
      expect(AgeCalculatorService.parseDob(null), isNull);
      expect(AgeCalculatorService.parseDob('invalid'), isNull);
    });

    test('Test 12: Child over 7 years is marked ineligible', () {
      final dob = DateTime(2018, 9, 18); // Exactly 8 years old
      final result = AgeCalculatorService.calculateAge(dob, refDate);

      expect(result.years, equals(8));
      expect(result.formattedAge, equals('8 years'));
      expect(result.assessmentType, equals('ineligible_over_7'));
      expect(result.isEligibleAge, isFalse);
      expect(result.isUnder3, isFalse);
      expect(result.isOver7, isTrue);
    });

    test('Test 13: getAgeGatingMessage provides clear, non-diagnostic guidance', () {
      final under3 = AgeCalculatorService.calculateAge(DateTime(2025, 9, 18), refDate); // 1 year old
      final messageUnder3 = AgeCalculatorService.getAgeGatingMessage(under3);
      expect(messageUnder3, contains('calibrated for children aged 3 to 7 years'));
      expect(messageUnder3, contains('1 year old'));

      final over7 = AgeCalculatorService.calculateAge(DateTime(2017, 9, 18), refDate); // 9 years old
      final messageOver7 = AgeCalculatorService.getAgeGatingMessage(over7);
      expect(messageOver7, contains('calibrated for children aged 3 to 7 years'));
      expect(messageOver7, contains('9 years old'));
    });
  });
}
