import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourierManagementPage extends StatefulWidget {
  const CourierManagementPage({super.key});

  @override
  State<CourierManagementPage> createState() =>
      _CourierManagementPageState();
}

class _CourierManagementPageState
    extends State<CourierManagementPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  bool saving = false;

  Future<void> _addCourier() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      _showMessage('Courier name and email are required.');
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      /*
       * Courier Authentication account creation will be connected
       * through secure backend/Cloud Function.
       *
       * This document is created first so the Admin can maintain
       * the courier master data.
       */

      final docRef = _firestore.collection('couriers').doc();

      await docRef.set({
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'courier',
        'active': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      if (!mounted) return;

      Navigator.pop(context);

      _showMessage('Courier added successfully.');
    } catch (e) {
      _showMessage(
        'Unable to add courier.\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> _updateCourier(
    String courierId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection('couriers')
          .doc(courierId)
          .update({
        ...data,
        'updatedAt': Timestamp.now(),
      });

      _showMessage('Courier updated.');
    } catch (e) {
      _showMessage(
        'Unable to update courier.\n$e',
      );
    }
  }

  Future<void> _toggleCourier(
    String courierId,
    bool currentStatus,
  ) async {
    await _updateCourier(
      courierId,
      {
        'active': !currentStatus,
      },
    );
  }

  Future<void> _deleteCourier(
    String courierId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Courier?'),
          content: const Text(
            'This will remove the courier record from '
            'Courier Management. Existing order history will '
            'not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _firestore
          .collection('couriers')
          .doc(courierId)
          .delete();

      _showMessage('Courier removed.');
    } catch (e) {
      _showMessage(
        'Unable to delete courier.\n$e',
      );
    }
  }

  void _showAddCourierDialog() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Add Courier',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Courier Name',
                    prefixIcon:
                        Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Courier Email',
                    prefixIcon:
                        Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon:
                        Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed:
                  saving ? null : _addCourier,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(
                saving ? 'Saving...' : 'Add Courier',
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditCourierDialog(
    String courierId,
    Map<String, dynamic> data,
  ) {
    final editNameController =
        TextEditingController(
      text: data['name']?.toString() ?? '',
    );

    final editEmailController =
        TextEditingController(
      text: data['email']?.toString() ?? '',
    );

    final editPhoneController =
        TextEditingController(
      text: data['phone']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        bool updating = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Edit Courier',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          editNameController,
                      decoration:
                          const InputDecoration(
                        labelText: 'Courier Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller:
                          editEmailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(
                        labelText: 'Courier Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller:
                          editPhoneController,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: updating
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: updating
                      ? null
                      : () async {
                          setDialogState(() {
                            updating = true;
                          });

                          await _updateCourier(
                            courierId,
                            {
                              'name':
                                  editNameController
                                      .text
                                      .trim(),
                              'email':
                                  editEmailController
                                      .text
                                      .trim(),
                              'phone':
                                  editPhoneController
                                      .text
                                      .trim(),
                            },
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: updating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _dateText(dynamic value) {
    if (value is! Timestamp) {
      return '';
    }

    final date = value.toDate().toLocal();

    final day =
        date.day.toString().padLeft(2, '0');
    final month =
        date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Courier Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showAddCourierDialog,
            tooltip: 'Add Courier',
            icon: const Icon(
              Icons.person_add_alt_1,
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _showAddCourierDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Courier'),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('couriers')
            .orderBy(
              'createdAt',
              descending: true,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load couriers.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 70,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No couriers added yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap Add Courier to create the '
                      'first courier record.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
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
              90,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final name =
                  data['name']?.toString() ??
                      'Unnamed Courier';

              final email =
                  data['email']?.toString() ?? '';

              final phone =
                  data['phone']?.toString() ?? '';

              final active =
                  data['active'] == true;

              final createdAt =
                  data['createdAt'];

              return Card(
                margin:
                    const EdgeInsets.only(bottom: 14),
                elevation: 2,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 27,
                            child: Icon(
                              Icons
                                  .local_shipping_outlined,
                              color: active
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style:
                                      const TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  email,
                                  style:
                                      const TextStyle(
                                    color: Colors.black54,
                                  ),
                                ),
                                if (phone.isNotEmpty)
                                  Text(
                                    phone,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditCourierDialog(
                                  doc.id,
                                  data,
                                );
                              }

                              if (value == 'toggle') {
                                _toggleCourier(
                                  doc.id,
                                  active,
                                );
                              }

                              if (value == 'delete') {
                                _deleteCourier(
                                  doc.id,
                                );
                              }
                            },
                            itemBuilder: (context) {
                              return [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                      ),
                                      SizedBox(width: 10),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        active
                                            ? Icons
                                                .block_outlined
                                            : Icons
                                                .check_circle_outline,
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Text(
                                        active
                                            ? 'Deactivate'
                                            : 'Activate',
                                      ),
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
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Delete',
                                        style:
                                            TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: Text(
                              active
                                  ? 'ACTIVE'
                                  : 'INACTIVE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.bold,
                                color: active
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (createdAt != null)
                            Text(
                              'Added: ${_dateText(createdAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
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
}
