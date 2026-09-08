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
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> handleCourierAfterLogin(User user) async {
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userSnapshot.exists) {
        return false;
      }

      final userData = userSnapshot.data() ?? {};
      final role = userData['role'];

      // Normal customer
      if (role != 'courier') {
        return false;
      }

      final courierSnapshot = await FirebaseFirestore.instance
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

      final status = courierData['status'];
      final documentsSubmitted =
          courierData['documentsSubmitted'] == true;
      final active = courierData['active'] == true;
      final approvedByAdmin =
          courierData['approvedByAdmin'] == true;

      // Registration hui thi, lekin documents complete nahi hue.
      if (status == 'pending_documents' ||
          !documentsSubmitted) {
        showMessage(
          'Documents complete karke approval ke liye submit karein.',
        );

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

      // Documents submit ho chuke hain, Admin approval pending hai.
      if (status == 'pending_approval') {
        showMessage(
          'Documents submit ho chuke hain. Admin approval ka wait karein.',
        );

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

      // Admin ne reject kiya hai.
      if (status == 'rejected') {
        showMessage(
          'Documents reject hue hain. Documents check/update karein.',
        );

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

      // Sirf fully approved + active courier ko normal login continue karne dein.
      if (status == 'approved' &&
          active &&
          approvedByAdmin) {
        return false;
      }

      // Kisi bhi unexpected/inactive condition mein Courier Panel na khule.
      showMessage(
        'Courier account abhi active/approved nahi hai.',
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Courier login check error: $e');
      }

      showMessage(
        'Courier account verify nahi ho paya. Please try again.',
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
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final snapshot = await userRef.get();

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

      final handled = await handleCourierAfterLogin(user);

      if (handled) {
        return;
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';

      if (e.code == 'user-not-found') {
        message = 'User account nahi mila.';
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Email ya password galat hai.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (e.code == 'user-disabled') {
        message = 'Ye account disabled hai.';
      } else if (e.code == 'too-many-requests') {
        message = 'Bahut attempts ho gaye. Thodi der baad try karein.';
      }

      showMessage(message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Email login error: $e');
      }

      showMessage('Something went wrong. Please try again.');
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
      showMessage('10 digit mobile number enter karein.');
      return;
    }

    // Development/Test OTP
    if (mobile == '9111111111') {
      setState(() {
        otpSent = true;
      });

      showMessage('Test OTP: 911111');
      return;
    }

    if (mobile == '9666666666') {
      setState(() {
        otpSent = true;
      });

      showMessage('Test OTP: 966666');
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
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }

          showMessage(
            e.message ?? 'OTP send nahi ho paya.',
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            otpSent = true;
            isLoading = false;
          });

          showMessage('OTP send ho gaya.');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      showMessage('OTP send nahi ho paya.');
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
      showMessage('Test OTP sirf test mobile numbers ke liye hai.');
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
        showMessage('Login failed.');
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

      showMessage(
        'OTP login failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> saveMobileAndFinish(
    String mobile, {
    User? existingUser,
  }) async {
    final user = existingUser ?? FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('User login nahi hua.');
      return;
    }

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final snapshot = await userRef.get();

      // IMPORTANT:
      // Existing courier/vendor/customer ka role/status overwrite nahi karna.
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
        await userRef.set({
          'uid': user.uid,
          'phone': mobile,
          'email': user.email ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
          'loginType': 'mobile',
        }, SetOptions(merge: true));
      }

      final handled = await handleCourierAfterLogin(user);

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

  Future<void> loginWithOtp() async {
    final mobile = mobileController.text.trim();

    if (mobile == '9111111111' ||
        mobile == '9666666666') {
      await verifyTestOtp();
      return;
    }

    showMessage(
      'OTP verification ke liye OTP enter karein.',
    );
  }

  void openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordPage(),
      ),
    );
  }

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      isLoading ? null : openForgotPassword,
                  child: const Text(
                    'Forgot Password?',
                  ),
                ),
              ),

              const SizedBox(height: 5),

              ElevatedButton(
                onPressed:
                    isLoading ? null : loginWithEmail,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Login with Email'),
              ),

              const SizedBox(height: 25),

              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 25),

              TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
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
                  keyboardType: TextInputType.number,
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
                      : const Text('Verify OTP'),
                ),
              ],

              const SizedBox(height: 25),

              const Text(
                'Test Courier: 9111111111 / OTP 911111',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Test Vendor: 9666666666 / OTP 966666',
                textAlign: TextAlign.center,
                style: TextStyle(
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
