import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState
    extends State<ForgotPasswordPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final emailController = TextEditingController();

  bool isLoading = false;

  static const Color primary =
      Color(0xFF5B35D5);
  static const Color primaryDark =
      Color(0xFF4323A8);

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor:
            isError ? Colors.red.shade600 : null,
        behavior:
            SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }

  Future<void> resetPassword() async {
    final email =
        emailController.text.trim();

    if (email.isEmpty) {
      showMessage(
        'Email enter karein.',
        isError: true,
      );
      return;
    }

    if (!email.contains('@')) {
      showMessage(
        'Valid email enter karein.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      showMessage(
        'Password reset link aapke email par bhej diya gaya hai.',
      );

      await Future.delayed(
        const Duration(seconds: 2),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message =
          'Password reset nahi ho saka.';

      switch (e.code) {
        case 'user-not-found':
          message =
              'Is email se koi account nahi mila.';
          break;

        case 'invalid-email':
          message =
              'Email address valid nahi hai.';
          break;

        case 'network-request-failed':
          message =
              'Internet connection check karein.';
          break;

        case 'too-many-requests':
          message =
              'Bahut attempts ho gaye. Thodi der baad try karein.';
          break;
      }

      showMessage(
        message,
        isError: true,
      );
    } catch (_) {
      showMessage(
        'Password reset ke time problem hui. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration inputDecoration() {
    return InputDecoration(
      labelText: 'Registered Email',
      prefixIcon: const Icon(
        Icons.email_outlined,
        color: primary,
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: primary,
          width: 1.7,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text(
          'Forgot Password',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor:
            Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            35,
            20,
            30,
          ),
          child: Column(
            children: [
              Container(
                height: 88,
                width: 88,
                decoration:
                    BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      primary,
                      primaryDark,
                    ],
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    27,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary
                          .withOpacity(.25),
                      blurRadius: 25,
                      offset:
                          const Offset(
                        0,
                        11,
                      ),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Reset Your Password',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Apna registered email enter karein. Hum password reset karne ke liye link bhej denge.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    25,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(.055),
                      blurRadius: 25,
                      offset:
                          const Offset(
                        0,
                        10,
                      ),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller:
                          emailController,
                      keyboardType:
                          TextInputType
                              .emailAddress,
                      textInputAction:
                          TextInputAction.done,
                      enabled: !isLoading,
                      onSubmitted: (_) {
                        if (!isLoading) {
                          resetPassword();
                        }
                      },
                      decoration:
                          inputDecoration(),
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child:
                          ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : resetPassword,
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              primary,
                          foregroundColor:
                              Colors.white,
                          elevation: 3,
                          shadowColor:
                              primary
                                  .withOpacity(
                            .25,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              17,
                            ),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<
                                          Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Icon(
                                    Icons
                                        .email_rounded,
                                    size: 21,
                                  ),
                                  SizedBox(
                                    width: 9,
                                  ),
                                  Text(
                                    'Send Reset Link',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          16,
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                decoration:
                    BoxDecoration(
                  color: primary
                      .withOpacity(.07),
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: primary,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Email receive hone ke baad link open karke naya password set karein. Uske baad Preesho mein Email + New Password se login karein.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
