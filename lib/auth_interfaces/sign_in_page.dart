
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_card_app_driver/auth_interfaces/sign_up_page.dart';
import 'package:smart_card_app_driver/manage_interfaces/home_screen.dart';
import 'package:smart_card_app_driver/services/auth_service.dart';
import 'package:smart_card_app_driver/themes/colors.dart';


class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _forgotPasswordEmailController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;
  final AuthenticationService _auth = AuthenticationService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _forgotPasswordEmailController.dispose();
    super.dispose();
  }

  void _showSnackBar(
    String message, {
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? AppColors.accentGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Show password reset dialog
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reset Password',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address to receive a password reset link.',
              style: GoogleFonts.inter(
                color: AppColors.grey700,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _forgotPasswordEmailController,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.email,
                  color: AppColors.primaryDark,
                ),
                labelText: 'Email',
                labelStyle: GoogleFonts.inter(color: AppColors.grey700),
                hintText: 'example@domain.com',
                hintStyle: GoogleFonts.inter(color: AppColors.grey500),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.primaryDark,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.accentGreen,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                filled: true,
                fillColor: AppColors.white,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppColors.grey700,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Reset Password',
              style: GoogleFonts.inter(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              final email = _forgotPasswordEmailController.text.trim();
              if (email.isEmpty) {
                _showSnackBar(
                  'Please enter your email address',
                  backgroundColor: Colors.red,
                );
                return;
              }
              
              Navigator.of(context).pop(); // Close the dialog
              
              setState(() => _isLoading = true);
              try {
                final result = await _auth.resetPassword(email);
                
                if (result['success'] == true) {
                  _showSnackBar(result['message']);
                } else {
                  _showSnackBar(
                    result['message'],
                    backgroundColor: Colors.red,
                  );
                }
              } catch (e) {
                _showSnackBar(
                  'Failed to send reset email: $e',
                  backgroundColor: Colors.red,
                );
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // Sign in with email and password
  Future<void> _signInWithEmail() async {
    // Validate input fields
    String? emailError = _auth.validateEmail(_emailController.text);
    if (emailError != null) {
      _showSnackBar(emailError, backgroundColor: Colors.red);
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showSnackBar('Please enter your password', backgroundColor: Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (result['driver'] != null) {
        _showSnackBar('Sign in successful');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else {
        _showSnackBar(
          result['error'] ?? 'Sign in failed',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar(
        'Sign in failed: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

 
 
 // Sign in with Google
 Future<void> _signInWithGoogle() async {
  setState(() => _isLoading = true);

  try {
    // Perform Google sign-in and get result
    final result = await _auth.signInWithGoogle();

    if (!mounted) return;

    // Log the result for debugging
    debugPrint('Sign-in result: $result');

    // Show success message (even if there's an error, for testing)
    _showSnackBar('Sign-in attempt completed');

    // Navigate to home screen regardless of result (for testing purposes)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );

    // Optionally show error message if sign-in failed
    if (result['driver'] == null) {
      debugPrint('Sign-in failed but navigating anyway: ${result['error']}');
      _showSnackBar(
        result['error'] ?? 'Google sign-in failed',
        backgroundColor: Colors.red,
      );
    }
  } catch (e) {
    if (!mounted) return;
    // Log the error for debugging
    debugPrint('Sign-in error: $e');
    // Show error to user
    _showSnackBar(
      'Error during sign-in: $e',
      backgroundColor: Colors.red,
    );
    // Navigate anyway (for testing purposes)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
  
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: Text(
          'Smart Card System - Driver',
          style: GoogleFonts.inter(
            fontSize: 22,
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 200,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.contain,
                  image: AssetImage('assets/auth/bus2.jpg'),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowGreen.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign in',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 25),
                    TextField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.email,
                          color: AppColors.primaryDark,
                        ),
                        labelText: 'Enter your email',
                        labelStyle: GoogleFonts.inter(color: AppColors.grey700),
                        hintText: 'example@domain.com',
                        hintStyle: GoogleFonts.inter(color: AppColors.grey500),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primaryDark,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.accentGreen,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.lock,
                          color: AppColors.primaryDark,
                        ),
                        labelText: 'Enter your password',
                        labelStyle: GoogleFonts.inter(color: AppColors.grey700),
                        hintText: '••••••••',
                        hintStyle: GoogleFonts.inter(color: AppColors.grey500),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primaryDark,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.accentGreen,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        filled: true,
                        fillColor: AppColors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.grey600,
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _isLoading ? null : _showForgotPasswordDialog,
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.inter(
                          color: _isLoading
                              ? AppColors.grey600
                              : AppColors.primaryDark,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isLoading ? null : _signInWithEmail,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: _isLoading
                              ? AppColors.grey600
                              : AppColors.accentGreen,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  'Sign in',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: _isLoading ? null : _signInWithGoogle,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isLoading
                                ? AppColors.grey600
                                : AppColors.primaryDark,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.google,
                              size: 18,
                              color: _isLoading
                                  ? AppColors.grey600
                                  : AppColors.primaryDark,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Sign with Google',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: _isLoading
                                    ? AppColors.grey600
                                    : AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignUpPage(),
                                ),
                              );
                            },
                      child: Text(
                        "Don't have an account? Register",
                        style: GoogleFonts.inter(
                          color: _isLoading
                              ? AppColors.grey600
                              : AppColors.primaryDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}