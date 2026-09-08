import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const Color primary = Color(0xFF5B35D5);
  static const Color primaryDark = Color(0xFF4323A8);

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  String selectedRole = 'customer';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
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
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor:
            isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  Future<void> signup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final mobile = mobileController.text.trim();
    final password = passwordController.text;
    final confirmPassword =
        confirmPasswordController.text;

    if (name.isEmpty) {
      showMessage(
        'Name enter karein.',
        isError: true,
      );
      return;
    }

    if (name.length < 2) {
      showMessage(
        'Valid name enter karein.',
        isError: true,
      );
      return;
    }

    if (email.isEmpty ||
        !RegExp(
          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
        ).hasMatch(email)) {
      showMessage(
        'Valid email address enter karein.',
        isError: true,
      );
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      showMessage(
        '10 digit mobile number enter karein.',
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
        'Password aur confirm password match nahi kar rahe.',
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
      credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception(
          'Firebase user create nahi hua.',
        );
      }

      try {
        await user.updateDisplayName(name);
      } catch (_) {}

      final now = FieldValue.serverTimestamp();

      // =====================================================
      // CUSTOMER
      // =====================================================

      if (selectedRole == 'customer') {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name,
          'displayName': name,
          'email': email,
          'phone': mobile,
          'mobile': mobile,
          'role': 'customer',
          'status': 'approved',
          'registrationStatus': 'approved',
          'active': true,
          'loginType': 'email',
          'createdAt': now,
          'updatedAt': now,
        });
      }

      // =====================================================
      // VENDOR
      // =====================================================

      else if (selectedRole == 'vendor') {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name,
          'displayName': name,
          'email': email,
          'phone': mobile,
          'mobile': mobile,
          'role': 'vendor',
          'status': 'pending',
          'registrationStatus': 'pending',
          'active': false,
          'loginType': 'email',
          'createdAt': now,
          'updatedAt': now,
        });

        await _firestore
            .collection('vendors')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name,
          'displayName': name,
          'email': email,
          'phone': mobile,
          'mobile': mobile,
          'role': 'vendor',
          'status': 'pending',
          'registrationStatus': 'pending',
          'active': false,
          'documentsSubmitted': false,
          'approvedByAdmin': false,
          'createdAt': now,
          'updatedAt': now,
        });
      }

      // =====================================================
      // COURIER
      // =====================================================

      else if (selectedRole == 'courier') {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name,
          'displayName': name,
          'email': email,
          'phone': mobile,
          'mobile': mobile,
          'role': 'courier',
          'status': 'pending_documents',
          'registrationStatus':
              'pending_documents',
          'active': false,
          'loginType': 'email',
          'documentsSubmitted': false,
          'approvedByAdmin': false,
          'createdAt': now,
          'updatedAt': now,
        });

        await _firestore
            .collection('couriers')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name,
          'displayName': name,
          'email': email,
          'phone': mobile,
          'mobile': mobile,
          'role': 'courier',
          'status': 'pending_documents',
          'registrationStatus':
              'pending_documents',
          'active': false,
          'documentsSubmitted': false,
          'approvedByAdmin': false,
          'documents': {},
          'createdAt': now,
          'updatedAt': now,
        });
      }

      // =====================================================
      // SIGN OUT AFTER REGISTRATION
      // =====================================================

      await _auth.signOut();

      if (!mounted) return;

      String successMessage;

      if (selectedRole == 'customer') {
        successMessage =
            'Account successfully create ho gaya.';
      } else if (selectedRole == 'vendor') {
        successMessage =
            'Vendor registration submit ho gayi. Admin approval ke baad login karein.';
      } else {
        successMessage =
            'Courier registration ho gayi. Login karke documents upload karein.';
      }

      showMessage(successMessage);

      await Future.delayed(
        const Duration(milliseconds: 800),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message =
          'Registration failed.';

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'Ye email already registered hai.';
          break;

        case 'invalid-email':
          message =
              'Email address valid nahi hai.';
          break;

        case 'weak-password':
          message =
              'Password bahut weak hai.';
          break;

        case 'operation-not-allowed':
          message =
              'Email/Password registration Firebase mein enabled nahi hai.';
          break;

        case 'network-request-failed':
          message =
              'Internet connection check karein.';
          break;

        case 'too-many-requests':
          message =
              'Bahut attempts ho gaye. Thodi der baad try karein.';
          break;

        default:
          if (e.message != null &&
              e.message!.trim().isNotEmpty) {
            message = e.message!;
          }
      }

      showMessage(
        message,
        isError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Signup error: $e',
        );
      }

      showMessage(
        'Account create nahi ho paya. Please try again.',
        isError: true,
      );

      // If Auth account was created but Firestore
      // registration failed, attempt cleanup.
      try {
        if (credential?.user != null) {
          await credential!.user!.delete();
        }
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

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
          width: 1.6,
        ),
      ),
    );
  }

  Widget roleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected =
        selectedRole == role;

    return Expanded(
      child: InkWell(
        borderRadius:
            BorderRadius.circular(17),
        onTap: isLoading
            ? null
            : () {
                setState(() {
                  selectedRole = role;
                });
              },
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFF0ECFF)
                : Colors.grey.shade50,
            borderRadius:
                BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? primary
                  : Colors.grey.shade200,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? primary
                      : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? Colors.white
                      : Colors.grey.shade600,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? primary
                      : Colors.black87,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLength = 0,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLength:
            maxLength > 0 ? maxLength : null,
        decoration: inputDecoration(
          label: label,
          icon: icon,
          suffixIcon: suffixIcon,
        ).copyWith(
          counterText:
              maxLength > 0 ? '' : null,
        ),
      ),
    );
  }

  Widget securityCard() {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: Colors.green.shade100,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color:
                  Colors.green.shade100,
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              Icons
                  .verified_user_outlined,
              color:
                  Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your information is secure',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Preesho aapki details ko securely handle karta hai.',
                  style: TextStyle(
                    color:
                        Colors.green.shade800,
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget createAccountButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
            isLoading ? null : signup,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor:
              primary.withOpacity(.25),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(17),
          ),
        ),
        child: isLoading
            ? const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 21,
                    height: 21,
                    child:
                        CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: 11),
                  Text(
                    'Creating Account...',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons
                        .person_add_alt_1_rounded,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: isLoading
              ? null
              : () {
                  Navigator.pop(context);
                },
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            18,
            3,
            18,
            35,
          ),
          child: Column(
            children: [
              // =================================================
              // LOGO / HEADER
              // =================================================

              Container(
                height: 76,
                width: 76,
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
                      BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primary
                          .withOpacity(.22),
                      blurRadius: 20,
                      offset:
                          const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Create your Preesho account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                'Join Preesho and enjoy a smarter shopping experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 23),

              // =================================================
              // MAIN CARD
              // =================================================

              Container(
                padding:
                    const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(.045),
                      blurRadius: 25,
                      offset:
                          const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose account type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Aap Preesho ko kis purpose ke liye use karna chahte hain?',
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        roleCard(
                          role: 'customer',
                          title: 'Customer',
                          subtitle:
                              'Shop & Order',
                          icon:
                              Icons.shopping_bag_outlined,
                        ),
                        const SizedBox(width: 8),
                        roleCard(
                          role: 'vendor',
                          title: 'Vendor',
                          subtitle:
                              'Sell Products',
                          icon:
                              Icons.storefront_outlined,
                        ),
                        const SizedBox(width: 8),
                        roleCard(
                          role: 'courier',
                          title: 'Courier',
                          subtitle:
                              'Deliver Orders',
                          icon:
                              Icons.local_shipping_outlined,
                        ),
                      ],
                    ),

                    const SizedBox(height: 21),

                    const Text(
                      'Personal Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 13),

                    textField(
                      controller:
                          nameController,
                      label: 'Full Name',
                      icon:
                          Icons.person_outline,
                      keyboardType:
                          TextInputType.name,
                    ),

                    textField(
                      controller:
                          emailController,
                      label: 'Email Address',
                      icon:
                          Icons.email_outlined,
                      keyboardType:
                          TextInputType.emailAddress,
                    ),

                    textField(
                      controller:
                          mobileController,
                      label:
                          'Mobile Number',
                      icon:
                          Icons.phone_outlined,
                      keyboardType:
                          TextInputType.phone,
                      maxLength: 10,
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Security',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 13),

                    textField(
                      controller:
                          passwordController,
                      label: 'Password',
                      icon:
                          Icons.lock_outline,
                      obscureText:
                          obscurePassword,
                      suffixIcon:
                          IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword =
                                !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),

                    textField(
                      controller:
                          confirmPasswordController,
                      label:
                          'Confirm Password',
                      icon:
                          Icons
                              .lock_reset_outlined,
                      obscureText:
                          obscureConfirmPassword,
                      suffixIcon:
                          IconButton(
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword =
                                !obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // =================================================
                    // ROLE INFO
                    // =================================================

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(13),
                      decoration:
                          BoxDecoration(
                        color: const Color(
                          0xFFF7F5FF,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                        border: Border.all(
                          color:
                              primary.withOpacity(.10),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            selectedRole ==
                                    'customer'
                                ? Icons
                                    .shopping_bag_outlined
                                : selectedRole ==
                                        'vendor'
                                    ? Icons
                                        .storefront_outlined
                                    : Icons
                                        .local_shipping_outlined,
                            color: primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedRole ==
                                      'customer'
                                  ? 'Customer account instantly active ho jayega.'
                                  : selectedRole ==
                                          'vendor'
                                      ? 'Vendor account Admin approval ke baad active hoga.'
                                      : 'Courier account mein login ke baad required documents upload karne honge.',
                              style:
                                  TextStyle(
                                color: Colors
                                    .grey.shade700,
                                fontSize: 11,
                                height: 1.4,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    createAccountButton(),

                    const SizedBox(height: 15),

                    securityCard(),
                  ],
                ),
              ),

              const SizedBox(height: 19),

              // =================================================
              // LOGIN
              // =================================================

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(
                      color:
                          Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const LoginPage(),
                              ),
                            );
                          },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: primary,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 3),

              Text(
                'By creating an account, you agree to use Preesho responsibly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
