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
  final emailController = TextEditingController();

  bool isLoading = false;

  static const Color primary = Color(0xFF5B35D5);
  static const Color primaryDark = Color(0xFF4323A8);

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
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Future<void> sendResetLink() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage(
        'Email address enter karein.',
        isError: true,
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      showMessage(
        'Valid email address enter karein.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      showMessage(
        'Password reset link aapke email par bhej diya gaya hai.',
      );

      await Future.delayed(
        const Duration(milliseconds: 900),
      );

      if (!mounted) return;

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message =
          'Password reset request failed.';

      switch (e.code) {
        case 'invalid-email':
          message =
              'Email address valid nahi hai.';
          break;

        case 'user-not-found':
          message =
              'Is email se koi account nahi mila.';
          break;

        case 'too-many-requests':
          message =
              'Bahut attempts ho gaye. Thodi der baad try karein.';
          break;

        case 'network-request-failed':
          message =
              'Internet connection check karein.';
          break;
      }

      showMessage(
        message,
        isError: true,
      );
    } catch (_) {
      showMessage(
        'Kuch problem hui. Please dobara try karein.',
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
      labelText: 'Email Address',
      hintText: 'Enter your registered email',
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
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
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
      backgroundColor: const Color(0xFFF7F7FA),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            25,
            20,
            35,
          ),
          child: Column(
            children: [
              // Icon
              Container(
                height: 88,
                width: 88,
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      primary,
                      primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(27),
                  boxShadow: [
                    BoxShadow(
                      color:
                          primary.withOpacity(.25),
                      blurRadius: 25,
                      offset:
                          const Offset(0, 11),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Colors.white,
                  size: 45,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Forgot Password?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'No worries! Enter your registered email and we will send you a password reset link.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 30),

              // Main Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(.055),
                      blurRadius: 25,
                      offset:
                          const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reset your password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'Use the email address connected with your Preesho account.',
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller:
                          emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isLoading) {
                          sendResetLink();
                        }
                      },
                      decoration:
                          inputDecoration(),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : sendResetLink,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              primary,
                          foregroundColor:
                              Colors.white,
                          elevation: 3,
                          shadowColor:
                              primary.withOpacity(.25),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              17,
                            ),
                          ),
                        ),
                        child: isLoading
                            ? const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  SizedBox(
                                    height: 21,
                                    width: 21,
                                    child:
                                        CircularProgressIndicator(
                                      color:
                                          Colors.white,
                                      strokeWidth:
                                          2.5,
                                    ),
                                  ),
                                  SizedBox(
                                      width: 12),
                                  Text(
                                    'Sending...',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Icon(
                                    Icons
                                        .mark_email_read_outlined,
                                  ),
                                  SizedBox(width: 9),
                                  Text(
                                    'Send Reset Link',
                                    style:
                                        TextStyle(
                                      fontSize: 15,
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

              const SizedBox(height: 18),

              // Security info
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius:
                      BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.green.shade100,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.green.shade100,
                        borderRadius:
                            BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons
                            .verified_user_outlined,
                        color:
                            Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Secure password recovery',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reset link sirf aapke registered email address par send hoga.',
                            style: TextStyle(
                              color: Colors
                                  .green
                                  .shade800,
                              fontSize: 11,
                              height: 1.4,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              TextButton.icon(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                ),
                label: const Text(
                  'Back to Login',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
