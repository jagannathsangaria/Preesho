import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'courier_documents_page.dart';
import 'forgot_password_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  static const Color primary = Color(0xFF5B35D5);
  static const Color primaryDark = Color(0xFF4323A8);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
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
        backgroundColor: isError ? Colors.red.shade600 : null,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(
    String uid,
  ) {
    return _firestore.collection('users').doc(uid).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getCourierDoc(
    String uid,
  ) {
    return _firestore.collection('couriers').doc(uid).get();
  }

  bool isTrue(dynamic value) {
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true';
  }

  String clean(dynamic value) {
    return value?.toString().trim() ?? '';
  }

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

      final uid = user.uid;

      final userSnapshot = await getUserDoc(uid);
      final courierSnapshot = await getCourierDoc(uid);

      final userData = userSnapshot.data() ?? {};
      final courierData =
          courierSnapshot.data() ?? {};

      final role =
          clean(userData['role']).toLowerCase();

      final courierRole =
          clean(courierData['role']).toLowerCase();

      final isCourier =
          role == 'courier' ||
          courierRole == 'courier' ||
          courierSnapshot.exists;

      if (isCourier) {
        await handleCourierLogin(
          uid: uid,
          userData: userData,
          courierData: courierData,
          courierExists: courierSnapshot.exists,
        );
        return;
      }

      final isAdmin =
          role == 'admin' ||
          role == 'superadmin' ||
          role == 'administrator';

      if (!isAdmin) {
        await _auth.signOut();

        showMessage(
          'Ye account Admin/Courier login ke liye authorized nahi hai.',
          isError: true,
        );
        return;
      }

      final active =
          userData['active'] == null
              ? true
              : isTrue(userData['active']);

      if (!active) {
        await _auth.signOut();

        showMessage(
          'Admin account inactive hai.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';

      switch (e.code) {
        case 'user-not-found':
          message = 'Account nahi mila.';
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
      }

      showMessage(
        message,
        isError: true,
      );
    } catch (e) {
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

  Future<void> handleCourierLogin({
    required String uid,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> courierData,
    required bool courierExists,
  }) async {
    Map<String, dynamic> data =
        Map<String, dynamic>.from(courierData);

    if (!courierExists) {
      final name =
          clean(userData['name']).isNotEmpty
              ? clean(userData['name'])
              : clean(userData['displayName']);

      final email =
          clean(userData['email']);

      final phone =
          clean(userData['phone']).isNotEmpty
              ? clean(userData['phone'])
              : clean(userData['mobile']);

      await _firestore
          .collection('couriers')
          .doc(uid)
          .set({
        'uid': uid,
        'name': name,
        'displayName': name,
        'email': email,
        'phone': phone,
        'mobile': phone,
        'role': 'courier',
        'status': 'pending_documents',
        'registrationStatus':
            'pending_documents',
        'active': false,
        'documentsSubmitted': false,
        'approvedByAdmin': false,
        'documents': {},
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      data = {
        'uid': uid,
        'name': name,
        'displayName': name,
        'email': email,
        'phone': phone,
        'mobile': phone,
        'role': 'courier',
        'status': 'pending_documents',
        'registrationStatus':
            'pending_documents',
        'active': false,
        'documentsSubmitted': false,
        'approvedByAdmin': false,
        'documents': {},
      };
    }

    final approved =
        isTrue(data['approvedByAdmin']) ||
            clean(data['status']).toLowerCase() ==
                'approved' ||
            clean(data['registrationStatus'])
                    .toLowerCase() ==
                'approved';

    final active =
        isTrue(data['active']);

    final documentsSubmitted =
        isTrue(data['documentsSubmitted']);

    final status =
        clean(
          data['status'],
        ).toLowerCase();

    final registrationStatus =
        clean(
          data['registrationStatus'],
        ).toLowerCase();

    if (approved && active) {
      if (!mounted) return;

      showMessage(
        'Courier login successful.',
      );

      Navigator.pop(context);
      return;
    }

    // IMPORTANT:
    // Pending courier ko sign out nahi karna.
    // Direct documents page par bhejna hai.
    if (!mounted) return;

    if (!documentsSubmitted ||
        status == 'pending_documents' ||
        registrationStatus ==
            'pending_documents' ||
        !approved) {
      showMessage(
        'Documents upload karein.',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CourierDocumentsPage(
            courierUid: uid,
          ),
        ),
      );

      return;
    }

    showMessage(
      'Courier account admin approval ke liye pending hai.',
      isError: true,
    );
  }

  Future<void> forgotPassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ForgotPasswordPage(),
      ),
    );
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
        borderSide:
            const BorderSide(
          color: primary,
          width: 1.7,
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
            20,
            20,
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
                    end: Alignment
                        .bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    27,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary
                          .withOpacity(.25),
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
                      .admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Admin / Courier Login',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Authorized Preesho staff members ke liye secure login.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(20),
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
                      'Sign in',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Enter your registered credentials.',
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller:
                          emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          inputDecoration(
                        label:
                            'Email Address',
                        icon: Icons
                            .email_outlined,
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                          passwordController,
                      obscureText:
                          obscurePassword,
                      textInputAction:
                          TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isLoading) {
                          login();
                        }
                      },
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

                    const SizedBox(height: 10),

                    Align(
                      alignment:
                          Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            isLoading
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

                    SizedBox(
                      width:
                          double.infinity,
                      height: 56,
                      child:
                          ElevatedButton(
                        onPressed:
                            isLoading
                                ? null
                                : login,
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              primary,
                          foregroundColor:
                              Colors.white,
                          elevation: 3,
                          shadowColor:
                              primary.withOpacity(
                            .25,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              17,
                            ),
                          ),
                        ),
                        child: isLoading
                            ? const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  SizedBox(
                                    height: 21,
                                    width: 21,
                                    child:
                                        CircularProgressIndicator(
                                      color: Colors
                                          .white,
                                      strokeWidth:
                                          2.5,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 12,
                                  ),
                                  Text(
                                    'Signing in...',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Icon(
                                    Icons
                                        .login_rounded,
                                  ),
                                  SizedBox(
                                    width: 9,
                                  ),
                                  Text(
                                    'Secure Login',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          15,
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(15),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.blue.shade50,
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                  border: Border.all(
                    color:
                        Colors.blue.shade100,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .blue.shade100,
                        borderRadius:
                            BorderRadius
                                .circular(
                          13,
                        ),
                      ),
                      child: Icon(
                        Icons
                            .verified_user_outlined,
                        color: Colors
                            .blue.shade700,
                      ),
                    ),
                    const SizedBox(
                        width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Text(
                            'Secure Staff Access',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(
                              height: 4),
                          Text(
                            'Courier account pending hone par login ke baad documents upload page automatically open hoga.',
                            style:
                                TextStyle(
                              color: Colors
                                  .blue
                                  .shade900,
                              fontSize: 11,
                              height: 1.4,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'Preesho • Authorized Access',
                style: TextStyle(
                  color:
                      Colors.grey.shade500,
                  fontSize: 11,
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
}
