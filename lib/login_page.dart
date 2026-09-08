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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    mobileController.dispose();
    otpController.dispose();
    super.dispose();
  }

  // ============================================================
  // STATUS NORMALIZER
  // ============================================================

  String normalizeStatus(dynamic value) {
    return value
            ?.toString()
            .trim()
            .toLowerCase()
            .replaceAll(' ', '_') ??
        '';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        backgroundColor:
            isError ? Colors.red : null,
      ),
    );
  }

  // ============================================================
  // OPEN COURIER DOCUMENT PAGE
  // ============================================================

  Future<void> openCourierDocuments(
    String uid,
  ) async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourierDocumentsPage(
          courierUid: uid,
        ),
      ),
    );
  }

  // ============================================================
  // RECOVER COURIER PROFILE
  //
  // Auth account मौजूद है लेकिन couriers/{uid} missing है,
  // तो users/{uid} से courier profile restore की जाएगी.
  // ============================================================

  Future<Map<String, dynamic>?> recoverCourierProfile(
    User user,
    Map<String, dynamic> userData,
  ) async {
    try {
      final courierRef =
          _firestore.collection('couriers').doc(user.uid);

      final courierSnapshot =
          await courierRef.get();

      // Existing courier document
      if (courierSnapshot.exists) {
        return courierSnapshot.data();
      }

      // ----------------------------------------------------------
      // DATA RECOVERY
      // ----------------------------------------------------------

      String name =
          userData['name']
                  ?.toString()
                  .trim() ??
              '';

      String phone =
          userData['phone']
                  ?.toString()
                  .trim() ??
              '';

      String email =
          userData['email']
                  ?.toString()
                  .trim() ??
              '';

      if (name.isEmpty) {
        name =
            (user.displayName ?? '').trim();
      }

      if (phone.isEmpty) {
        phone =
            (user.phoneNumber ?? '')
                .replaceFirst('+91', '')
                .trim();
      }

      if (email.isEmpty) {
        email =
            (user.email ?? '').trim();
      }

      final existingStatus =
          normalizeStatus(
        userData['status'] ??
            userData['registrationStatus'],
      );

      final status =
          existingStatus.isEmpty
              ? 'pending_documents'
              : existingStatus;

      final courierData =
          <String, dynamic>{
        'uid': user.uid,
        'name': name,
        'phone': phone,
        'email': email,
        'role': 'courier',
        'status': status,
        'registrationStatus':
            status,
        'active':
            userData['active'] == true,
        'documentsSubmitted':
            userData['documentsSubmitted'] ==
                true,
        'approvedByAdmin':
            userData['approvedByAdmin'] ==
                true,
        'documents': {},
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      await courierRef.set(
        courierData,
        SetOptions(merge: true),
      );

      return courierData;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Recover courier profile error: $e',
        );
      }

      return null;
    }
  }

  // ============================================================
  // COURIER LOGIN ROUTING
  //
  // RETURN VALUE:
  //
  // true  = courier flow handled, normal login continue नहीं करना
  //
  // false = fully approved courier, caller Courier Panel flow
  //         continue कर सकता है.
  // ============================================================

  Future<bool> handleCourierAfterLogin(
    User user,
  ) async {
    try {
      // ----------------------------------------------------------
      // USERS PROFILE
      // ----------------------------------------------------------

      final userRef =
          _firestore.collection('users').doc(user.uid);

      final userSnapshot =
          await userRef.get();

      Map<String, dynamic> userData =
          {};

      if (userSnapshot.exists) {
        userData =
            userSnapshot.data() ?? {};
      }

      final userRole =
          userData['role']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      // Not a courier
      if (userRole != 'courier') {
        return false;
      }

      // ----------------------------------------------------------
      // COURIER PROFILE
      // ----------------------------------------------------------

      Map<String, dynamic>? courierData;

      final courierSnapshot =
          await _firestore
              .collection('couriers')
              .doc(user.uid)
              .get();

      if (courierSnapshot.exists) {
        courierData =
            courierSnapshot.data();
      } else {
        courierData =
            await recoverCourierProfile(
          user,
          userData,
        );
      }

      // ----------------------------------------------------------
      // PROFILE NOT FOUND
      // ----------------------------------------------------------

      if (courierData == null) {
        showMessage(
          'Courier profile nahi mil rahi. '
          'Please admin se contact karein.',
          isError: true,
        );

        return true;
      }

      // ----------------------------------------------------------
      // DATA
      // ----------------------------------------------------------

      final status =
          normalizeStatus(
        courierData['status'] ??
            courierData['registrationStatus'] ??
            userData['status'] ??
            userData['registrationStatus'] ??
            'pending_documents',
      );

      final documentsSubmitted =
          courierData['documentsSubmitted'] ==
              true;

      final active =
          courierData['active'] == true;

      final approvedByAdmin =
          courierData['approvedByAdmin'] ==
              true;

      // ==========================================================
      // 1. DOCUMENTS NOT COMPLETE
      // ==========================================================

      if (status == 'pending_documents' ||
          !documentsSubmitted) {
        showMessage(
          'Registration complete hai. '
          'Ab required documents complete karein.',
        );

        await openCourierDocuments(
          user.uid,
        );

        return true;
      }

      // ==========================================================
      // 2. APPROVAL PENDING
      // ==========================================================

      if (status == 'pending_approval') {
        showMessage(
          'Documents submit ho gaye hain. '
          'Admin approval ka wait karein.',
        );

        await openCourierDocuments(
          user.uid,
        );

        return true;
      }

      // ==========================================================
      // 3. REJECTED
      // ==========================================================

      if (status == 'rejected') {
        final reason =
            courierData['rejectionReason']
                    ?.toString()
                    .trim() ??
                '';

        if (reason.isNotEmpty) {
          showMessage(
            'Documents reject hue hain: $reason',
            isError: true,
          );
        } else {
          showMessage(
            'Documents reject hue hain. '
            'Documents check karke dobara submit karein.',
            isError: true,
          );
        }

        await openCourierDocuments(
          user.uid,
        );

        return true;
      }

      // ==========================================================
      // 4. FULLY APPROVED
      //
      // ONLY THIS CONDITION ALLOWS COURIER PANEL
      // ==========================================================

      if (status == 'approved' &&
          active &&
          approvedByAdmin) {
        return false;
      }

      // ==========================================================
      // 5. APPROVED BUT NOT ACTIVE
      // ==========================================================

      if (status == 'approved') {
        showMessage(
          'Courier approved hai, lekin account abhi active nahi hai.',
          isError: true,
        );

        await openCourierDocuments(
          user.uid,
        );

        return true;
      }

      // ==========================================================
      // 6. UNKNOWN STATUS
      // ==========================================================

      showMessage(
        'Courier account verification pending hai.',
      );

      await openCourierDocuments(
        user.uid,
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Courier routing error: $e',
        );
      }

      showMessage(
        'Courier account verify nahi ho paya. '
        'Please try again.',
        isError: true,
      );

      return true;
    }
  }

  // ============================================================
  // SAVE USER PROFILE
  //
  // Existing courier/vendor/customer profile ko overwrite नहीं
  // किया जाएगा.
  // ============================================================

  Future<void> saveUserProfile(
    User user, {
    String loginType = 'email',
  }) async {
    try {
      final userRef =
          _firestore.collection('users').doc(user.uid);

      final snapshot =
          await userRef.get();

      // ----------------------------------------------------------
      // NEW USER
      // ----------------------------------------------------------

      if (!snapshot.exists) {
        await userRef.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'role': 'customer',
          'status': 'approved',
          'registrationStatus':
              'approved',
          'active': true,
          'createdAt':
              FieldValue.serverTimestamp(),
          'loginType': loginType,
        });

        return;
      }

      // ----------------------------------------------------------
      // EXISTING USER
      // Do not change role/status.
      // ----------------------------------------------------------

      await userRef.set(
        {
          'uid': user.uid,
          'updatedAt':
              FieldValue.serverTimestamp(),
          'loginType': loginType,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Save user profile error: $e',
        );
      }
    }
  }

  // ============================================================
  // EMAIL LOGIN
  // ============================================================

  Future<void> loginWithEmail() async {
    final email =
        emailController.text.trim();

    final password =
        passwordController.text.trim();

    if (email.isEmpty ||
        password.isEmpty) {
      showMessage(
        'Email aur password enter karein.',
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

      final user =
          credential.user;

      if (user == null) {
        showMessage(
          'Login failed.',
          isError: true,
        );
        return;
      }

      // ----------------------------------------------------------
      // USER PROFILE
      // ----------------------------------------------------------

      final userSnapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      final userData =
          userSnapshot.data() ?? {};

      final role =
          userData['role']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      // ==========================================================
      // COURIER
      // ==========================================================

      if (role == 'courier') {
        final handled =
            await handleCourierAfterLogin(
          user,
        );

        if (handled) {
          return;
        }

        // --------------------------------------------------------
        // Fully approved + active courier
        // --------------------------------------------------------

        if (!mounted) return;

        Navigator.pop(
          context,
          true,
        );

        return;
      }

      // ==========================================================
      // CUSTOMER / VENDOR / OTHER
      // ==========================================================

      await saveUserProfile(
        user,
        loginType: 'email',
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } on FirebaseAuthException catch (e) {
      String message =
          'Login failed.';

      switch (e.code) {
        case 'user-not-found':
          message =
              'Is email se account nahi mila.';
          break;

        case 'wrong-password':
          message =
              'Password galat hai.';
          break;

        case 'invalid-credential':
          message =
              'Email ya password galat hai.';
          break;

        case 'invalid-email':
          message =
              'Invalid email address.';
          break;

        case 'user-disabled':
          message =
              'Ye account disabled hai.';
          break;

        case 'too-many-requests':
          message =
              'Bahut attempts ho gaye. '
              'Thodi der baad try karein.';
          break;

        case 'operation-not-allowed':
          message =
              'Email/password login Firebase mein enabled nahi hai.';
          break;

        case 'network-request-failed':
          message =
              'Internet connection check karein.';
          break;
      }

      showMessage(
        message,
        isError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Email login error: $e',
        );
      }

      showMessage(
        'Something went wrong. Please try again.',
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

  // ============================================================
  // SEND FIREBASE OTP
  // ============================================================

  Future<void> sendOtp() async {
    final mobile =
        mobileController.text.trim();

    if (mobile.isEmpty ||
        mobile.length != 10) {
      showMessage(
        '10 digit mobile number enter karein.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // TEST NUMBERS
    // ----------------------------------------------------------

    if (mobile == '9111111111' ||
        mobile == '9666666666') {
      setState(() {
        otpSent = true;
        isLoading = false;
      });

      showMessage(
        'Test OTP available hai.',
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$mobile',

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            final result =
                await _auth
                    .signInWithCredential(
              credential,
            );

            final user =
                result.user;

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
              isError: true,
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
            e.message ??
                'OTP send nahi ho paya.',
            isError: true,
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

          showMessage(
            'OTP send ho gaya.',
          );
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

        forceResendingToken:
            resendToken,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      if (kDebugMode) {
        debugPrint(
          'Send OTP error: $e',
        );
      }

      showMessage(
        'OTP send nahi ho paya.',
        isError: true,
      );
    }
  }

  // ============================================================
  // VERIFY FIREBASE OTP
  // ============================================================

  Future<void> verifyFirebaseOtp() async {
    final otp =
        otpController.text.trim();

    if (otp.isEmpty ||
        otp.length != 6) {
      showMessage(
        '6 digit OTP enter karein.',
        isError: true,
      );
      return;
    }

    if (verificationId == null ||
        verificationId!.isEmpty) {
      showMessage(
        'Pehle OTP send karein.',
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
          PhoneAuthProvider.credential(
        verificationId:
            verificationId!,
        smsCode: otp,
      );

      final result =
          await _auth.signInWithCredential(
        credential,
      );

      final user =
          result.user;

      if (user == null) {
        showMessage(
          'OTP login failed.',
          isError: true,
        );
        return;
      }

      await saveMobileAndFinish(
        mobileController.text.trim(),
        existingUser: user,
      );
    } on FirebaseAuthException catch (e) {
      String message =
          'OTP verification failed.';

      if (e.code ==
          'invalid-verification-code') {
        message =
            'OTP galat hai.';
      } else if (e.code ==
          'session-expired') {
        message =
            'OTP expire ho gaya. Dobara OTP send karein.';
      } else if (e.code ==
          'invalid-verification-id') {
        message =
            'Verification session invalid hai. '
            'Dobara OTP send karein.';
      }

      showMessage(
        message,
        isError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Firebase OTP verification error: $e',
        );
      }

      showMessage(
        'OTP verification failed.',
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

  // ============================================================
  // TEST OTP
  // ============================================================

  Future<void> verifyTestOtp() async {
    final mobile =
        mobileController.text.trim();

    final otp =
        otpController.text.trim();

    String? expectedOtp;

    if (mobile == '9111111111') {
      expectedOtp = '911111';
    } else if (mobile == '9666666666') {
      expectedOtp = '966666';
    }

    if (expectedOtp == null) {
      showMessage(
        'Test OTP sirf test mobile numbers ke liye hai.',
        isError: true,
      );
      return;
    }

    if (otp != expectedOtp) {
      showMessage(
        'Invalid OTP.',
        isError: true,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final email =
          '$mobile@preesho.test';

      UserCredential credential;

      try {
        credential =
            await _auth
                .signInWithEmailAndPassword(
          email: email,
          password: expectedOtp,
        );
      } on FirebaseAuthException {
        credential =
            await _auth
                .createUserWithEmailAndPassword(
          email: email,
          password: expectedOtp,
        );
      }

      final user =
          credential.user;

      if (user == null) {
        showMessage(
          'Test login failed.',
          isError: true,
        );
        return;
      }

      await saveMobileAndFinish(
        mobile,
        existingUser: user,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Test OTP login error: $e',
        );
      }

      showMessage(
        'Test OTP login failed.',
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

  // ============================================================
  // MOBILE LOGIN
  // ============================================================

  Future<void> loginWithOtp() async {
    final mobile =
        mobileController.text.trim();

    if (mobile == '9111111111' ||
        mobile == '9666666666') {
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
        existingUser ??
            _auth.currentUser;

    if (user == null) {
      showMessage(
        'User login nahi hua.',
        isError: true,
      );
      return;
    }

    try {
      final userRef =
          _firestore
              .collection('users')
              .doc(user.uid);

      final snapshot =
          await userRef.get();

      // ==========================================================
      // EXISTING PROFILE
      // ==========================================================

      if (snapshot.exists) {
        final existingData =
            snapshot.data() ?? {};

        final role =
            existingData['role']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        // --------------------------------------------------------
        // COURIER
        // --------------------------------------------------------

        if (role == 'courier') {
          final handled =
              await handleCourierAfterLogin(
            user,
          );

          if (handled) {
            return;
          }

          // Fully approved courier
          if (!mounted) return;

          Navigator.pop(
            context,
            true,
          );

          return;
        }

        // --------------------------------------------------------
        // EXISTING CUSTOMER / VENDOR
        // --------------------------------------------------------

        await userRef.set(
          {
            'uid': user.uid,
            'phone': mobile,
            'email': user.email ?? '',
            'updatedAt':
                FieldValue.serverTimestamp(),
            'loginType': 'mobile',
          },
          SetOptions(
            merge: true,
          ),
        );
      } else {
        // ========================================================
        // NEW CUSTOMER
        // ========================================================

        await userRef.set({
          'uid': user.uid,
          'phone': mobile,
          'email': user.email ?? '',
          'role': 'customer',
          'status': 'approved',
          'registrationStatus':
              'approved',
          'active': true,
          'createdAt':
              FieldValue.serverTimestamp(),
          'loginType': 'mobile',
        });
      }

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Save mobile profile error: $e',
        );
      }

      showMessage(
        'Profile save nahi ho payi. '
        'Please try again.',
        isError: true,
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
        builder: (_) =>
            const ForgotPasswordPage(),
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
        title:
            const Text('Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: 20,
              ),

              const Text(
                'Welcome to Preesho',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // EMAIL
              // ==================================================

              TextField(
                controller:
                    emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Email',
                  prefixIcon:
                      Icon(
                    Icons.email_outlined,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // PASSWORD
              // ==================================================

              TextField(
                controller:
                    passwordController,
                obscureText:
                    obscurePassword,
                decoration:
                    InputDecoration(
                  labelText:
                      'Password',
                  prefixIcon:
                      const Icon(
                    Icons.lock_outline,
                  ),
                  border:
                      const OutlineInputBorder(),
                  suffixIcon:
                      IconButton(
                    icon:
                        Icon(
                      obscurePassword
                          ? Icons
                              .visibility_off
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

              const SizedBox(
                height: 10,
              ),

              Align(
                alignment:
                    Alignment.centerRight,
                child:
                    TextButton(
                  onPressed:
                      isLoading
                          ? null
                          : openForgotPassword,
                  child:
                      const Text(
                    'Forgot Password?',
                  ),
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              // ==================================================
              // EMAIL LOGIN
              // ==================================================

              SizedBox(
                height: 50,
                child:
                    ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : loginWithEmail,
                  child:
                      isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Text(
                              'Login with Email',
                            ),
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              const Row(
                children: [
                  Expanded(
                    child:
                        Divider(),
                  ),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    child:
                        Text('OR'),
                  ),
                  Expanded(
                    child:
                        Divider(),
                  ),
                ],
              ),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // MOBILE
              // ==================================================

              TextField(
                controller:
                    mobileController,
                keyboardType:
                    TextInputType.phone,
                maxLength: 10,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Mobile Number',
                  prefixText:
                      '+91 ',
                  prefixIcon:
                      Icon(
                    Icons.phone_android,
                  ),
                  border:
                      OutlineInputBorder(),
                  counterText:
                      '',
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // SEND OTP
              // ==================================================

              if (!otpSent)
                SizedBox(
                  height: 50,
                  child:
                      ElevatedButton(
                    onPressed:
                        isLoading
                            ? null
                            : sendOtp,
                    child:
                        const Text(
                      'Send OTP',
                    ),
                  ),
                ),

              // ==================================================
              // OTP
              // ==================================================

              if (otpSent) ...[
                const SizedBox(
                  height: 5,
                ),

                TextField(
                  controller:
                      otpController,
                  keyboardType:
                      TextInputType.number,
                  maxLength: 6,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Enter OTP',
                    prefixIcon:
                        Icon(
                      Icons.password,
                    ),
                    border:
                        OutlineInputBorder(),
                    counterText:
                        '',
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                SizedBox(
                  height: 50,
                  child:
                      ElevatedButton(
                    onPressed:
                        isLoading
                            ? null
                            : loginWithOtp,
                    child:
                        isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Text(
                                'Verify OTP',
                              ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                TextButton(
                  onPressed:
                      isLoading
                          ? null
                          : () {
                              setState(() {
                                otpSent =
                                    false;
                                verificationId =
                                    null;
                                resendToken =
                                    null;
                                otpController
                                    .clear();
                              });
                            },
                  child:
                      const Text(
                    'Change Mobile Number',
                  ),
                ),
              ],

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // TEST LOGIN
              // ==================================================

              const Text(
                'Test Courier: 9111111111 / OTP 911111',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize: 12,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              const Text(
                'Test Vendor: 9666666666 / OTP 966666',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
