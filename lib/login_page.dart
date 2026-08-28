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

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      showMessage(
        'Mobile number must be exactly 10 digits.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final phoneNumber = '+91$mobile';

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,

        // ======================================================
        // AUTOMATIC VERIFICATION
        // ======================================================

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance
                .signInWithCredential(credential);

            if (!mounted) return;

            await loadCustomerData();

            if (!mounted) return;

            Navigator.pop(context, true);
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

        verificationFailed:
            (FirebaseAuthException e) {
          if (!mounted) return;

          String message =
              'OTP could not be sent.';

          if (e.code == 'invalid-phone-number') {
            message =
                'Please enter a valid 10 digit mobile number.';
          } else if (e.code ==
              'too-many-requests') {
            message =
                'Too many attempts. Please try again later.';
          } else if (e.code ==
              'quota-exceeded') {
            message =
                'SMS quota exceeded. Please try again later.';
          } else if (e.code ==
              'operation-not-allowed') {
            message =
                'Phone authentication is not enabled in Firebase.';
          } else if (e.code ==
              'network-request-failed') {
            message =
                'Internet connection problem.';
          } else if (e.message != null) {
            message = e.message!;
          }

          showMessage(message);
        },

        // ======================================================
        // OTP SENT
        // ======================================================

        codeSent: (
          String id,
          int? resendToken,
        ) {
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

        // ======================================================
        // AUTO RETRIEVAL TIMEOUT
        // ======================================================

        codeAutoRetrievalTimeout:
            (String id) {
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

    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      showMessage(
        'Please enter the 6 digit OTP.',
      );
      return;
    }

    if (verificationId == null) {
      showMessage(
        'Please request OTP again.',
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

      await FirebaseAuth.instance
          .signInWithCredential(
        credential,
      );

      if (!mounted) return;

      await loadCustomerData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login successful',
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message =
          'OTP verification failed.';

      if (e.code == 'invalid-verification-code') {
        message =
            'Incorrect OTP. Please check and try again.';
      } else if (e.code ==
          'session-expired') {
        message =
            'OTP expired. Please request a new OTP.';
      } else if (e.code ==
          'invalid-credential') {
        message =
            'Invalid OTP. Please try again.';
      } else if (e.code ==
          'network-request-failed') {
        message =
            'Internet connection problem.';
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
  // LOAD / CREATE CUSTOMER DATA
  // ============================================================

  Future<void> loadCustomerData() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final userRef = FirebaseFirestore
          .instance
          .collection('users')
          .doc(user.uid);

      final snapshot =
          await userRef.get();

      if (!snapshot.exists) {
        await userRef.set(
          {
            'uid': user.uid,
            'mobile':
                mobileController.text.trim(),
            'createdAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      } else {
        await userRef.set(
          {
            'uid': user.uid,
            'mobile':
                mobileController.text.trim(),
            'lastLoginAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      }
    } catch (_) {
      // Authentication is successful even if
      // Firestore temporarily fails.
    }
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mobile Login',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
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
                  // =================================================
                  // ICON
                  // =================================================

                  const Icon(
                    Icons
                        .phone_android_outlined,
                    size: 80,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // =================================================
                  // TITLE
                  // =================================================

                  const Text(
                    'Welcome to Preesho',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    otpSent
                        ? 'Enter the OTP sent to your mobile'
                        : 'Login with your mobile number',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: Colors
                          .grey
                          .shade700,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(
                    height: 32,
                  ),

                  // =================================================
                  // MOBILE NUMBER
                  // =================================================

                  TextFormField(
                    controller:
                        mobileController,

                    enabled:
                        !otpSent &&
                            !loading,

                    keyboardType:
                        TextInputType.phone,

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
                        Icons
                            .phone_outlined,
                      ),

                      counterText:
                          '',

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                    ),

                    validator:
                        (value) {
                      final mobile =
                          value?.trim() ??
                              '';

                      if (mobile.isEmpty) {
                        return 'Please enter mobile number';
                      }

                      if (!RegExp(
                        r'^[0-9]{10}$',
                      ).hasMatch(
                        mobile,
                      )) {
                        return 'Mobile number must be exactly 10 digits';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // =================================================
                  // OTP
                  // =================================================

                  if (otpSent) ...[
                    TextFormField(
                      controller:
                          otpController,

                      enabled:
                          !loading,

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
                        letterSpacing:
                            8,
                      ),

                      decoration:
                          InputDecoration(
                        labelText:
                            'OTP',

                        hintText:
                            'Enter 6 digit OTP',

                        prefixIcon:
                            const Icon(
                          Icons
                              .lock_outline,
                        ),

                        counterText:
                            '',

                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                      ),

                      onFieldSubmitted:
                          (_) {
                        if (!loading) {
                          verifyOtp();
                        }
                      },

                      validator:
                          (value) {
                        final otp =
                            value?.trim() ??
                                '';

                        if (!RegExp(
                          r'^[0-9]{6}$',
                        ).hasMatch(
                          otp,
                        )) {
                          return 'Enter a valid 6 digit OTP';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextButton(
                      onPressed:
                          loading
                              ? null
                              : changeMobile,
                      child:
                          const Text(
                        'Change Mobile Number',
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),
                  ],

                  // =================================================
                  // BUTTON
                  // =================================================

                  SizedBox(
                    height: 52,

                    child:
                        FilledButton.icon(
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
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : Icon(
                                  otpSent
                                      ? Icons
                                          .verified_outlined
                                      : Icons
                                          .sms_outlined,
                                ),

                      label:
                          Text(
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

                  const SizedBox(
                    height: 20,
                  ),

                  // =================================================
                  // SECURITY MESSAGE
                  // =================================================

                  const Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      Icon(
                        Icons
                            .verified_user_outlined,
                        size: 18,
                      ),
                      SizedBox(
                        width: 6,
                      ),
                      Text(
                        'Secure OTP login',
                        style:
                            TextStyle(
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    'Your mobile number is required to place an order.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: Colors
                          .grey
                          .shade600,
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
