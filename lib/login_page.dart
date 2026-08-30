import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

// ============================================================
// PASSWORD LOGIN
// ============================================================

Future<void> loginWithPassword() async {
final email = emailController.text.trim();
final password = passwordController.text;

if (email.isEmpty || password.isEmpty) {
  showMessage('Please enter email and password');
  return;
}

setState(() => loading = true);

try {
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email,
    password: password,
  );

  if (!mounted) return;

  showMessage('Login successful');
  Navigator.pop(context, true);
} on FirebaseAuthException catch (e) {
  String message = 'Login failed';

  if (e.code == 'user-not-found') {
    message = 'No account found with this email.';
  } else if (e.code == 'wrong-password' ||
      e.code == 'invalid-credential') {
    message = 'Incorrect email or password.';
  } else if (e.code == 'invalid-email') {
    message = 'Invalid email address.';
  } else if (e.code == 'too-many-requests') {
    message = 'Too many attempts. Try again later.';
  } else if (e.message != null && e.message!.isNotEmpty) {
    message = e.message!;
  }

  showMessage(message);
} catch (_) {
  showMessage('Something went wrong. Please try again.');
} finally {
  if (mounted) {
    setState(() => loading = false);
  }
}

}

// ============================================================
// SEND MOBILE OTP
// ============================================================

Future<void> sendMobileOtp() async {
final mobile = mobileController.text.trim();

if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
  showMessage('Please enter a valid 10 digit mobile number');
  return;
}

final phoneNumber = '+91$mobile';

setState(() => loading = true);

try {
  await FirebaseAuth.instance.verifyPhoneNumber(
    phoneNumber: phoneNumber,

    verificationCompleted:
        (PhoneAuthCredential credential) async {
      try {
        await FirebaseAuth.instance.signInWithCredential(
          credential,
        );

        await saveMobileAndFinish(mobile);
      } catch (e) {
        if (mounted) {
          showMessage(
            'Automatic verification failed:\n$e',
          );
        }
      }
    },

    // ========================================================
    // VERIFICATION FAILED
    // SHOW EXACT FIREBASE ERROR FOR DIAGNOSIS
    // ========================================================

    verificationFailed: (FirebaseAuthException e) {
      if (mounted) {
        setState(() => loading = false);

        showMessage(
          'ERROR CODE: ${e.code}\n\n'
          'ERROR MESSAGE: ${e.message ?? "No message"}',
        );
      }
    },

    // ========================================================
    // OTP SENT
    // ========================================================

    codeSent: (String id, int? resendToken) {
      if (!mounted) return;

      verificationId = id;

      setState(() {
        loading = false;
        otpMode = true;
      });

      showMessage('OTP sent successfully');
    },

    // ========================================================
    // AUTO RETRIEVAL TIMEOUT
    // ========================================================

    codeAutoRetrievalTimeout: (String id) {
      verificationId = id;

      if (mounted) {
        setState(() => loading = false);
      }
    },
  );
} on FirebaseAuthException catch (e) {
  if (mounted) {
    setState(() => loading = false);

    showMessage(
      'ERROR CODE: ${e.code}\n\n'
      'ERROR MESSAGE: ${e.message ?? "No message"}',
    );
  }
} catch (e) {
  if (mounted) {
    setState(() => loading = false);

    showMessage(
      'UNEXPECTED ERROR:\n$e',
    );
  }
}

}

// ============================================================
// VERIFY OTP
// ============================================================

Future<void> verifyMobileOtp() async {
final otp = otpController.text.trim();

if (otp.length != 6) {
  showMessage('Please enter the 6 digit OTP');
  return;
}

if (verificationId == null) {
  showMessage('Please request OTP again');
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

  final mobile = mobileController.text.trim();

  await saveMobileAndFinish(mobile);
} on FirebaseAuthException catch (e) {
  String message = 'Invalid OTP';

  if (e.code == 'invalid-verification-code') {
    message = 'Incorrect OTP. Please try again.';
  } else if (e.code == 'session-expired') {
    message = 'OTP expired. Please request a new OTP.';
  } else if (e.message != null && e.message!.isNotEmpty) {
    message = e.message!;
  }

  if (mounted) {
    setState(() => loading = false);
    showMessage(message);
  }
} catch (e) {
  if (mounted) {
    setState(() => loading = false);
    showMessage('OTP verification failed:\n$e');
  }
}

}

// ============================================================
// SAVE USER MOBILE + FINISH LOGIN
// ============================================================

Future<void> saveMobileAndFinish(String mobile) async {
final user = FirebaseAuth.instance.currentUser;

if (user == null) {
  throw Exception('Firebase user not found');
}

await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .set(
  {
    'uid': user.uid,
    'mobile': mobile,
    'countryCode': '+91',
    'phoneNumber': '+91$mobile',
    'loginType': 'phone',
    'onboardingCompleted': false,
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
  },
  SetOptions(merge: true),
);

if (!mounted) return;

setState(() => loading = false);

showMessage('Login successful');

Navigator.pop(context, true);

}

// ============================================================
// MESSAGE
// ============================================================

void showMessage(String message) {
if (!mounted) return;

ScaffoldMessenger.of(context).hideCurrentSnackBar();

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 8),
  ),
);

}

// ============================================================
// DISPOSE
// ============================================================

@override
void dispose() {
emailController.dispose();
passwordController.dispose();
mobileController.dispose();
otpController.dispose();

super.dispose();

}

// ============================================================
// UI
// ============================================================

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: Text(
mobileMode ? 'Login with Mobile' : 'Login',
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),
),
body: SafeArea(
child: Center(
child: SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
Icon(
mobileMode
? Icons.phone_android
: Icons.shopping_bag_outlined,
size: 80,
),

            const SizedBox(height: 20),

            Text(
              otpMode
                  ? 'Verify Mobile Number'
                  : mobileMode
                      ? 'Login with Mobile'
                      : 'Welcome back!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              otpMode
                  ? 'Enter the 6 digit OTP'
                  : mobileMode
                      ? 'Enter your mobile number'
                      : 'Login to continue shopping',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 30),

            // PASSWORD LOGIN
            if (!mobileMode) ...[
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!loading) {
                    loginWithPassword();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
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
                  child: const Text('Forgot Password?'),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: loading ? null : loginWithPassword,
                  icon: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    loading ? 'Logging in...' : 'Login',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () {
                        setState(() {
                          mobileMode = true;
                          otpMode = false;
                        });
                      },
                icon: const Icon(Icons.phone_android),
                label: const Text('Login with Mobile'),
              ),
            ],

            // MOBILE NUMBER
            if (mobileMode && !otpMode) ...[
              TextFormField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: const Icon(Icons.phone),
                  prefixText: '+91 ',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: loading ? null : sendMobileOtp,
                  icon: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.sms_outlined),
                  label: Text(
                    loading ? 'Sending OTP...' : 'Send OTP',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () {
                        setState(() {
                          mobileMode = false;
                          otpMode = false;
                          mobileController.clear();
                        });
                      },
                icon: const Icon(Icons.password),
                label: const Text('Login with Password'),
              ),
            ],

            // OTP SCREEN
            if (mobileMode && otpMode) ...[
              Text(
                '+91 ${mobileController.text}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Enter OTP',
                  prefixIcon: const Icon(Icons.lock_outline),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: loading ? null : verifyMobileOtp,
                  icon: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.verified),
                  label: Text(
                    loading ? 'Verifying...' : 'Verify OTP',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: loading
                    ? null
                    : () {
                        setState(() {
                          otpMode = false;
                          otpController.clear();
                          verificationId = null;
                        });
                      },
                child: const Text('Change Mobile Number'),
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade100,
                ),
                child: const Text(
                  'TEST LOGIN\n\n'
                  'Firebase test number:\n'
                  '+91 97859 47493\n\n'
                  'Test OTP:\n'
                  '654321',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            Text(
              mobileMode
                  ? 'Mobile login is secured by Firebase Phone Authentication.'
                  : 'Use your email and password to login securely.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

}
}
