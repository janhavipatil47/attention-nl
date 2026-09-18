import 'package:shared_preferences/shared_preferences.dart';

/// Holds the exact chronological age calculation result.
class ChildAgeResult {
  const ChildAgeResult({
    required this.dob,
    required this.asOfDate,
    required this.years,
    required this.months,
    required this.days,
    required this.fractionalYears,
    required this.formattedAge,
    required this.assessmentType,
    required this.assessmentGroupLabel,
  });

  final DateTime dob;
  final DateTime asOfDate;
  final int years;
  final int months;
  final int days;
  final double fractionalYears;
  final String formattedAge;
  final String assessmentType; // 'age_3_to_5' or 'age_6_to_7'
  final String assessmentGroupLabel; // '3–5 years' or '6–7 years'

  bool get isAge3To5 => assessmentType == 'age_3_to_5';
  bool get isAge6To7 => assessmentType == 'age_6_to_7';
  bool get isEligibleAge => years >= 3 && years <= 7;
  bool get isUnder3 => years < 3;
  bool get isOver7 => years > 7;

  @override
  String toString() {
    return 'ChildAgeResult(dob: $dob, asOf: $asOfDate, age: $formattedAge, fractional: $fractionalYears, group: $assessmentGroupLabel)';
  }
}

/// Service for calculating exact chronological age from Date of Birth (DOB).
class AgeCalculatorService {
  /// Returns a user-friendly explanation when a child is not in the eligible 3–7 age range.
  static String getAgeGatingMessage(ChildAgeResult ageResult) {
    if (ageResult.isUnder3) {
      return 'NeuroLearn assessments are specifically calibrated for children aged 3 to 7 years. '
          'Your child is currently recorded as ${ageResult.formattedAge} old (< 3 years). '
          'Assessment modules will become available once your child turns 3.';
    } else if (ageResult.isOver7) {
      return 'NeuroLearn assessments are specifically calibrated for children aged 3 to 7 years. '
          'Your child is currently recorded as ${ageResult.formattedAge} old (> 7 years).';
    }
    return '';
  }

  /// Calculates the exact chronological age from [dob] as of [currentDate] (defaults to now).
  static ChildAgeResult calculateAge(DateTime dob, [DateTime? currentDate]) {
    final DateTime target = currentDate ?? DateTime.now();
    final DateTime targetDate = DateTime(target.year, target.month, target.day);
    final DateTime birthDate = DateTime(dob.year, dob.month, dob.day);

    if (birthDate.isAfter(targetDate)) {
      return ChildAgeResult(
        dob: birthDate,
        asOfDate: targetDate,
        years: 0,
        months: 0,
        days: 0,
        fractionalYears: 0.0,
        formattedAge: '0 years',
        assessmentType: 'ineligible_under_3',
        assessmentGroupLabel: 'Under 3 years',
      );
    }

    int years = targetDate.year - birthDate.year;
    int months = targetDate.month - birthDate.month;
    int days = targetDate.day - birthDate.day;

    if (days < 0) {
      months -= 1;
      // Get days in the previous month relative to targetDate
      final DateTime prevMonth = DateTime(targetDate.year, targetDate.month - 1, 1);
      final int daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
      days += daysInPrevMonth;
    }

    if (months < 0) {
      years -= 1;
      months += 12;
    }

    // Precise fractional years for intermediate calculations
    final double rawFractional = years + (months / 12.0) + (days / 365.25);
    final double fractionalYears = double.parse(rawFractional.toStringAsFixed(2));

    // Formatted parent-friendly age string
    String formattedAge;
    if (years == 0 && months == 0) {
      formattedAge = '$days ${days == 1 ? "day" : "days"}';
    } else if (years == 0) {
      formattedAge = '$months ${months == 1 ? "month" : "months"}';
    } else if (months == 0) {
      formattedAge = '$years ${years == 1 ? "year" : "years"}';
    } else {
      formattedAge = '$years ${years == 1 ? "year" : "years"} $months ${months == 1 ? "month" : "months"}';
    }

    // Assessment age band decision:
    // Strictly calibrated for children aged 3 to 7 years
    String assessmentType;
    String assessmentGroupLabel;
    if (years < 3) {
      assessmentType = 'ineligible_under_3';
      assessmentGroupLabel = 'Under 3 years';
    } else if (years >= 6 && years <= 7) {
      assessmentType = 'age_6_to_7';
      assessmentGroupLabel = '6–7 years';
    } else if (years > 7) {
      assessmentType = 'ineligible_over_7';
      assessmentGroupLabel = 'Over 7 years';
    } else {
      assessmentType = 'age_3_to_5';
      assessmentGroupLabel = '3–5 years';
    }

    return ChildAgeResult(
      dob: birthDate,
      asOfDate: targetDate,
      years: years,
      months: months,
      days: days,
      fractionalYears: fractionalYears,
      formattedAge: formattedAge,
      assessmentType: assessmentType,
      assessmentGroupLabel: assessmentGroupLabel,
    );
  }

  /// Parses a Date of Birth from a String or DateTime object safely.
  static DateTime? parseDob(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  /// Reads DOB from SharedPreferences, with fallback to legacy integer age for backwards compatibility.
  static DateTime? getDobFromPrefs(SharedPreferences prefs) {
    final String? dobString = prefs.getString('childDob');
    if (dobString != null && dobString.isNotEmpty) {
      final parsed = parseDob(dobString);
      if (parsed != null) return parsed;
    }

    // Legacy fallback: if childDob is not present, use childAgeValue if available
    final int? legacyAge = prefs.getInt('childAgeValue');
    if (legacyAge != null && legacyAge > 0) {
      final now = DateTime.now();
      return DateTime(now.year - legacyAge, now.month, now.day);
    }

    return null;
  }

  /// Convenience method to compute age result directly from SharedPreferences.
  static ChildAgeResult? getAgeResultFromPrefs(SharedPreferences prefs, [DateTime? currentDate]) {
    final dob = getDobFromPrefs(prefs);
    if (dob == null) return null;
    return calculateAge(dob, currentDate);
  }
}
