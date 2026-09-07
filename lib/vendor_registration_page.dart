import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'vendor_documents_page.dart';

class VendorRegistrationPage extends StatefulWidget {
  const VendorRegistrationPage({super.key});

  @override
  State<VendorRegistrationPage> createState() =>
      _VendorRegistrationPageState();
}

class _VendorRegistrationPageState
    extends State<VendorRegistrationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController _businessNameController =
      TextEditingController();

  final TextEditingController _ownerNameController =
      TextEditingController();

  final TextEditingController _mobileController =
      TextEditingController();

  final TextEditingController _otpController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  // ============================================================
  // TEST OTP
  // ============================================================

  static const String _testMobile = '9666666666';
  static const String _testOtp = '966666';

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // REGISTER VENDOR
  // ============================================================

  Future<void> _registerVendor() async {
    if (_loading) return;

    final businessName =
        _businessNameController.text.trim();

    final ownerName =
        _ownerNameController.text.trim();

    final mobile =
        _mobileController.text.trim();

    final otp =
        _otpController.text.trim();

    final email =
        _emailController.text.trim().toLowerCase();

    final password =
        _passwordController.text.trim();

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (businessName.isEmpty) {
      _showMessage(
        'Please enter Business / Shop Name.',
      );
      return;
    }

    if (ownerName.isEmpty) {
      _showMessage(
        'Please enter Owner Name.',
      );
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      _showMessage(
        'Please enter a valid 10-digit mobile number.',
      );
      return;
    }

    if (otp.isEmpty) {
      _showMessage(
        'Please enter OTP.',
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      _showMessage(
        'Please enter a valid email address.',
      );
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password must be at least 6 characters.',
      );
      return;
    }

    // ==========================================================
    // TEST OTP
    // ==========================================================

    if (mobile == _testMobile && otp != _testOtp) {
      _showMessage(
        'Invalid test OTP.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    User? createdUser;

    try {
      // ========================================================
      // FIREBASE AUTH ACCOUNT
      // ========================================================

      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception(
          'Unable to create vendor account.',
        );
      }

      final uid = createdUser.uid;

      // ========================================================
      // USERS DOCUMENT
      // ========================================================

      await _firestore
          .collection('users')
          .doc(uid)
          .set({
        'uid': uid,
        'name': ownerName,
        'businessName': businessName,
        'phone': mobile,
        'email': email,
        'role': 'vendor',

        // Vendor cannot login before approval.
        'status': 'pending_documents',
        'active': false,

        'createdAt':
            FieldValue.serverTimestamp(),
      });

      // ========================================================
      // VENDORS DOCUMENT
      // ========================================================

      await _firestore
          .collection('vendors')
          .doc(uid)
          .set({
        'uid': uid,
        'name': ownerName,
        'businessName': businessName,
        'phone': mobile,
        'email': email,
        'role': 'vendor',

        // Initial registration state.
        'status': 'pending_documents',
        'active': false,

        // Admin must explicitly approve.
        'approvedByAdmin': false,

        // Documents have not been submitted yet.
        'documentsSubmitted': false,

        // Documents metadata.
        'documents': {},

        'createdAt':
            FieldValue.serverTimestamp(),
      });

      // ========================================================
      // IMPORTANT
      // DO NOT SIGN OUT HERE.
      //
      // Vendor Documents page needs authenticated Firebase user
      // to upload documents and update Firestore.
      // ========================================================

      if (!mounted) return;

      _showMessage(
        'Registration successful. Please upload your documents.',
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDocumentsPage(
            vendorUid: uid,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      // ========================================================
      // AUTH ERROR
      // ========================================================

      debugPrint(
        'Vendor registration Auth error: ${e.code}',
      );

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'This email is already registered.';
          break;

        case 'invalid-email':
          message =
              'Please enter a valid email address.';
          break;

        case 'weak-password':
          message =
              'Password is too weak. Use at least 6 characters.';
          break;

        case 'operation-not-allowed':
          message =
              'Email/password registration is not enabled in Firebase.';
          break;

        case 'network-request-failed':
          message =
              'Network error. Please check your internet connection.';
          break;

        default:
          message =
              'Registration failed. Please try again.';
      }

      if (mounted) {
        _showMessage(message);
      }
    } on FirebaseException catch (e) {
      // ========================================================
      // FIREBASE / FIRESTORE ERROR
      // ========================================================

      debugPrint(
        'Vendor registration Firebase error: ${e.code}',
      );

      // --------------------------------------------------------
      // If Firestore write fails after Auth account creation,
      // sign out so the partially created account cannot
      // accidentally access the application.
      // --------------------------------------------------------

      if (createdUser != null) {
        try {
          await _auth.signOut();
        } catch (_) {}
      }

      if (mounted) {
        if (e.code == 'permission-denied') {
          _showMessage(
            'Registration permission denied. Please check Firebase Rules.',
          );
        } else {
          _showMessage(
            'Unable to save vendor registration. Please try again.',
          );
        }
      }
    } catch (e) {
      // ========================================================
      // GENERAL ERROR
      // ========================================================

      debugPrint(
        'Vendor registration error: $e',
      );

      if (createdUser != null) {
        try {
          await _auth.signOut();
        } catch (_) {}
      }

      if (mounted) {
        _showMessage(
          'Unable to complete registration. Please try again.',
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vendor Registration',
          style: TextStyle(
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
                maxWidth: 500,
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

                      const CircleAvatar(
                        radius: 40,
                        child: Icon(
                          Icons.storefront_outlined,
                          size: 44,
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Register as Vendor',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Create your Preesho Vendor account',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================================
                      // BUSINESS NAME
                      // ==================================================

                      TextField(
                        controller:
                            _businessNameController,

                        textInputAction:
                            TextInputAction.next,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Business / Shop Name',
                          hintText:
                              'Enter business name',
                          prefixIcon:
                              Icon(
                            Icons.store_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==================================================
                      // OWNER NAME
                      // ==================================================

                      TextField(
                        controller:
                            _ownerNameController,

                        textInputAction:
                            TextInputAction.next,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Owner Name',
                          hintText:
                              'Enter owner name',
                          prefixIcon:
                              Icon(
                            Icons.person_outline,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==================================================
                      // MOBILE
                      // ==================================================

                      TextField(
                        controller:
                            _mobileController,

                        keyboardType:
                            TextInputType.phone,

                        maxLength: 10,

                        textInputAction:
                            TextInputAction.next,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Mobile Number',
                          hintText:
                              'Enter 10-digit mobile',
                          prefixIcon:
                              Icon(
                            Icons.phone_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==================================================
                      // OTP
                      // ==================================================

                      TextField(
                        controller:
                            _otpController,

                        keyboardType:
                            TextInputType.number,

                        maxLength: 6,

                        textInputAction:
                            TextInputAction.next,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'OTP',
                          hintText:
                              'Enter OTP',
                          prefixIcon:
                              Icon(
                            Icons.verified_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==================================================
                      // EMAIL
                      // ==================================================

                      TextField(
                        controller:
                            _emailController,

                        keyboardType:
                            TextInputType.emailAddress,

                        textInputAction:
                            TextInputAction.next,

                        autocorrect: false,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Email Address',
                          hintText:
                              'Enter vendor email',
                          prefixIcon:
                              Icon(
                            Icons.email_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

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
                          _registerVendor();
                        },

                        decoration:
                            InputDecoration(
                          labelText:
                              'Password',
                          hintText:
                              'Minimum 6 characters',

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

                      const SizedBox(height: 24),

                      // ==================================================
                      // REGISTER BUTTON
                      // ==================================================

                      SizedBox(
                        height: 52,

                        child:
                            FilledButton.icon(
                          onPressed:
                              _loading
                                  ? null
                                  : _registerVendor,

                          icon:
                              _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2.5,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .person_add_alt_1,
                                    ),

                          label:
                              Text(
                            _loading
                                ? 'Creating Account...'
                                : 'Register Vendor',
                            style:
                                const TextStyle(
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // APPROVAL INFORMATION
                      // ==================================================

                      Container(
                        padding:
                            const EdgeInsets.all(14),

                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          border:
                              Border.all(
                            color:
                                Theme.of(context)
                                    .dividerColor,
                          ),
                        ),

                        child:
                            const Column(
                          children: [
                            Icon(
                              Icons
                                  .admin_panel_settings_outlined,
                              size: 30,
                            ),

                            SizedBox(
                              height: 8,
                            ),

                            Text(
                              'Admin Approval Required',
                              textAlign:
                                  TextAlign.center,
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            SizedBox(
                              height: 5,
                            ),

                            Text(
                              'After registration, upload the required documents. Your Vendor account will remain inactive until Admin verifies and approves it.',
                              textAlign:
                                  TextAlign.center,
                              style:
                                  TextStyle(
                                fontSize:
                                    12,
                                color:
                                    Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==================================================
                      // TEST OTP INFO
                      // ==================================================

                      if (_mobileController.text ==
                          _testMobile)
                        Container(
                          padding:
                              const EdgeInsets.all(
                            12,
                          ),

                          decoration:
                              BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(
                              10,
                            ),
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .surfaceContainerHighest,
                          ),

                          child:
                              const Text(
                            'Development Test OTP: 966666',
                            textAlign:
                                TextAlign.center,
                            style:
                                TextStyle(
                              fontSize:
                                  12,
                              fontWeight:
                                  FontWeight.bold,
                            ),
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
