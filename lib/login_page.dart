import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final mobileController = TextEditingController();
  final otpController = TextEditingController();

  String? verificationId;

  bool loading = false;
  bool otpSent = false;

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

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance
                .signInWithCredential(credential);

            if (!mounted) return;

            Navigator.pop(context, true);
          } catch (e) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Automatic verification failed. Please enter OTP.',
                ),
              ),
            );
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          String message = 'OTP could not be sent.';

          if (e.code == 'invalid-phone-number') {
            message = 'Please enter a valid 10 digit mobile number.';
          } else if (e.code == 'too-many-requests') {
            message =
                'Too many OTP requests. Please try again later.';
          } else if (e.code == 'network-request-failed') {
            message = 'Internet connection problem.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
            ),
          );

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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'OTP sent successfully.',
              ),
            ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter the 6 digit OTP.',
          ),
        ),
      );
      return;
    }

    if (verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please request OTP again.',
          ),
        ),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login successful.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'OTP verification failed.';

      if (e.code == 'invalid-verification-code') {
        message = 'Incorrect OTP. Please check and try again.';
      } else if (e.code == 'session-expired') {
        message =
            'OTP expired. Please request a new OTP.';
      } else if (e.code == 'too-many-requests') {
        message =
            'Too many attempts. Please try again later.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );

      setState(() {
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // CHANGE NUMBER
  // ============================================================

  void changeNumber() {
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
                    enabled: !otpSent && !loading,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,

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
                        return
                            'Mobile number must be exactly 10 digits';
                      }

                      return null;
                    },
                  ),

                  // ==================================================
                  // OTP
                  // ==================================================

                  if (otpSent) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: otpController,
                      keyboardType:
                          TextInputType.number,
                      maxLength: 6,

                      decoration: InputDecoration(
                        labelText: 'OTP',
                        hintText:
                            'Enter 6 digit OTP',
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

                    const SizedBox(height: 10),

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

                  const SizedBox(height: 18),

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
                                  ? Icons.verified_outlined
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

                  const SizedBox(height: 20),

                  const Text(
                    'Mobile number verification is required to continue.',
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
