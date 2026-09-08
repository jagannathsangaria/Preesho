import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'vendor_documents_page.dart';

class VendorRegistrationPage extends StatefulWidget {
  const VendorRegistrationPage({super.key});

  @override
  State<VendorRegistrationPage> createState() =>
      _VendorRegistrationPageState();
}

class _VendorRegistrationPageState
    extends State<VendorRegistrationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _registerVendor() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Vendor name enter karein.',
        isError: true,
      );
      return;
    }

    if (phone.isEmpty) {
      _showMessage(
        'Mobile number enter karein.',
        isError: true,
      );
      return;
    }

    if (email.isEmpty) {
      _showMessage(
        'Email enter karein.',
        isError: true,
      );
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password minimum 6 characters ka hona chahiye.',
        isError: true,
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception(
          'Vendor account create nahi hua.',
        );
      }

      final uid = user.uid;

      await user.updateDisplayName(name);

      final batch = _firestore.batch();

      final userRef =
          _firestore.collection('users').doc(uid);

      final vendorRef =
          _firestore.collection('vendors').doc(uid);

      batch.set(
        userRef,
        {
          'uid': uid,
          'name': name,
          'phone': phone,
          'email': email,
          'role': 'vendor',

          // Vendor approval flow
          'status': 'pending_documents',
          'registrationStatus': 'pending_documents',
          'active': false,
          'approvedByAdmin': false,

          'documentsSubmitted': false,
          'documents': {},

          'createdAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        vendorRef,
        {
          'uid': uid,
          'name': name,
          'phone': phone,
          'email': email,
          'role': 'vendor',

          // Vendor approval flow
          'status': 'pending_documents',
          'registrationStatus': 'pending_documents',
          'active': false,
          'approvedByAdmin': false,

          'documentsSubmitted': false,
          'documents': {},

          'rejectionReason': '',

          'createdAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Registration Successful',
            ),
            content: const Text(
              'Vendor account create ho gaya hai.\n\n'
              'Ab KYC details enter karein aur Admin approval ke liye submit karein.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDocumentsPage(
            vendorUid: uid,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'Is email se account pehle se bana hua hai.';
          break;

        case 'invalid-email':
          message =
              'Email address valid nahi hai.';
          break;

        case 'weak-password':
          message =
              'Password bahut weak hai.';
          break;

        case 'network-request-failed':
          message =
              'Internet connection check karein.';
          break;

        default:
          message =
              e.message ??
                  'Vendor registration failed.';
      }

      _showMessage(
        message,
        isError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

      _showMessage(
        'Vendor registration failed.\n$e',
        isError: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Registration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Vendor Account',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Registration ke baad PAN, Aadhaar, GST, Bank aur Address Proof details submit karni hongi.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 25),

              TextFormField(
                controller: _nameController,
                textCapitalization:
                    TextCapitalization.words,
                decoration:
                    const InputDecoration(
                  labelText: 'Vendor / Business Name',
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.store_outlined),
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _phoneController,
                keyboardType:
                    TextInputType.phone,
                decoration:
                    const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.phone_outlined),
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration:
                    const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller:
                    _passwordController,
                obscureText:
                    _obscurePassword,
                decoration:
                    InputDecoration(
                  labelText: 'Password',
                  border:
                      const OutlineInputBorder(),
                  prefixIcon:
                      const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword =
                            !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons
                              .visibility_off_outlined,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed:
                      _loading
                          ? null
                          : _registerVendor,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.person_add_outlined,
                        ),
                  label: Text(
                    _loading
                        ? 'Creating Account...'
                        : 'Register as Vendor',
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Card(
                child: Padding(
                  padding:
                      EdgeInsets.all(15),
                  child: Text(
                    'Important: Vendor account Admin approval ke bina active nahi hoga.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
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
