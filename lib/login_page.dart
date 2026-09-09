import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'courier_documents_page.dart';
import 'courier_panel.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  static const Color primary = Color(0xFF5B35D5);
  static const Color primaryDark = Color(0xFF4323A8);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // BACK
  // ------------------------------------------------------------

  void _goBack() {
    if (isLoading) return;

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  // ------------------------------------------------------------
  // MESSAGE
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // STATUS NORMALIZATION
  // ------------------------------------------------------------

  String _normalizeStatus(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';

    switch (status) {
      case 'pending':
      case 'pending_documents':
      case 'documents_pending':
      case 'document_pending':
        return 'pending_documents';

      case 'pending_approval':
      case 'pending approval':
      case 'waiting_for_approval':
      case 'submitted':
        return 'pending_approval';

      case 'approved':
      case 'active':
      case 'verified':
        return 'approved';

      case 'rejected':
      case 'declined':
        return 'rejected';

      default:
        return status;
    }
  }

  // ------------------------------------------------------------
  // CHECK COURIER
  // ------------------------------------------------------------

  Future<void> _handleCourierLogin(User user) async {
    final uid = user.uid;

    Map<String, dynamic>? courierData;

    // First check couriers collection.
    try {
      final courierSnapshot =
          await _firestore
              .collection('couriers')
              .doc(uid)
              .get();

      if (courierSnapshot.exists) {
        courierData = courierSnapshot.data();
      }
    } catch (_) {
      // Continue with users collection fallback.
    }

    // Fallback to users collection.
    if (courierData == null) {
      try {
        final userSnapshot =
            await _firestore
                .collection('users')
                .doc(uid)
                .get();

        if (userSnapshot.exists) {
          final data = userSnapshot.data();

          if (data != null) {
            final role =
                data['role']?.toString().toLowerCase() ?? '';

            if (role == 'courier') {
              courierData = data;
            }
          }
        }
      } catch (_) {
        // Normal customer login can continue.
      }
    }

    // Not a courier.
    if (courierData == null) {
      if (!mounted) return;

      showMessage('Login successful.');

      Navigator.pop(context, true);
      return;
    }

    final data = courierData;

    final status = _normalizeStatus(
      data['status'] ??
          data['registrationStatus'] ??
          data['approvalStatus'],
    );

    final approvedByAdmin =
        data['approvedByAdmin'] == true ||
        data['isApproved'] == true ||
        data['approved'] == true;

    final active = data['active'] == true;

    final documentsSubmitted =
        data['documentsSubmitted'] == true;

    // ----------------------------------------------------------
    // APPROVED COURIER
    // ----------------------------------------------------------

    if (status == 'approved' &&
        approvedByAdmin &&
        active) {
      if (!mounted) return;

      showMessage(
        'Courier login successful.',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CourierPanel(),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // REJECTED COURIER
    // ----------------------------------------------------------

    if (status == 'rejected') {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CourierDocumentsPage(),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // DOCUMENTS NOT SUBMITTED
    // ----------------------------------------------------------

    if (!documentsSubmitted ||
        status == 'pending_documents' ||
        status.isEmpty) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CourierDocumentsPage(),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // DOCUMENTS SUBMITTED / WAITING FOR ADMIN
    // ----------------------------------------------------------

    if (status == 'pending_approval' ||
        !approvedByAdmin ||
        !active) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CourierDocumentsPage(),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // FALLBACK
    // ----------------------------------------------------------

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CourierDocumentsPage(),
      ),
    );
  }

  // ------------------------------------------------------------
  // LOGIN
  // ------------------------------------------------------------

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

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

    if (password.isEmpty) {
      showMessage(
        'Password enter karein.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      final credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        showMessage(
          'Login failed.',
          isError: true,
        );
        return;
      }

      await _handleCourierLogin(user);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';

      switch (e.code) {
        case 'user-not-found':
          message =
              'Is email se account nahi mila.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message =
              'Email ya password galat hai.';
          break;

        case 'invalid-email':
          message =
              'Email address valid nahi hai.';
          break;

        case 'user-disabled':
          message =
              'Ye account disabled hai.';
          break;

        case 'too-many-requests':
          message =
              'Bahut attempts ho gaye. Thodi der baad try karein.';
          break;

        case 'network-request-failed':
          message =
              'Internet connection check karein.';
          break;

        case 'operation-not-allowed':
          message =
              'Email/Password login Firebase mein enabled nahi hai.';
          break;
      }

      showMessage(
        message,
        isError: true,
      );
    } catch (e) {
      showMessage(
        'Login ke time problem hui. Please try again.',
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

  // ------------------------------------------------------------
  // FORGOT PASSWORD
  // ------------------------------------------------------------

  Future<void> forgotPassword() async {
    if (isLoading) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordPage(),
      ),
    );
  }

  // ------------------------------------------------------------
  // INPUT DECORATION
  // ------------------------------------------------------------

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: primary,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(
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

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isLoading,
      onPopInvokedWithResult:
          (didPop, result) {
        if (didPop) return;

        if (!isLoading) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF7F7FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed:
                isLoading ? null : _goBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics:
                const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              20,
              15,
              20,
              35,
            ),
            child: Column(
              children: [
                // ------------------------------------------------
                // LOGO
                // ------------------------------------------------

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
                    Icons
                        .shopping_bag_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Welcome to Preesho',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -.6,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Login karke apne orders aur shopping ko manage karein.',
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

                // ------------------------------------------------
                // LOGIN CARD
                // ------------------------------------------------

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
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Apne registered email aur password se login karein.',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 22),

                      TextField(
                        controller:
                            emailController,
                        keyboardType:
                            TextInputType
                                .emailAddress,
                        textInputAction:
                            TextInputAction.next,
                        enabled: !isLoading,
                        decoration:
                            inputDecoration(
                          label:
                              'Email Address',
                          icon: Icons
                              .email_outlined,
                        ),
                      ),

                      const SizedBox(height: 15),

                      TextField(
                        controller:
                            passwordController,
                        obscureText:
                            obscurePassword,
                        textInputAction:
                            TextInputAction.done,
                        enabled: !isLoading,
                        onSubmitted: (_) {
                          if (!isLoading) {
                            login();
                          }
                        },
                        decoration:
                            inputDecoration(
                          label: 'Password',
                          icon: Icons
                              .lock_outline_rounded,
                          suffixIcon:
                              IconButton(
                            onPressed:
                                isLoading
                                    ? null
                                    : () {
                                        setState(
                                          () {
                                            obscurePassword =
                                                !obscurePassword;
                                          },
                                        );
                                      },
                            icon: Icon(
                              obscurePassword
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Align(
                        alignment:
                            Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              isLoading
                                  ? null
                                  : forgotPassword,
                          child:
                              const Text(
                            'Forgot Password?',
                            style:
                                TextStyle(
                              color: primary,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child:
                            ElevatedButton(
                          onPressed:
                              isLoading
                                  ? null
                                  : login,
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                primary,
                            foregroundColor:
                                Colors.white,
                            elevation: 3,
                            shadowColor:
                                primary.withOpacity(
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
                                          .login_rounded,
                                      size: 21,
                                    ),
                                    SizedBox(
                                      width: 9,
                                    ),
                                    Text(
                                      'Login',
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

                // ------------------------------------------------
                // SECURITY INFO
                // ------------------------------------------------

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
                    border: Border.all(
                      color: primary
                          .withOpacity(.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .security_rounded,
                        color: primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aapki login information Firebase Authentication ke through secure rahegi.',
                          style: TextStyle(
                            color: Colors
                                .grey.shade700,
                            fontSize: 12,
                            height: 1.4,
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
      ),
    );
  }
}
