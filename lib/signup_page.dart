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
            final userCredential =
                await FirebaseAuth.instance
                    .signInWithCredential(
              credential,
            );

            await saveCustomerData(
              userCredential.user,
            );
          } catch (e) {
            if (!mounted) return;

            showMessage(
              'Automatic verification failed. Please enter OTP.',
            );

            setState(() {
              loading = false;
            });
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          String message =
              'OTP could not be sent.';

          if (e.code == 'invalid-phone-number') {
            message =
                'Please enter a valid mobile number.';
          } else if (e.code == 'too-many-requests') {
            message =
                'Too many attempts. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            message =
                'SMS limit reached. Please try again later.';
          } else if (e.code ==
              'network-request-failed') {
            message =
                'Internet connection problem.';
          } else if (e.code ==
              'operation-not-allowed') {
            message =
                'Phone authentication is not enabled in Firebase.';
          }

          showMessage(message);

          setState(() {
            loading = false;
          });
        },

        codeSent:
            (String id, int? resendToken) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            otpSent = true;
            loading = false;
          });

          showMessage(
            'OTP sent to +91 $mobile',
          );
        },

        codeAutoRetrievalTimeout:
            (String id) {
          verificationId = id;
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final otp = otpController.text.trim();

    if (verificationId == null) {
      showMessage(
        'Please request OTP again.',
      );
      return;
    }

    if (!RegExp(
      r'^[0-9]{6}$',
    ).hasMatch(otp)) {
      showMessage(
        'Please enter a valid 6 digit OTP.',
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

      final userCredential =
          await FirebaseAuth.instance
              .signInWithCredential(
        credential,
      );

      await saveCustomerData(
        userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      String message =
          'OTP verification failed.';

      if (e.code ==
          'invalid-verification-code') {
        message =
            'Incorrect OTP. Please check and try again.';
      } else if (e.code == 'session-expired') {
        message =
            'OTP has expired. Please request a new OTP.';
      } else if (e.code ==
          'credential-already-in-use') {
        message =
            'This mobile number is already registered.';
      } else if (e.code ==
          'network-request-failed') {
        message =
            'Internet connection problem.';
      }

      if (!mounted) return;

      showMessage(message);

      setState(() {
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Account creation failed. Please try again.',
      );

      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // SAVE CUSTOMER DATA
  // ============================================================

  Future<void> saveCustomerData(
    User? user,
  ) async {
    if (user == null) {
      if (mounted) {
        showMessage(
          'Account could not be created.',
        );

        setState(() {
          loading = false;
        });
      }

      return;
    }

    try {
      final name =
          nameController.text.trim();

      final mobile =
          mobileController.text.trim();

      final email =
          emailController.text.trim();

      final data = <String, dynamic>{
        'uid': user.uid,
        'name': name,
        'mobile': mobile,
        'phoneNumber': '+91$mobile',
        'createdAt':
            FieldValue.serverTimestamp(),
      };

      // ========================================================
      // EMAIL IS OPTIONAL
      // ========================================================

      if (email.isNotEmpty) {
        data['email'] = email;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        data,
        SetOptions(
          merge: true,
        ),
      );

      // Save name in Firebase Auth profile.
      try {
        await user.updateDisplayName(name);
      } catch (_) {}

      if (!mounted) return;

      showMessage(
        'Account created successfully.',
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      showMessage(
        'Account created, but customer details could not be saved.\n'
        '${e.message ?? e.code}',
      );

      setState(() {
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Account created, but details could not be saved.',
      );

      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // CHANGE MOBILE
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
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();
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
          'Create Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),

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
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    otpSent
                        ? 'Enter the OTP sent to your mobile'
                        : 'Mobile verification is required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =================================================
                  // NAME
                  // =================================================

                  TextFormField(
                    controller:
                        nameController,
                    enabled: !loading,

                    textInputAction:
                        TextInputAction.next,

                    decoration:
                        InputDecoration(
                      labelText:
                          'Full Name',
                      hintText:
                          'Enter your name',
                      prefixIcon:
                          const Icon(
                        Icons.person_outline,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                    ),

                    validator: (value) {
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

                  // =================================================
                  // MOBILE
                  // =================================================

                  TextFormField(
                    controller:
                        mobileController,

                    enabled:
                        !otpSent && !loading,

                    keyboardType:
                        TextInputType.phone,

                    textInputAction:
                        TextInputAction.next,

                    maxLength: 10,

                    decoration:
                        InputDecoration(
                      labelText:
                          'Mobile Number',
                      hintText:
                          'Enter 10 digit mobile number',
                      prefixText:
                          '+91 ',
                      prefixIcon:
                          const Icon(
                        Icons.phone_outlined,
                      ),
                      counterText: '',
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
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

                  // =================================================
                  // EMAIL OPTIONAL
                  // =================================================

                  TextFormField(
                    controller:
                        emailController,

                    enabled: !loading,

                    keyboardType:
                        TextInputType.emailAddress,

                    textInputAction:
                        TextInputAction.next,

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
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                    ),

                    validator: (value) {
                      final email =
                          value?.trim() ?? '';

                      // EMAIL OPTIONAL
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

                  // =================================================
                  // OTP
                  // =================================================

                  if (otpSent) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                          otpController,

                      enabled: !loading,

                      keyboardType:
                          TextInputType.number,

                      maxLength: 6,

                      textAlign:
                          TextAlign.center,

                      style:
                          const TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 5,
                      ),

                      decoration:
                          InputDecoration(
                        labelText: 'OTP',
                        hintText:
                            'Enter 6 digit OTP',
                        prefixIcon:
                            const Icon(
                          Icons.lock_outline,
                        ),
                        counterText: '',
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                      ),

                      validator: (value) {
                        final otp =
                            value?.trim() ?? '';

                        if (!RegExp(
                          r'^[0-9]{6}$',
                        ).hasMatch(otp)) {
                          return
                              'Enter valid 6 digit OTP';
                        }

                        return null;
                      },
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

                  const SizedBox(height: 20),

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
                                ? 'Creating Account...'
                                : 'Sending OTP...'
                            : otpSent
                                ? 'Verify OTP & Create Account'
                                : 'Send OTP',

                        textAlign:
                            TextAlign.center,

                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Mobile OTP verification is mandatory.\n'
                    'Email is optional and can be added for order updates.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // LOGIN
                  // =================================================

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
