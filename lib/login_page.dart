import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ============================================================
  // PASSWORD LOGIN CONTROLLERS
  // ============================================================

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // ============================================================
  // TEST MOBILE LOGIN CONTROLLER
  // ============================================================

  final mobileController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool mobileMode = false;

  // ============================================================
  // EMAIL + PASSWORD LOGIN
  // ============================================================

  Future<void> loginWithPassword() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter email and password');
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      showMessage('Login successful');
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';

      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Incorrect email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Try again later.';
      }

      showMessage(message);
    } catch (_) {
      showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  // ============================================================
  // TEST MOBILE LOGIN
  // NO OTP - FIREBASE ANONYMOUS AUTH
  // ============================================================

  Future<void> loginWithTestMobile() async {
    final mobile = mobileController.text.trim();

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      showMessage('Please enter a valid 10 digit mobile number');
      return;
    }

    setState(() => loading = true);

    try {
      // If user is already logged in, use existing user.
      User? user = FirebaseAuth.instance.currentUser;

      // Otherwise create anonymous Firebase user.
      if (user == null) {
        final result =
            await FirebaseAuth.instance.signInAnonymously();

        user = result.user;
      }

      if (!mounted) return;

      showMessage('Test login successful');

      // Return true to previous page (Checkout)
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String message = 'Test login failed';

      if (e.code == 'operation-not-allowed') {
        message =
            'Anonymous login is not enabled in Firebase.';
      } else if (e.code == 'network-request-failed') {
        message =
            'Please check your internet connection.';
      } else if (e.message != null) {
        message = e.message!;
      }

      showMessage(message);
    } catch (_) {
      showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          mobileMode ? 'Test Mobile Login' : 'Login',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Icon(
                  mobileMode
                      ? Icons.phone_android
                      : Icons.shopping_bag_outlined,
                  size: 80,
                ),

                const SizedBox(height: 20),

                Text(
                  mobileMode
                      ? 'Login with Mobile'
                      : 'Welcome back!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  mobileMode
                      ? 'Enter your mobile number to continue'
                      : 'Login to continue shopping',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 30),

                // =================================================
                // EMAIL + PASSWORD MODE
                // =================================================

                if (!mobileMode) ...[
                  TextFormField(
                    controller: emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    textInputAction:
                        TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    textInputAction:
                        TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!loading) {
                        loginWithPassword();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
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
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  Align(
                    alignment:
                        Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ForgotPasswordPage(),
                                ),
                              );
                            },
                      child: const Text(
                        'Forgot Password?',
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: loading
                          ? null
                          : loginWithPassword,
                      icon: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        loading
                            ? 'Logging in...'
                            : 'Login',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () {
                            setState(() {
                              mobileMode = true;
                            });
                          },
                    icon: const Icon(
                      Icons.phone_android,
                    ),
                    label: const Text(
                      'Login with Mobile',
                    ),
                  ),
                ],

                // =================================================
                // TEST MOBILE LOGIN MODE
                // =================================================

                if (mobileMode) ...[
                  TextFormField(
                    controller: mobileController,
                    keyboardType:
                        TextInputType.phone,
                    maxLength: 10,
                    textInputAction:
                        TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!loading) {
                        loginWithTestMobile();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon:
                          const Icon(Icons.phone),
                      prefixText: '+91 ',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: loading
                          ? null
                          : loginWithTestMobile,
                      icon: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.login,
                            ),
                      label: Text(
                        loading
                            ? 'Please wait...'
                            : 'Continue',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () {
                            setState(() {
                              mobileMode = false;
                              mobileController.clear();
                            });
                          },
                    icon: const Icon(
                      Icons.password,
                    ),
                    label: const Text(
                      'Login with Password',
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Test Mode: No OTP will be sent. You can continue using any valid 10 digit mobile number.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],

                if (!mobileMode) ...[
                  const SizedBox(height: 20),

                  Text(
                    'Use your email and password to login securely.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
