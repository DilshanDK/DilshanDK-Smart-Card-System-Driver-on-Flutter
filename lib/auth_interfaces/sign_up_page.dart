// ignore_for_file: deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_card_app_driver/manage_interfaces/home_screen.dart';
import 'package:smart_card_app_driver/services/auth_service.dart';
import 'package:smart_card_app_driver/themes/colors.dart';
import 'package:smart_card_app_driver/auth_interfaces/sign_in_page.dart';


class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseNoController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;
  final AuthenticationService _auth = AuthenticationService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _licenseNoController.dispose();
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

  // Validate input fields
  void _validateFields() {
    String? nameError = _auth.validateName(_nameController.text);
    String? emailError = _auth.validateEmail(_emailController.text);
    String? phoneError = _auth.validatePhone(_phoneController.text);
    String? passwordError = _auth.validatePassword(_passwordController.text);
    String? licenseNoError = _licenseNoController.text.trim().isEmpty
        ? 'License number cannot be empty'
        : null;

    if (nameError != null ||
        emailError != null ||
        phoneError != null ||
        passwordError != null ||
        licenseNoError != null) {
      _showSnackBar(
        nameError ??
            emailError ??
            phoneError ??
            passwordError ??
            licenseNoError!,
        backgroundColor: Colors.red,
      );
      return;
    }
  }

  // Handle sign-up with email and password
  Future<void> _handleSignUp() async {
    _validateFields();

    setState(() => _isLoading = true);
    try {
      final result = await _auth.signUpWithEmailAndPassword(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
        licenseNo: _licenseNoController.text.trim(),
      );

      if (result['error'] != null) {
        _showSnackBar(result['error'], backgroundColor: Colors.red);
      } else if (result['driver'] != null) {
        _showSnackBar('Sign-up successful');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else {
        _showSnackBar('Sign-up failed for unknown reason',
            backgroundColor: Colors.red);
      }
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e',
          backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign Up',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 25),
                      // Name Field
                      TextField(
                        controller: _nameController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.person,
                            color: AppColors.primaryDark,
                          ),
                          labelText: 'Full Name',
                          labelStyle:
                              GoogleFonts.inter(color: AppColors.grey700),
                          hintText: 'John Smith',
                          hintStyle:
                              GoogleFonts.inter(color: AppColors.grey500),
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
                      ),
                      const SizedBox(height: 20),
                      // Email Field
                      TextField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.email,
                            color: AppColors.primaryDark,
                          ),
                          labelText: 'Enter your email',
                          labelStyle:
                              GoogleFonts.inter(color: AppColors.grey700),
                          hintText: 'example@domain.com',
                          hintStyle:
                              GoogleFonts.inter(color: AppColors.grey500),
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
                      // Phone Field
                      TextField(
                        controller: _phoneController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.phone,
                            color: AppColors.primaryDark,
                          ),
                          labelText: 'Phone Number',
                          labelStyle:
                              GoogleFonts.inter(color: AppColors.grey700),
                          hintText: '+1234567890',
                          hintStyle:
                              GoogleFonts.inter(color: AppColors.grey500),
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
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),
                      // License Number Field
                      TextField(
                        controller: _licenseNoController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.card_membership,
                            color: AppColors.primaryDark,
                          ),
                          labelText: 'License Number',
                          labelStyle:
                              GoogleFonts.inter(color: AppColors.grey700),
                          hintText: 'ABC123456',
                          hintStyle:
                              GoogleFonts.inter(color: AppColors.grey500),
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
                      ),
                      const SizedBox(height: 20),
                      // Password Field
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
                          labelStyle:
                              GoogleFonts.inter(color: AppColors.grey700),
                          hintText: '••••••••',
                          hintStyle:
                              GoogleFonts.inter(color: AppColors.grey500),
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
                      const SizedBox(height: 20),
                      // Sign Up Button
                      GestureDetector(
                        onTap: _isLoading ? null : _handleSignUp,
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
                                    'Sign Up',
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
                      // Google Sign Up Button
                      
                      // Sign In Link
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignInPage(),
                                  ),
                                );
                              },
                        child: Text(
                          'Already have an account? Sign In',
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
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}