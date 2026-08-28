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
      final phoneNumber = '+91$mobile';

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance
                .signInWithCredential(credential);

            if (!mounted) return;

            await saveUserData();

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
          } else if (e.message != null) {
            message = e.message!;
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

          showMessage('OTP sent successfully.');
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

      showMessage(
        'Unable to send OTP. Please try again.',
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

    if (otp.length != 6 ||
        !RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
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
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otp,
      );

      await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await saveUserData();

      if (!mounted) return;

      showMessage('Login successful.');

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'OTP verification failed.';

      if (e.code == 'invalid-verification-code') {
        message = 'Incorrect OTP. Please check and try again.';
      } else if (e.code == 'session-expired') {
        message = 'OTP expired. Please request a new OTP.';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid OTP. Please request a new OTP.';
      }

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
  // SAVE / UPDATE USER DATA
  // ============================================================

  Future<void> saveUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final mobile = mobileController.text.trim();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(
      {
        'uid': user.uid,
        'mobile': mobile,
        'phoneNumber': user.phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
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
  // CHANGE NUMBER
  // ============================================================

  void changeMobileNumber() {
    setState(() {
      otpSent = false;
      verificationId = null;
      otpController.clear();
      loading = false;
    });
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
                    Icons.shopping_bag_outlined,
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
                    otpSent
                        ? 'Enter the OTP sent to your mobile'
                        : 'Login using your mobile number',
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

                  if (!otpSent)
                    TextFormField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      maxLength: 10,

                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        hintText:
                            'Enter 10 digit mobile number',

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

                      onFieldSubmitted: (_) {
                        if (!loading) {
                          sendOtp();
                        }
                      },
                    ),

                  // ==================================================
                  // OTP
                  // ==================================================

                  if (otpSent)
                    Column(
                      children: [
                        TextFormField(
                          controller: otpController,
                          keyboardType:
                              TextInputType.number,
                          textInputAction:
                              TextInputAction.done,
                          maxLength: 6,

                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),

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

                          onFieldSubmitted: (_) {
                            if (!loading) {
                              verifyOtp();
                            }
                          },
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'OTP sent to +91 ${mobileController.text}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextButton(
                          onPressed:
                              loading
                                  ? null
                                  : changeMobileNumber,
                          child: const Text(
                            'Change Mobile Number',
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // BUTTON
                  // ==================================================

                  SizedBox(
                    height: 54,

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
                                  ? Icons.verified_outlined
                                  : Icons.sms_outlined,
                            ),

                      label: Text(
                        loading
                            ? otpSent
                                ? 'Verifying OTP...'
                                : 'Sending OTP...'
                            : otpSent
                                ? 'Verify OTP'
                                : 'Send OTP',

                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

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
                    'Email is optional and can be added later for order updates.',
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
