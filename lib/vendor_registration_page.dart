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
  final businessNameController = TextEditingController();
  final ownerNameController = TextEditingController();
  final mobileController = TextEditingController();
  final otpController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const String testMobile = '9666666666';
  static const String testOtp = '966666';

  bool loading = false;
  bool otpVerified = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    businessNameController.dispose();
    ownerNameController.dispose();
    mobileController.dispose();
    otpController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // SEND TEST OTP
  // --------------------------------------------------

  Future<void> sendOtp() async {
    if (loading) return;

    final mobile = mobileController.text.trim();

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      _showMessage(
        'Please enter a valid 10-digit mobile number.',
        isError: true,
      );
      return;
    }

    if (mobile != testMobile) {
      _showMessage(
        'For testing, please use 9666666666.',
        isError: true,
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final existingVendor = await _firestore
          .collection('vendors')
          .where('phone', isEqualTo: mobile)
          .limit(1)
          .get();

      if (existingVendor.docs.isNotEmpty) {
        _showMessage(
          'This mobile number is already registered.',
          isError: true,
        );
        return;
      }

      final existingUser = await _firestore
          .collection('users')
          .where('phone', isEqualTo: mobile)
          .limit(1)
          .get();

      if (existingUser.docs.isNotEmpty) {
        _showMessage(
          'This mobile number is already registered.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;

      _showMessage(
        'Test OTP sent. Use OTP: 966666',
        isError: false,
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'VENDOR OTP ERROR: ${e.code} - ${e.message}',
      );

      _showMessage(
        'We could not send the OTP right now. Please try again.',
        isError: true,
      );
    } catch (e) {
      debugPrint('VENDOR OTP UNKNOWN ERROR: $e');

      _showMessage(
        'Something went wrong. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // VERIFY OTP
  // --------------------------------------------------

  void verifyOtp() {
    if (loading) return;

    final mobile = mobileController.text.trim();
    final otp = otpController.text.trim();

    if (mobile != testMobile) {
      _showMessage(
        'Please use the test mobile number 9666666666.',
        isError: true,
      );
      return;
    }

    if (otp != testOtp) {
      _showMessage(
        'Invalid OTP. Please enter 966666.',
        isError: true,
      );
      return;
    }

    setState(() {
      otpVerified = true;
    });

    _showMessage(
      'Mobile number verified successfully.',
      isError: false,
    );
  }

  // --------------------------------------------------
  // REGISTER VENDOR
  // --------------------------------------------------

  Future<void> registerVendor() async {
    if (loading) return;

    final businessName =
        businessNameController.text.trim();
    final ownerName =
        ownerNameController.text.trim();
    final mobile = mobileController.text.trim();
    final email = emailController.text.trim();
    final password =
        passwordController.text.trim();

    if (businessName.isEmpty) {
      _showMessage(
        'Please enter your business or shop name.',
        isError: true,
      );
      return;
    }

    if (ownerName.isEmpty) {
      _showMessage(
        'Please enter the owner name.',
        isError: true,
      );
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      _showMessage(
        'Please enter a valid 10-digit mobile number.',
        isError: true,
      );
      return;
    }

    if (mobile != testMobile) {
      _showMessage(
        'For testing, please use 9666666666.',
        isError: true,
      );
      return;
    }

    if (!otpVerified) {
      _showMessage(
        'Please verify your mobile number first.',
        isError: true,
      );
      return;
    }

    if (email.isEmpty ||
        !RegExp(
          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
        ).hasMatch(email)) {
      _showMessage(
        'Please enter a valid email address.',
        isError: true,
      );
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password must contain at least 6 characters.',
        isError: true,
      );
      return;
    }

    setState(() {
      loading = true;
    });

    User? createdUser;

    try {
      // ----------------------------------------------
      // FINAL DUPLICATE CHECK
      // ----------------------------------------------

      final existingVendor = await _firestore
          .collection('vendors')
          .where('phone', isEqualTo: mobile)
          .limit(1)
          .get();

      if (existingVendor.docs.isNotEmpty) {
        _showMessage(
          'This mobile number is already registered.',
          isError: true,
        );
        return;
      }

      // ----------------------------------------------
      // CREATE FIREBASE AUTH ACCOUNT
      // ----------------------------------------------

      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception(
          'Vendor account could not be created.',
        );
      }

      final uid = createdUser.uid;

      // ----------------------------------------------
      // USERS PROFILE
      // ----------------------------------------------

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

        // Vendor cannot login/use panel
        // until Admin approval.
        'status': 'pending_documents',
        'active': false,

        'createdAt':
            FieldValue.serverTimestamp(),
      });

      // ----------------------------------------------
      // VENDOR PROFILE
      // ----------------------------------------------

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

        'status': 'pending_documents',
        'active': false,

        'documentsSubmitted': false,
        'approvedByAdmin': false,

        // Document data will be added by
        // VendorDocumentsPage.
        'documents': {},

        'createdAt':
            FieldValue.serverTimestamp(),
      });

      // ----------------------------------------------
      // SIGN OUT
      // ----------------------------------------------

      await _auth.signOut();

      if (!mounted) return;

      // ----------------------------------------------
      // OPEN DOCUMENT PAGE
      // ----------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDocumentsPage(
            vendorUid: uid,
          ),
        ),
      );
    }

    // ----------------------------------------------
    // AUTH ERROR
    // ----------------------------------------------

    on FirebaseAuthException catch (e) {
      debugPrint(
        'VENDOR AUTH ERROR: ${e.code} - ${e.message}',
      );

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'This email address is already registered. '
              'Please use another email.';
          break;

        case 'weak-password':
          message =
              'Your password is too weak. '
              'Please use at least 6 characters.';
          break;

        case 'invalid-email':
          message =
              'Please enter a valid email address.';
          break;

        case 'operation-not-allowed':
          message =
              'Registration is temporarily unavailable. '
              'Please try again later.';
          break;

        case 'network-request-failed':
          message =
              'Unable to connect. Please check your internet connection.';
          break;

        case 'too-many-requests':
          message =
              'Too many attempts. Please try again later.';
          break;

        default:
          message =
              'We could not complete registration. Please try again.';
      }

      _showMessage(
        message,
        isError: true,
      );
    }

    // ----------------------------------------------
    // FIRESTORE ERROR
    // ----------------------------------------------

    on FirebaseException catch (e) {
      debugPrint(
        'VENDOR FIREBASE ERROR: ${e.code} - ${e.message}',
      );

      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (cleanupError) {
          debugPrint(
            'VENDOR AUTH CLEANUP ERROR: $cleanupError',
          );
        }
      }

      String message;

      switch (e.code) {
        case 'permission-denied':
          message =
              'Registration is temporarily unavailable. '
              'Please try again later.';
          break;

        case 'unavailable':
          message =
              'Server is temporarily unavailable. '
              'Please try again shortly.';
          break;

        case 'network-request-failed':
          message =
              'Please check your internet connection and try again.';
          break;

        case 'failed-precondition':
          message =
              'Registration service is not ready yet. '
              'Please try again later.';
          break;

        default:
          message =
              'We could not complete registration. '
              'Please try again later.';
      }

      _showMessage(
        message,
        isError: true,
      );
    }

    // ----------------------------------------------
    // UNKNOWN ERROR
    // ----------------------------------------------

    catch (e) {
      debugPrint(
        'VENDOR UNKNOWN ERROR: $e',
      );

      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (cleanupError) {
          debugPrint(
            'VENDOR AUTH CLEANUP ERROR: $cleanupError',
          );
        }
      }

      _showMessage(
        'We could not complete registration. '
        'Please try again later.',
        isError: true,
      );
    }

    finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // MESSAGE
  // --------------------------------------------------

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(
          seconds: isError ? 4 : 5,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --------------------------------------------------
  // DECORATION
  // --------------------------------------------------

  InputDecoration _decoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.storefront,
                size: 72,
              ),

              const SizedBox(height: 10),

              const Text(
                'Create Vendor Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Complete registration first. '
                'Documents will be submitted in the next step.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 25),

              // BUSINESS NAME
              TextField(
                controller: businessNameController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: _decoration(
                  'Business / Shop Name',
                  Icons.store_outlined,
                ),
              ),

              const SizedBox(height: 15),

              // OWNER NAME
              TextField(
                controller: ownerNameController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: _decoration(
                  'Owner Name',
                  Icons.person_outline,
                ),
              ),

              const SizedBox(height: 15),

              // MOBILE
              TextField(
                controller: mobileController,
                keyboardType:
                    TextInputType.phone,
                maxLength: 10,
                enabled: !otpVerified,
                decoration: _decoration(
                  'Mobile Number',
                  Icons.phone_outlined,
                ),
              ),

              const SizedBox(height: 4),

              // SEND OTP
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed:
                      loading || otpVerified
                          ? null
                          : sendOtp,
                  icon: const Icon(
                    Icons.sms_outlined,
                  ),
                  label: Text(
                    otpVerified
                        ? 'Mobile Verified'
                        : 'SEND OTP',
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // OTP
              TextField(
                controller: otpController,
                keyboardType:
                    TextInputType.number,
                maxLength: 6,
                enabled: !otpVerified,
                decoration: _decoration(
                  'Enter OTP',
                  Icons.verified_user_outlined,
                ),
              ),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      loading || otpVerified
                          ? null
                          : verifyOtp,
                  child: Text(
                    otpVerified
                        ? 'OTP VERIFIED ✓'
                        : 'VERIFY OTP',
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // EMAIL
              TextField(
                controller: emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration: _decoration(
                  'Email Address',
                  Icons.email_outlined,
                ),
              ),

              const SizedBox(height: 15),

              // PASSWORD
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: _decoration(
                  'Password',
                  Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword =
                            !obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // REGISTER
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      loading
                          ? null
                          : registerVendor,
                  child: loading
                      ? const SizedBox(
                          width: 25,
                          height: 25,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'SUBMIT REGISTRATION',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 18),

              // TEST INFO
              Container(
                padding:
                    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Registration',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Mobile: 9666666666',
                    ),
                    Text(
                      'OTP: 966666',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                'After registration, your documents must be '
                'submitted and verified by Preesho Admin before '
                'your vendor account can be activated.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
