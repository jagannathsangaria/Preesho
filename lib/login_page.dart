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

  bool loading = false;
  bool otpSent = false;

  String? verificationId;

  // ============================================================
  // SEND OTP
  // ============================================================

  Future<void> sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

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

            Navigator.pop(context, true);
          } catch (e) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Automatic verification failed: $e',
                ),
              ),
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
                'Too many attempts. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            message =
                'SMS limit reached. Please try again later.';
          } else if (e.code == 'network-request-failed') {
            message =
                'Internet connection problem.';
          } else if (e.message != null &&
              e.message!.isNotEmpty) {
            message = e.message!;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 5),
            ),
          );
        },

        codeSent: (
          String verificationIdValue,
          int? resendToken,
        ) {
          if (!mounted) return;

          setState(() {
            verificationId = verificationIdValue;
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

        codeAutoRetrievalTimeout: (
          String verificationIdValue,
        ) {
          verificationId = verificationIdValue;
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong: $e',
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

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.length != 6 ||
        !RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
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

    FocusScope.of(context).unfocus();

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
        message = 'Incorrect OTP. Please try again.';
      } else if (e.code == 'session-expired') {
        message =
            'OTP expired. Please request a new OTP.';
      } else if (e.code == 'invalid-verification-id') {
        message =
            'Verification expired. Please request a new OTP.';
      } else if (e.code == 'too-many-requests') {
        message =
            'Too many attempts. Please try again later.';
      } else if (e.message != null &&
          e.message!.isNotEmpty) {
        message = e.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
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

  // ============================================================
  // CHANGE MOBILE NUMBER
  // ============================================================

  void changeMobile() {
    if (loading) return;

    setState(() {
      otpSent = false;
      verificationId = null;
      otpController.clear();
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
                        return 'Please enter your mobile number';
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

                  if (otpSent)
                    TextFormField(
                      controller: otpController,
                      enabled: !loading,
                      keyboardType:
                          TextInputType.number,
                      maxLength: 6,

                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
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

                      validator: (value) {
                        final otp =
                            value?.trim() ?? '';

                        if (otp.length != 6 ||
                            !RegExp(
                              r'^[0-9]{6}$',
                            ).hasMatch(otp)) {
                          return
                              'Enter a valid 6 digit OTP';
                        }

                        return null;
                      },
                    ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // BUTTON
                  // ==================================================

                  SizedBox(
                    height: 52,

                    child: FilledButton.icon(
                      onPressed: loading
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
                            ? otpSent
                                ? 'Verifying...'
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

                  const SizedBox(height: 12),

                  // ==================================================
                  // CHANGE NUMBER
                  // ==================================================

                  if (otpSent)
                    TextButton(
                      onPressed:
                          loading ? null : changeMobile,

                      child: const Text(
                        'Change Mobile Number',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  const Text(
                    'Your mobile number is required for login and order updates.',
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
