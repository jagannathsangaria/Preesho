import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final pincodeController = TextEditingController();

  bool loading = false;

  // ============================================================
  // SAVE CUSTOMER DETAILS
  // ============================================================

  Future<void> saveDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(
        'Please login with your mobile number first.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final mobile = user.phoneNumber ?? '';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'name': nameController.text.trim(),
          'mobile': mobile,
          'email': emailController.text.trim(),
          'address': addressController.text.trim(),
          'city': cityController.text.trim(),
          'pincode': pincodeController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.updateDisplayName(
        nameController.text.trim(),
      );

      if (!mounted) return;

      showMessage(
        'Customer details saved successfully.',
      );

      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      showMessage(
        'Could not save details: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // INPUT FIELD
  // ============================================================

  Widget inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: requiredField
              ? label
              : '$label (Optional)',
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        validator: validator,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final mobile = user?.phoneNumber ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customer Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.person_outline,
                size: 75,
              ),

              const SizedBox(height: 16),

              const Text(
                'Complete Your Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Your mobile number is verified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // VERIFIED MOBILE
              // ==================================================

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.verified,
                    color: Colors.green,
                  ),
                  title: const Text(
                    'Mobile Number',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    mobile.isEmpty
                        ? 'Verified mobile number'
                        : mobile,
                  ),
                  trailing: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // NAME
              // ==================================================

              inputField(
                controller: nameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Please enter your name';
                  }

                  if (value.trim().length < 2) {
                    return 'Please enter a valid name';
                  }

                  return null;
                },
              ),

              // ==================================================
              // EMAIL OPTIONAL
              // ==================================================

              inputField(
                controller: emailController,
                label: 'Email',
                hint: 'Enter your email if available',
                icon: Icons.email_outlined,
                keyboardType:
                    TextInputType.emailAddress,
                requiredField: false,
                validator: (value) {
                  final email =
                      value?.trim() ?? '';

                  if (email.isEmpty) {
                    return null;
                  }

                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(email)) {
                    return 'Enter a valid email';
                  }

                  return null;
                },
              ),

              // ==================================================
              // ADDRESS
              // ==================================================

              inputField(
                controller: addressController,
                label: 'Address',
                hint:
                    'House no., street, area',
                icon: Icons.home_outlined,
                maxLines: 3,
                validator: (value) {
                  if (value == null ||
                      value.trim().length < 5) {
                    return 'Enter a complete address';
                  }

                  return null;
                },
              ),

              // ==================================================
              // CITY
              // ==================================================

              inputField(
                controller: cityController,
                label: 'City',
                hint: 'Enter your city',
                icon: Icons.location_city_outlined,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Please enter city';
                  }

                  return null;
                },
              ),

              // ==================================================
              // PINCODE
              // ==================================================

              inputField(
                controller: pincodeController,
                label: 'PIN Code',
                hint: 'Enter 6 digit PIN code',
                icon: Icons.pin_drop_outlined,
                keyboardType:
                    TextInputType.number,
                validator: (value) {
                  if (!RegExp(
                    r'^[0-9]{6}$',
                  ).hasMatch(
                    value?.trim() ?? '',
                  )) {
                    return 'Enter a valid 6 digit PIN code';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 8),

              // ==================================================
              // SAVE BUTTON
              // ==================================================

              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed:
                      loading ? null : saveDetails,
                  icon: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.save_outlined,
                        ),
                  label: Text(
                    loading
                        ? 'Saving...'
                        : 'Save & Continue',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Email is optional. Mobile number is your mandatory login method.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    addressController.dispose();
    cityController.dispose();
    pincodeController.dispose();
    super.dispose();
  }
}
