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

  final mobileController = TextEditingController();
  final otpController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();

  bool loading = false;
  bool otpSent = false;
  bool otpVerified = false;

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

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance
                .signInWithCredential(credential);

            if (!mounted) return;

            setState(() {
              otpVerified = true;
              loading = false;
            });

            showMessage('Mobile number verified.');
          } catch (_) {
            if (!mounted) return;

            setState(() {
              loading = false;
            });

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
          } else if (e.message != null &&
              e.message!.isNotEmpty) {
            message = e.message!;
          }

          setState(() {
            loading = false;
          });

          showMessage(message);
        },

        codeSent: (String id, int? resendToken) {
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

        codeAutoRetrievalTimeout: (String id) {
          verificationId = id;

          if (mounted) {
            setState(() {
              loading = false;
            });
          }
        },
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Something went wrong. Please try again.',
      );
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

      await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (!mounted) return;

      setState(() {
        otpVerified = true;
        loading = false;
      });

      showMessage(
        'Mobile number verified successfully.',
      );
    } on FirebaseAuthException catch (e) {
      String message = 'OTP verification failed.';

      if (e.code == 'invalid-verification-code') {
        message = 'Incorrect OTP. Please try again.';
      } else if (e.code == 'session-expired') {
        message =
            'OTP expired. Please request a new OTP.';
      } else if (e.code == 'invalid-credential') {
        message =
            'Invalid OTP. Please request a new OTP.';
      }

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Something went wrong. Please try again.',
      );
    }
  }

  // ============================================================
  // CREATE / SAVE CUSTOMER PROFILE
  // ============================================================

  Future<void> createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!otpVerified) {
      showMessage(
        'Please verify your mobile number with OTP first.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(
        'Mobile verification is incomplete. Please try again.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      final mobile = mobileController.text.trim();

      // ==========================================================
      // UPDATE DISPLAY NAME
      // ==========================================================

      try {
        await user.updateDisplayName(name);
      } catch (_) {}

      // ==========================================================
      // OPTIONAL EMAIL
      // ==========================================================

      if (email.isNotEmpty) {
        try {
          await user.updateEmail(email);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            if (!mounted) return;

            setState(() {
              loading = false;
            });

            showMessage(
              'This email is already linked to another account.',
            );
            return;
          }
        } catch (_) {}
      }

      // ==========================================================
      // SAVE CUSTOMER DATA
      // ==========================================================

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'name': name,
          'mobile': mobile,
          'phoneNumber': user.phoneNumber,
          'email': email.isEmpty ? null : email,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Account created successfully.',
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Could not save account details.\n'
        '${e.message ?? e.code}',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Account creation failed. Please try again.',
      );
    }
  }

  // ============================================================
  // CHANGE MOBILE NUMBER
  // ============================================================

  void changeMobile() {
    if (loading) return;

    setState(() {
      otpSent = false;
      otpVerified = false;
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
    nameController.dispose();
    emailController.dispose();
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
                    'Mobile number verification is required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =================================================
                  // MOBILE
                  // =================================================

                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    textInputAction:
                        otpSent
                            ? TextInputAction.next
                            : TextInputAction.done,
                    maxLength: 10,
                    enabled:
                        !otpVerified && !loading,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      hintText:
                          'Enter 10 digit mobile number',
                      prefixText: '+91 ',
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                      ),
                      counterText: '',
                      suffixIcon:
                          otpVerified
                              ? const Icon(
                                  Icons.verified,
                                  color: Colors.green,
                                )
                              : null,
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
                            'Enter a valid 10 digit number';
                      }

                      return null;
                    },
                  ),

                  // =================================================
                  // OTP
                  // =================================================

                  if (otpSent && !otpVerified) ...[
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

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed:
                          loading
                              ? null
                              : changeMobile,
                      child: const Text(
                        'Change Mobile Number',
                      ),
                    ),
                  ],

                  // =================================================
                  // SEND / VERIFY OTP
                  // =================================================

                  if (!otpVerified) ...[
                    const SizedBox(height: 16),

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
                  ],

                  // =================================================
                  // CUSTOMER DETAILS
                  // =================================================

                  if (otpVerified) ...[
                    const SizedBox(height: 24),

                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Mobile number verified: +91 ${mobileController.text}',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // NAME

                    TextFormField(
                      controller:
                          nameController,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          InputDecoration(
                        labelText: 'Full Name',
                        hintText:
                            'Enter your name',
                        prefixIcon:
                            const Icon(
                          Icons.person_outline,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (!otpVerified) {
                          return null;
                        }

                        if (value == null ||
                            value.trim().isEmpty) {
                          return
                              'Please enter your name';
                        }

                        if (value.trim().length <
                            2) {
                          return
                              'Please enter a valid name';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // EMAIL OPTIONAL

                    TextFormField(
                      controller:
                          emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.done,
                      decoration:
                          InputDecoration(
                        labelText:
                            'Email (Optional)',
                        hintText:
                            'Enter email if you want',
                        prefixIcon:
                            const Icon(
                          Icons.email_outlined,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final email =
                            value?.trim() ?? '';

                        if (email.isEmpty) {
                          return null;
                        }

                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return
                              'Enter a valid email';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // CREATE ACCOUNT

                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            loading
                                ? null
                                : createAccount,
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
                                : const Icon(
                                    Icons
                                        .person_add_alt_1,
                                  ),
                        label: Text(
                          loading
                              ? 'Creating Account...'
                              : 'Create Account',
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

                  const SizedBox(height: 20),

                  const Text(
                    'Mobile number is mandatory. Email is optional and can be added later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed:
                        loading
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
