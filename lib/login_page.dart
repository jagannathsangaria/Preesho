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

    setState(() {
      loading = true;
    });

    final mobile = mobileController.text.trim();

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

            await loadUserData();

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
            message = 'Internet connection problem.';
          }

          showMessage(message);
        },

        codeSent: (String id, int? resendToken) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            otpSent = true;
          });

          showMessage(
            'OTP sent to +91 $mobile',
          );
        },

        codeAutoRetrievalTimeout: (String id) {
          verificationId = id;
        },
      );
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
  // VERIFY OTP
  // ============================================================

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.length != 6) {
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

      await loadUserData();

      if (!mounted) return;

      showMessage('Login successful');

      Navigator.pop(context, true);
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
  // LOAD / CREATE USER DATA
  // ============================================================

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      await userRef.set(
        {
          'uid': user.uid,
          'mobile': user.phoneNumber ?? '',
          'name': '',
          'email': '',
          'address': '',
          'city': '',
          'pincode': '',
          'createdAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      await userRef.set(
        {
          'uid': user.uid,
          'mobile': user.phoneNumber ?? '',
          'lastLoginAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
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
                    keyboardType:
                        TextInputType.phone,
                    maxLength: 10,
                    enabled: !otpSent && !loading,

                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      hintText:
                          'Enter 10 digit mobile number',
                      prefixIcon:
                          const Icon(Icons.phone_outlined),
                      prefixText: '+91 ',
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
                        return
                            'Please enter mobile number';
                      }

                      if (!RegExp(
                        r'^[0-9]{10}$',
                      ).hasMatch(mobile)) {
                        return
                            'Mobile number must be exactly 10 digits';
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
                      controller:
                          otpController,
                      keyboardType:
                          TextInputType.number,
                      maxLength: 6,

                      decoration: InputDecoration(
                        labelText: 'OTP',
                        hintText:
                            'Enter 6 digit OTP',
                        prefixIcon:
                            const Icon(
                          Icons.lock_outline,
                        ),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),

                      validator: (value) {
                        final otp =
                            value?.trim() ?? '';

                        if (otp.length != 6) {
                          return
                              'Enter the 6 digit OTP';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            loading
                                ? null
                                : verifyOtp,

                        icon: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.verified,
                              ),

                        label: Text(
                          loading
                              ? 'Verifying...'
                              : 'Verify OTP & Login',

                          style:
                              const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              setState(() {
                                otpSent = false;
                                verificationId = null;
                                otpController.clear();
                              });
                            },
                      child: const Text(
                        'Change Mobile Number',
                      ),
                    ),
                  ]

                  // ==================================================
                  // SEND OTP BUTTON
                  // ==================================================

                  else ...[
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            loading
                                ? null
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
                            : const Icon(
                                Icons.sms_outlined,
                              ),

                        label: Text(
                          loading
                              ? 'Sending OTP...'
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
                  ],

                  const SizedBox(height: 24),

                  const Text(
                    'Mobile number verification is required to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Email is optional and can be added later from your profile.',
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

  @override
  void dispose() {
    mobileController.dispose();
    otpController.dispose();
    super.dispose();
  }
}
