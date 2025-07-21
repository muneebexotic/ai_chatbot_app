import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

void _signUp() async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  setState(() => _isLoading = true);

  final fullName = _fullNameController.text.trim();
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill in all fields')),
    );
    setState(() => _isLoading = false);
    return;
  }

  try {
    final isNewUser = await authProvider.signUp(email, password, fullName);

    if (authProvider.isLoggedIn) {
      if (isNewUser) {
        Navigator.pushReplacementNamed(context, '/photo-upload');
      } else {
        Navigator.pushReplacementNamed(context, '/chat');
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign Up failed: $e')),
    );
  }

  setState(() => _isLoading = false);
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔙 Back Button
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF232627),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              const SizedBox(height: 32),

              // 👋 Title
              const Text(
                'Create Your\nAccount',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 32),

              // 👤 Full Name
              _buildTextField(
                controller: _fullNameController,
                icon: Icons.person,
                hintText: 'Full Name',
              ),

              const SizedBox(height: 16),

              // 📧 Email
              _buildTextField(
                controller: _emailController,
                icon: Icons.email,
                hintText: 'Enter Your Email',
              ),

              const SizedBox(height: 16),

              // 🔒 Password
              _buildTextField(
                controller: _passwordController,
                icon: Icons.lock,
                hintText: 'Password',
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white54,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 🔐 Forget password (optional in sign up but left here for layout consistency)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Forget password?',
                  style: TextStyle(color: Colors.white54),
                ),
              ),

              const SizedBox(height: 24),

              // 🔘 Sign Up Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 16, fontFamily: 'Poppins'),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // 👤 Create account
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ───── Divider ─────
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),

              // 🌐 Continue with Google
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        try {
                          await authProvider.signInWithGoogle();

                          // Debug log
                          print(
                            "✅ After signInWithGoogle, isLoggedIn: ${authProvider.isLoggedIn}",
                          );

                          if (authProvider.isLoggedIn) {
                            Navigator.pushReplacementNamed(context, '/chat');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '❌ Google Sign-In succeeded, but user is null.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Google Sign-In failed: $e'),
                            ),
                          );
                        }
                      },

                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: Center(
                          child: Image.asset(
                            'assets/google_logo.png',
                            width: 38,
                            height: 38,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF232627),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
