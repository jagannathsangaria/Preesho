import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'onboarding_page.dart';
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
  // OTP LOGIN CONTROLLERS
  // ============================================================

  final mobileController = TextEditingController();
  final otpController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  bool otpMode = false;
  bool otpSent = false;

  String verificationId = '';
  int? resendToken;

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
  // SEND OTP
  // ============================================================

  Future<void> sendOtp({bool resend = false}) async {
    final mobile = mobileController.text.trim();

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      showMessage('Please enter a valid 10 digit mobile number');
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$mobile',
        forceResendingToken: resend ? resendToken : null,

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            final credentialResult =
                await FirebaseAuth.instance
                    .signInWithCredential(credential);

            await handlePhoneLogin(
              credentialResult.user,
            );
          } catch (_) {
            if (mounted) {
              showMessage('Automatic verification failed');
            }
          }
        },

        verificationFailed:
            (FirebaseAuthException e) {
          if (!mounted) return;

          String message = 'OTP verification failed';

          if (e.code == 'invalid-phone-number') {
            message = 'Invalid mobile number.';
          } else if (e.code == 'too-many-requests') {
            message =
                'Too many requests. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            message =
                'SMS quota exceeded. Please try again later.';
          } else if (e.message != null) {
            message = e.message!;
          }

          setState(() => loading = false);
          showMessage(message);
        },

        codeSent: (
          String newVerificationId,
          int? newResendToken,
        ) {
          if (!mounted) return;

          setState(() {
            verificationId = newVerificationId;
            resendToken = newResendToken;
            otpSent = true;
            loading = false;
          });

          showMessage('OTP sent successfully');
        },

        codeAutoRetrievalTimeout:
            (String newVerificationId) {
          verificationId = newVerificationId;
        },

        timeout: const Duration(seconds: 60),
      );
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        showMessage('Could not send OTP. Please try again.');
      }
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      showMessage('Please enter a valid 6 digit OTP');
      return;
    }

    if (verificationId.isEmpty) {
      showMessage('Please request OTP first');
      return;
    }

    setState(() => loading = true);

    try {
      final credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final result =
          await FirebaseAuth.instance
              .signInWithCredential(credential);

      await handlePhoneLogin(result.user);
    } on FirebaseAuthException catch (e) {
      String message = 'OTP verification failed';

      if (e.code == 'invalid-verification-code') {
        message = 'Incorrect OTP.';
      } else if (e.code == 'session-expired') {
        message =
            'OTP expired. Please request a new OTP.';
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
  // CHECK IF NEW OR EXISTING USER
  // ============================================================

  Future<void> handlePhoneLogin(User? user) async {
    if (user == null) {
      showMessage('Login failed. Please try again.');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      // NEW USER → ONBOARDING
      if (!doc.exists ||
          doc.data()?['onboardingCompleted'] != true) {
        final completed =
            await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const OnboardingPage(),
          ),
        );

        if (completed == true && mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // EXISTING USER → LOGIN COMPLETE
        showMessage('Login successful');
        Navigator.pop(context, true);
      }
    } catch (_) {
      // If Firestore has a temporary issue,
      // allow authenticated user to continue.
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    mobileController.dispose();
    otpController.dispose();
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
          otpMode
              ? 'Login with Mobile'
              : 'Login',
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
                  otpMode
                      ? Icons.phone_android
                      : Icons.shopping_bag_outlined,
                  size: 80,
                ),

                const SizedBox(height: 20),

                Text(
                  otpMode
                      ? 'Login with Mobile OTP'
                      : 'Welcome back!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  otpMode
                      ? otpSent
                          ? 'Enter the OTP sent to your mobile'
                          : 'Enter your mobile number'
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

                if (!otpMode) ...[
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
                    controller:
                        passwordController,
                    obscureText:
                        obscurePassword,
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
                              otpMode = true;
                              otpSent = false;
                            });
                          },
                    icon: const Icon(
                      Icons.phone_android,
                    ),
                    label: const Text(
                      'Login with Mobile OTP',
                    ),
                  ),
                ],

                // =================================================
                // MOBILE OTP MODE
                // =================================================

                if (otpMode) ...[
                  if (!otpSent)
                    TextFormField(
                      controller:
                          mobileController,
                      keyboardType:
                          TextInputType.phone,
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText:
                            'Mobile Number',
                        prefixIcon:
                            const Icon(Icons.phone),
                        prefixText: '+91 ',
                        counterText: '',
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                    ),

                  if (otpSent) ...[
                    Text(
                      '+91 ${mobileController.text}',
                      textAlign:
                          TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller:
                          otpController,
                      keyboardType:
                          TextInputType.number,
                      maxLength: 6,
                      textAlign:
                          TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight:
                            FontWeight.bold,
                      ),
                      decoration:
                          InputDecoration(
                        labelText:
                            '6 Digit OTP',
                        counterText: '',
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: loading
                          ? null
                          : () {
                              if (otpSent) {
                                verifyOtp();
                              } else {
                                sendOtp();
                              }
                            },
                      icon: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              otpSent
                                  ? Icons.verified
                                  : Icons.sms,
                            ),
                      label: Text(
                        loading
                            ? 'Please wait...'
                            : otpSent
                                ? 'Verify OTP'
                                : 'Send OTP',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  if (otpSent) ...[
                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              sendOtp(resend: true);
                            },
                      child:
                          const Text('Resend OTP'),
                    ),

                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              setState(() {
                                otpSent = false;
                                otpController.clear();
                                verificationId = '';
                              });
                            },
                      child: const Text(
                        'Change Mobile Number',
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () {
                            setState(() {
                              otpMode = false;
                              otpSent = false;
                              otpController.clear();
                            });
                          },
                    icon: const Icon(
                      Icons.password,
                    ),
                    label: const Text(
                      'Login with Password',
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                Text(
                  otpMode
                      ? 'New users can verify their mobile number and create their account.'
                      : 'Use your email and password to login securely.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
