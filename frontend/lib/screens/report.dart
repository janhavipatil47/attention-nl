import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

//void main() => runApp(const MaterialApp(home: AssessmentReport(), debugShowCheckedModeBanner: false));

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildGradientHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
              child: Column(
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  _buildSkillOverview(),
                  const SizedBox(height: 20),
                  _buildObservations(),
                  const SizedBox(height: 20),
                  _buildActionSection(),
                  const SizedBox(height: 30),
                  _buildBottomButtons(),
                  const SizedBox(height: 40),
                  _buildFooterImage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Purple Gradient Header
  Widget _buildGradientHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8ECAFF), Color(0xFF7B61FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: const [
          Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          SizedBox(height: 10),
          Text(
            "Assessment Complete 🎉",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            "Here are Aarav's insights based on your\nresponses and activities",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // 2. Moderate Support Card
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const CircleAvatar(backgroundColor: Color(0xFFFFF9C4), child: Icon(Icons.warning_amber_rounded, color: Colors.orange)),
          const SizedBox(height: 15),
          const Text("🟡 Moderate Support Needed", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            "Your child may need support in attention\nand reading skills.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(20)),
            child: const Text("Confidence Score: 85% >", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          )
        ],
      ),
    );
  }

  // 3. Skill Overview (Progress Bars)
  Widget _buildSkillOverview() {
    return _buildSectionContainer(
      title: "Skill Overview 🧠",
      child: Column(
        children: [
          _buildProgressBar("Reading", 0.60, Colors.blue),
          _buildProgressBar("Writing", 0.55, Colors.green),
          _buildProgressBar("Attention", 0.45, Colors.orange),
          _buildProgressBar("Memory", 0.65, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text("${(value * 100).toInt()}%", style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.grey.shade100,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  // 4. Key Observations
  Widget _buildObservations() {
    return _buildSectionContainer(
      title: "Key Observations 💡",
      child: Column(
        children: [
          _buildBulletItem("Gets distracted easily during tasks", Colors.blue),
          _buildBulletItem("Takes more time to complete activities", Colors.green),
          _buildBulletItem("Shows moderate difficulty in reading", Colors.purple),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: dotColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }

  // 5. Action Section (Activity Cards)
  Widget _buildActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("What You Can Do 💙", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _buildActionCard("Improve Reading Skills", "Practice simple word recognition daily", "Recommended for Reading 📚", Colors.blue, "Start Activity"),
        _buildActionCard("Boost Focus", "Play short attention-building games", "Based on Assessment ✨", Colors.orange, "Play Now"),
      ],
    );
  }

  Widget _buildActionCard(String title, String desc, String tag, Color color, String btnText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(desc, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 10),
          Text(tag, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(btnText, style: const TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  // Helper Container for White Sections
  Widget _buildSectionContainer({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(colors: [Colors.pinkAccent, Colors.purpleAccent]),
          ),
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_search, color: Colors.white),
            label: const Text("Consult a Specialist", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildSmallBtn(Icons.refresh, "Retake\nAssessment")),
            const SizedBox(width: 15),
            Expanded(child: _buildSmallBtn(Icons.sports_esports, "Go to\nActivities")),
          ],
        )
      ],
    );
  }

  Widget _buildSmallBtn(IconData icon, String label) {
    return Container(
      height: 60,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFooterImage() {
    return Column(
      children: const [
        Text(
          "\"With the right support, every child can\ngrow and improve\" 🌈",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black45, fontSize: 12, fontStyle: FontStyle.italic),
        ),
        SizedBox(height: 20),
        Icon(Icons.group, size: 80, color: Colors.blueGrey),
      ],
    );
  }
}