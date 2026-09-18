import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/age_calculator_service.dart';
import 'homePage.dart';

class ChildInfoScreen extends StatefulWidget {
  const ChildInfoScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  State<ChildInfoScreen> createState() => _ChildInfoScreenState();
}

class _ChildInfoScreenState extends State<ChildInfoScreen> {
  final TextEditingController _childNameController = TextEditingController();
  final List<String> _gradeOptions = <String>[
    'Nursery',
    'LKG',
    'UKG',
    'Grade 1',
    'Grade 2',
  ];

  DateTime? _selectedDob;
  String? _selectedGrade;

  @override
  void initState() {
    super.initState();
    _loadExistingDetails();
  }

  Future<void> _loadExistingDetails() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String storedName = (prefs.getString('childName') ?? '').trim();
    final String storedGrade = (prefs.getString('childGrade') ?? '').trim();
    final DateTime? storedDob = AgeCalculatorService.getDobFromPrefs(prefs);

    if (mounted) {
      setState(() {
        if (storedName.isNotEmpty) {
          _childNameController.text = storedName;
        }
        if (storedGrade.isNotEmpty && _gradeOptions.contains(storedGrade)) {
          _selectedGrade = storedGrade;
        }
        _selectedDob = storedDob;
      });
    }
  }

  @override
  void dispose() {
    _childNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final DateTime initial = _selectedDob ??
        DateTime.now().subtract(const Duration(days: 365 * 4));
    final DateTime firstDate =
        DateTime.now().subtract(const Duration(days: 365 * 18));
    final DateTime lastDate = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(lastDate) ? lastDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Child\'s Date of Birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6E56CF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A2B47),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  Future<void> _saveAndContinue() async {
    final String childName = _childNameController.text.trim();
    if (childName.isEmpty || _selectedDob == null || _selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete child name, date of birth, and grade.'),
        ),
      );
      return;
    }

    final ChildAgeResult ageResult = AgeCalculatorService.calculateAge(_selectedDob!);

    if (!ageResult.isEligibleAge) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text('Assessment Age Limit'),
            ],
          ),
          content: Text(
            AgeCalculatorService.getAgeGatingMessage(ageResult),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('childName', childName);
    await prefs.setString('childDob', _selectedDob!.toIso8601String().split('T').first);
    await prefs.setString('childAge', ageResult.formattedAge);
    await prefs.setInt('childAgeValue', ageResult.years);
    await prefs.setString('childGrade', _selectedGrade!);

    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningHomeScreen(
          userId: widget.userId,
          userName: widget.userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ChildAgeResult? ageResult;
    if (_selectedDob != null) {
      ageResult = AgeCalculatorService.calculateAge(_selectedDob!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
          child: Column(
            children: [
              // Header Row: Back Button and Progress Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1A2B47), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8ECAFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 40), // Balance the back button
                ],
              ),

              const SizedBox(height: 20),
              const Text(
                'NeuroLearn',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
              ),
              const SizedBox(height: 15),
              // Illustration Placeholder
              const Icon(Icons.family_restroom, size: 100, color: Colors.blueGrey),

              const SizedBox(height: 20),
              const Text(
                'Tell us about your child',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
              ),
              const SizedBox(height: 8),
              const Text(
                "This helps us personalize your experience",
                style: TextStyle(color: Colors.black45, fontSize: 14),
              ),

              const SizedBox(height: 30),

              // White Form Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFF),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(Icons.person, "Child's Name"),
                    _buildTextField(),

                    const SizedBox(height: 20),
                    _buildLabel(Icons.cake, "Date of Birth"),
                    _buildDobSelector(),

                    if (ageResult != null) ...[
                      const SizedBox(height: 12),
                      _buildCalculatedAgeCard(ageResult),
                    ],

                    const SizedBox(height: 20),
                    _buildLabel(Icons.school, "Grade/Class"),
                    _buildGradeDropdown(),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Continue Button
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8ECAFF), Color(0xFFB3D9FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build the icon + label row
  Widget _buildLabel(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A2B47)),
          ),
        ],
      ),
    );
  }

  // Helper for text input
  Widget _buildTextField() {
    return TextField(
      controller: _childNameController,
      decoration: InputDecoration(
        hintText: "Enter your child's name",
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black12),
        ),
      ),
    );
  }

  Widget _buildDobSelector() {
    final String formattedDateStr = _selectedDob != null
        ? '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}'
        : 'Select Date of Birth';

    return InkWell(
      onTap: _pickDateOfBirth,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formattedDateStr,
                style: TextStyle(
                  color: _selectedDob != null ? const Color(0xFF1A2B47) : Colors.black26,
                  fontSize: 14,
                  fontWeight: _selectedDob != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_rounded, color: Colors.blueAccent, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculatedAgeCard(ChildAgeResult ageResult) {
    final bool isEligible = ageResult.isEligibleAge;
    final Color cardBg = isEligible ? const Color(0xFFEFF5FF) : const Color(0xFFFFF3F3);
    final Color cardBorder = isEligible ? const Color(0xFF8ECAFF) : const Color(0xFFFFB2B2);
    final Color titleColor = isEligible ? const Color(0xFF1A2B47) : const Color(0xFFC62828);
    final Color subColor = isEligible ? const Color(0xFF275DAD) : const Color(0xFFD32F2F);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEligible ? Icons.auto_awesome : Icons.warning_amber_rounded,
                size: 16,
                color: titleColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Current Age: ${ageResult.formattedAge}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isEligible
                ? 'Assessment Group: ${ageResult.assessmentGroupLabel}'
                : 'Assessment Status: Unavailable (${ageResult.assessmentGroupLabel})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: subColor,
            ),
          ),
          if (!isEligible) ...[
            const SizedBox(height: 6),
            Text(
              AgeCalculatorService.getAgeGatingMessage(ageResult),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFB71C1C),
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedGrade,
          hint: const Text('Select grade', style: TextStyle(color: Colors.black26, fontSize: 14)),
          icon: const Icon(Icons.expand_more, color: Colors.black26),
          items: _gradeOptions
              .map(
                (String grade) => DropdownMenuItem<String>(
                  value: grade,
                  child: Text(grade),
                ),
              )
              .toList(),
          onChanged: (String? value) {
            setState(() {
              _selectedGrade = value;
            });
          },
        ),
      ),
    );
  }
}