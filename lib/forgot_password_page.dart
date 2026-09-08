import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();

  bool isLoading = false;

  static const Color primary = Color(0xFF5B35D5);
  static const Color primaryDark = Color(0xFF4323A8);
  static const Color background = Color(0xFFF7F7FA);

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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor:
              isError ? Colors.red.shade600 : Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(email)) {
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
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      showMessage(
        'Password reset link aapke email par bhej diya gaya hai.',
      );

      await Future.delayed(
        const Duration(milliseconds: 1000),
      );

      if (!mounted) return;

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Password reset request failed.';

      switch (e.code) {
        case 'invalid-email':
          message = 'Email address valid nahi hai.';
          break;

        case 'user-not-found':
          message = 'Is email se koi account nahi mila.';
          break;

        case 'too-many-requests':
          message =
              'Bahut attempts ho gaye. Thodi der baad dobara try karein.';
          break;

        case 'network-request-failed':
          message = 'Internet connection check karein.';
          break;

        case 'user-disabled':
          message = 'Ye account disabled hai.';
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
      prefixIcon: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primary.withOpacity(.10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.email_outlined,
          color: primary,
          size: 21,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFFF9F9FC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 17,
      ),
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 13,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: primary,
          width: 1.8,
        ),
      ),
    );
  }

  Widget buildTopIcon() {
    return Container(
      height: 94,
      width: 94,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            primary,
            primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(.25),
            blurRadius: 28,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: const Icon(
        Icons.lock_reset_rounded,
        color: Colors.white,
        size: 48,
      ),
    );
  }

  Widget buildStep(
    int number,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: primary.withOpacity(.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              icon,
              color: primary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number. $title',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: isLoading
              ? null
              : () {
                  Navigator.pop(context);
                },
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            35,
          ),
          child: Column(
            children: [
              buildTopIcon(),

              const SizedBox(height: 24),

              const Text(
                'Forgot Password?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),

              const SizedBox(height: 9),

              Text(
                'Don\'t worry! We\'ll help you reset your\nPreesho account password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.grey.shade100,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.055),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(.09),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.password_rounded,
                            color: primary,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Reset your password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 9),

                    Text(
                      'Enter the email address linked to your Preesho account.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 21),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading,
                      autocorrect: false,
                      onSubmitted: (_) {
                        if (!isLoading) {
                          sendResetLink();
                        }
                      },
                      decoration: inputDecoration(),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : sendResetLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              primary.withOpacity(.55),
                          elevation: 4,
                          shadowColor: primary.withOpacity(.25),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: isLoading
                            ? const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 21,
                                    width: 21,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Sending...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.mark_email_read_outlined,
                                    size: 21,
                                  ),
                                  SizedBox(width: 9),
                                  Text(
                                    'Send Reset Link',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
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

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.shade100,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: Colors.green.shade700,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your account is secure',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Reset link only registered email address par send hoga.',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontSize: 11.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade100,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How it works',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 16),

                    buildStep(
                      1,
                      Icons.email_outlined,
                      'Enter your email',
                      'Use the email registered with your Preesho account.',
                    ),

                    const SizedBox(height: 15),

                    buildStep(
                      2,
                      Icons.mark_email_read_outlined,
                      'Check your inbox',
                      'Firebase will send a secure password reset email.',
                    ),

                    const SizedBox(height: 15),

                    buildStep(
                      3,
                      Icons.lock_open_rounded,
                      'Create a new password',
                      'Open the email link and choose your new password.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

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

              const SizedBox(height: 4),

              Text(
                'Preesho • Secure Account Recovery',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
