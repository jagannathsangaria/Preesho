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
  final TextEditingController loginEmailController =
      TextEditingController();
  final TextEditingController loginPasswordController =
      TextEditingController();

  // Registration controllers
  final TextEditingController mobileController =
      TextEditingController();
  final TextEditingController otpController =
      TextEditingController();
  final TextEditingController nameController =
      TextEditingController();
  final TextEditingController registerEmailController =
      TextEditingController();
  final TextEditingController registerPasswordController =
      TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController addressController =
      TextEditingController();
  final TextEditingController pinCodeController =
      TextEditingController();

  bool isLogin = true;
  bool otpSent = false;
  bool otpVerified = false;
  bool isLoading = false;

  bool obscureLoginPassword = true;
  bool obscureRegisterPassword = true;
  bool obscureConfirmPassword = true;

  String? verificationId;
  int? resendToken;

  @override
  void dispose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();

    mobileController.dispose();
    otpController.dispose();
    nameController.dispose();
    registerEmailController.dispose();
    registerPasswordController.dispose();
    confirmPasswordController.dispose();
    addressController.dispose();
    pinCodeController.dispose();

    super.dispose();
  }

  // ============================================================
  // COMMON MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> login() async {
    final email = loginEmailController.text.trim();
    final password = loginPasswordController.text;

    if (email.isEmpty) {
      _showMessage("Please enter your email.", error: true);
      return;
    }

    if (password.isEmpty) {
      _showMessage("Please enter your password.", error: true);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;

      if (user == null) {
        _showMessage(
          "Login failed. Please try again.",
          error: true,
        );
        return;
      }

      await _handleUserLogin(user);

    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message = "Invalid email address.";
          break;

        case 'user-not-found':
          message = "No account found with this email.";
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message = "Incorrect email or password.";
          break;

        case 'user-disabled':
          message = "This account has been disabled.";
          break;

        case 'too-many-requests':
          message =
              "Too many attempts. Please try again later.";
          break;

        default:
          message =
              e.message ?? "Login failed. Please try again.";
      }

      _showMessage(message, error: true);

    } catch (e) {
      _showMessage(
        "Something went wrong. Please try again.",
        error: true,
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
  // HANDLE USER LOGIN / COURIER LOGIN
  // ============================================================

  Future<void> _handleUserLogin(User user) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      String? role;

      if (userDoc.exists) {
        final data = userDoc.data();

        if (data != null) {
          role = data['role']?.toString().toLowerCase();
        }
      }

      // --------------------------------------------------------
      // COURIER
      // --------------------------------------------------------

      if (role == 'courier') {
        await _handleCourierLogin(user.uid);
        return;
      }

      // --------------------------------------------------------
      // CUSTOMER
      // --------------------------------------------------------

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/',
      );

    } catch (e) {
      _showMessage(
        "Unable to load account details.",
        error: true,
      );
    }
  }

  // ============================================================
  // COURIER LOGIN
  // ============================================================

  Future<void> _handleCourierLogin(String uid) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> courierDoc =
          await _firestore
              .collection('couriers')
              .doc(uid)
              .get();

      Map<String, dynamic>? data;

      if (courierDoc.exists) {
        data = courierDoc.data();
      }

      // Fallback to users collection
      if (data == null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          data = userDoc.data();
        }
      }

      final String status =
          (data?['status'] ??
                  data?['approvalStatus'] ??
                  data?['registrationStatus'] ??
                  '')
              .toString()
              .toLowerCase()
              .trim();

      if (!mounted) return;

      // Approved courier
      if (status == 'approved' ||
          status == 'active' ||
          status == 'verified') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const CourierPanel(),
          ),
        );
        return;
      }

      // Pending documents / approval
      if (status == 'pending_documents' ||
          status == 'pending-approval' ||
          status == 'pending_approval' ||
          status == 'pending' ||
          status.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const CourierDocumentsPage(),
          ),
        );
        return;
      }

      // Rejected
      if (status == 'rejected') {
        _showMessage(
          "Your courier application has been rejected.",
          error: true,
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CourierDocumentsPage(),
        ),
      );

    } catch (e) {
      _showMessage(
        "Unable to load courier account.",
        error: true,
      );
    }
  }

  // ============================================================
  // SEND OTP
  // ============================================================

  Future<void> sendOtp({bool resend = false}) async {
    final mobile =
        mobileController.text.trim().replaceAll(' ', '');

    if (mobile.length != 10) {
      _showMessage(
        "Please enter a valid 10-digit mobile number.",
        error: true,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final String phoneNumber = '+91$mobile';

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,

        timeout: const Duration(seconds: 60),

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          // Android automatic verification.
          try {
            await _completePhoneVerification(credential);
          } catch (_) {}
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() {
            isLoading = false;
          });

          String message;

          switch (e.code) {
            case 'invalid-phone-number':
              message =
                  "Invalid mobile number.";
              break;

            case 'too-many-requests':
              message =
                  "Too many OTP requests. Please try later.";
              break;

            case 'quota-exceeded':
              message =
                  "Firebase SMS quota exceeded.";
              break;

            case 'app-not-authorized':
              message =
                  "This app is not authorized for Firebase Phone Authentication.";
              break;

            default:
              message =
                  e.message ??
                      "OTP could not be sent.";
          }

          _showMessage(
            message,
            error: true,
          );
        },

        codeSent:
            (String verificationIdValue,
                int? resendTokenValue) {
          if (!mounted) return;

          setState(() {
            verificationId =
                verificationIdValue;

            resendToken =
                resendTokenValue;

            otpSent = true;
            otpVerified = false;
            isLoading = false;
          });

          _showMessage(
            resend
                ? "OTP resent successfully."
                : "OTP sent to your mobile number.",
          );
        },

        codeAutoRetrievalTimeout:
            (String verificationIdValue) {
          verificationId =
              verificationIdValue;

          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
        },

        forceResendingToken:
            resend ? resendToken : null,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      _showMessage(
        "Unable to send OTP. Please try again.",
        error: true,
      );
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (verificationId == null) {
      _showMessage(
        "Please request OTP first.",
        error: true,
      );
      return;
    }

    if (otp.length != 6) {
      _showMessage(
        "Please enter the 6-digit OTP.",
        error: true,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final PhoneAuthCredential credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otp,
      );

      await _completePhoneVerification(
        credential,
      );

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      String message;

      switch (e.code) {
        case 'invalid-verification-code':
          message =
              "Incorrect OTP. Please check and try again.";
          break;

        case 'session-expired':
          message =
              "OTP expired. Please request a new OTP.";
          break;

        case 'credential-already-in-use':
          message =
              "This mobile number is already registered.";
          break;

        default:
          message =
              e.message ??
                  "OTP verification failed.";
      }

      _showMessage(
        message,
        error: true,
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      _showMessage(
        "OTP verification failed.",
        error: true,
      );
    }
  }

  // ============================================================
  // COMPLETE PHONE VERIFICATION
  // ============================================================

  Future<void> _completePhoneVerification(
    PhoneAuthCredential credential,
  ) async {
    try {
      UserCredential result;

      final currentUser = _auth.currentUser;

      // If no user exists, sign in using phone.
      if (currentUser == null) {
        result = await _auth.signInWithCredential(
          credential,
        );
      } else {
        // If user already exists, link phone.
        result = await currentUser.linkWithCredential(
          credential,
        );
      }

      final user = result.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'phone-user-null',
          message: 'Phone verification failed.',
        );
      }

      if (!mounted) return;

      setState(() {
        otpVerified = true;
        isLoading = false;
      });

      _showMessage(
        "Mobile number verified successfully.",
      );

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      if (e.code == 'provider-already-linked') {
        setState(() {
          otpVerified = true;
        });

        _showMessage(
          "Mobile number is already verified.",
        );
        return;
      }

      if (e.code == 'credential-already-in-use') {
        _showMessage(
          "This mobile number is already registered with another account.",
          error: true,
        );
        return;
      }

      rethrow;
    }
  }

  // ============================================================
  // REGISTER CUSTOMER
  // ============================================================

  Future<void> registerCustomer() async {
    if (!otpVerified) {
      _showMessage(
        "Please verify your mobile number with OTP first.",
        error: true,
      );
      return;
    }

    final name = nameController.text.trim();
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
      _showMessage(
        "Please enter your name.",
        error: true,
      );
      return;
    }

    if (email.isEmpty) {
      _showMessage(
        "Please enter your email.",
        error: true,
      );
      return;
    }

    if (!email.contains('@')) {
      _showMessage(
        "Please enter a valid email.",
        error: true,
      );
      return;
    }

    if (password.length < 6) {
      _showMessage(
        "Password must be at least 6 characters.",
        error: true,
      );
      return;
    }

    if (password != confirmPassword) {
      _showMessage(
        "Passwords do not match.",
        error: true,
      );
      return;
    }

    if (address.isEmpty) {
      _showMessage(
        "Please enter your address.",
        error: true,
      );
      return;
    }

    if (pinCode.length != 6) {
      _showMessage(
        "Please enter a valid 6-digit PIN code.",
        error: true,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      User? user = _auth.currentUser;

      // --------------------------------------------------------
      // SAFETY CHECK
      // --------------------------------------------------------

      if (user == null) {
        throw FirebaseAuthException(
          code: 'phone-session-missing',
          message:
              'Phone verification session is missing.',
        );
      }

      // --------------------------------------------------------
      // LINK EMAIL + PASSWORD TO SAME PHONE USER
      // --------------------------------------------------------

      final emailCredential =
          EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      UserCredential linkedCredential;

      try {
        linkedCredential =
            await user.linkWithCredential(
          emailCredential,
        );
      } on FirebaseAuthException catch (e) {
        // If email provider is already linked,
        // continue only if it is the current user.
        if (e.code ==
            'provider-already-linked') {
          try {
  final linkedCredential = await user.linkWithCredential(
    emailCredential,
  );

  user = linkedCredential.user ?? user;
} on FirebaseAuthException catch (e) {
  if (e.code == 'provider-already-linked') {
    await user.reload();
    user = _auth.currentUser ?? user;
  } else {
    rethrow;
  }
}
        } else {
          rethrow;
        }
      }

      user = linkedCredential.user ??
          _auth.currentUser;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message:
              'Unable to create account.',
        );
      }

      // --------------------------------------------------------
      // UPDATE DISPLAY NAME
      // --------------------------------------------------------

      await user.updateDisplayName(name);

      // --------------------------------------------------------
      // FIRESTORE CUSTOMER DATA
      // --------------------------------------------------------

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

          'registrationComplete': true,

          'createdAt':
              FieldValue.serverTimestamp(),

          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      _showMessage(
        "Account created successfully.",
      );

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/',
      );

    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
              "This email is already registered.";
          break;

        case 'invalid-email':
          message =
              "Please enter a valid email.";
          break;

        case 'weak-password':
          message =
              "Password is too weak.";
          break;

        case 'provider-already-linked':
          message =
              "Email/password is already linked.";
          break;

        case 'credential-already-in-use':
          message =
              "This email is already connected to another account.";
          break;

        default:
          message =
              e.message ??
                  "Registration failed.";
      }

      _showMessage(
        message,
        error: true,
      );

    } catch (e) {
      _showMessage(
        "Registration failed. Please try again.",
        error: true,
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
  // FORGOT PASSWORD
  // ============================================================

  void forgotPassword() {
    Navigator.push(
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

  void switchMode(bool loginMode) {
    setState(() {
      isLogin = loginMode;

      otpSent = false;
      otpVerified = false;
      verificationId = null;
      otpController.clear();
    });
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          "Preesho",
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
                CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 15),

              const Text(
                "Welcome to Preesho",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                isLogin
                    ? "Login to continue shopping"
                    : "Create your Preesho account",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // LOGIN / REGISTER SWITCH
              // ==================================================

              Container(
                padding:
                    const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _modeButton(
                        title: "Login",
                        selected: isLogin,
                        onTap: () =>
                            switchMode(true),
                      ),
                    ),
                    Expanded(
                      child: _modeButton(
                        title: "New User",
                        selected: !isLogin,
                        onTap: () =>
                            switchMode(false),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // LOGIN
              // ==================================================

              if (isLogin)
                _buildLoginForm(),

              // ==================================================
              // REGISTER
              // ==================================================

              if (!isLogin)
                _buildRegisterForm(),

              const SizedBox(height: 25),

              Center(
                child: Text(
                  "© Preesho",
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGIN FORM
  // ============================================================

  Widget _buildLoginForm() {
    return Column(
      children: [

        _textField(
          controller: loginEmailController,
          label: "Email",
          hint: "Enter registered email",
          icon: Icons.email_outlined,
          keyboardType:
              TextInputType.emailAddress,
        ),

        const SizedBox(height: 16),

        _textField(
          controller: loginPasswordController,
          label: "Password",
          hint: "Enter password",
          icon: Icons.lock_outline,
          obscureText: obscureLoginPassword,
          suffixIcon: IconButton(
            icon: Icon(
              obscureLoginPassword
                  ? Icons.visibility_outlined
                  : Icons
                      .visibility_off_outlined,
            ),
            onPressed: () {
              setState(() {
                obscureLoginPassword =
                    !obscureLoginPassword;
              });
            },
          ),
        ),

        const SizedBox(height: 10),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: forgotPassword,
            child: const Text(
              "Forgot Password?",
            ),
          ),
        ),

        const SizedBox(height: 10),

        _primaryButton(
          title: "Login",
          onPressed: isLoading
              ? null
              : login,
        ),
      ],
    );
  }

  // ============================================================
  // REGISTER FORM
  // ============================================================

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [

        // ------------------------------------------------------
        // MOBILE
        // ------------------------------------------------------

        _textField(
          controller: mobileController,
          label: "Mobile Number",
          hint: "10-digit mobile number",
          icon: Icons.phone_outlined,
          keyboardType:
              TextInputType.phone,
          enabled: !otpVerified,
          maxLength: 10,
        ),

        const SizedBox(height: 12),

        if (!otpVerified)
          _primaryButton(
            title: otpSent
                ? "Resend OTP"
                : "Send OTP",
            onPressed: isLoading
                ? null
                : () => sendOtp(
                      resend: otpSent,
                    ),
          ),

        // ------------------------------------------------------
        // OTP
        // ------------------------------------------------------

        if (otpSent && !otpVerified) ...[
          const SizedBox(height: 16),

          _textField(
            controller: otpController,
            label: "OTP",
            hint: "Enter 6-digit OTP",
            icon: Icons.sms_outlined,
            keyboardType:
                TextInputType.number,
            maxLength: 6,
          ),

          const SizedBox(height: 12),

          _primaryButton(
            title: "Verify OTP",
            onPressed: isLoading
                ? null
                : verifyOtp,
          ),
        ],

        // ------------------------------------------------------
        // VERIFIED
        // ------------------------------------------------------

        if (otpVerified) ...[
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green
                  .withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green
                    .withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified,
                  color: Colors.green,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Mobile number verified successfully",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ----------------------------------------------------
          // NAME
          // ----------------------------------------------------

          _textField(
            controller: nameController,
            label: "Name",
            hint: "Enter your full name",
            icon: Icons.person_outline,
          ),

          const SizedBox(height: 16),

          // ----------------------------------------------------
          // EMAIL
          // ----------------------------------------------------

          _textField(
            controller:
                registerEmailController,
            label: "Email ID",
            hint: "Enter email address",
            icon: Icons.email_outlined,
            keyboardType:
                TextInputType.emailAddress,
          ),

          const SizedBox(height: 16),

          // ----------------------------------------------------
          // PASSWORD DIRECTLY BELOW EMAIL
          // ----------------------------------------------------

          _textField(
            controller:
                registerPasswordController,
            label: "Password",
            hint: "Create password",
            icon: Icons.lock_outline,
            obscureText:
                obscureRegisterPassword,
            suffixIcon: IconButton(
              icon: Icon(
                obscureRegisterPassword
                    ? Icons
                        .visibility_outlined
                    : Icons
                        .visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  obscureRegisterPassword =
                      !obscureRegisterPassword;
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // ----------------------------------------------------
          // CONFIRM PASSWORD
          // ----------------------------------------------------

          _textField(
            controller:
                confirmPasswordController,
            label: "Confirm Password",
            hint: "Re-enter password",
            icon: Icons.lock_reset_outlined,
            obscureText:
                obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirmPassword
                    ? Icons
                        .visibility_outlined
                    : Icons
                        .visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  obscureConfirmPassword =
                      !obscureConfirmPassword;
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // ----------------------------------------------------
          // ADDRESS
          // ----------------------------------------------------

          _textField(
            controller: addressController,
            label: "Address",
            hint: "Enter complete address",
            icon: Icons.home_outlined,
            maxLines: 3,
          ),

          const SizedBox(height: 16),

          // ----------------------------------------------------
          // PIN CODE
          // ----------------------------------------------------

          _textField(
            controller: pinCodeController,
            label: "PIN Code",
            hint: "6-digit PIN code",
            icon: Icons.location_on_outlined,
            keyboardType:
                TextInputType.number,
            maxLength: 6,
          ),

          const SizedBox(height: 22),

          // ----------------------------------------------------
          // CREATE ACCOUNT
          // ----------------------------------------------------

          _primaryButton(
            title: "Create Account",
            onPressed: isLoading
                ? null
                : registerCustomer,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // MODE BUTTON
  // ============================================================

  Widget _modeButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.06),
                    blurRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.black
                  : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    bool enabled = true,
    int? maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      decoration: InputDecoration(
        counterText: "",
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled
            ? Colors.white
            : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.blue,
            width: 1.5,
          ),
        ),
        disabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PRIMARY BUTTON
  // ============================================================

  Widget _primaryButton({
    required String title,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
