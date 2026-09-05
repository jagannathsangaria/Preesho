import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  bool loading = false;
  bool obscurePassword = true;
  bool mobileMode = false;
  bool otpMode = false;

  String? verificationId;
  String? verifiedMobile;

  bool _loginCompleted = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    mobileController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Colors.red : null,
        ),
      );
  }

  String firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'invalid-verification-code':
        return 'The OTP is incorrect.';
      case 'invalid-verification-id':
        return 'OTP session expired. Please request a new OTP.';
      case 'session-expired':
        return 'OTP expired. Please request a new OTP.';
      case 'quota-exceeded':
        return 'OTP limit reached. Please try again later.';
      case 'invalid-phone-number':
        return 'Please enter a valid mobile number.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<void> loginWithEmail() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty) {
      showMessage('Please enter your email.', error: true);
      return;
    }

    if (password.isEmpty) {
      showMessage('Please enter your password.', error: true);
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await saveUserProfile(
          user,
          loginType: 'email',
        );
      }

      if (!mounted) return;

      showMessage('Login successful.');
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      showMessage(
        firebaseErrorMessage(e),
        error: true,
      );
    } catch (_) {
      showMessage(
        'Unable to login. Please try again.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> sendOtp() async {
    final mobile = mobileController.text.trim();

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      showMessage(
        'Please enter a valid 10-digit mobile number.',
        error: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      otpMode = false;
      verificationId = null;
      _loginCompleted = false;
    });

    final phoneNumber = '+91$mobile';

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,

        verificationCompleted: (PhoneAuthCredential credential) async {
          if (_loginCompleted) return;

          try {
            await FirebaseAuth.instance.signInWithCredential(
              credential,
            );

            await saveMobileAndFinish(mobile);
          } on FirebaseAuthException catch (e) {
            if (mounted) {
              showMessage(
                firebaseErrorMessage(e),
                error: true,
              );
            }
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() => loading = false);

          showMessage(
            firebaseErrorMessage(e),
            error: true,
          );

          if (kDebugMode) {
            debugPrint(
              'Firebase Phone Auth Error: ${e.code} ${e.message}',
            );
          }
        },

        codeSent: (String id, int? resendToken) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            verifiedMobile = mobile;
            otpMode = true;
            loading = false;
          });

          showMessage('OTP sent successfully.');
        },

        codeAutoRetrievalTimeout: (String id) {
          verificationId = id;
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);

        showMessage(
          'Unable to send OTP. Please try again.',
          error: true,
        );
      }
    }
  }

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (verificationId == null || verificationId!.isEmpty) {
      showMessage(
        'OTP session expired. Please request a new OTP.',
        error: true,
      );
      return;
    }

    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      showMessage(
        'Please enter the 6-digit OTP.',
        error: true,
      );
      return;
    }

    setState(() => loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otp,
      );

      await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await saveMobileAndFinish(
        verifiedMobile ?? mobileController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      showMessage(
        firebaseErrorMessage(e),
        error: true,
      );
    } catch (_) {
      showMessage(
        'OTP verification failed. Please try again.',
        error: true,
      );
    } finally {
      if (mounted && !_loginCompleted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> saveUserProfile(
    User user, {
    required String loginType,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final existing = await ref.get();

    final data = <String, dynamic>{
      'uid': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'loginType': loginType,
    };

    if (user.email != null && user.email!.isNotEmpty) {
      data['email'] = user.email;
    }

    if (user.displayName != null &&
        user.displayName!.trim().isNotEmpty) {
      data['name'] = user.displayName!.trim();
    }

    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['onboardingCompleted'] = false;
    }

    await ref.set(
      data,
      SetOptions(merge: true),
    );
  }

  Future<void> saveMobileAndFinish(String mobile) async {
    if (_loginCompleted) return;

    _loginCompleted = true;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _loginCompleted = false;
      if (mounted) {
        setState(() => loading = false);
      }
      return;
    }

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final existing = await ref.get();

      final data = <String, dynamic>{
        'uid': user.uid,
        'mobile': mobile,
        'countryCode': '+91',
        'phoneNumber': '+91$mobile',
        'loginType': 'phone',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!existing.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['onboardingCompleted'] = false;
      }

      await ref.set(
        data,
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() => loading = false);

      showMessage('Login successful.');

      await Future.delayed(
        const Duration(milliseconds: 300),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (_) {
      _loginCompleted = false;

      if (mounted) {
        setState(() => loading = false);

        showMessage(
          'Login successful, but profile could not be saved.',
          error: true,
        );
      }
    }
  }

  void switchToPassword() {
    setState(() {
      mobileMode = false;
      otpMode = false;
      verificationId = null;
      otpController.clear();
      loading = false;
    });
  }

  void switchToMobile() {
    setState(() {
      mobileMode = true;
      otpMode = false;
      verificationId = null;
      otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          mobileMode ? 'Mobile Login' : 'Login',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              CircleAvatar(
                radius: 38,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(
                          alpha: 0.10,
                        ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Welcome to Preesho',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                mobileMode
                    ? 'Login using your mobile number'
                    : 'Login to continue shopping',
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 30),

              if (!mobileMode) ...[
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => loginWithEmail(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ForgotPasswordPage(),
                              ),
                            );
                          },
                    child: const Text(
                      'Forgot Password?',
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading
                        ? null
                        : loginWithEmail,
                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : switchToMobile,
                    icon: const Icon(
                      Icons.phone_android,
                    ),
                    label: const Text(
                      'Login with Mobile',
                    ),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  enabled: !otpMode,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '10-digit mobile number',
                    prefixText: '+91 ',
                    prefixIcon: Icon(
                      Icons.phone_android_outlined,
                    ),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 16),

                if (!otpMode)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: loading
                          ? null
                          : sendOtp,
                      icon: loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.sms_outlined,
                            ),
                      label: Text(
                        loading
                            ? 'Sending OTP...'
                            : 'Send OTP',
                      ),
                    ),
                  ),

                if (otpMode) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.green.withValues(
                        alpha: 0.08,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'OTP sent to +91 ${verifiedMobile ?? mobileController.text}',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Enter OTP',
                      hintText: '6-digit OTP',
                      prefixIcon: Icon(
                        Icons.password_outlined,
                      ),
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: loading
                          ? null
                          : verifyOtp,
                      child: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify OTP',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            setState(() {
                              otpMode = false;
                              verificationId = null;
                              otpController.clear();
                            });
                          },
                    child: const Text(
                      'Change Mobile Number',
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : switchToPassword,
                  icon: const Icon(
                    Icons.email_outlined,
                  ),
                  label: const Text(
                    'Login with Password',
                  ),
                ),

                if (kDebugMode && otpMode) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'DEBUG MODE: Firebase test phone numbers '
                      'configured in Firebase Console can be used here.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 28),

              const Text(
                'Your login is secured by Firebase Authentication.',
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
