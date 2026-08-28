import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final mobileController = TextEditingController();
  final otpController = TextEditingController();

  bool loading = false;
  bool otpSent = false;

  String? verificationId;

  // ============================================================
  // SEND OTP
  // ============================================================

  Future<void> sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final mobile = mobileController.text.trim();

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$mobile',

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(
              credential,
            );

            if (!mounted) return;

            await saveUserData();

            if (!mounted) return;

            Navigator.pop(context, true);
          } catch (e) {
            if (!mounted) return;

            showMessage(
              'Automatic verification failed. Please enter OTP.',
            );
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          String message = 'OTP could not be sent.';

          if (e.code == 'invalid-phone-number') {
            message = 'Please enter a valid mobile number.';
          } else if (e.code == 'too-many-requests') {
            message =
                'Too many OTP requests. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            message =
                'SMS limit reached. Please try again later.';
          } else if (e.code == 'network-request-failed') {
            message =
                'Internet connection problem.';
          }

          showMessage(message);

          setState(() {
            loading = false;
          });
        },

        codeSent: (String id, int? resendToken) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            otpSent = true;
            loading = false;
          });

          showMessage(
            'OTP sent to +91$mobile',
          );
        },

        codeAutoRetrievalTimeout: (String id) {
          verificationId = id;

          if (mounted) {
            setState(() {
              loading = false;
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Unable to send OTP. Please try again.',
      );
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> verifyOtp() async {
    if (verificationId == null) {
      showMessage('Please request OTP first.');
      return;
    }

    final otp = otpController.text.trim();

    if (otp.length != 6 ||
        !RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      showMessage('Please enter the 6 digit OTP.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otp,
      );

      final result = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (result.user == null) {
        throw Exception('Login failed');
      }

      await saveUserData();

      if (!mounted) return;

      showMessage('Login successful');

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'OTP verification failed.';

      if (e.code == 'invalid-verification-code') {
        message = 'Incorrect OTP. Please check and try again.';
      } else if (e.code == 'session-expired') {
        message =
            'OTP expired. Please request a new OTP.';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid OTP. Please try again.';
      }

      showMessage(message);
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE / UPDATE USER
  // ============================================================

  Future<void> saveUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final mobile = mobileController.text.trim();

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final snapshot = await userRef.get();

      if (!snapshot.exists) {
        await userRef.set(
          {
            'uid': user.uid,
            'mobile': mobile,
            'phoneNumber': '+91$mobile',
            'createdAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        await userRef.set(
          {
            'mobile': mobile,
            'phoneNumber': '+91$mobile',
            'lastLoginAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // Login should not fail only because
      // Firestore profile update failed.
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // SIGN UP
  // ============================================================

  Future<void> openSignup() async {
    if (loading) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SignupPage(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      showMessage(
        'Account details saved. Please login with your mobile number.',
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    mobileController.dispose();
    otpController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Login',
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
                    Icons.phone_android,
                    size: 80,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Welcome to Preesho',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Login with your mobile number',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ==================================================
                  // MOBILE NUMBER
                  // ==================================================

                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    enabled: !otpSent,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      hintText: 'Enter 10 digit mobile number',
                      prefixText: '+91 ',
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

                  // ==================================================
                  // OTP
                  // ==================================================

                  if (otpSent) ...[
                    TextFormField(
                      controller: otpController,
                      keyboardType:
                          TextInputType.number,
                      maxLength: 6,
                      textInputAction:
                          TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'OTP',
                        hintText: 'Enter 6 digit OTP',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Align(
                      alignment:
                          Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            loading
                                ? null
                                : () {
                                    setState(() {
                                      otpSent = false;
                                      verificationId =
                                          null;
                                      otpController
                                          .clear();
                                    });
                                  },
                        child: const Text(
                          'Change Number',
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],

                  // ==================================================
                  // BUTTON
                  // ==================================================

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                          loading
                              ? null
                              : otpSent
                                  ? verifyOtp
                                  : sendOtp,
                      icon: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              otpSent
                                  ? Icons.verified
                                  : Icons.sms_outlined,
                            ),
                      label: Text(
                        loading
                            ? 'Please wait...'
                            : otpSent
                                ? 'Verify OTP'
                                : 'Send OTP',
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed:
                        loading
                            ? null
                            : openSignup,
                    child: const Text(
                      "New customer? Create Account",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Mobile number and OTP are required for login.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
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
