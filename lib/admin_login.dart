import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_panel.dart';
import 'courier_panel.dart';
import 'vendor_panel.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool loading = false;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Email and password required');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('User account not found.');
      }

      final firestore = FirebaseFirestore.instance;

      // ============================================================
      // 1. ADMIN CHECK
      // ============================================================

      final adminDoc = await firestore
          .collection('Admins')
          .doc(user.uid)
          .get();

      if (adminDoc.exists) {
        final data = adminDoc.data() ?? {};

        final role = data['Role']
            ?.toString()
            .trim()
            .toLowerCase();

        if (role == 'admin') {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminPanel(),
            ),
          );

          return;
        }
      }

      // ============================================================
      // 2. USER DOCUMENT
      // ============================================================

      final userDoc = await firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final roleValue = userData['role'] ?? userData['Role'];

      final role = roleValue
          ?.toString()
          .trim()
          .toLowerCase();

      // ============================================================
      // 3. COURIER CHECK
      // ============================================================

      if (role == 'courier') {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const CourierPanel(),
          ),
        );

        return;
      }

      // ============================================================
      // 4. VENDOR CHECK
      // ============================================================

      if (role == 'vendor') {
        final vendorDoc = await firestore
            .collection('vendors')
            .doc(user.uid)
            .get();

        final vendorData = vendorDoc.data() ?? {};

        // User document status
        final userVendorStatus =
            userData['vendorStatus']
                ?.toString()
                .trim()
                .toLowerCase();

        // Vendor document status
        final vendorStatus =
            vendorData['status']
                ?.toString()
                .trim()
                .toLowerCase();

        // Prefer vendor document status if available.
        final effectiveStatus =
            vendorStatus?.isNotEmpty == true
                ? vendorStatus
                : userVendorStatus;

        // Active can be maintained in either document.
        final userActive =
            userData['active'] == true;

        final vendorActive =
            vendorData['active'] == true;

        final isActive =
            userActive || vendorActive;

        // ------------------------------------------------------------
        // APPROVED + ACTIVE VENDOR
        // ------------------------------------------------------------

        if (effectiveStatus == 'approved' && isActive) {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const VendorPanel(),
            ),
          );

          return;
        }

        // ------------------------------------------------------------
        // VENDOR NOT APPROVED
        // ------------------------------------------------------------

        await FirebaseAuth.instance.signOut();

        if (effectiveStatus == 'pending') {
          showMessage(
            'Vendor account is pending approval.',
          );
        } else if (effectiveStatus == 'rejected') {
          showMessage(
            'Vendor application has been rejected.',
          );
        } else if (effectiveStatus == 'suspended') {
          showMessage(
            'Vendor account is suspended.',
          );
        } else if (effectiveStatus != 'approved') {
          showMessage(
            'Vendor account is not approved yet.',
          );
        } else if (!isActive) {
          showMessage(
            'Vendor account is inactive.',
          );
        } else {
          showMessage(
            'Vendor access denied.',
          );
        }

        return;
      }

      // ============================================================
      // 5. UNKNOWN / UNAUTHORIZED STAFF
      // ============================================================

      await FirebaseAuth.instance.signOut();

      showMessage(
        'Access denied. This account is not authorized for staff login.',
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';

      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        message = 'Invalid email or password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'too-many-requests') {
        message =
            'Too many attempts. Try again later.';
      } else if (e.code == 'network-request-failed') {
        message =
            'Network error. Check your internet connection.';
      } else if (e.code == 'user-disabled') {
        message =
            'This account has been disabled.';
      }

      showMessage(message);
    } catch (e) {
      showMessage(
        'Something went wrong:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Staff Login',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    size: 70,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Preesho Staff Login',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Admin, Courier & Vendor access',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 28),

                  TextField(
                    controller: emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter email',
                      prefixIcon:
                          const Icon(
                        Icons.email_outlined,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon:
                          const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            hidePassword =
                                !hidePassword;
                          });
                        },
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => login(),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                          loading ? null : login,
                      icon: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.login,
                            ),
                      label: Text(
                        loading
                            ? 'Logging in...'
                            : 'Login',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
