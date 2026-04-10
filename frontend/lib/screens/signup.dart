import 'package:flutter/material.dart';
import 'childDetails.dart';

class NeuroLearnSignUp extends StatefulWidget {
  const NeuroLearnSignUp({super.key});

  @override
  State<NeuroLearnSignUp> createState() => _NeuroLearnSignUpState();
}

class _NeuroLearnSignUpState extends State<NeuroLearnSignUp> {
  bool isSignUp = true; // Toggle state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      body: SafeArea(
        child: SingleChildScrollView( // Added scroll for smaller screens
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20),
          child: Column(
            children: [
              // Logo Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: const Icon(Icons.spa, color: Colors.blueAccent, size: 35),
              ),
              const SizedBox(height: 15),
              const Text(
                'NeuroLearn',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
              ),
              const Text("Supporting your child's learning journey", style: TextStyle(color: Colors.black54)),
              
              const SizedBox(height: 20),
              // Illustration placeholder
              const Icon(Icons.family_restroom, size: 100, color: Colors.blueGrey),

              const SizedBox(height: 25),

              // Sign Up / Login Toggle Tab
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildToggleItem("Sign Up", isSignUp),
                    _buildToggleItem("Login", !isSignUp),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Form Fields
              _buildInputField(label: "Full Name", hint: "Enter your full name", icon: Icons.person_outline),
              const SizedBox(height: 15),
              _buildInputField(label: "Email Address", hint: "Enter your email", icon: Icons.email_outlined),
              const SizedBox(height: 15),
              _buildInputField(
                label: "Password", 
                hint: "Create a password", 
                icon: Icons.lock_outline, 
                isPassword: true
              ),

              const SizedBox(height: 30),

              // Get Started Button
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8ECAFF), Color(0xFFB3D9FF)],
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChildInfoScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Get Started", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),
              
              // Footer Links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? ", style: TextStyle(color: Colors.black54)),
                  GestureDetector(
                    onTap: () {},
                    child: const Text("Sign In", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              const Text(
                "By continuing, you agree to our Terms of Service and Privacy Policy",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Toggle Tab Helper
  Widget _buildToggleItem(String title, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isSignUp = (title == "Sign Up")),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF8ECAFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: active ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Text Field Helper
  Widget _buildInputField({required String label, required String hint, required IconData icon, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A2B47))),
        const SizedBox(height: 8),
        TextField(
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.black26),
            suffixIcon: isPassword ? const Icon(Icons.visibility_outlined, color: Colors.black26) : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}