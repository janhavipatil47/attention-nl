import 'package:flutter/material.dart';
import 'report.dart';

class SmartAssessmentScreen extends StatelessWidget {
  const SmartAssessmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                
                // Question 1 (Pink)
                _buildQuestionCard(
                  color: const Color(0xFFFFF0F3),
                  number: "1",
                  question: "Does your child get distracted easily?",
                  options: ["Never", "Sometimes", "Often"],
                  selectedIndex: 1,
                  showEmojis: true,
                ),

                // Quick Activity (Yellow)
                _buildActivityCard(),

                // Question 3 (Green)
                _buildQuestionCard(
                  color: const Color(0xFFF0FFF4),
                  number: "3",
                  question: "Does your child take more time than others to complete tasks?",
                  options: ["Rarely", "Sometimes", "Often"],
                  selectedIndex: 1,
                ),
                
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
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSelected ? Colors.pinkAccent : Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  if (showEmojis) Text(["😄", "😐", "😫"][index] + " "),
                  Text(options[index], style: TextStyle(color: isSelected ? Colors.black87 : Colors.black45)),
                  const Spacer(),
                  if (isSelected) const Icon(Icons.check, size: 18, color: Colors.pinkAccent),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(25)),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.videogame_asset, color: Colors.orange),
              SizedBox(width: 10),
              Text("Quick Activity 🎮", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          const Text("Arrange the letters to form a word", style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ["C", "A", "T"].map((l) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 45, height: 45,
              decoration: BoxDecoration(color: const Color(0xFFFFE082), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5D4037))),
            )).toList(),
          ),
          const Icon(Icons.arrow_downward, color: Colors.orange, size: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 45, height: 45,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFE082), style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(10),
              ),
            )),
          ),
        ],
      ),
    );
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportScreen()),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
          icon: const Icon(Icons.help_outline, color: Colors.white),
          label: const Text("View Report", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}