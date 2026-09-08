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

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      _showMessage('Please enter your email address.');
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Please enter your password.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        _showMessage('Login failed. Please try again.');
        return;
      }

      // ----------------------------------------------------------
      // ADMIN LOGIN
      // ----------------------------------------------------------

      if (_selectedRole == 'admin') {
        await _checkAdmin(user.uid);
        return;
      }

      // ----------------------------------------------------------
      // USER PROFILE
      // ----------------------------------------------------------

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

      final userData = userDoc.data() ?? {};

      final userRole = (
        userData['role'] ??
        userData['Role'] ??
        ''
      ).toString().trim().toLowerCase();

      // ----------------------------------------------------------
      // COURIER LOGIN
      // ----------------------------------------------------------

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

      // ----------------------------------------------------------
      // VENDOR LOGIN
      // ----------------------------------------------------------

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
          message = 'Email or password is incorrect.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'user-not-found':
          message = 'No account found with this email.';
          break;

        case 'wrong-password':
          message = 'Incorrect password.';
          break;

        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your internet.';
          break;

        default:
          message = e.message ?? 'Login failed. Please try again.';
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
    final adminDoc = await _firestore
        .collection('Admins')
        .doc(uid)
        .get();

    if (!adminDoc.exists) {
      await _auth.signOut();

      _showMessage('Admin access denied.');
      return;
    }

    final adminData = adminDoc.data() ?? {};

    final role = (
      adminData['role'] ??
      adminData['Role'] ??
      ''
    ).toString().trim().toLowerCase();

    if (role != 'admin') {
      await _auth.signOut();

      _showMessage('Admin access denied.');
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
        ? (courierDoc.data() ?? {})
        : <String, dynamic>{};

    final userStatus = (
      userData['status'] ?? ''
    ).toString().trim().toLowerCase();

    final courierStatus = (
      courierData['status'] ?? ''
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

    // ----------------------------------------------------------
    // If courier document exists, verify role
    // ----------------------------------------------------------

    if (courierDoc.exists && courierRole.isNotEmpty) {
      if (courierRole != 'courier') {
        await _auth.signOut();

        _showMessage(
          'Courier account verification failed.',
        );
        return;
      }
    }

    // ----------------------------------------------------------
    // IMPORTANT:
    // Pending documents should NOT sign out.
    // Courier must be able to open document upload page.
    // ----------------------------------------------------------

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

    // ----------------------------------------------------------
    // DOCUMENTS SUBMITTED - WAITING FOR ADMIN
    // ----------------------------------------------------------

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

    // ----------------------------------------------------------
    // REJECTED
    // ----------------------------------------------------------

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

    // ----------------------------------------------------------
    // SUSPENDED
    // ----------------------------------------------------------

    if (status == 'suspended') {
      await _auth.signOut();

      _showMessage(
        'Courier account is suspended.',
      );
      return;
    }

    // ----------------------------------------------------------
    // STATUS MUST BE APPROVED
    // ----------------------------------------------------------

    if (status != 'approved') {
      await _auth.signOut();

      _showMessage(
        'Courier account is not approved yet.',
      );
      return;
    }

    // ----------------------------------------------------------
    // ADMIN APPROVAL CHECK
    // ----------------------------------------------------------

    if (!approvedByAdmin) {
      await _auth.signOut();

      _showMessage(
        'Courier approval is pending from Admin.',
      );
      return;
    }

    // ----------------------------------------------------------
    // ACTIVE CHECK
    // ----------------------------------------------------------

    if (!courierActive || !userActive) {
      await _auth.signOut();

      _showMessage(
        'Courier account is currently inactive.',
      );
      return;
    }

    // ----------------------------------------------------------
    // APPROVED COURIER PANEL
    // ----------------------------------------------------------

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CourierPanel(),
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
    final vendorDoc = await _firestore
        .collection('vendors')
        .doc(uid)
        .get();

    if (!vendorDoc.exists) {
      await _auth.signOut();

      _showMessage(
        'Vendor profile not found. Please contact Admin.',
      );
      return;
    }

    final vendorData = vendorDoc.data() ?? {};

    final vendorRole = (
      vendorData['role'] ??
      vendorData['Role'] ??
      ''
    ).toString().trim().toLowerCase();

    final userStatus = (
      userData['status'] ?? ''
    ).toString().trim().toLowerCase();

    final vendorStatus = (
      vendorData['status'] ?? ''
    ).toString().trim().toLowerCase();

    final userActive =
        userData['active'] == true;

    final vendorActive =
        vendorData['active'] == true;

    final approvedByAdmin =
        vendorData['approvedByAdmin'] == true;

    // ----------------------------------------------------------
    // ROLE CHECK
    // ----------------------------------------------------------

    if (vendorRole != 'vendor') {
      await _auth.signOut();

      _showMessage(
        'Vendor account verification failed.',
      );
      return;
    }

    // ----------------------------------------------------------
    // PENDING DOCUMENTS
    // ----------------------------------------------------------

    if (userStatus == 'pending_documents' ||
        vendorStatus == 'pending_documents') {
      await _auth.signOut();

      _showMessage(
        'Please complete Vendor documents first.',
      );
      return;
    }

    // ----------------------------------------------------------
    // PENDING APPROVAL
    // ----------------------------------------------------------

    if (userStatus == 'pending_approval' ||
        vendorStatus == 'pending_approval') {
      await _auth.signOut();

      _showMessage(
        'Vendor documents are under Admin review.',
      );
      return;
    }

    // ----------------------------------------------------------
    // REJECTED
    // ----------------------------------------------------------

    if (userStatus == 'rejected' ||
        vendorStatus == 'rejected') {
      await _auth.signOut();

      _showMessage(
        'Vendor account/documents were rejected by Admin.',
      );
      return;
    }

    // ----------------------------------------------------------
    // SUSPENDED
    // ----------------------------------------------------------

    if (userStatus == 'suspended' ||
        vendorStatus == 'suspended') {
      await _auth.signOut();

      _showMessage(
        'Vendor account is suspended.',
      );
      return;
    }

    // ----------------------------------------------------------
    // APPROVED STATUS CHECK
    // ----------------------------------------------------------

    if (userStatus != 'approved' ||
        vendorStatus != 'approved') {
      await _auth.signOut();

      _showMessage(
        'Vendor account is not approved.',
      );
      return;
    }

    // ----------------------------------------------------------
    // ADMIN APPROVAL CHECK
    // ----------------------------------------------------------

    if (!approvedByAdmin) {
      await _auth.signOut();

      _showMessage(
        'Vendor approval is pending from Admin.',
      );
      return;
    }

    // ----------------------------------------------------------
    // ACTIVE CHECK
    // ----------------------------------------------------------

    if (!userActive || !vendorActive) {
      await _auth.signOut();

      _showMessage(
        'Vendor account is currently inactive.',
      );
      return;
    }

    // ----------------------------------------------------------
    // VENDOR PANEL
    // ----------------------------------------------------------

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const VendorPanel(),
      ),
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordPage(),
      ),
    );
  }

  void _openCourierRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CourierRegistrationPage(),
      ),
    );
  }

  void _openVendorRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VendorRegistrationPage(),
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
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // ROLE TITLE
  // ============================================================

  String get _roleTitle {
    switch (_selectedRole) {
      case 'courier':
        return 'Courier Login';

      case 'vendor':
        return 'Vendor Login';

      default:
        return 'Admin Login';
    }
  }

  String get _roleSubtitle {
    switch (_selectedRole) {
      case 'courier':
        return 'Login to manage deliveries and orders';

      case 'vendor':
        return 'Login to manage your products and orders';

      default:
        return 'Secure access to Preesho administration';
    }
  }

  IconData get _roleIcon {
    switch (_selectedRole) {
      case 'courier':
        return Icons.delivery_dining_rounded;

      case 'vendor':
        return Icons.storefront_rounded;

      default:
        return Icons.admin_panel_settings_rounded;
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Preesho',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),
              child: Column(
                children: [
                  // ------------------------------------------------
                  // TOP ICON
                  // ------------------------------------------------

                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF111827),
                          Color(0xFF374151),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                          color: Colors.black.withOpacity(0.12),
                        ),
                      ],
                    ),
                    child: Icon(
                      _roleIcon,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ------------------------------------------------
                  // TITLE
                  // ------------------------------------------------

                  Text(
                    _roleTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    _roleSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ------------------------------------------------
                  // LOGIN CARD
                  // ------------------------------------------------

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                          color: Colors.black.withOpacity(0.06),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        // ------------------------------------------
                        // ROLE
                        // ------------------------------------------

                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: 'Login As',
                            prefixIcon: const Icon(
                              Icons.manage_accounts_rounded,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FC),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                            DropdownMenuItem(
                              value: 'vendor',
                              child: Text('Vendor'),
                            ),
                            DropdownMenuItem(
                              value: 'courier',
                              child: Text('Courier'),
                            ),
                          ],
                          onChanged: _loading
                              ? null
                              : (value) {
                                  if (value == null) return;

                                  setState(() {
                                    _selectedRole = value;
                                  });
                                },
                        ),

                        const SizedBox(height: 16),

                        // ------------------------------------------
                        // EMAIL
                        // ------------------------------------------

                        TextField(
                          controller: _emailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          textInputAction:
                              TextInputAction.next,
                          enabled: !_loading,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'Enter your email',
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                            ),
                            filled: true,
                            fillColor:
                                const Color(0xFFF8F9FC),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ------------------------------------------
                        // PASSWORD
                        // ------------------------------------------

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !_loading,
                          textInputAction:
                              TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword =
                                      !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons
                                        .visibility_off_outlined,
                              ),
                            ),
                            filled: true,
                            fillColor:
                                const Color(0xFFF8F9FC),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // ------------------------------------------
                        // FORGOT PASSWORD
                        // ------------------------------------------

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : _openForgotPassword,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ------------------------------------------
                        // LOGIN BUTTON
                        // ------------------------------------------

                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed:
                                _loading ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF111827),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.login_rounded,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        // ------------------------------------------
                        // REGISTRATION
                        // ------------------------------------------

                        if (_selectedRole == 'vendor') ...[
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : _openVendorRegistration,
                            icon: const Icon(
                              Icons.storefront_rounded,
                            ),
                            label: const Text(
                              'Register as Vendor',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize:
                                  const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],

                        if (_selectedRole == 'courier') ...[
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : _openCourierRegistration,
                            icon: const Icon(
                              Icons.delivery_dining_rounded,
                            ),
                            label: const Text(
                              'Register as Courier',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize:
                                  const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ------------------------------------------------
                  // SECURITY INFORMATION
                  // ------------------------------------------------

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius:
                                BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.verified_user_outlined,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Secure Login',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your account information is protected '
                                'using Firebase Authentication.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
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
