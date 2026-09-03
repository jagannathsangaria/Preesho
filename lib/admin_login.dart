import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_panel.dart';
import 'courier_panel.dart';
import 'vendor_panel.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // STAFF LOGIN
  // ============================================================

  Future<void> _login() async {
    if (_loading) {
      return;
    }

    final email =
        _emailController.text.trim();

    final password =
        _passwordController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        'Please enter email.',
      );
      return;
    }

    if (password.isEmpty) {
      _showMessage(
        'Please enter password.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // ========================================================
      // FIREBASE AUTH LOGIN
      // ========================================================

      final credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user =
          credential.user;

      if (user == null) {
        throw Exception(
          'Unable to login.',
        );
      }

      // ========================================================
      // ADMIN CHECK
      // ========================================================

      final adminDoc =
          await _firestore
              .collection('Admins')
              .doc(user.uid)
              .get();

      if (adminDoc.exists) {
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

        if (role == 'admin') {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AdminPanel(),
            ),
          );

          return;
        }
      }

      // ========================================================
      // USERS DOCUMENT
      // ========================================================

      final userDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      final userData =
          userDoc.data() ?? {};

      final roleValue =
          userData['role'] ??
              userData['Role'];

      final role =
          roleValue
              ?.toString()
              .trim()
              .toLowerCase();

      // ========================================================
      // COURIER CHECK
      // ========================================================

      if (role == 'courier') {
        final active =
            userData['active'] != false;

        if (!active) {
          await _auth.signOut();

          _showMessage(
            'Courier account is inactive.',
          );

          return;
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const CourierPanel(),
          ),
        );

        return;
      }

      // ========================================================
      // VENDOR CHECK
      // ========================================================

      if (role == 'vendor') {
        final vendorDoc =
            await _firestore
                .collection('vendors')
                .doc(user.uid)
                .get();

        final vendorData =
            vendorDoc.data() ?? {};

        // ======================================================
        // VENDOR STATUS
        // ======================================================

        final userStatus =
            userData['vendorStatus']
                ?.toString()
                .trim()
                .toLowerCase();

        final vendorStatus =
            vendorData['status']
                ?.toString()
                .trim()
                .toLowerCase();

        final status =
            vendorStatus.isNotEmpty
                ? vendorStatus
                : userStatus;

        // ======================================================
        // VENDOR ACTIVE
        // ======================================================

        final userActive =
            userData['active'] == true;

        final vendorActive =
            vendorData['active'] == true;

        final active =
            userActive ||
                vendorActive;

        // ======================================================
        // ONLY APPROVED + ACTIVE VENDOR
        // ======================================================

        if (status != 'approved') {
          await _auth.signOut();

          _showMessage(
            status == 'pending'
                ? 'Vendor account is pending approval.'
                : status == 'rejected'
                    ? 'Vendor account has been rejected.'
                    : status == 'suspended'
                        ? 'Vendor account is suspended.'
                        : 'Vendor account is not approved.',
          );

          return;
        }

        if (!active) {
          await _auth.signOut();

          _showMessage(
            'Vendor account is inactive.',
          );

          return;
        }

        // ======================================================
        // OPEN VENDOR PANEL
        // ======================================================

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const VendorPanel(),
          ),
        );

        return;
      }

      // ========================================================
      // ACCESS DENIED
      // ========================================================

      await _auth.signOut();

      _showMessage(
        'Staff access denied.',
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
              'Please enter a valid email.';
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
              'Too many attempts. Please try again later.';
          break;

        default:
          message =
              'Login failed. Please try again.';
      }

      if (mounted) {
        _showMessage(message);
      }
    } catch (e) {
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
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
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
          'Staff Login',
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
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 450,
              ),
              child: Card(
                elevation: 3,
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      // ==================================================
                      // ICON
                      // ==================================================

                      const CircleAvatar(
                        radius: 38,
                        child: Icon(
                          Icons
                              .admin_panel_settings_outlined,
                          size: 42,
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      const Text(
                        'Staff Login',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'Admin, Courier & Vendor access',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),

                      const SizedBox(
                        height: 28,
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
                            TextInputAction
                                .next,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Email',
                          hintText:
                              'Enter staff email',
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
                            TextInputAction
                                .done,
                        onSubmitted:
                            (_) {
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
                            Icons
                                .lock_outline,
                          ),
                          suffixIcon:
                              IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                            icon:
                                Icon(
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
                        height: 24,
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
                                      width:
                                          24,
                                      height:
                                          24,
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

                      const SizedBox(
                        height: 16,
                      ),

                      const Text(
                        'Only authorized staff accounts can access this panel.',
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
