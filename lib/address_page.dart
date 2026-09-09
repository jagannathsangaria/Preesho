import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pinCodeController = TextEditingController();

  bool _isSaving = false;

  User? get _currentUser => _auth.currentUser;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pinCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    final user = _currentUser;

    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};

      _nameController.text =
          (data['name'] ?? user.displayName ?? '').toString();

      _mobileController.text =
          (data['mobile'] ?? '').toString();

      _stateController.text =
          (data['state'] ?? '').toString();
    } catch (_) {
      _nameController.text = user.displayName ?? '';
    }
  }

  void _clearForm() {
    _nameController.clear();
    _mobileController.clear();
    _addressController.clear();
    _cityController.clear();
    _stateController.clear();
    _pinCodeController.clear();
  }

  Future<void> _showAddressForm({
    DocumentSnapshot<Map<String, dynamic>>? existingAddress,
  }) async {
    final data = existingAddress?.data();

    _clearForm();

    if (data != null) {
      _nameController.text = (data['name'] ?? '').toString();
      _mobileController.text = (data['mobile'] ?? '').toString();
      _addressController.text = (data['address'] ?? '').toString();
      _cityController.text = (data['city'] ?? '').toString();
      _stateController.text = (data['state'] ?? '').toString();
      _pinCodeController.text = (data['pinCode'] ?? '').toString();
    } else {
      await _loadUserDetails();
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            existingAddress == null
                                ? 'Add New Address'
                                : 'Edit Address',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                    ),

                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _mobileController,
                      label: 'Mobile Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                    ),

                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _addressController,
                      label: 'Complete Address',
                      icon: Icons.home_outlined,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _cityController,
                      label: 'City',
                      icon: Icons.location_city_outlined,
                    ),

                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _stateController,
                      label: 'State',
                      icon: Icons.map_outlined,
                    ),

                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _pinCodeController,
                      label: 'PIN Code',
                      icon: Icons.pin_drop_outlined,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setModalState(() {
                                  _isSaving = true;
                                });

                                final success =
                                    await _saveAddress(
                                  existingAddress:
                                      existingAddress,
                                );

                                if (!mounted) return;

                                setModalState(() {
                                  _isSaving = false;
                                });

                                if (success) {
                                  Navigator.pop(context);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                existingAddress == null
                                    ? 'Save Address'
                                    : 'Update Address',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    _clearForm();
    _isSaving = false;

    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _saveAddress({
    DocumentSnapshot<Map<String, dynamic>>? existingAddress,
  }) async {
    final user = _currentUser;

    if (user == null) {
      _showMessage('Please login first.');
      return false;
    }

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final pinCode = _pinCodeController.text.trim();

    if (name.isEmpty) {
      _showMessage('Please enter your name.');
      return false;
    }

    if (mobile.length != 10) {
      _showMessage('Please enter a valid 10-digit mobile number.');
      return false;
    }

    if (address.isEmpty) {
      _showMessage('Please enter your complete address.');
      return false;
    }

    if (city.isEmpty) {
      _showMessage('Please enter your city.');
      return false;
    }

    if (state.isEmpty) {
      _showMessage('Please enter your state.');
      return false;
    }

    if (pinCode.length != 6) {
      _showMessage('Please enter a valid 6-digit PIN code.');
      return false;
    }

    try {
      final addressData = {
        'userId': user.uid,
        'name': name,
        'mobile': mobile,
        'address': address,
        'city': city,
        'state': state,
        'pinCode': pinCode,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingAddress == null) {
        addressData['createdAt'] =
            FieldValue.serverTimestamp();

        await _firestore
            .collection('addresses')
            .add(addressData);

        _showMessage(
          'Address saved successfully.',
          success: true,
        );
      } else {
        await _firestore
            .collection('addresses')
            .doc(existingAddress.id)
            .update(addressData);

        _showMessage(
          'Address updated successfully.',
          success: true,
        );
      }

      return true;
    } on FirebaseException catch (e) {
      _showMessage(
        e.message ?? 'Unable to save address.',
      );
      return false;
    } catch (_) {
      _showMessage('Something went wrong.');
      return false;
    }
  }

  Future<void> _deleteAddress(
    DocumentSnapshot<Map<String, dynamic>> address,
  ) async {
    final user = _currentUser;

    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Address'),
          content: const Text(
            'Are you sure you want to delete this address?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _firestore
          .collection('addresses')
          .doc(address.id)
          .delete();

      _showMessage(
        'Address deleted successfully.',
        success: true,
      );
    } on FirebaseException catch (e) {
      _showMessage(
        e.message ?? 'Unable to delete address.',
      );
    } catch (_) {
      _showMessage('Something went wrong.');
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.black,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  void _showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Addresses'),
        ),
        body: const Center(
          child: Text(
            'Please login to manage your addresses.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'My Addresses',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressForm(),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('addresses')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load addresses.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final addresses = snapshot.data?.docs ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Address Added',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your delivery address to place orders.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showAddressForm(),
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Add Your First Address',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              final data = address.data();

              final name =
                  (data['name'] ?? '').toString();
              final mobile =
                  (data['mobile'] ?? '').toString();
              final fullAddress =
                  (data['address'] ?? '').toString();
              final city =
                  (data['city'] ?? '').toString();
              final state =
                  (data['state'] ?? '').toString();
              final pin =
                  (data['pinCode'] ?? '').toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(
                              Icons.location_on_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name.isEmpty
                                  ? 'Delivery Address'
                                  : name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showAddressForm(
                                  existingAddress:
                                      address,
                                );
                              } else if (value ==
                                  'delete') {
                                _deleteAddress(address);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined),
                                    SizedBox(width: 10),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons
                                          .delete_outline,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      if (mobile.isNotEmpty)
                        _addressLine(
                          Icons.phone_outlined,
                          mobile,
                        ),

                      _addressLine(
                        Icons.home_outlined,
                        fullAddress,
                      ),

                      _addressLine(
                        Icons.location_city_outlined,
                        '$city, $state - $pin',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _addressLine(
    IconData icon,
    String text,
  ) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
