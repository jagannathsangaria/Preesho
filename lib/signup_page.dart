import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  Future<void> signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (passwordController.text !=
        confirmPasswordController.text) {
      showMessage('Passwords do not match');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text;
      final name = nameController.text.trim();
      final mobile = mobileController.text.trim();

      // =================================================
      // STEP 1: CREATE FIREBASE AUTH ACCOUNT
      // =================================================

      UserCredential credential;

      try {
        credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        String message = 'Sign up failed';

        if (e.code == 'email-already-in-use') {
          message =
              'This email is already registered. Please login.';
        } else if (e.code == 'invalid-email') {
          message = 'Please enter a valid email address.';
        } else if (e.code == 'weak-password') {
          message =
              'Password is too weak. Use at least 6 characters.';
        } else if (e.code == 'network-request-failed') {
          message =
              'Internet connection problem. Please try again.';
        } else if (e.code == 'operation-not-allowed') {
          message =
              'Email/Password authentication is not enabled.';
        }

        showMessage(message);
        return;
      }

      final user = credential.user;

      if (user == null) {
        showMessage(
          'Account could not be created. Please try again.',
        );
        return;
      }

      // =================================================
      // STEP 2: UPDATE FIREBASE USER PROFILE
      // =================================================

      try {
        await user.updateDisplayName(name);
      } catch (_) {
        // Profile update failure should NOT make signup fail.
      }

      // =================================================
      // STEP 3: SAVE CUSTOMER DATA TO FIRESTORE
      // =================================================

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
          {
            'uid': user.uid,
            'name': name,
            'mobile': mobile,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (firestoreError) {
        // IMPORTANT:
        // Authentication account is already successfully created.
        //
        // If Firestore fails, do NOT tell the customer
        // that signup failed.
        //
        // The account can still be used for login.
      }

      if (!mounted) return;

      // =================================================
      // STEP 4: SUCCESS
      // =================================================

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created successfully. Please login.',
          ),
        ),
      );

      // Sign out so the user reaches the normal login flow.
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account creation could not be completed. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 75,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Create your Preesho account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Join Preesho and start shopping',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =================================================
                  // NAME
                  // =================================================

                  TextFormField(
                    controller: nameController,
                    textInputAction:
                        TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your name',
                      prefixIcon: const Icon(
                        Icons.person_outline,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Please enter your name';
                      }

                      if (value.trim().length < 2) {
                        return 'Please enter a valid name';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // =================================================
                  // MOBILE
                  // =================================================

                  TextFormField(
                    controller: mobileController,
                    keyboardType:
                        TextInputType.phone,
                    textInputAction:
                        TextInputAction.next,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      hintText:
                          'Enter 10 digit mobile number',
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                      ),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      final mobile =
                          value?.trim() ?? '';

                      if (mobile.isEmpty) {
                        return 'Please enter mobile number';
                      }

                      if (!RegExp(
                        r'^[0-9]{10}$',
                      ).hasMatch(mobile)) {
                        return 'Enter a valid 10 digit number';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // =================================================
                  // EMAIL
                  // =================================================

                  TextFormField(
                    controller: emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    textInputAction:
                        TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText:
                          'Enter your email',
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      final email =
                          value?.trim() ?? '';

                      if (email.isEmpty) {
                        return 'Please enter your email';
                      }

                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Enter a valid email';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // =================================================
                  // PASSWORD
                  // =================================================

                  TextFormField(
                    controller:
                        passwordController,
                    obscureText: obscurePassword,
                    textInputAction:
                        TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText:
                          'Minimum 6 characters',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword =
                                !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Please enter a password';
                      }

                      if (value.length < 6) {
                        return
                            'Password must be at least 6 characters';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // =================================================
                  // CONFIRM PASSWORD
                  // =================================================

                  TextFormField(
                    controller:
                        confirmPasswordController,
                    obscureText:
                        obscureConfirmPassword,
                    textInputAction:
                        TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!loading) {
                        signup();
                      }
                    },
                    decoration: InputDecoration(
                      labelText:
                          'Confirm Password',
                      hintText:
                          'Enter password again',
                      prefixIcon: const Icon(
                        Icons.lock_reset_outlined,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword =
                                !obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return
                            'Please confirm your password';
                      }

                      if (value !=
                          passwordController.text) {
                        return
                            'Passwords do not match';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // CREATE ACCOUNT BUTTON
                  // =================================================

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed:
                          loading ? null : signup,
                      child: loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // LOGIN
                  // =================================================

                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            Navigator.pop(
                              context,
                            );
                          },
                    child: const Text(
                      'Already have an account? Login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
