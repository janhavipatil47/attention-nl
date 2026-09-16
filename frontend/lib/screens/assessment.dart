import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/questionnaire_service.dart';
import '../services/auth_service.dart';
import 'handwriting_screening.dart';

class SmartAssessmentScreen extends StatefulWidget {
  const SmartAssessmentScreen({super.key, this.userId = 'anonymous_user'});

  final String userId;

  @override
  State<SmartAssessmentScreen> createState() => _SmartAssessmentScreenState();
}

class _SmartAssessmentScreenState extends State<SmartAssessmentScreen> {
  final Map<int, int> _responses = <int, int>{};
  final TextEditingController _observationsController = TextEditingController();
  bool _isSubmitting = false;
  bool _childDetailsChecked = false;
  bool _hasChildDetails = false;

  @override
  void initState() {
    super.initState();
    _checkChildDetails();
  }

  Future<void> _checkChildDetails() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String childName = (prefs.getString('childName') ?? '').trim();
    final int? childAge = prefs.getInt('childAgeValue');
    final String childGrade = (prefs.getString('childGrade') ?? '').trim();

    if (!mounted) {
      return;
    }

    setState(() {
      _hasChildDetails = childName.isNotEmpty && childAge != null && childGrade.isNotEmpty;
      _childDetailsChecked = true;
    });
  }

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_childDetailsChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasChildDetails) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.black54),
          title: const Text(
            'Smart Assessment',
            style: TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please complete child details before starting assessment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black54),
        title: Column(
          children: const [
            Text("Smart Assessment 🧠", style: TextStyle(color: Color(0xFF1A2B47), fontSize: 18, fontWeight: FontWeight.bold)),
            Text("Preview Mode • 5 Steps", style: TextStyle(color: Colors.purple, fontSize: 12)),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  "Answer a few questions and play\nfun games 💙",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
                ),
                const SizedBox(height: 25),
                ...List.generate(QuestionnaireService.questions.length, (index) {
                  final cardColor = index.isEven
                      ? const Color(0xFFFFF0F3)
                      : const Color(0xFFF0FFF4);

                  return _buildQuestionCard(
                    color: cardColor,
                    number: '${index + 1}',
                    question: QuestionnaireService.questions[index],
                    options: QuestionnaireService.responseOptions,
                    selectedIndex: _responses[index],
                    onOptionSelected: (selectedOption) {
                      setState(() {
                        _responses[index] = selectedOption;
                      });
                    },
                    showEmojis: false,
                  );
                }),
                _buildObservationsCard(),
                
                const SizedBox(height: 20),
                const Text(
                  "You're doing great! This helps us\nunderstand better ✨",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomButton(context),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: index < 4 ? Colors.purple.withOpacity(0.4) : Colors.grey.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
      )),
    );
  }

  Widget _buildQuestionCard({
    required Color color, 
    required String number, 
    required String question, 
    required List<String> options, 
    int? selectedIndex,
    required ValueChanged<int> onOptionSelected,
    bool showEmojis = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 12, backgroundColor: Colors.white70, child: Text(number, style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 10),
              Expanded(child: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 15),
          ...List.generate(options.length, (index) {
            bool isSelected = index == selectedIndex;
            return InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => onOptionSelected(index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: isSelected ? Colors.pinkAccent : Colors.transparent, width: 2),
                ),
                child: Row(
                  children: [
                    if (showEmojis) Text(_emojiForOption(index) + ' '),
                    Text(options[index], style: TextStyle(color: isSelected ? Colors.black87 : Colors.black45)),
                    const Spacer(),
                    if (isSelected) const Icon(Icons.check, size: 18, color: Colors.pinkAccent),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _emojiForOption(int index) {
    const emojis = <String>['😄', '😐', '😫', '😭'];
    if (index < 0 || index >= emojis.length) {
      return '•';
    }
    return emojis[index];
  }

  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.blueAccent]),
        ),
        child: ElevatedButton.icon(
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (_responses.length != QuestionnaireService.questions.length) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please answer all questions before submitting.'),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _isSubmitting = true;
                  });

                  try {
                    await QuestionnaireService.submitQuestionnaireResponses(
                      userId: widget.userId,
                      responses: _responses,
                      additionalObservations: _observationsController.text,
                    );

                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thank you for your response. You are in right hands.'),
                      ),
                    );

                    // Get current user's ageOfChild from Firebase and route accordingly
                    final currentUser = await AuthService.currentUser();
                    final SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    final int? ageFromPrefs = prefs.getInt('childAgeValue');
                    final int? ageOfChild = ageFromPrefs ?? currentUser?.ageOfChild;

                    print('DEBUG: Current user = ${currentUser?.email}');
                    print('DEBUG: Current user ageOfChild = $ageOfChild');
                    
                    // Prefer actual child age; default to 5 (younger flow) if missing.
                    final int childAge = ageOfChild ?? 5;
                    print('DEBUG: Using childAge = $childAge');
                    print('DEBUG: childAge >= 6 = ${childAge >= 6}');

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HandwritingScreeningScreen(
                          childAge: childAge,
                        ),
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Submission failed: $error')),
                    );
                  } finally {
                    if (context.mounted) {
                      setState(() {
                        _isSubmitting = false;
                      });
                    }
                  }
                },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
          icon: const Icon(Icons.help_outline, color: Colors.white),
          label: Text(
            _isSubmitting ? 'Submitting...' : 'Submit & Start Child Assessment',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildObservationsCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Additional Observations',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          const Text(
            'Share any notes about your child that may help us understand better.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observationsController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Type your observations here...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
