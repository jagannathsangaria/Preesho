import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'courier_documents_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final mobileController = TextEditingController();
  final otpController = TextEditingController();

  bool isLoading = false;
  bool otpSent = false;
  bool obscurePassword = true;

  String? verificationId;
  int? resendToken;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    mobileController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // COURIER LOGIN ROUTING
  // ============================================================

  Future<bool> handleCourierAfterLogin(User user) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // ----------------------------------------------------------
      // USERS PROFILE
      // ----------------------------------------------------------

      final userSnapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userSnapshot.exists) {
        return false;
      }

      final userData = userSnapshot.data() ?? {};
      final userRole = userData['role']?.toString().toLowerCase();

      // ----------------------------------------------------------
      // CUSTOMER / OTHER USER
      // ----------------------------------------------------------

      if (userRole != 'courier') {
        return false;
      }

      // ----------------------------------------------------------
      // COURIER PROFILE
      // ----------------------------------------------------------

      final courierSnapshot = await firestore
          .collection('couriers')
          .doc(user.uid)
          .get();

      if (!courierSnapshot.exists) {
        showMessage(
          'Courier profile nahi mila. Admin se contact karein.',
        );
        return true;
      }

      final courierData = courierSnapshot.data() ?? {};

      final status =
          courierData['status']?.toString().toLowerCase() ?? '';

      final documentsSubmitted =
          courierData['documentsSubmitted'] == true;

      final active =
          courierData['active'] == true;

      final approvedByAdmin =
          courierData['approvedByAdmin'] == true;

      // ==========================================================
      // 1. REGISTERED BUT DOCUMENTS NOT SUBMITTED
      // ==========================================================

      if (status == 'pending_documents' ||
          !documentsSubmitted) {
        // IMPORTANT:
        // Login BLOCK nahi karna hai.
        // Direct Documents Page open karna hai.

        if (!mounted) return true;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourierDocumentsPage(
              courierUid: user.uid,
            ),
          ),
        );

        return true;
      }

      // ==========================================================
      // 2. DOCUMENTS SUBMITTED - ADMIN APPROVAL PENDING
      // ==========================================================

      if (status == 'pending_approval') {
        if (!mounted) return true;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourierDocumentsPage(
              courierUid: user.uid,
            ),
          ),
        );

        return true;
      }

      // ==========================================================
      // 3. DOCUMENTS REJECTED
      // ==========================================================

      if (status == 'rejected') {
        if (!mounted) return true;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourierDocumentsPage(
              courierUid: user.uid,
            ),
          ),
        );

        return true;
      }

      // ==========================================================
      // 4. FULLY APPROVED COURIER
      // ==========================================================

      if (status == 'approved' &&
          active &&
          approvedByAdmin) {
        // Courier Panel ko open karne ki permission.
        return false;
      }

      // ==========================================================
      // 5. OTHER UNAPPROVED STATUS
      // ==========================================================

      if (!mounted) return true;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourierDocumentsPage(
            courierUid: user.uid,
          ),
        ),
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Courier routing error: $e');
      }

      showMessage(
        'Courier account verify nahi ho paya. Please try again.',
      );

      return true;
    }
  }

  // ============================================================
  // SAVE USER PROFILE
  // ============================================================

  Future<void> saveUserProfile(
    User user, {
    String loginType = 'email',
  }) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final snapshot = await userRef.get();

      // Existing Courier / Vendor / Customer ko overwrite nahi karna.
      if (!snapshot.exists) {
        await userRef.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'role': 'customer',
          'status': 'approved',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'loginType': loginType,
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Save user profile error: $e');
      }
    }
  }

  // ============================================================
  // EMAIL LOGIN
  // ============================================================

  Future<void> loginWithEmail() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage('Email aur password enter karein.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        showMessage('Login failed.');
        return;
      }

      await saveUserProfile(
        user,
        loginType: 'email',
      );

      final handled =
          await handleCourierAfterLogin(user);

      if (handled) {
        return;
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';

      switch (e.code) {
        case 'user-not-found':
          message = 'User account nahi mila.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message = 'Email ya password galat hai.';
          break;

        case 'invalid-email':
          message = 'Invalid email address.';
          break;

        case 'user-disabled':
          message = 'Ye account disabled hai.';
          break;

        case 'too-many-requests':
          message =
              'Bahut attempts ho gaye. Thodi der baad try karein.';
          break;
      }

      showMessage(message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Email login error: $e');
      }

      showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SEND FIREBASE OTP
  // ============================================================

  Future<void> sendOtp() async {
    final mobile = mobileController.text.trim();

    if (mobile.isEmpty || mobile.length != 10) {
      showMessage('10 digit mobile number enter karein.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$mobile',

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            final result = await FirebaseAuth.instance
                .signInWithCredential(credential);

            final user = result.user;

            if (user != null) {
              await saveMobileAndFinish(
                mobile,
                existingUser: user,
              );
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'Automatic phone verification error: $e',
              );
            }

            showMessage(
              'Automatic verification failed.',
            );
          }
        },

        verificationFailed:
            (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }

          showMessage(
            e.message ?? 'OTP send nahi ho paya.',
          );
        },

        codeSent: (
          String id,
          int? token,
        ) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            resendToken = token;
            otpSent = true;
            isLoading = false;
          });

          showMessage('OTP send ho gaya.');
        },

        codeAutoRetrievalTimeout:
            (String id) {
          verificationId = id;

          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
        },

        forceResendingToken: resendToken,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      if (kDebugMode) {
        debugPrint('Send OTP error: $e');
      }

      showMessage('OTP send nahi ho paya.');
    }
  }

  // ============================================================
  // VERIFY FIREBASE OTP
  // ============================================================

  Future<void> verifyFirebaseOtp() async {
    final otp = otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      showMessage('6 digit OTP enter karein.');
      return;
    }

    if (verificationId == null ||
        verificationId!.isEmpty) {
      showMessage('Pehle OTP send karein.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otp,
      );

      final result = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final user = result.user;

      if (user == null) {
        showMessage('OTP login failed.');
        return;
      }

      await saveMobileAndFinish(
        mobileController.text.trim(),
        existingUser: user,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'OTP verification failed.';

      if (e.code == 'invalid-verification-code') {
        message = 'OTP galat hai.';
      } else if (e.code == 'session-expired') {
        message =
            'OTP expire ho gaya. Dobara OTP send karein.';
      } else if (e.code == 'invalid-verification-id') {
        message =
            'Verification session invalid hai. Dobara OTP send karein.';
      }

      showMessage(message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Firebase OTP verification error: $e',
        );
      }

      showMessage('OTP verification failed.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // TEST OTP
  // ============================================================

  Future<void> verifyTestOtp() async {
    final mobile = mobileController.text.trim();
    final otp = otpController.text.trim();

    String? expectedOtp;

    if (mobile == '9111111111') {
      expectedOtp = '911111';
    } else if (mobile == '9666666666') {
      expectedOtp = '966666';
    }

    if (expectedOtp == null) {
      showMessage(
        'Test OTP sirf test mobile numbers ke liye hai.',
      );
      return;
    }

    if (otp != expectedOtp) {
      showMessage('Invalid OTP.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final email = '$mobile@preesho.test';

      UserCredential credential;

      try {
        credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: email,
          password: expectedOtp,
        );
      } on FirebaseAuthException {
        credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email,
          password: expectedOtp,
        );
      }

      final user = credential.user;

      if (user == null) {
        showMessage('Test login failed.');
        return;
      }

      await saveMobileAndFinish(
        mobile,
        existingUser: user,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Test OTP login error: $e');
      }

      showMessage('Test OTP login failed.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // MOBILE LOGIN
  // ============================================================

  Future<void> loginWithOtp() async {
    final mobile = mobileController.text.trim();

    if (mobile == '9111111111') {
      await verifyTestOtp();
      return;
    }

    if (mobile == '9666666666') {
      await verifyTestOtp();
      return;
    }

    await verifyFirebaseOtp();
  }

  // ============================================================
  // SAVE MOBILE USER
  // ============================================================

  Future<void> saveMobileAndFinish(
    String mobile, {
    User? existingUser,
  }) async {
    final user =
        existingUser ?? FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('User login nahi hua.');
      return;
    }

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final snapshot = await userRef.get();

      if (!snapshot.exists) {
        await userRef.set({
          'uid': user.uid,
          'phone': mobile,
          'email': user.email ?? '',
          'role': 'customer',
          'status': 'approved',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'loginType': 'mobile',
        });
      } else {
        await userRef.set(
          {
            'uid': user.uid,
            'phone': mobile,
            'email': user.email ?? '',
            'updatedAt': FieldValue.serverTimestamp(),
            'loginType': 'mobile',
          },
          SetOptions(merge: true),
        );
      }

      final handled =
          await handleCourierAfterLogin(user);

      if (handled) {
        return;
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Save mobile profile error: $e');
      }

      showMessage(
        'Profile save nahi ho payi. Please try again.',
      );
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  void openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordPage(),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              const Text(
                'Welcome to Preesho',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon:
                      Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon:
                      const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
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

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : openForgotPassword,
                  child: const Text(
                    'Forgot Password?',
                  ),
                ),
              ),

              const SizedBox(height: 5),

              ElevatedButton(
                onPressed:
                    isLoading ? null : loginWithEmail,
                child: const Text(
                  'Login with Email',
                ),
              ),

              const SizedBox(height: 25),

              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 25),

              TextField(
                controller: mobileController,
                keyboardType:
                    TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixText: '+91 ',
                  prefixIcon:
                      Icon(Icons.phone_android),
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),

              const SizedBox(height: 15),

              if (!otpSent)
                ElevatedButton(
                  onPressed:
                      isLoading ? null : sendOtp,
                  child: const Text('Send OTP'),
                ),

              if (otpSent) ...[
                const SizedBox(height: 5),

                TextField(
                  controller: otpController,
                  keyboardType:
                      TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP',
                    prefixIcon:
                        Icon(Icons.password),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 15),

                ElevatedButton(
                  onPressed:
                      isLoading ? null : loginWithOtp,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify OTP',
                        ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          setState(() {
                            otpSent = false;
                            verificationId = null;
                            otpController.clear();
                          });
                        },
                  child: const Text(
                    'Change Mobile Number',
                  ),
                ),
              ],

              const SizedBox(height: 25),

              const Text(
                'Test Courier: 9111111111 / OTP 911111',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),

              const SizedBox(height: 5),

              const Text(
                'Test Vendor: 9666666666 / OTP 966666',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
