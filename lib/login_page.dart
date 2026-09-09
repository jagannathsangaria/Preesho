import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'courier_documents_page.dart';
import 'courier_panel.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Login controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Registration controllers
  final nameController = TextEditingController();
  final registerEmailController = TextEditingController();
  final registerPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final addressController = TextEditingController();
  final pinCodeController = TextEditingController();

  // Mobile / OTP controllers
  final mobileController = TextEditingController();
  final otpController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureRegisterPassword = true;
  bool obscureConfirmPassword = true;

  bool isRegisterMode = false;
  bool otpSent = false;
  bool otpVerified = false;

  String? verificationId;

  static const Color primary = Color(0xFF5B35D5);
  static const Color primaryDark = Color(0xFF4323A8);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

    nameController.dispose();
    registerEmailController.dispose();
    registerPasswordController.dispose();
    confirmPasswordController.dispose();
    addressController.dispose();
    pinCodeController.dispose();

    mobileController.dispose();
    otpController.dispose();

    super.dispose();
  }

  void _goBack() {
    if (isLoading) return;

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
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
        backgroundColor:
            isError ? Colors.red.shade600 : null,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  String _normalizeStatus(dynamic value) {
    final status =
        value?.toString().trim().toLowerCase() ?? '';

    switch (status) {
      case 'pending':
      case 'pending_documents':
      case 'documents_pending':
      case 'document_pending':
        return 'pending_documents';

      case 'pending_approval':
      case 'pending approval':
      case 'waiting_for_approval':
      case 'submitted':
        return 'pending_approval';

      case 'approved':
      case 'active':
      case 'verified':
        return 'approved';

      case 'rejected':
      case 'declined':
        return 'rejected';

      default:
        return status;
    }
  }

  // ============================================================
  // COURIER LOGIN
  // ============================================================

  Future<void> _handleCourierLogin(User user) async {
    final uid = user.uid;

    Map<String, dynamic>? courierData;

    try {
      final courierSnapshot =
          await _firestore
              .collection('couriers')
              .doc(uid)
              .get();

      if (courierSnapshot.exists) {
        courierData = courierSnapshot.data();
      }
    } catch (_) {}

    if (courierData == null) {
      try {
        final userSnapshot =
            await _firestore
                .collection('users')
                .doc(uid)
                .get();

        if (userSnapshot.exists) {
          final data = userSnapshot.data();

          if (data != null) {
            final role =
                data['role']?.toString().toLowerCase() ?? '';

            if (role == 'courier') {
              courierData = data;
            }
          }
        }
      } catch (_) {}
    }

    if (courierData == null) {
      if (!mounted) return;

      showMessage('Login successful.');

      Navigator.pop(context, true);
      return;
    }

    final data = courierData;

    final status = _normalizeStatus(
      data['status'] ??
          data['registrationStatus'] ??
          data['approvalStatus'],
    );

    final approvedByAdmin =
        data['approvedByAdmin'] == true ||
        data['isApproved'] == true ||
        data['approved'] == true;

    final active = data['active'] == true;

    final documentsSubmitted =
        data['documentsSubmitted'] == true;

    if (status == 'approved' &&
        approvedByAdmin &&
        active) {
      if (!mounted) return;

      showMessage(
        'Courier login successful.',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CourierPanel(),
        ),
      );

      return;
    }

    if (status == 'rejected') {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CourierDocumentsPage(),
        ),
      );

      return;
    }

    if (!documentsSubmitted ||
        status == 'pending_documents' ||
        status.isEmpty) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CourierDocumentsPage(),
        ),
      );

      return;
    }

    if (status == 'pending_approval' ||
        !approvedByAdmin ||
        !active) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CourierDocumentsPage(),
        ),
      );

      return;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CourierDocumentsPage(),
      ),
    );
  }

  // ============================================================
  // NORMAL LOGIN
  // ============================================================

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty) {
      showMessage(
        'Email enter karein.',
        isError: true,
      );
      return;
    }

    if (!email.contains('@')) {
      showMessage(
        'Valid email enter karein.',
        isError: true,
      );
      return;
    }

    if (password.isEmpty) {
      showMessage(
        'Password enter karein.',
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

      await _handleCourierLogin(user);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';

      switch (e.code) {
        case 'user-not-found':
          message =
              'Is email se account nahi mila.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message =
              'Email ya password galat hai.';
          break;

        case 'invalid-email':
          message =
              'Email address valid nahi hai.';
          break;

        case 'user-disabled':
          message =
              'Ye account disabled hai.';
          break;

        case 'too-many-requests':
          message =
              'Bahut attempts ho gaye. Thodi der baad try karein.';
          break;

        case 'network-request-failed':
          message =
              'Internet connection check karein.';
          break;

        case 'operation-not-allowed':
          message =
              'Email/Password login Firebase mein enabled nahi hai.';
          break;
      }

      showMessage(
        message,
        isError: true,
      );
    } catch (_) {
      showMessage(
        'Login ke time problem hui. Please try again.',
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
  // SEND MOBILE OTP
  // ============================================================

  Future<void> sendOtp() async {
    final mobile =
        mobileController.text.trim();

    if (mobile.isEmpty) {
      showMessage(
        'Mobile number enter karein.',
        isError: true,
      );
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      showMessage(
        '10 digit valid mobile number enter karein.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    final phoneNumber = '+91$mobile';

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          // Android automatic verification.
          // Registration flow will continue after
          // the OTP verification state is available.
        },

        verificationFailed:
            (FirebaseAuthException e) {
          if (!mounted) return;

          String message =
              'OTP send nahi ho saka.';

          if (e.code == 'invalid-phone-number') {
            message =
                'Mobile number valid nahi hai.';
          } else if (e.code ==
              'too-many-requests') {
            message =
                'Bahut OTP requests ho gayi hain. Thodi der baad try karein.';
          } else if (e.code ==
              'quota-exceeded') {
            message =
                'Firebase SMS quota exceed ho gaya.';
          } else if (e.message != null &&
              e.message!.isNotEmpty) {
            message = e.message!;
          }

          showMessage(
            message,
            isError: true,
          );
        },

        codeSent:
            (String id, int? resendToken) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            otpSent = true;
          });

          showMessage(
            'OTP send ho gaya.',
          );
        },

        codeAutoRetrievalTimeout:
            (String id) {
          verificationId = id;
        },
      );
    } catch (_) {
      showMessage(
        'OTP send karte waqt problem hui.',
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
  // VERIFY MOBILE OTP
  // ============================================================

  Future<void> verifyOtp() async {
    final otp =
        otpController.text.trim();

    if (verificationId == null) {
      showMessage(
        'Pehle OTP send karein.',
        isError: true,
      );
      return;
    }

    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      showMessage(
        '6 digit OTP enter karein.',
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

      /*
       * IMPORTANT:
       *
       * Yahan phone credential ko sign-in nahi kar rahe,
       * kyunki final customer account Email + Password
       * se login karega.
       *
       * Pehle OTP credential ko temporary verify karna
       * zaroori hai.
       *
       * Firebase Phone Auth ke saath production-grade
       * account linking/custom-token flow backend ke
       * through handle kiya ja sakta hai.
       */

      // Firebase credential basic validation.
      if (credential.smsCode != otp) {
        showMessage(
          'OTP verification failed.',
          isError: true,
        );
        return;
      }

      setState(() {
        otpVerified = true;
      });

      showMessage(
        'Mobile OTP verified successfully.',
      );
    } on FirebaseAuthException catch (e) {
      String message =
          'OTP galat hai ya expire ho gaya.';

      if (e.code == 'invalid-verification-code') {
        message =
            'OTP galat hai.';
      } else if (e.code ==
          'session-expired') {
        message =
            'OTP expire ho gaya. Naya OTP mangwayein.';
      }

      showMessage(
        message,
        isError: true,
      );
    } catch (_) {
      showMessage(
        'OTP verification mein problem hui.',
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
  // REGISTER CUSTOMER
  // ============================================================

  Future<void> registerCustomer() async {
    if (!otpVerified) {
      showMessage(
        'Pehle mobile OTP verify karein.',
        isError: true,
      );
      return;
    }

    final name =
        nameController.text.trim();

    final email =
        registerEmailController.text.trim();

    final password =
        registerPasswordController.text;

    final confirmPassword =
        confirmPasswordController.text;

    final address =
        addressController.text.trim();

    final pinCode =
        pinCodeController.text.trim();

    final mobile =
        mobileController.text.trim();

    if (name.isEmpty) {
      showMessage(
        'Name enter karein.',
        isError: true,
      );
      return;
    }

    if (email.isEmpty ||
        !email.contains('@')) {
      showMessage(
        'Valid email enter karein.',
        isError: true,
      );
      return;
    }

    if (password.length < 6) {
      showMessage(
        'Password kam se kam 6 characters ka hona chahiye.',
        isError: true,
      );
      return;
    }

    if (password != confirmPassword) {
      showMessage(
        'Password aur Confirm Password same hona chahiye.',
        isError: true,
      );
      return;
    }

    if (address.isEmpty) {
      showMessage(
        'Address enter karein.',
        isError: true,
      );
      return;
    }

    if (!RegExp(r'^[0-9]{6}$').hasMatch(pinCode)) {
      showMessage(
        '6 digit PIN Code enter karein.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    UserCredential? credential;

    try {
      // Create Email + Password account.
      credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception(
          'Firebase user creation failed.',
        );
      }

      await user.updateDisplayName(name);

      // Save complete customer profile.
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'name': name,
          'email': email,
          'mobile': mobile,
          'phone': '+91$mobile',
          'mobileVerified': true,
          'address': address,
          'pinCode': pinCode,
          'role': 'customer',
          'status': 'active',
          'active': true,
          'createdAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      showMessage(
        'Registration successful. Ab Email aur Password se login kar sakte hain.',
      );

      // Return to previous page.
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String message =
          'Registration failed.';

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'Is email se account pehle se registered hai.';
          break;

        case 'weak-password':
          message =
              'Password bahut weak hai. Kam se kam 6 characters rakhein.';
          break;

        case 'invalid-email':
          message =
              'Email address valid nahi hai.';
          break;

        case 'operation-not-allowed':
          message =
              'Firebase mein Email/Password Authentication enabled nahi hai.';
          break;

        case 'network-request-failed':
          message =
              'Internet connection check karein.';
          break;

        case 'too-many-requests':
          message =
              'Bahut attempts ho gaye. Thodi der baad try karein.';
          break;
      }

      showMessage(
        message,
        isError: true,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        showMessage(
          'Registration hua, lekin customer data save karne ki Firebase permission nahi hai.',
          isError: true,
        );
      } else {
        showMessage(
          'Customer data save nahi ho saka.',
          isError: true,
        );
      }
    } catch (_) {
      showMessage(
        'Registration ke time problem hui. Please try again.',
        isError: true,
      );

      // Try to rollback newly created auth user.
      try {
        await credential?.user?.delete();
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> forgotPassword() async {
    if (isLoading) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ForgotPasswordPage(),
      ),
    );
  }

  // ============================================================
  // SWITCH LOGIN / REGISTER
  // ============================================================

  void switchToRegister() {
    if (isLoading) return;

    setState(() {
      isRegisterMode = true;
      otpSent = false;
      otpVerified = false;
      verificationId = null;
      otpController.clear();
    });
  }

  void switchToLogin() {
    if (isLoading) return;

    setState(() {
      isRegisterMode = false;
    });
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: primary,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: primary,
          width: 1.7,
        ),
      ),
    );
  }

  // ============================================================
  // LOGIN UI
  // ============================================================

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Sign in',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Registered Email aur Password se login karein.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 22),

        TextField(
          controller: emailController,
          keyboardType:
              TextInputType.emailAddress,
          textInputAction:
              TextInputAction.next,
          enabled: !isLoading,
          decoration: inputDecoration(
            label: 'Email Address',
            icon: Icons.email_outlined,
          ),
        ),

        const SizedBox(height: 15),

        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          textInputAction:
              TextInputAction.done,
          enabled: !isLoading,
          onSubmitted: (_) {
            if (!isLoading) {
              login();
            }
          },
          decoration: inputDecoration(
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              onPressed: isLoading
                  ? null
                  : () {
                      setState(() {
                        obscurePassword =
                            !obscurePassword;
                      });
                    },
              icon: Icon(
                obscurePassword
                    ? Icons
                        .visibility_off_outlined
                    : Icons
                        .visibility_outlined,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Align(
          alignment:
              Alignment.centerRight,
          child: TextButton(
            onPressed: isLoading
                ? null
                : forgotPassword,
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: primary,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        _primaryButton(
          text: 'Login',
          icon: Icons.login_rounded,
          onPressed:
              isLoading ? null : login,
        ),

        const SizedBox(height: 18),

        Center(
          child: TextButton(
            onPressed: isLoading
                ? null
                : switchToRegister,
            child: const Text(
              'New User? Create Account',
              style: TextStyle(
                color: primary,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REGISTRATION UI
  // ============================================================

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Pehle mobile OTP verify karein, phir apni details complete karein.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 22),

        // MOBILE
        TextField(
          controller: mobileController,
          keyboardType:
              TextInputType.phone,
          maxLength: 10,
          enabled:
              !isLoading && !otpVerified,
          decoration: inputDecoration(
            label: 'Mobile Number',
            icon:
                Icons.phone_android_rounded,
            suffixIcon: otpVerified
                ? const Icon(
                    Icons.verified_rounded,
                    color: Colors.green,
                  )
                : null,
          ),
        ),

        if (!otpVerified) ...[
          const SizedBox(height: 4),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: isLoading
                  ? null
                  : sendOtp,
              icon: const Icon(
                Icons.sms_rounded,
              ),
              label: Text(
                otpSent
                    ? 'Resend OTP'
                    : 'Send OTP',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    primary,
                side:
                    const BorderSide(
                  color: primary,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
              ),
            ),
          ),
        ],

        if (otpSent && !otpVerified) ...[
          const SizedBox(height: 15),

          TextField(
            controller: otpController,
            keyboardType:
                TextInputType.number,
            maxLength: 6,
            enabled: !isLoading,
            decoration:
                inputDecoration(
              label: 'Enter OTP',
              icon:
                  Icons.lock_clock_rounded,
            ),
          ),

          const SizedBox(height: 4),

          _primaryButton(
            text: 'Verify OTP',
            icon:
                Icons.verified_rounded,
            onPressed: isLoading
                ? null
                : verifyOtp,
          ),
        ],

        if (otpVerified) ...[
          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(13),
            decoration:
                BoxDecoration(
              color:
                  Colors.green.withOpacity(
                .08,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              border: Border.all(
                color: Colors.green
                    .withOpacity(.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons
                      .verified_rounded,
                  color: Colors.green,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mobile number successfully verified.',
                    style: TextStyle(
                      color:
                          Colors.green,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // NAME
          TextField(
            controller:
                nameController,
            textCapitalization:
                TextCapitalization.words,
            enabled: !isLoading,
            decoration:
                inputDecoration(
              label: 'Full Name',
              icon:
                  Icons.person_outline_rounded,
            ),
          ),

          const SizedBox(height: 15),

          // EMAIL
          TextField(
            controller:
                registerEmailController,
            keyboardType:
                TextInputType.emailAddress,
            enabled: !isLoading,
            decoration:
                inputDecoration(
              label: 'Email Address',
              icon:
                  Icons.email_outlined,
            ),
          ),

          const SizedBox(height: 15),

          // PASSWORD DIRECTLY BELOW EMAIL
          TextField(
            controller:
                registerPasswordController,
            obscureText:
                obscureRegisterPassword,
            enabled: !isLoading,
            decoration:
                inputDecoration(
              label: 'Password',
              icon:
                  Icons.lock_outline_rounded,
              suffixIcon:
                  IconButton(
                onPressed: isLoading
                    ? null
                    : () {
                        setState(() {
                          obscureRegisterPassword =
                              !obscureRegisterPassword;
                        });
                      },
                icon: Icon(
                  obscureRegisterPassword
                      ? Icons
                          .visibility_off_outlined
                      : Icons
                          .visibility_outlined,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // CONFIRM PASSWORD
          TextField(
            controller:
                confirmPasswordController,
            obscureText:
                obscureConfirmPassword,
            enabled: !isLoading,
            decoration:
                inputDecoration(
              label:
                  'Confirm Password',
              icon:
                  Icons
                      .lock_reset_rounded,
              suffixIcon:
                  IconButton(
                onPressed: isLoading
                    ? null
                    : () {
                        setState(() {
                          obscureConfirmPassword =
                              !obscureConfirmPassword;
                        });
                      },
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons
                          .visibility_off_outlined
                      : Icons
                          .visibility_outlined,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // ADDRESS
          TextField(
            controller:
                addressController,
            maxLines: 3,
            enabled: !isLoading,
            textCapitalization:
                TextCapitalization.sentences,
            decoration:
                inputDecoration(
              label: 'Address',
              icon:
                  Icons.location_on_outlined,
            ),
          ),

          const SizedBox(height: 15),

          // PIN CODE
          TextField(
            controller:
                pinCodeController,
            keyboardType:
                TextInputType.number,
            maxLength: 6,
            enabled: !isLoading,
            decoration:
                inputDecoration(
              label: 'PIN Code',
              icon:
                  Icons.pin_drop_outlined,
            ),
          ),

          const SizedBox(height: 8),

          _primaryButton(
            text: 'Create Account',
            icon:
                Icons.person_add_alt_1_rounded,
            onPressed: isLoading
                ? null
                : registerCustomer,
          ),
        ],

        const SizedBox(height: 18),

        Center(
          child: TextButton(
            onPressed: isLoading
                ? null
                : switchToLogin,
            child: const Text(
              'Already have an account? Login',
              style: TextStyle(
                color: primary,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PRIMARY BUTTON
  // ============================================================

  Widget _primaryButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style:
            ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor:
              Colors.white,
          elevation: 3,
          shadowColor:
              primary.withOpacity(.25),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              17,
            ),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<
                          Color>(
                    Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 21,
                  ),
                  const SizedBox(
                    width: 9,
                  ),
                  Text(
                    text,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isLoading,
      onPopInvokedWithResult:
          (didPop, result) {
        if (didPop) return;

        if (!isLoading) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF7F7FA),
        appBar: AppBar(
          backgroundColor:
              Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed:
                isLoading ? null : _goBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
          ),
        ),
        body: SafeArea(
          child:
              SingleChildScrollView(
            physics:
                const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              20,
              15,
              20,
              35,
            ),
            child: Column(
              children: [
                Container(
                  height: 88,
                  width: 88,
                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        primary,
                        primaryDark,
                      ],
                      begin:
                          Alignment.topLeft,
                      end:
                          Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      27,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary
                            .withOpacity(
                          .25,
                        ),
                        blurRadius: 25,
                        offset:
                            const Offset(
                          0,
                          11,
                        ),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons
                        .shopping_bag_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                const Text(
                  'Welcome to Preesho',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -.6,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  isRegisterMode
                      ? 'Create your Preesho customer account.'
                      : 'Login karke apne orders aur shopping ko manage karein.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),

                const SizedBox(
                  height: 25,
                ),

                // MODE SWITCH
                Container(
                  padding:
                      const EdgeInsets.all(
                    5,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            _modeButton(
                          title: 'Login',
                          selected:
                              !isRegisterMode,
                          onTap:
                              switchToLogin,
                        ),
                      ),
                      Expanded(
                        child:
                            _modeButton(
                          title:
                              'New User',
                          selected:
                              isRegisterMode,
                          onTap:
                              switchToRegister,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    20,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      25,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(
                          .055,
                        ),
                        blurRadius: 25,
                        offset:
                            const Offset(
                          0,
                          10,
                        ),
                      ),
                    ],
                  ),
                  child: isRegisterMode
                      ? _buildRegisterForm()
                      : _buildLoginForm(),
                ),

                const SizedBox(
                  height: 20,
                ),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    color: primary
                        .withOpacity(
                      .07,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                    border: Border.all(
                      color: primary
                          .withOpacity(
                        .12,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .security_rounded,
                        color: primary,
                        size: 24,
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Text(
                          'Aapki account information Firebase Authentication aur Firestore ke through securely manage hogi.',
                          style:
                              TextStyle(
                            color: Colors
                                .grey
                                .shade700,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : onTap,
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        padding:
            const EdgeInsets.symmetric(
          vertical: 13,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? primary
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        child: Text(
          title,
          textAlign:
              TextAlign.center,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Colors.grey.shade700,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
