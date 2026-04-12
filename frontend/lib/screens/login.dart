import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'accountCreationScreen.dart';
import 'homePage.dart';
import 'signup.dart';

class NeuroLearnLogin extends StatefulWidget {
  const NeuroLearnLogin({super.key});

  @override
  State<NeuroLearnLogin> createState() => _NeuroLearnLoginState();
}

class _NeuroLearnLoginState extends State<NeuroLearnLogin> {
  bool isLogin = true; // Set to true for this screen
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LearningHomeScreen(
            userId: user.id,
            userName: user.fullName,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20),
          child: Column(
            children: [
              // Logo Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: const Icon(Icons.spa, color: Colors.blueAccent, size: 35),
              ),
              const SizedBox(height: 15),
              const Text(
                'NeuroLearn',
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF1A2B47),
                ),
              ),
              const Text(
                "Supporting your child's learning journey",
                style: TextStyle(color: Colors.black54),
              ),
              
              const SizedBox(height: 25),
              // Illustration placeholder
              const Icon(Icons.family_restroom, size: 120, color: Colors.blueGrey),

              const SizedBox(height: 30),

              // Sign Up / Login Toggle Tab
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    _buildToggleItem("Sign Up", !isLogin),
                    _buildToggleItem("Login", isLogin),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              // Login Form Fields
              _buildInputField(
                label: "Email Address", 
                hint: "Enter your email", 
                icon: Icons.email_outlined,
                controller: _emailController,
              ),
              const SizedBox(height: 20),
              _buildInputField(
                label: "Password", 
                hint: "Enter your password", 
                icon: Icons.lock_outline, 
                isPassword: true,
                controller: _passwordController,
              ),

              const SizedBox(height: 35),

              // Login Button
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8ECAFF), Color(0xFFB3D9FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                    _isLoading ? 'Logging in...' : 'Login',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 25),
              
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("New to NeuroLearn? ", style: TextStyle(color: Colors.black54)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NeuroLearnLanding()),
                      );
                    },
                    child: const Text(
                      "Create an account",
                      style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for the Toggle Tab
  Widget _buildToggleItem(String title, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (title == 'Sign Up') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NeuroLearnSignUp()),
            );
            return;
          }

          setState(() => isLogin = true);
        },
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF8ECAFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: active ? Colors.white : Colors.black45,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  // Helper for Styled Input Fields
  Widget _buildInputField({
    required String label, 
    required String hint, 
    required IconData icon, 
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A2B47), fontSize: 14),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black26),
            prefixIcon: Icon(icon, color: Colors.black26),
            suffixIcon: isPassword ? const Icon(Icons.visibility_outlined, color: Colors.black26) : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}