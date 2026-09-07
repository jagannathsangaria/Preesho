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
    final name = nameController.text.trim();
    final mobile = mobileController.text.trim();
    final password = passwordController.text.trim();
    final vehicleNumber =
        vehicleNumberController.text.trim().toUpperCase();

    if (name.isEmpty ||
        mobile.isEmpty ||
        password.isEmpty ||
        vehicleNumber.isEmpty) {
      _showMessage('Please fill all fields');
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      _showMessage('Please enter a valid 10-digit mobile number');
      return;
    }

    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // Check whether mobile number is already registered.
      final existing = await _firestore
          .collection('couriers')
          .where('phone', isEqualTo: mobile)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        _showMessage('This mobile number is already registered');
        setState(() {
          loading = false;
        });
        return;
      }

      // Firebase Auth requires an email.
      // We generate an internal email from the mobile number.
      final internalEmail = 'courier_$mobile@preesho.app';

      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: internalEmail,
        password: password,
      );

      final uid = credential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'phone': mobile,
        'role': 'courier',
        'active': true,
        'vehicleNumber': vehicleNumber,
        'vehicleType': vehicleType,
        'email': internalEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('couriers').doc(uid).set({
        'uid': uid,
        'name': name,
        'phone': mobile,
        'role': 'courier',
        'active': true,
        'vehicleNumber': vehicleNumber,
        'vehicleType': vehicleType,
        'email': internalEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _auth.signOut();

      if (!mounted) return;

      _showMessage('Courier account created successfully');

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';

      if (e.code == 'email-already-in-use') {
        message = 'This mobile number is already registered';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'network-request-failed') {
        message = 'Please check your internet connection';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courier Registration'),
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

              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  'Name',
                  Icons.person,
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: _decoration(
                  'Mobile Number',
                  Icons.phone,
                ),
              ),

              const SizedBox(height: 5),

              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: _decoration(
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
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: vehicleNumberController,
                textCapitalization: TextCapitalization.characters,
                decoration: _decoration(
                  'Vehicle Number',
                  Icons.directions_car,
                ),
              ),

              const SizedBox(height: 15),

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

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : registerCourier,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'REGISTER',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
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
