import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final mobile = mobileController.text.trim();

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$mobile',

        // ======================================================
        // AUTO VERIFICATION
        // ======================================================

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(
              credential,
            );

            if (!mounted) return;

            await afterLogin();
          } catch (e) {
            if (!mounted) return;

            showMessage(
              'Automatic verification failed. Please enter OTP.',
            );
          }
        },

        // ======================================================
        // VERIFICATION FAILED
        // ======================================================

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
            message = 'Internet connection problem.';
          } else if (e.message != null &&
              e.message!.isNotEmpty) {
            message = e.message!;
          }

          showMessage(message);

          setState(() {
            loading = false;
          });
        },

        // ======================================================
        // CODE SENT
        // ======================================================

        codeSent: (
          String id,
          int? resendToken,
        ) {
          if (!mounted) return;

          verificationId = id;

          setState(() {
            otpSent = true;
            loading = false;
          });

          showMessage(
            'OTP sent to +91$mobile',
          );
        },

        // ======================================================
        // AUTO RETRIEVAL TIMEOUT
        // ======================================================

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

      showMessage(
        'Something went wrong. Please try again.',
      );

      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      showMessage('Please enter the 6 digit OTP.');
      return;
    }

    if (verificationId == null) {
      showMessage('Please request OTP again.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otp,
      );

      await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (!mounted) return;

      await afterLogin();
    } on FirebaseAuthException catch (e) {
      String message = 'OTP verification failed.';

      if (e.code == 'invalid-verification-code') {
        message = 'Incorrect OTP. Please check and try again.';
      } else if (e.code == 'session-expired') {
        message =
            'OTP expired. Please request a new OTP.';
      } else if (e.code == 'invalid-credential') {
        message =
            'Invalid OTP. Please request a new OTP.';
      }

      if (!mounted) return;

      showMessage(message);

      setState(() {
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Something went wrong. Please try again.',
      );

      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // AFTER LOGIN
  // ============================================================

  Future<void> afterLogin() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        showMessage('Login failed. Please try again.');
        setState(() {
          loading = false;
        });
      }
      return;
    }

    final mobile = mobileController.text.trim();

    // ==========================================================
    // CREATE / UPDATE USER DOCUMENT
    // ==========================================================

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'mobile': mobile,
          'phoneNumber': user.phoneNumber,
          'lastLoginAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Login should continue even if Firestore update fails.
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login successful'),
      ),
    );

    Navigator.pop(context, true);
  }

  // ============================================================
  // CHANGE NUMBER
  // ============================================================

  void changeNumber() {
    if (loading) return;

    setState(() {
      otpSent = false;
      verificationId = null;
      otpController.clear();
    });
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
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

                  // =================================================
                  // MOBILE NUMBER
                  // =================================================

                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    textInputAction:
                        otpSent
                            ? TextInputAction.next
                            : TextInputAction.done,
                    maxLength: 10,
                    enabled: !otpSent && !loading,
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

                  // =================================================
                  // OTP
                  // =================================================

                  if (otpSent) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: otpController,
                      keyboardType:
                          TextInputType.number,
                      textInputAction:
                          TextInputAction.done,
                      maxLength: 6,
                      onFieldSubmitted: (_) {
                        if (!loading) {
                          verifyOtp();
                        }
                      },
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

                    const SizedBox(height: 8),

                    Align(
                      alignment:
                          Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            loading
                                ? null
                                : changeNumber,
                        child: const Text(
                          'Change Mobile Number',
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // =================================================
                  // BUTTON
                  // =================================================

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                          loading
                              ? null
                              : otpSent
                                  ? verifyOtp
                                  : sendOtp,
                      icon:
                          loading
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
                            ? otpSent
                                ? 'Verifying...'
                                : 'Sending OTP...'
                            : otpSent
                                ? 'Verify OTP & Login'
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

                  const SizedBox(height: 20),

                  // =================================================
                  // INFORMATION
                  // =================================================

                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              otpSent
                                  ? 'OTP has been sent to your mobile number. Enter the OTP to continue.'
                                  : 'Your mobile number is required for login. A 6 digit OTP will be sent for verification.',
                              style: TextStyle(
                                color:
                                    Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // NOTE
                  // =================================================

                  const Text(
                    'Email is optional. You can add your email later from your profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
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
