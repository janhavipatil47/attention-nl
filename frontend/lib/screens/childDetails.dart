import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final List<int> _ageOptions = <int>[3, 4, 5, 6, 7];
  final List<String> _gradeOptions = <String>[
    'Nursery',
    'LKG',
    'UKG',
    'Grade 1',
    'Grade 2',
  ];

  int? _selectedAge;
  String? _selectedGrade;

  @override
  void dispose() {
    _childNameController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final String childName = _childNameController.text.trim();
    if (childName.isEmpty || _selectedAge == null || _selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete child name, age, and grade.')),
      );
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('childName', childName);
    await prefs.setInt('childAgeValue', _selectedAge!);
    await prefs.setString('childAge', _selectedAge!.toString());
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
                  children: [
                    _buildLabel(Icons.person, "Child's Name"),
                    _buildTextField(),
                    
                    const SizedBox(height: 20),
                    _buildLabel(Icons.cake, "Age"),
                    _buildAgeDropdown(),
                    
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

  Widget _buildAgeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedAge,
          hint: const Text('Select age', style: TextStyle(color: Colors.black26, fontSize: 14)),
          icon: const Icon(Icons.expand_more, color: Colors.black26),
          items: _ageOptions
              .map(
                (int age) => DropdownMenuItem<int>(
                  value: age,
                  child: Text(age.toString()),
                ),
              )
              .toList(),
          onChanged: (int? value) {
            setState(() {
              _selectedAge = value;
            });
          },
        ),
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