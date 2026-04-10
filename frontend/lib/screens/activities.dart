import 'package:flutter/material.dart';

class ActivitiesDashboard extends StatelessWidget {
  const ActivitiesDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header Section
            _buildHeader(),
            const SizedBox(height: 25),

            // Recommended Section
            _buildSectionTitle("Recommended for You ⭐"),
            const SizedBox(height: 15),
            _buildRecommendedCards(),
            const SizedBox(height: 25),

            // Category Chips
            _buildCategoryChips(),
            const SizedBox(height: 25),

            // All Activities Grid
            _buildSectionTitle("All Activities"),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 0.85,
              children: [
                _buildActivityGridItem("Letter Match", "Match letters with sounds", const Color(0xFFFFF4D0), const Color(0xFFEBB100), Icons.font_download),
                _buildActivityGridItem("Shape Sort", "Sort shapes by color", const Color(0xFFE0F9E9), const Color(0xFF27C466), Icons.category),
                _buildActivityGridItem("Pattern Game", "Complete the pattern", const Color(0xFFF1E8FF), const Color(0xFF9E62FF), Icons.extension),
                _buildActivityGridItem("Number Fun", "Count and learn", const Color(0xFFFFE5E5), const Color(0xFFF44336), Icons.calculate),
              ],
            ),
            const SizedBox(height: 25),

            // Progress Card
            _buildProgressCard(),
            const SizedBox(height: 25),

            // Challenge Card
            _buildChallengeCard(),
            
            const SizedBox(height: 40),
            const Text(
              "Small steps every day lead to big\nimprovements 💙",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 25,
          backgroundColor: Colors.white,
          child: Text("🧠", style: TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Activities 🎮", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("Let's help Aarav improve step by step 💡", style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF0E7FF), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.tune, color: Color(0xFF9E62FF)),
        )
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)));
  }

  Widget _buildRecommendedCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPromoCard(
            color: const Color(0xFFFFDDE4),
            title: "Reading Booster",
            subtitle: "Improve word recognition",
            btnColor: const Color(0xFFED4C8F),
          ),
          const SizedBox(width: 15),
          _buildPromoCard(
            color: const Color(0xFFD6F5FF),
            title: "Focus Training",
            subtitle: "Attention span exercise",
            btnColor: const Color(0xFF4CAFED),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard({required Color color, required String title, required String subtitle, required Color btnColor}) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.book, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: btnColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 45),
            ),
            child: const Text("🎮 Start", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      {"icon": "🧠", "label": "Focus", "color": Color(0xFFF0E7FF)},
      {"icon": "📚", "label": "Reading", "color": Color(0xFFFFE5EB)},
      {"icon": "✍️", "label": "Writing", "color": Color(0xFFE0F9E9)},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: categories.map((cat) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: cat['color'] as Color, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Text(cat['icon'] as String),
            const SizedBox(width: 5),
            Text(cat['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildActivityGridItem(String name, String desc, Color bg, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2),
          const Spacer(),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(double.infinity, 35),
            ),
            child: const Text("▶ Play", style: TextStyle(color: Colors.white, fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Your Progress 🙌", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(children: const [Icon(Icons.star, color: Colors.amber, size: 18), Icon(Icons.star, color: Colors.amber, size: 18), Icon(Icons.star, color: Colors.amber, size: 18)]),
            ],
          ),
          const SizedBox(height: 10),
          const Text("3 activities completed today", style: TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 15),
          LinearProgressIndicator(value: 0.6, backgroundColor: Colors.grey.shade100, color: Colors.pinkAccent, minHeight: 10, borderRadius: BorderRadius.circular(10)),
          const SizedBox(height: 8),
          const Text("6 out of 10 daily activities", style: TextStyle(fontSize: 11, color: Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildChallengeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFCC80)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's Challenge 🎯", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const Text("Complete 2 activities to earn a star ⭐", style: TextStyle(fontSize: 13)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Start Challenge", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF9E62FF),
      unselectedItemColor: Colors.black26,
      currentIndex: 1,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.sports_esports), label: "Activities"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Reports"),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Support"),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
      ],
    );
  }
}