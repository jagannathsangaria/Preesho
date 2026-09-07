import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourierRegistrationPage extends StatefulWidget {
  const CourierRegistrationPage({super.key});

  @override
  State<CourierRegistrationPage> createState() =>
      _CourierRegistrationPageState();
}

class _CourierRegistrationPageState
    extends State<CourierRegistrationPage> {
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();
  final vehicleNumberController = TextEditingController();

  String vehicleType = 'Bike';

  bool loading = false;
  bool obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> registerCourier() async {
    if (loading) return;

    final name = nameController.text.trim();
    final mobile = mobileController.text.trim();
    final password = passwordController.text.trim();
    final vehicleNumber =
        vehicleNumberController.text.trim().toUpperCase();

    // -----------------------------
    // BASIC VALIDATION
    // -----------------------------

    if (name.isEmpty) {
      _showMessage(
        'Please enter your name.',
        isError: true,
      );
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      _showMessage(
        'Please enter a valid 10-digit mobile number.',
        isError: true,
      );
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password must contain at least 6 characters.',
        isError: true,
      );
      return;
    }

    if (vehicleNumber.isEmpty) {
      _showMessage(
        'Please enter your vehicle number.',
        isError: true,
      );
      return;
    }

    setState(() {
      loading = true;
    });

    User? createdUser;

    try {
      // -----------------------------
      // CHECK DUPLICATE MOBILE
      // -----------------------------

      final existing = await _firestore
          .collection('couriers')
          .where('phone', isEqualTo: mobile)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        _showMessage(
          'This mobile number is already registered. '
          'Please use another number.',
          isError: true,
        );
        return;
      }

      // -----------------------------
      // CREATE INTERNAL EMAIL
      // -----------------------------

      final internalEmail =
          'courier_$mobile@preesho.app';

      // -----------------------------
      // CREATE FIREBASE AUTH ACCOUNT
      // -----------------------------

      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: internalEmail,
        password: password,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception(
          'User account could not be created.',
        );
      }

      final uid = createdUser.uid;

      // -----------------------------
      // CREATE USER PROFILE
      // -----------------------------

      await _firestore
          .collection('users')
          .doc(uid)
          .set({
        'uid': uid,
        'name': name,
        'phone': mobile,
        'role': 'courier',
        'active': true,
        'vehicleNumber': vehicleNumber,
        'vehicleType': vehicleType,
        'email': internalEmail,
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      // -----------------------------
      // CREATE COURIER PROFILE
      // -----------------------------

      await _firestore
          .collection('couriers')
          .doc(uid)
          .set({
        'uid': uid,
        'name': name,
        'phone': mobile,
        'role': 'courier',
        'active': true,
        'vehicleNumber': vehicleNumber,
        'vehicleType': vehicleType,
        'email': internalEmail,
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      // -----------------------------
      // SIGN OUT AFTER REGISTRATION
      // -----------------------------

      await _auth.signOut();

      if (!mounted) return;

      _showMessage(
        'Courier account created successfully. '
        'You can now login.',
        isError: false,
      );

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      Navigator.pop(context);
    }

    // -----------------------------
    // FIREBASE AUTH ERRORS
    // -----------------------------

    on FirebaseAuthException catch (e) {
      debugPrint(
        'COURIER AUTH ERROR: ${e.code} - ${e.message}',
      );

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'This mobile number is already registered. '
              'Please use another number.';
          break;

        case 'weak-password':
          message =
              'Your password is too weak. '
              'Please use a stronger password.';
          break;

        case 'invalid-email':
          message =
              'We could not process your registration. '
              'Please try again.';
          break;

        case 'operation-not-allowed':
          message =
              'Registration is temporarily unavailable. '
              'Please try again later.';
          break;

        case 'network-request-failed':
          message =
              'Unable to connect to the server. '
              'Please check your internet connection.';
          break;

        case 'too-many-requests':
          message =
              'Too many registration attempts. '
              'Please try again after some time.';
          break;

        default:
          message =
              'We could not complete your registration. '
              'Please try again.';
      }

      _showMessage(
        message,
        isError: true,
      );
    }

    // -----------------------------
    // FIRESTORE / FIREBASE ERRORS
    // -----------------------------

    on FirebaseException catch (e) {
      debugPrint(
        'COURIER FIREBASE ERROR: '
        '${e.code} - ${e.message}',
      );

      // If Auth account was created but Firestore
      // failed, remove the incomplete Auth account.
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (cleanupError) {
          debugPrint(
            'COURIER CLEANUP ERROR: $cleanupError',
          );
        }
      }

      String message;

      switch (e.code) {
        case 'permission-denied':
          message =
              'Registration is temporarily unavailable. '
              'Please try again later.';
          break;

        case 'unavailable':
          message =
              'Server is temporarily unavailable. '
              'Please try again in a few moments.';
          break;

        case 'network-request-failed':
          message =
              'Please check your internet connection '
              'and try again.';
          break;

        case 'failed-precondition':
          message =
              'Registration service is not ready yet. '
              'Please try again later.';
          break;

        default:
          message =
              'We could not complete your registration. '
              'Please try again later.';
      }

      _showMessage(
        message,
        isError: true,
      );
    }

    // -----------------------------
    // UNKNOWN ERRORS
    // -----------------------------

    catch (e) {
      debugPrint(
        'COURIER UNKNOWN ERROR: $e',
      );

      // Cleanup incomplete Auth account.
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (cleanupError) {
          debugPrint(
            'COURIER CLEANUP ERROR: $cleanupError',
          );
        }
      }

      _showMessage(
        'We could not complete your registration. '
        'Please try again later.',
        isError: true,
      );
    }

    // -----------------------------
    // STOP LOADING
    // -----------------------------

    finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // -----------------------------
  // MESSAGE
  // -----------------------------

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
        duration: Duration(
          seconds: isError ? 4 : 3,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -----------------------------
  // INPUT DECORATION
  // -----------------------------

  InputDecoration _decoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // -----------------------------
  // UI
  // -----------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Courier Registration',
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            children: [
              const Icon(
                Icons.delivery_dining,
                size: 70,
              ),

              const SizedBox(height: 10),

              const Text(
                'Create Courier Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              // NAME
              TextField(
                controller: nameController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: _decoration(
                  'Name',
                  Icons.person,
                ),
              ),

              const SizedBox(height: 15),

              // MOBILE
              TextField(
                controller: mobileController,
                keyboardType:
                    TextInputType.phone,
                maxLength: 10,
                decoration: _decoration(
                  'Mobile Number',
                  Icons.phone,
                ),
              ),

              const SizedBox(height: 5),

              // PASSWORD
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration:
                    _decoration(
                  'Password',
                  Icons.lock,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
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

              const SizedBox(height: 15),

              // VEHICLE NUMBER
              TextField(
                controller:
                    vehicleNumberController,
                textCapitalization:
                    TextCapitalization.characters,
                decoration: _decoration(
                  'Vehicle Number',
                  Icons.directions_car,
                ),
              ),

              const SizedBox(height: 15),

              // VEHICLE TYPE
              DropdownButtonFormField<String>(
                value: vehicleType,

                decoration: _decoration(
                  'Vehicle Type',
                  Icons.two_wheeler,
                ),

                items: const [
                  DropdownMenuItem(
                    value: 'Bike',
                    child: Text('Bike'),
                  ),
                  DropdownMenuItem(
                    value: 'Scooter',
                    child: Text('Scooter'),
                  ),
                  DropdownMenuItem(
                    value: 'Car',
                    child: Text('Car'),
                  ),
                  DropdownMenuItem(
                    value: 'Auto',
                    child: Text('Auto'),
                  ),
                  DropdownMenuItem(
                    value: 'Other',
                    child: Text('Other'),
                  ),
                ],

                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      vehicleType = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 25),

              // REGISTER BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,

                child: ElevatedButton(
                  onPressed:
                      loading
                          ? null
                          : registerCourier,

                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'REGISTER',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
