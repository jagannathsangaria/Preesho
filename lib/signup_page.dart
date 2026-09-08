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

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  String selectedRole = 'customer';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const Color primary = Color(0xFF5B35D5);
  static const Color primaryDark = Color(0xFF4323A8);

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

    if (email.isEmpty || !email.contains('@')) {
      showMessage(
        'Valid email address enter karein.',
        isError: true,
      );
      return;
    }

    if (mobile.isEmpty || mobile.length != 10) {
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
        showMessage(
          'Account create nahi ho paya.',
          isError: true,
        );
        return;
      }

      try {
        await user.updateDisplayName(name);
      } catch (_) {}

      final now = FieldValue.serverTimestamp();

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
      } else if (selectedRole == 'vendor') {
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
      } else if (selectedRole == 'courier') {
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

      if (!mounted) return;

      await _auth.signOut();

      if (!mounted) return;

      showMessage(
        selectedRole == 'customer'
            ? 'Account successfully create ho gaya.'
            : selectedRole == 'vendor'
                ? 'Vendor registration submit ho gayi. Admin approval ke baad login karein.'
                : 'Courier registration ho gayi. Login karke documents upload karein.',
      );

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed.';

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
              'Email registration Firebase mein enabled nahi hai.';
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
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color: primary,
          width: 1.7,
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
              const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 14,
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
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 43,
                width: 43,
                decoration:
                    BoxDecoration(
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
                  fontWeight:
                      FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
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

  Widget primaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
            isLoading ? null : signup,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              primary,
          foregroundColor:
              Colors.white,
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
                    height: 21,
                    width: 21,
                    child:
                        CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: 12),
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
                    Icons.person_add_alt_1_rounded,
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
            height: 42,
            width: 42,
            decoration:
                BoxDecoration(
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
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Preesho aapki details ko securely handle karta hai.',
                  style: TextStyle(
                    color:
                        Colors.green.shade800,
                    fontSize: 11,
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
          onPressed: () {
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
            5,
            18,
            35,
          ),
          child: Column(
            children: [
              Container(
                height: 78,
                width: 78,
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
                    end: Alignment
                        .bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    24,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary
                          .withOpacity(.25),
                      blurRadius: 24,
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
                  size: 40,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Create your Preesho account',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'Join Preesho aur easy shopping experience enjoy karein.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 28),

              Container(
                padding:
                    const EdgeInsets.all(18),
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
                          .withOpacity(.055),
                      blurRadius: 25,
                      offset:
                          const Offset(
                        0,
                        10,
                      ),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Account Type',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        roleCard(
                          role: 'customer',
                          title: 'Customer',
                          subtitle:
                              'Shop products',
                          icon: Icons
                              .shopping_bag_outlined,
                        ),
                        const SizedBox(width: 8),
                        roleCard(
                          role: 'vendor',
                          title: 'Vendor',
                          subtitle:
                              'Sell products',
                          icon: Icons
                              .storefront_outlined,
                        ),
                        const SizedBox(width: 8),
                        roleCard(
                          role: 'courier',
                          title: 'Courier',
                          subtitle:
                              'Deliver orders',
                          icon: Icons
                              .delivery_dining_outlined,
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    TextField(
                      controller:
                          nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          inputDecoration(
                        label: 'Full Name',
                        icon: Icons
                            .person_outline_rounded,
                      ),
                    ),

                    const SizedBox(height: 13),

                    TextField(
                      controller:
                          emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          inputDecoration(
                        label: 'Email Address',
                        icon: Icons
                            .email_outlined,
                      ),
                    ),

                    const SizedBox(height: 13),

                    TextField(
                      controller:
                          mobileController,
                      keyboardType:
                          TextInputType.phone,
                      maxLength: 10,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          inputDecoration(
                        label:
                            'Mobile Number',
                        icon: Icons
                            .phone_android_rounded,
                      ).copyWith(
                        prefixText:
                            '+91 ',
                        counterText: '',
                      ),
                    ),

                    const SizedBox(height: 13),

                    TextField(
                      controller:
                          passwordController,
                      obscureText:
                          obscurePassword,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          inputDecoration(
                        label: 'Password',
                        icon: Icons
                            .lock_outline_rounded,
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
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 13),

                    TextField(
                      controller:
                          confirmPasswordController,
                      obscureText:
                          obscureConfirmPassword,
                      textInputAction:
                          TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isLoading) {
                          signup();
                        }
                      },
                      decoration:
                          inputDecoration(
                        label:
                            'Confirm Password',
                        icon: Icons
                            .lock_reset_outlined,
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
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (selectedRole ==
                        'courier')
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          13,
                        ),
                        margin:
                            const EdgeInsets.only(
                          bottom: 14,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.blue
                              .shade50,
                          borderRadius:
                              BorderRadius.circular(
                            15,
                          ),
                          border: Border.all(
                            color: Colors.blue
                                .shade100,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Icon(
                              Icons
                                  .info_outline_rounded,
                              color: Colors.blue
                                  .shade700,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                'Courier registration ke baad login karke required documents upload karne honge.',
                                style: TextStyle(
                                  color: Colors
                                      .blue
                                      .shade900,
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (selectedRole ==
                        'vendor')
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          13,
                        ),
                        margin:
                            const EdgeInsets.only(
                          bottom: 14,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.orange
                              .shade50,
                          borderRadius:
                              BorderRadius.circular(
                            15,
                          ),
                          border: Border.all(
                            color: Colors.orange
                                .shade100,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Icon(
                              Icons
                                  .info_outline_rounded,
                              color: Colors.orange
                                  .shade800,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                'Vendor account admin verification ke baad active hoga.',
                                style: TextStyle(
                                  color: Colors
                                      .orange
                                      .shade900,
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    primaryButton(),

                    const SizedBox(height: 16),

                    Center(
                      child: Wrap(
                        alignment:
                            WrapAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(
                              color: Colors
                                  .grey
                                  .shade600,
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: isLoading
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
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              securityCard(),

              const SizedBox(height: 15),

              Text(
                'By creating an account, you agree to Preesho terms & privacy policy.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey.shade500,
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
