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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color primary = Color(0xFF5B35D5);
  static const Color primaryDark = Color(0xFF4323A8);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    mobileController.dispose();
    otpController.dispose();
    super.dispose();
  }

  String normalizeStatus(dynamic value) {
    return value?.toString().trim().toLowerCase().replaceAll(' ', '_') ?? '';
  }

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
        duration: const Duration(seconds: 4),
        backgroundColor: isError ? Colors.red.shade600 : null,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Future<void> openCourierDocuments(String uid) async {
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

  Future<Map<String, dynamic>?> recoverCourierProfile(
    User user,
    Map<String, dynamic> userData,
  ) async {
    try {
      final courierRef =
          _firestore.collection('couriers').doc(user.uid);

      final courierSnapshot = await courierRef.get();

      if (courierSnapshot.exists) {
        return courierSnapshot.data();
      }

      String name =
          userData['name']?.toString().trim() ?? '';

      String phone =
          userData['phone']?.toString().trim() ?? '';

      String email =
          userData['email']?.toString().trim() ?? '';

      if (name.isEmpty) {
        name = (user.displayName ?? '').trim();
      }

      if (phone.isEmpty) {
        phone = (user.phoneNumber ?? '')
            .replaceFirst('+91', '')
            .trim();
      }

      if (email.isEmpty) {
        email = (user.email ?? '').trim();
      }

      final existingStatus = normalizeStatus(
        userData['status'] ??
            userData['registrationStatus'],
      );

      final status = existingStatus.isEmpty
          ? 'pending_documents'
          : existingStatus;

      final courierData = <String, dynamic>{
        'uid': user.uid,
        'name': name,
        'phone': phone,
        'email': email,
        'role': 'courier',
        'status': status,
        'registrationStatus': status,
        'active': userData['active'] == true,
        'documentsSubmitted':
            userData['documentsSubmitted'] == true,
        'approvedByAdmin':
            userData['approvedByAdmin'] == true,
        'documents': {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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

  Future<bool> handleCourierAfterLogin(User user) async {
    try {
      final userRef =
          _firestore.collection('users').doc(user.uid);

      final userSnapshot = await userRef.get();

      Map<String, dynamic> userData = {};

      if (userSnapshot.exists) {
        userData = userSnapshot.data() ?? {};
      }

      final userRole =
          userData['role']?.toString().trim().toLowerCase() ?? '';

      if (userRole != 'courier') {
        return false;
      }

      Map<String, dynamic>? courierData;

      final courierSnapshot = await _firestore
          .collection('couriers')
          .doc(user.uid)
          .get();

      if (courierSnapshot.exists) {
        courierData = courierSnapshot.data();
      } else {
        courierData = await recoverCourierProfile(
          user,
          userData,
        );
      }

      if (courierData == null) {
        showMessage(
          'Courier profile nahi mil rahi. Please admin se contact karein.',
          isError: true,
        );

        return true;
      }

      final status = normalizeStatus(
        courierData['status'] ??
            courierData['registrationStatus'] ??
            userData['status'] ??
            userData['registrationStatus'] ??
            'pending_documents',
      );

      final documentsSubmitted =
          courierData['documentsSubmitted'] == true;

      final active =
          courierData['active'] == true;

      final approvedByAdmin =
          courierData['approvedByAdmin'] == true;

      if (status == 'pending_documents' ||
          !documentsSubmitted) {
        showMessage(
          'Registration complete hai. Ab required documents complete karein.',
        );

        await openCourierDocuments(user.uid);

        return true;
      }

      if (status == 'pending_approval') {
        showMessage(
          'Documents submit ho gaye hain. Admin approval ka wait karein.',
        );

        await openCourierDocuments(user.uid);

        return true;
      }

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
            'Documents reject hue hain. Documents check karke dobara submit karein.',
            isError: true,
          );
        }

        await openCourierDocuments(user.uid);

        return true;
      }

      if (status == 'approved' &&
          active &&
          approvedByAdmin) {
        return false;
      }

      if (status == 'approved') {
        showMessage(
          'Courier approved hai, lekin account abhi active nahi hai.',
          isError: true,
        );

        await openCourierDocuments(user.uid);

        return true;
      }

      showMessage(
        'Courier account verification pending hai.',
      );

      await openCourierDocuments(user.uid);

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Courier routing error: $e',
        );
      }

      showMessage(
        'Courier account verify nahi ho paya. Please try again.',
        isError: true,
      );

      return true;
    }
  }

  Future<void> saveUserProfile(
    User user, {
    String loginType = 'email',
  }) async {
    try {
      final userRef =
          _firestore.collection('users').doc(user.uid);

      final snapshot = await userRef.get();

      if (!snapshot.exists) {
        await userRef.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'role': 'customer',
          'status': 'approved',
          'registrationStatus': 'approved',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'loginType': loginType,
        });

        return;
      }

      await userRef.set(
        {
          'uid': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
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

  Future<void> loginWithEmail() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
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

      final user = credential.user;

      if (user == null) {
        showMessage(
          'Login failed.',
          isError: true,
        );
        return;
      }

      final userSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userSnapshot.data() ?? {};

      final role =
          userData['role']?.toString().trim().toLowerCase() ?? '';

      if (role == 'courier') {
        final handled =
            await handleCourierAfterLogin(user);

        if (handled) {
          return;
        }

        if (!mounted) return;

        Navigator.pop(context, true);

        return;
      }

      await saveUserProfile(
        user,
        loginType: 'email',
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';

      switch (e.code) {
        case 'user-not-found':
          message = 'Is email se account nahi mila.';
          break;

        case 'wrong-password':
          message = 'Password galat hai.';
          break;

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

        case 'operation-not-allowed':
          message =
              'Email/password login Firebase mein enabled nahi hai.';
          break;

        case 'network-request-failed':
          message = 'Internet connection check karein.';
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

  Future<void> sendOtp() async {
    final mobile = mobileController.text.trim();

    if (mobile.isEmpty || mobile.length != 10) {
      showMessage(
        '10 digit mobile number enter karein.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

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
                await _auth.signInWithCredential(
              credential,
            );

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
            e.message ?? 'OTP send nahi ho paya.',
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

        forceResendingToken: resendToken,
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

  Future<void> verifyFirebaseOtp() async {
    final otp = otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
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
        verificationId: verificationId!,
        smsCode: otp,
      );

      final result =
          await _auth.signInWithCredential(
        credential,
      );

      final user = result.user;

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

      if (e.code == 'invalid-verification-code') {
        message = 'OTP galat hai.';
      } else if (e.code == 'session-expired') {
        message =
            'OTP expire ho gaya. Dobara OTP send karein.';
      } else if (e.code == 'invalid-verification-id') {
        message =
            'Verification session invalid hai. Dobara OTP send karein.';
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
      final email = '$mobile@preesho.test';

      UserCredential credential;

      try {
        credential =
            await _auth.signInWithEmailAndPassword(
          email: email,
          password: expectedOtp,
        );
      } on FirebaseAuthException {
        credential =
            await _auth.createUserWithEmailAndPassword(
          email: email,
          password: expectedOtp,
        );
      }

      final user = credential.user;

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

  Future<void> loginWithOtp() async {
    final mobile = mobileController.text.trim();

    if (mobile == '9111111111' ||
        mobile == '9666666666') {
      await verifyTestOtp();
      return;
    }

    await verifyFirebaseOtp();
  }

  Future<void> saveMobileAndFinish(
    String mobile, {
    User? existingUser,
  }) async {
    final user = existingUser ?? _auth.currentUser;

    if (user == null) {
      showMessage(
        'User login nahi hua.',
        isError: true,
      );
      return;
    }

    try {
      final userRef =
          _firestore.collection('users').doc(user.uid);

      final snapshot = await userRef.get();

      if (snapshot.exists) {
        final existingData =
            snapshot.data() ?? {};

        final role =
            existingData['role']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        if (role == 'courier') {
          final handled =
              await handleCourierAfterLogin(user);

          if (handled) {
            return;
          }

          if (!mounted) return;

          Navigator.pop(context, true);

          return;
        }

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
      } else {
        await userRef.set({
          'uid': user.uid,
          'phone': mobile,
          'email': user.email ?? '',
          'role': 'customer',
          'status': 'approved',
          'registrationStatus': 'approved',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'loginType': 'mobile',
        });
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Save mobile profile error: $e',
        );
      }

      showMessage(
        'Profile save nahi ho payi. Please try again.',
        isError: true,
      );
    }
  }

  void openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordPage(),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: primary,
      ),
      prefixText: prefixText,
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

  Widget _buildLogo() {
    return Container(
      height: 82,
      width: 82,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            primary,
            primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(.25),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.shopping_bag_rounded,
        color: Colors.white,
        size: 43,
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        _buildLogo(),
        const SizedBox(height: 22),
        const Text(
          'Welcome to Preesho',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Login karke shopping start karein',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailLogin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Login',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            label: 'Email Address',
            icon: Icons.email_outlined,
          ),
        ),

        const SizedBox(height: 13),

        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!isLoading) {
              loginWithEmail();
            }
          },
          decoration: _inputDecoration(
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  obscurePassword = !obscurePassword;
                });
              },
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed:
                isLoading ? null : openForgotPassword,
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),

        const SizedBox(height: 5),

        _primaryButton(
          text: 'Login with Email',
          icon: Icons.login_rounded,
          onPressed:
              isLoading ? null : loginWithEmail,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey.shade300,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.grey.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLogin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mobile Login',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),

        Text(
          otpSent
              ? 'OTP aapke mobile number par bheja gaya hai.'
              : 'Mobile number se quick login karein.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 14),

        TextField(
          controller: mobileController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          enabled: !otpSent && !isLoading,
          decoration: _inputDecoration(
            label: 'Mobile Number',
            icon: Icons.phone_android_rounded,
            prefixText: '+91 ',
          ).copyWith(
            counterText: '',
          ),
        ),

        if (!otpSent) ...[
          const SizedBox(height: 14),

          _primaryButton(
            text: 'Send OTP',
            icon: Icons.sms_outlined,
            onPressed:
                isLoading ? null : sendOtp,
          ),
        ],

        if (otpSent) ...[
          const SizedBox(height: 14),

          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: _inputDecoration(
              label: 'Enter 6 Digit OTP',
              icon: Icons.password_rounded,
            ).copyWith(
              counterText: '',
            ),
          ),

          const SizedBox(height: 14),

          _primaryButton(
            text: 'Verify OTP',
            icon: Icons.verified_rounded,
            onPressed:
                isLoading ? null : loginWithOtp,
          ),

          const SizedBox(height: 5),

          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: isLoading
                  ? null
                  : () {
                      setState(() {
                        otpSent = false;
                        verificationId = null;
                        resendToken = null;
                        otpController.clear();
                      });
                    },
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
              ),
              label: const Text(
                'Change Mobile Number',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _primaryButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading && onPressed == null
            ? const SizedBox(
                height: 21,
                width: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          isLoading && onPressed == null
              ? 'Please wait...'
              : text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              disabled ? Colors.grey.shade400 : primary,
          foregroundColor: Colors.white,
          elevation: disabled ? 0 : 3,
          shadowColor: primary.withOpacity(.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.green.shade100,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Secure Login',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Aapki login details secure rakhi jaati hain.',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.shade100,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.developer_mode_rounded,
                size: 19,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              Text(
                'Developer Test Login',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Courier: 9111111111  •  OTP: 911111\n'
            'Vendor: 9666666666  •  OTP: 966666',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.orange.shade900,
              fontSize: 11,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            18,
            5,
            18,
            35,
          ),
          child: Column(
            children: [
              _buildHeader(),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.055),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildEmailLogin(),

                    const SizedBox(height: 25),

                    _buildDivider(),

                    const SizedBox(height: 25),

                    _buildMobileLogin(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _buildSecurityCard(),

              const SizedBox(height: 16),

              _buildTestInfo(),

              const SizedBox(height: 15),

              Text(
                'By continuing, you agree to Preesho terms & privacy policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
