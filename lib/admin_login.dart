import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_panel.dart';
import 'courier_documents_page.dart';
import 'courier_panel.dart';
import 'courier_registration_page.dart';
import 'forgot_password_page.dart';
import 'vendor_panel.dart';
import 'vendor_registration_page.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  String _selectedRole = 'admin';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    if (_loading) return;

    final email =
        _emailController.text.trim().toLowerCase();
    final password =
        _passwordController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        'Please enter your email address.',
      );
      return;
    }

    if (!email.contains('@')) {
      _showMessage(
        'Please enter a valid email address.',
      );
      return;
    }

    if (password.isEmpty) {
      _showMessage(
        'Please enter your password.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        _showMessage(
          'Login failed. Please try again.',
        );
        return;
      }

      // ========================================================
      // ADMIN LOGIN
      // ========================================================

      if (_selectedRole == 'admin') {
        await _checkAdmin(user.uid);
        return;
      }

      // ========================================================
      // USER PROFILE
      // ========================================================

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();

        _showMessage(
          'Staff profile not found. Please contact Admin.',
        );
        return;
      }

      final userData =
          userDoc.data() ?? <String, dynamic>{};

      final userRole = (
        userData['role'] ??
        userData['Role'] ??
        ''
      ).toString().trim().toLowerCase();

      // ========================================================
      // COURIER LOGIN
      // ========================================================

      if (_selectedRole == 'courier') {
        if (userRole != 'courier') {
          await _auth.signOut();

          _showMessage(
            'This account is not registered as a Courier.',
          );
          return;
        }

        await _checkCourier(
          user.uid,
          userData,
        );

        return;
      }

      // ========================================================
      // VENDOR LOGIN
      // ========================================================

      if (_selectedRole == 'vendor') {
        if (userRole != 'vendor') {
          await _auth.signOut();

          _showMessage(
            'This account is not registered as a Vendor.',
          );
          return;
        }

        await _checkVendor(
          user.uid,
          userData,
        );

        return;
      }
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-credential':
          message =
              'Email or password is incorrect.';
          break;

        case 'invalid-email':
          message =
              'Please enter a valid email address.';
          break;

        case 'user-disabled':
          message =
              'This account has been disabled.';
          break;

        case 'user-not-found':
          message =
              'No account found with this email.';
          break;

        case 'wrong-password':
          message =
              'Incorrect password.';
          break;

        case 'too-many-requests':
          message =
              'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message =
              'Network error. Please check your internet.';
          break;

        default:
          message =
              e.message ??
              'Login failed. Please try again.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // ADMIN CHECK
  // ============================================================

  Future<void> _checkAdmin(String uid) async {
    // Admin is identified from:
    // users/{uid}
    //
    // No hard-coded UID is used.
    // Old Admins collection is not required.

    final userDoc = await _firestore
        .collection('users')
        .doc(uid)
        .get();

    if (!userDoc.exists) {
      await _auth.signOut();

      _showMessage(
        'Admin profile not found. '
        'Please create users/$uid with role = admin.',
      );
      return;
    }

    final data =
        userDoc.data() ??
        <String, dynamic>{};

    final role = (
      data['role'] ??
      data['Role'] ??
      ''
    ).toString().trim().toLowerCase();

    final active =
        data['active'] == null ||
        data['active'] == true;

    final status =
        (data['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

    if (role != 'admin' ||
        !active ||
        status != 'active') {
      await _auth.signOut();

      _showMessage(
        'Admin access denied. '
        'Check role=admin, status=active '
        'and active=true.',
      );
      return;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminPanel(),
      ),
    );
  }

  // ============================================================
  // COURIER CHECK
  // ============================================================

  Future<void> _checkCourier(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    final courierDoc = await _firestore
        .collection('couriers')
        .doc(uid)
        .get();

    final courierData = courierDoc.exists
        ? (courierDoc.data() ??
            <String, dynamic>{})
        : <String, dynamic>{};

    final userStatus = (
      userData['status'] ??
      ''
    ).toString().trim().toLowerCase();

    final courierStatus = (
      courierData['status'] ??
      ''
    ).toString().trim().toLowerCase();

    final status = courierStatus.isNotEmpty
        ? courierStatus
        : userStatus;

    final courierRole = (
      courierData['role'] ??
      courierData['Role'] ??
      ''
    ).toString().trim().toLowerCase();

    final courierActive =
        courierData['active'] == true;

    final userActive =
        userData['active'] == true;

    final approvedByAdmin =
        courierData['approvedByAdmin'] == true ||
        userData['approvedByAdmin'] == true;

    final documentsSubmitted =
        courierData['documentsSubmitted'] == true ||
        userData['documentsSubmitted'] == true;

    // ==========================================================
    // COURIER DOCUMENT EXISTS - VERIFY ROLE
    // ==========================================================

    if (courierDoc.exists &&
        courierRole.isNotEmpty) {
      if (courierRole != 'courier') {
        await _auth.signOut();

        _showMessage(
          'Courier account verification failed.',
        );
        return;
      }
    }

    // ==========================================================
    // PENDING DOCUMENTS
    // ==========================================================

    if (status == 'pending_documents' ||
        !documentsSubmitted) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CourierDocumentsPage(
            courierUid: uid,
          ),
        ),
      );

      return;
    }

    // ==========================================================
    // PENDING APPROVAL
    // ==========================================================

    if (status == 'pending_approval') {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CourierDocumentsPage(
            courierUid: uid,
          ),
        ),
      );

      return;
    }

    // ==========================================================
    // REJECTED
    // ==========================================================

    if (status == 'rejected') {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CourierDocumentsPage(
            courierUid: uid,
          ),
        ),
      );

      return;
    }

    // ==========================================================
    // SUSPENDED
    // ==========================================================

    if (status == 'suspended') {
      await _auth.signOut();

      _showMessage(
        'Courier account is suspended.',
      );
      return;
    }

    // ==========================================================
    // APPROVED COURIER
    // ==========================================================

    final isApproved =
        status == 'approved' ||
        status == 'active' ||
        approvedByAdmin;

    if (isApproved &&
        (courierActive || userActive)) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CourierPanel(),
        ),
      );

      return;
    }

    // ==========================================================
    // FALLBACK
    // ==========================================================

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CourierDocumentsPage(
          courierUid: uid,
        ),
      ),
    );
  }

  // ============================================================
  // VENDOR CHECK
  // ============================================================

  Future<void> _checkVendor(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    final status = (
      userData['status'] ??
      'active'
    ).toString().trim().toLowerCase();

    final active =
        userData['active'] == null ||
        userData['active'] == true;

    if (!active) {
      await _auth.signOut();

      _showMessage(
        'Vendor account is inactive.',
      );
      return;
    }

    if (status == 'rejected') {
      await _auth.signOut();

      _showMessage(
        'Vendor account has been rejected.',
      );
      return;
    }

    if (status == 'suspended') {
      await _auth.signOut();

      _showMessage(
        'Vendor account is suspended.',
      );
      return;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const VendorPanel(),
      ),
    );
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordPage(),
      ),
    );
  }

  // ============================================================
  // COURIER REGISTRATION
  // ============================================================

  void _openCourierRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CourierRegistrationPage(),
      ),
    );
  }

  // ============================================================
  // VENDOR REGISTRATION
  // ============================================================

  void _openVendorRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const VendorRegistrationPage(),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // ROLE SELECTOR
  // ============================================================

  Widget _roleButton({
    required String value,
    required String title,
    required IconData icon,
  }) {
    final selected =
        _selectedRole == value;

    return Expanded(
      child: GestureDetector(
        onTap: _loading
            ? null
            : () {
                setState(() {
                  _selectedRole = value;
                });
              },
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF111827)
                : Colors.white,
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF111827)
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? Colors.white
                    : const Color(0xFF374151),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                    color: selected
                        ? Colors.white
                        : const Color(
                            0xFF374151,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8F9FC),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF111827),
          width: 1.2,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 520,
              ),
              child: Column(
                children: [
                  // =================================================
                  // HEADER
                  // =================================================

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 25,
                          offset:
                              const Offset(0, 10),
                          color: Colors.black
                              .withOpacity(0.06),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFF111827,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              22,
                            ),
                          ),
                          child: const Icon(
                            Icons
                                .admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        const Text(
                          'Preesho',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          'Secure Staff Portal',
                          style: TextStyle(
                            color: Colors
                                .grey.shade600,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // LOGIN CARD
                  // =================================================

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 25,
                          offset:
                              const Offset(0, 10),
                          color: Colors.black
                              .withOpacity(0.05),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Select your account type',
                          style: TextStyle(
                            color: Colors
                                .grey.shade600,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        // =========================================
                        // ROLE BUTTONS
                        // =========================================

                        Row(
                          children: [
                            _roleButton(
                              value: 'admin',
                              title: 'Admin',
                              icon: Icons
                                  .admin_panel_settings_outlined,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            _roleButton(
                              value: 'courier',
                              title: 'Courier',
                              icon: Icons
                                  .delivery_dining_outlined,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            _roleButton(
                              value: 'vendor',
                              title: 'Vendor',
                              icon: Icons
                                  .storefront_outlined,
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 22,
                        ),

                        // =========================================
                        // EMAIL
                        // =========================================

                        TextField(
                          controller:
                              _emailController,
                          keyboardType:
                              TextInputType
                                  .emailAddress,
                          textInputAction:
                              TextInputAction.next,
                          autocorrect: false,
                          decoration:
                              _inputDecoration(
                            label:
                                'Email Address',
                            icon: Icons
                                .email_outlined,
                          ),
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        // =========================================
                        // PASSWORD
                        // =========================================

                        TextField(
                          controller:
                              _passwordController,
                          obscureText:
                              _obscurePassword,
                          textInputAction:
                              TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_loading) {
                              _login();
                            }
                          },
                          decoration:
                              _inputDecoration(
                            label: 'Password',
                            icon: Icons
                                .lock_outline_rounded,
                            suffixIcon:
                                IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword =
                                      !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons
                                        .visibility_outlined
                                    : Icons
                                        .visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        // =========================================
                        // FORGOT PASSWORD
                        // =========================================

                        Align(
                          alignment:
                              Alignment.centerRight,
                          child:
                              TextButton(
                            onPressed:
                                _loading
                                    ? null
                                    : _openForgotPassword,
                            child:
                                const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        // =========================================
                        // LOGIN BUTTON
                        // =========================================

                        SizedBox(
                          height: 54,
                          child:
                              FilledButton(
                            onPressed:
                                _loading
                                    ? null
                                    : _login,
                            style:
                                FilledButton
                                    .styleFrom(
                              backgroundColor:
                                  const Color(
                                0xFF111827,
                              ),
                              foregroundColor:
                                  Colors.white,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  16,
                                ),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2.5,
                                      color:
                                          Colors.white,
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
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text(
                                        'Login',
                                        style:
                                            TextStyle(
                                          fontSize:
                                              16,
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        // =========================================
                        // VENDOR REGISTRATION
                        // =========================================

                        if (_selectedRole ==
                            'vendor') ...[
                          const SizedBox(
                            height: 14,
                          ),
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : _openVendorRegistration,
                            icon: const Icon(
                              Icons
                                  .storefront_rounded,
                            ),
                            label:
                                const Text(
                              'Register as Vendor',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            style:
                                OutlinedButton
                                    .styleFrom(
                              minimumSize:
                                  const Size
                                      .fromHeight(
                                52,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  16,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // =========================================
                        // COURIER REGISTRATION
                        // =========================================

                        if (_selectedRole ==
                            'courier') ...[
                          const SizedBox(
                            height: 14,
                          ),
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : _openCourierRegistration,
                            icon: const Icon(
                              Icons
                                  .delivery_dining_rounded,
                            ),
                            label:
                                const Text(
                              'Register as Courier',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            style:
                                OutlinedButton
                                    .styleFrom(
                              minimumSize:
                                  const Size
                                      .fromHeight(
                                52,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // SECURITY INFORMATION
                  // =================================================

                  Container(
                    padding:
                        const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFF1F5F9,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              13,
                            ),
                          ),
                          child: const Icon(
                            Icons
                                .verified_user_outlined,
                            color:
                                Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Text(
                                'Secure Login',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                'Your account information is protected '
                                'using Firebase Authentication.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors
                                      .grey.shade600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Preesho • Secure Staff Portal',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey.shade500,
                      fontWeight:
                          FontWeight.w600,
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
