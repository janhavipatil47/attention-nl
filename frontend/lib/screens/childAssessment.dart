import 'package:flutter/material.dart';

class ChildAssessmentScreen extends StatelessWidget {
  const ChildAssessmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black54),
        title: const Column(
          children: [
            Text(
              'Child Assessment',
              style: TextStyle(
                color: Color(0xFF1A2B47),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Next Step',
              style: TextStyle(color: Colors.purple, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.child_care, size: 72, color: Colors.blueAccent),
              SizedBox(height: 16),
              Text(
                'Child assessment starts here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2B47),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'You can now continue with the child-focused assessment flow.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
