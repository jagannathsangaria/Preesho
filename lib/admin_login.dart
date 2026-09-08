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
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

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
      _showMessage('Please enter your email address.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Please enter password.');
      return;
    }

    if (!email.contains('@')) {
      _showMessage(
        'Please use the registered email address for login.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // ========================================================
      // FIREBASE AUTH
      // ========================================================

      final credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Unable to login.');
      }

      // ========================================================
      // ADMIN LOGIN
      // ========================================================

      if (_selectedRole == 'admin') {
        await _checkAdmin(user.uid);
        return;
      }

      // ========================================================
      // USERS DOCUMENT
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
          userDoc.data() ?? {};

      final roleValue =
          userData['role'] ?? userData['Role'];

      final role =
          roleValue
              ?.toString()
              .trim()
              .toLowerCase();

      // ========================================================
      // COURIER LOGIN
      // ========================================================

      if (_selectedRole == 'courier') {
        if (role != 'courier') {
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
        if (role != 'vendor') {
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

      await _auth.signOut();

      _showMessage(
        'Invalid login role.',
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-credential':
          message =
              'Invalid email or password.';
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
              'Account not found.';
          break;

        case 'wrong-password':
          message =
              'Incorrect password.';
          break;

        case 'too-many-requests':
          message =
              'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message =
              'Network error. Please check your internet connection.';
          break;

        default:
          message =
              'Login failed. Please try again.';
      }

      if (mounted) {
        _showMessage(message);
      }
    } catch (e) {
      debugPrint(
        'Staff login error: $e',
      );

      if (mounted) {
        _showMessage(
          'Unable to login. Please try again.',
        );
      }
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

      _showMessage(
        'Admin access denied.',
      );

      return;
    }

    final adminData =
        adminDoc.data() ?? {};

    final roleValue =
        adminData['role'] ??
        adminData['Role'];

    final role =
        roleValue
            ?.toString()
            .trim()
            .toLowerCase();

    if (role != 'admin') {
      await _auth.signOut();

      _showMessage(
        'Admin access denied.',
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
    // ----------------------------------------------------------
    // GET COURIER PROFILE
    // ----------------------------------------------------------

    final courierDoc = await _firestore
        .collection('couriers')
        .doc(uid)
        .get();

    Map<String, dynamic> courierData = {};

    if (courierDoc.exists) {
      courierData =
          courierDoc.data() ?? {};
    }

    // ----------------------------------------------------------
    // GET STATUS FROM BOTH USERS AND COURIERS
    // ----------------------------------------------------------

    final userStatus =
        userData['status']
            ?.toString()
            .trim()
            .toLowerCase();

    final courierStatus =
        courierData['status']
            ?.toString()
            .trim()
            .toLowerCase();

    final status =
        courierStatus ?? userStatus;

    // ----------------------------------------------------------
    // ROLE
    // ----------------------------------------------------------

    final courierRole =
        courierData['role']
            ?.toString()
            .trim()
            .toLowerCase();

    // ----------------------------------------------------------
    // ACTIVE
    // ----------------------------------------------------------

    final courierActive =
        courierData['active'] == true;

    final userActive =
        userData['active'] == true;

    // ----------------------------------------------------------
    // ADMIN APPROVAL
    // ----------------------------------------------------------

    final approvedByAdmin =
        courierData['approvedByAdmin'] == true ||
        userData['approvedByAdmin'] == true;

    // ----------------------------------------------------------
    // DOCUMENTS
    // ----------------------------------------------------------

    final documentsSubmitted =
        courierData['documentsSubmitted'] == true ||
        userData['documentsSubmitted'] == true;

    // ==========================================================
    // COURIER ROLE CHECK
    // ==========================================================

    if (courierDoc.exists &&
        courierRole != null &&
        courierRole != 'courier') {
      await _auth.signOut();

      _showMessage(
        'Invalid Courier profile.',
      );

      return;
    }

    // ==========================================================
    // IMPORTANT:
    // DOCUMENTS NOT SUBMITTED
    // DO NOT SIGN OUT
    // OPEN DOCUMENT PAGE
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
    // DOCUMENTS SUBMITTED
    // WAITING FOR ADMIN APPROVAL
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
    // OPEN DOCUMENT PAGE FOR CORRECTION / RESUBMISSION
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
    // APPROVED CHECK
    // ==========================================================

    if (status != 'approved') {
      await _auth.signOut();

      _showMessage(
        'Courier account is not approved.',
      );

      return;
    }

    // ==========================================================
    // ADMIN APPROVAL CHECK
    // ==========================================================

    if (!approvedByAdmin) {
      await _auth.signOut();

      _showMessage(
        'Courier has not been approved by Admin.',
      );

      return;
    }

    // ==========================================================
    // ACTIVE CHECK
    // ==========================================================

    if (!courierActive ||
        !userActive) {
      await _auth.signOut();

      _showMessage(
        'Courier account is inactive.',
      );

      return;
    }

    // ==========================================================
    // APPROVED COURIER
    // OPEN COURIER PANEL
    // ==========================================================

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

    final vendorData =
        vendorDoc.data() ?? {};

    final vendorRole =
        vendorData['role']
            ?.toString()
            .trim()
            .toLowerCase();

    final userStatus =
        userData['status']
            ?.toString()
            .trim()
            .toLowerCase();

    final vendorStatus =
        vendorData['status']
            ?.toString()
            .trim()
            .toLowerCase();

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
        'Invalid Vendor profile.',
      );

      return;
    }

    // ----------------------------------------------------------
    // BOTH USER + VENDOR MUST BE APPROVED
    // ----------------------------------------------------------

    if (userStatus != 'approved' ||
        vendorStatus != 'approved') {
      await _auth.signOut();

      String message;

      if (userStatus == 'pending_documents' ||
          vendorStatus == 'pending_documents') {
        message =
            'Please complete Vendor documents first.';
      } else if (userStatus == 'pending_approval' ||
          vendorStatus == 'pending_approval') {
        message =
            'Vendor documents are under Admin review.';
      } else if (userStatus == 'rejected' ||
          vendorStatus == 'rejected') {
        message =
            'Vendor account/documents were rejected by Admin.';
      } else if (userStatus == 'suspended' ||
          vendorStatus == 'suspended') {
        message =
            'Vendor account is suspended.';
      } else {
        message =
            'Vendor account is not approved.';
      }

      _showMessage(message);
      return;
    }

    // ----------------------------------------------------------
    // ADMIN APPROVAL CHECK
    // ----------------------------------------------------------

    if (!approvedByAdmin) {
      await _auth.signOut();

      _showMessage(
        'Vendor has not been approved by Admin.',
      );

      return;
    }

    // ----------------------------------------------------------
    // BOTH USER + VENDOR MUST BE ACTIVE
    // ----------------------------------------------------------

    if (!userActive ||
        !vendorActive) {
      await _auth.signOut();

      _showMessage(
        'Vendor account is inactive.',
      );

      return;
    }

    // ----------------------------------------------------------
    // OPEN VENDOR PANEL
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
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // ROLE NAME
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _roleTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 450,
              ),
              child: Card(
                elevation: 3,
                child: Padding(
                  padding:
                      const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // ==================================================
                      // ICON
                      // ==================================================

                      CircleAvatar(
                        radius: 38,
                        child: Icon(
                          _selectedRole ==
                                  'courier'
                              ? Icons
                                  .delivery_dining
                              : _selectedRole ==
                                      'vendor'
                                  ? Icons
                                      .storefront_outlined
                                  : Icons
                                      .admin_panel_settings_outlined,
                          size: 42,
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      Text(
                        _roleTitle,
                        textAlign:
                            TextAlign.center,
                        style:
                            const TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'Preesho Staff Access',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      // ==================================================
                      // ROLE DROPDOWN
                      // ==================================================

                      DropdownButtonFormField<String>(
                        value:
                            _selectedRole,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Login Type',
                          prefixIcon:
                              Icon(
                            Icons
                                .manage_accounts_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text(
                              'Admin Login',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'vendor',
                            child: Text(
                              'Vendor Login',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'courier',
                            child: Text(
                              'Courier Login',
                            ),
                          ),
                        ],
                        onChanged:
                            _loading
                                ? null
                                : (value) {
                                    if (value ==
                                        null) {
                                      return;
                                    }

                                    setState(() {
                                      _selectedRole =
                                          value;
                                    });
                                  },
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ==================================================
                      // EMAIL
                      // ==================================================

                      TextField(
                        controller:
                            _emailController,
                        keyboardType:
                            TextInputType
                                .emailAddress,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Email Address',
                          hintText:
                              'Enter registered email',
                          prefixIcon:
                              Icon(
                            Icons
                                .email_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ==================================================
                      // PASSWORD
                      // ==================================================

                      TextField(
                        controller:
                            _passwordController,
                        obscureText:
                            _obscurePassword,
                        textInputAction:
                            TextInputAction.done,
                        onSubmitted: (_) {
                          _login();
                        },
                        decoration:
                            InputDecoration(
                          labelText:
                              'Password',
                          hintText:
                              'Enter password',
                          prefixIcon:
                              const Icon(
                            Icons.lock_outline,
                          ),
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
                          border:
                              const OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      // ==================================================
                      // FORGOT PASSWORD
                      // ==================================================

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
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      // ==================================================
                      // LOGIN BUTTON
                      // ==================================================

                      SizedBox(
                        height: 52,
                        child:
                            FilledButton(
                          onPressed:
                              _loading
                                  ? null
                                  : _login,
                          child:
                              _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            16,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                        ),
                      ),

                      // ==================================================
                      // VENDOR REGISTRATION
                      // ==================================================

                      if (_selectedRole ==
                          'vendor') ...[
                        const SizedBox(
                          height: 18,
                        ),
                        const Divider(),
                        const SizedBox(
                          height: 8,
                        ),
                        const Text(
                          'New Vendor?',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _loading
                                  ? null
                                  : _openVendorRegistration,
                          icon:
                              const Icon(
                            Icons
                                .storefront_outlined,
                          ),
                          label:
                              const Text(
                            'Register as Vendor',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],

                      // ==================================================
                      // COURIER REGISTRATION
                      // ==================================================

                      if (_selectedRole ==
                          'courier') ...[
                        const SizedBox(
                          height: 18,
                        ),
                        const Divider(),
                        const SizedBox(
                          height: 8,
                        ),
                        const Text(
                          'New Courier?',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _loading
                                  ? null
                                  : _openCourierRegistration,
                          icon:
                              const Icon(
                            Icons
                                .delivery_dining,
                          ),
                          label:
                              const Text(
                            'Register as Courier',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 18,
                      ),

                      // ==================================================
                      // SECURITY MESSAGE
                      // ==================================================

                      const Text(
                        'Vendor and Courier accounts require Admin approval before access is allowed.',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          fontSize: 12,
                          color:
                              Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
