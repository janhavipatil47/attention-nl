import 'package:flutter/material.dart';
import 'assessment.dart';
import 'activities.dart';
import 'report.dart';

class LearningHomeScreen extends StatelessWidget {
  const LearningHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const CustomBottomNavBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TopGreetingCard(),
              const SizedBox(height: 18),

              // Center illustration
              Center(
                child: Column(
                  children: [
                    Container(
                      height: 130,
                      width: 130,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2EA),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Text(
                          "🧒📚",
                          style: TextStyle(fontSize: 56),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "Let's understand your child\nbetter 😊",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2A2A2A),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Start a quick assessment to get personalized\ninsights",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E8E),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFB56EFF),
                      Color(0xFFFF6EB6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SmartAssessmentScreen()),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      "Start Smart Assessment",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "Takes only 3–4 minutes ⏱",
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8F8F8F),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // What you'll get
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD9CC),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const Text(
                      "What You'll Get ✨",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6E4A4A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _featureTile(
                      icon: Icons.bar_chart_rounded,
                      iconBg: const Color(0xFFE7D7FF),
                      iconColor: const Color(0xFF8B5CF6),
                      text: "Personalized Report",
                    ),
                    const SizedBox(height: 10),
                    _featureTile(
                      icon: Icons.track_changes,
                      iconBg: const Color(0xFFD7E8FF),
                      iconColor: const Color(0xFF3B82F6),
                      text: "Learning Insights",
                    ),
                    const SizedBox(height: 10),
                    _featureTile(
                      icon: Icons.person,
                      iconBg: const Color(0xFFD7F5DF),
                      iconColor: const Color(0xFF22C55E),
                      text: "Expert Guidance",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Right place card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7F1FF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "You're in the right place 💙",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF355C7D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Answer a few simple questions and play fun\ngames to help us understand your child better",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5E7484),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE6E6E6),
                        ),
                      ),
                      child: const Text(
                        "\"Every child learns differently — and\nthat's okay 🌈\"",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF6B6B6B),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF585858),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class TopGreetingCard extends StatelessWidget {
  const TopGreetingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFC58CFF),
            Color(0xFFE2B7FF),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Opacity(
              opacity: 0.15,
              child: Text(
                "🧸",
                style: TextStyle(fontSize: 110),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: Color(0xFF555555),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Hi, Priya 👋",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3D2C55),
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Welcome to your child's learning journey",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B5E7A),
                ),
              ),
            ],
          ),
          const Positioned(
            bottom: 8,
            left: 110,
            child: Text(
              "👧",
              style: TextStyle(fontSize: 52),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {}, // Already on Home
            child: const _NavItem(
              icon: Icons.home_rounded,
              label: "Home",
              active: true,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ActivitiesDashboard()),
              );
            },
            child: const _NavItem(
              icon: Icons.extension_rounded,
              label: "Activities",
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportScreen()),
              );
            },
            child: const _NavItem(
              icon: Icons.show_chart_rounded,
              label: "Reports",
            ),
          ),
          GestureDetector(
            onTap: () {}, // TODO: Add Support screen
            child: const _NavItem(
              icon: Icons.chat_bubble_rounded,
              label: "Support",
            ),
          ),
          GestureDetector(
            onTap: () {}, // TODO: Add Profile screen
            child: const _NavItem(
              icon: Icons.person_rounded,
              label: "Profile",
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = const Color(0xFF9C4DFF);
    final Color inactiveColor = const Color(0xFFA0A0A0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 22,
          color: active ? activeColor : inactiveColor,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? activeColor : inactiveColor,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}