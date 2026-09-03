import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_functions/firebase_functions.dart';

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

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool saving = false;
  bool obscurePassword = true;

  Future<void> _addCourier() async {
    final name = nameController.text.trim();
    final email =
        emailController.text.trim().toLowerCase();
    final phone = phoneController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      _showMessage(
        'Courier name, email and password are required.',
      );
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password must contain at least 6 characters.',
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final callable =
          _functions.httpsCallable(
        'createCourierAccount',
      );

      final result = await callable.call({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      });

      if (!mounted) return;

      final resultData =
          result.data is Map
              ? Map<String, dynamic>.from(
                  result.data as Map,
                )
              : <String, dynamic>{};

      Navigator.pop(context);

      _showMessage(
        resultData['message']?.toString() ??
            'Courier account created successfully.',
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'unauthenticated':
          message =
              'Please login again as Admin.';
          break;

        case 'permission-denied':
          message =
              'Only Admin can create courier accounts.';
          break;

        case 'already-exists':
          message =
              'A Firebase account already exists with this email.';
          break;

        case 'invalid-argument':
          message =
              e.message ??
                  'Please check courier details.';
          break;

        default:
          message =
              e.message ??
                  'Unable to create courier account.';
      }

      _showMessage(message);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to create courier account.\n$e',
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

      if (mounted) {
        _showMessage('Courier updated.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to update courier.\n$e',
        );
      }
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
            'The courier record will be removed from '
            'Courier Management. Firebase Authentication '
            'account and existing order history will not '
            'be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
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
          .collection('couriers')
          .doc(courierId)
          .delete();

      if (mounted) {
        _showMessage('Courier removed.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to delete courier.\n$e',
        );
      }
    }
  }

  void _showAddCourierDialog() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();

    obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        bool dialogSaving = false;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Add Courier',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Courier Name',
                        prefixIcon:
                            Icon(
                          Icons
                              .person_outline,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller:
                          emailController,
                      keyboardType:
                          TextInputType
                              .emailAddress,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Courier Email',
                        prefixIcon:
                            Icon(
                          Icons
                              .email_outlined,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller:
                          phoneController,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Phone Number',
                        prefixIcon:
                            Icon(
                          Icons
                              .phone_outlined,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller:
                          passwordController,
                      obscureText:
                          obscurePassword,
                      decoration:
                          InputDecoration(
                        labelText:
                            'Login Password',
                        prefixIcon:
                            const Icon(
                          Icons
                              .lock_outline,
                        ),
                        border:
                            const OutlineInputBorder(),
                        suffixIcon:
                            IconButton(
                          onPressed: () {
                            setDialogState(() {
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
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment:
                          Alignment.centerLeft,
                      child: Text(
                        'Minimum 6 characters',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogSaving
                      ? null
                      : () =>
                          Navigator.pop(
                            context,
                          ),
                  child:
                      const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: dialogSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            dialogSaving =
                                true;
                          });

                          await _addCourier();

                          if (mounted) {
                            setDialogState(() {
                              dialogSaving =
                                  false;
                            });
                          }
                        },
                  icon: dialogSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.add,
                        ),
                  label: Text(
                    dialogSaving
                        ? 'Creating...'
                        : 'Create Courier',
                  ),
                ),
              ],
            );
          },
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
      text:
          data['name']?.toString() ?? '',
    );

    final editEmailController =
        TextEditingController(
      text:
          data['email']?.toString() ?? '',
    );

    final editPhoneController =
        TextEditingController(
      text:
          data['phone']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        bool updating = false;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Edit Courier',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          editNameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Courier Name',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller:
                          editEmailController,
                      keyboardType:
                          TextInputType
                              .emailAddress,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Courier Email',
                        border:
                            OutlineInputBorder(),
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
                        labelText:
                            'Phone Number',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: updating
                      ? null
                      : () =>
                          Navigator.pop(
                            context,
                          ),
                  child:
                      const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: updating
                      ? null
                      : () async {
                          final name =
                              editNameController
                                  .text
                                  .trim();

                          final email =
                              editEmailController
                                  .text
                                  .trim()
                                  .toLowerCase();

                          final phone =
                              editPhoneController
                                  .text
                                  .trim();

                          if (name.isEmpty ||
                              email.isEmpty) {
                            _showMessage(
                              'Name and email are required.',
                            );
                            return;
                          }

                          setDialogState(() {
                            updating =
                                true;
                          });

                          await _updateCourier(
                            courierId,
                            {
                              'name': name,
                              'email': email,
                              'phone': phone,
                            },
                          );

                          if (context.mounted) {
                            Navigator.pop(
                              context,
                            );
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

  // ------------------------------------------------------------
  // ORDER ASSIGNMENT
  // ------------------------------------------------------------

  Future<void> _assignOrderToCourier(
    String orderId,
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    try {
      final orderRef =
          _firestore.collection('orders').doc(orderId);

      final courierName =
          courierData['name']?.toString() ??
              'Courier';

      final courierPhone =
          courierData['phone']?.toString() ??
              '';

      await _firestore.runTransaction(
        (transaction) async {
          final orderSnapshot =
              await transaction.get(orderRef);

          if (!orderSnapshot.exists) {
            throw Exception(
              'Order not found.',
            );
          }

          final orderData =
              orderSnapshot.data() ?? {};

          final currentStatus =
              _normalizeOrderStatus(
            orderData['orderStatus'] ??
                orderData['status'],
          );

          if (currentStatus != 'Shipped') {
            throw Exception(
              'Only Shipped orders can be assigned to a courier.',
            );
          }

          final existingCourierId =
              orderData['courierId']
                      ?.toString()
                      .trim() ??
                  '';

          if (existingCourierId.isNotEmpty &&
              existingCourierId != courierId) {
            throw Exception(
              'This order is already assigned to another courier.',
            );
          }

          final now = Timestamp.now();

          transaction.update(
            orderRef,
            {
              'courierId': courierId,
              'courierPersonName':
                  courierName,
              'courierPhone':
                  courierPhone,
              'courierAssignedAt':
                  orderData[
                          'courierAssignedAt'] ??
                      now,
              'updatedAt': now,
            },
          );
        },
      );

      if (mounted) {
        _showMessage(
          'Order assigned to $courierName.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      String message = e.toString();

      if (message.startsWith(
        'Exception: ',
      )) {
        message =
            message.substring(
          'Exception: '.length,
        );
      }

      _showMessage(message);
    }
  }

  String _normalizeOrderStatus(
    dynamic value,
  ) {
    if (value == null) {
      return 'Placed';
    }

    final status =
        value.toString().trim();

    switch (status.toLowerCase()) {
      case 'placed':
        return 'Placed';

      case 'confirmed':
        return 'Confirmed';

      case 'processing':
        return 'Processing';

      case 'packed':
        return 'Packed';

      case 'shipped':
        return 'Shipped';

      case 'picked by courier':
      case 'picked_by_courier':
      case 'picked':
        return 'Picked by Courier';

      case 'out for delivery':
      case 'out_for_delivery':
      case 'outfordelivery':
        return 'Out for Delivery';

      case 'delivered':
        return 'Delivered';

      case 'cancelled':
      case 'canceled':
        return 'Cancelled';

      default:
        return status;
    }
  }

  Future<void> _showAssignOrderDialog(
    DocumentSnapshot<Map<String, dynamic>>
        orderDoc,
  ) async {
    final orderData =
        orderDoc.data() ?? {};

    final orderId =
        orderData['orderId']
                ?.toString() ??
            orderDoc.id;

    final currentCourierId =
        orderData['courierId']
                ?.toString()
                .trim() ??
            '';

    final courierSnapshot =
        await _firestore
            .collection('couriers')
            .where(
              'active',
              isEqualTo: true,
            )
            .get();

    if (!mounted) return;

    final couriers =
        courierSnapshot.docs;

    if (couriers.isEmpty) {
      _showMessage(
        'No active couriers available.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Assign Courier\nOrder #$orderId',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount:
                  couriers.length,
              separatorBuilder:
                  (_, __) =>
                      const Divider(),
              itemBuilder:
                  (context, index) {
                final courier =
                    couriers[index];

                final data =
                    courier.data();

                final name =
                    data['name']
                            ?.toString() ??
                        'Courier';

                final email =
                    data['email']
                            ?.toString() ??
                        '';

                final phone =
                    data['phone']
                            ?.toString() ??
                        '';

                final selected =
                    currentCourierId ==
                        courier.id;

                return ListTile(
                  leading:
                      CircleAvatar(
                    child: Icon(
                      Icons
                          .local_shipping_outlined,
                      color: selected
                          ? Colors.green
                          : null,
                    ),
                  ),
                  title: Text(
                    name,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle:
                      Text(
                    [
                      if (email.isNotEmpty)
                        email,
                      if (phone.isNotEmpty)
                        phone,
                    ].join('\n'),
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons
                              .check_circle,
                          color:
                              Colors.green,
                        )
                      : const Icon(
                          Icons
                              .radio_button_unchecked,
                        ),
                  onTap: () async {
                    Navigator.pop(
                      context,
                    );

                    await _assignOrderToCourier(
                      orderDoc.id,
                      courier.id,
                      data,
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child:
                  const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderAssignmentSection() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('orders')
          .where(
            'orderStatus',
            isEqualTo: 'Shipped',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(18),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            ),
          );
        }

        final orders =
            snapshot.data?.docs ?? [];

        if (orders.isEmpty) {
          return Card(
            margin:
                const EdgeInsets.only(
              bottom: 16,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: const Padding(
              padding:
                  EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    Icons
                        .assignment_turned_in_outlined,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No Shipped orders waiting '
                      'for courier assignment.',
                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin:
              const EdgeInsets.only(
            bottom: 16,
          ),
          elevation: 2,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons
                          .local_shipping_outlined,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Courier Assignment',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${orders.length} Shipped order(s) available',
                  style:
                      const TextStyle(
                    color:
                        Colors.black54,
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                ...orders.map(
                  (doc) {
                    final data =
                        doc.data();

                    final orderId =
                        data['orderId']
                                ?.toString() ??
                            doc.id;

                    final customer =
                        data['customerName']
                                ?.toString() ??
                            data['name']
                                ?.toString() ??
                            'Customer';

                    final assignedCourierId =
                        data['courierId']
                                ?.toString()
                                .trim() ??
                            '';

                    final assignedName =
                        data['courierPersonName']
                                ?.toString() ??
                            '';

                    return Container(
                      margin:
                          const EdgeInsets.only(
                        bottom: 10,
                      ),
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        border: Border.all(
                          color: Colors
                              .grey
                              .shade300,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .inventory_2_outlined,
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Order #$orderId',
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  customer,
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.black54,
                                  ),
                                ),
                                if (assignedCourierId
                                        .isNotEmpty ||
                                    assignedName
                                        .isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets
                                            .only(
                                      top: 4,
                                    ),
                                    child:
                                        Text(
                                      assignedName
                                              .isNotEmpty
                                          ? 'Assigned: $assignedName'
                                          : 'Courier ID: $assignedCourierId',
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.green,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          OutlinedButton(
                            onPressed:
                                () {
                              _showAssignOrderDialog(
                                doc,
                              );
                            },
                            child: Text(
                              assignedCourierId
                                      .isEmpty
                                  ? 'Assign'
                                  : 'View / Assign',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  String _dateText(
    dynamic value,
  ) {
    if (value is! Timestamp) {
      return '';
    }

    final date =
        value.toDate().toLocal();

    final day =
        date.day
            .toString()
            .padLeft(2, '0');

    final month =
        date.month
            .toString()
            .padLeft(2, '0');

    final year =
        date.year.toString();

    return '$day/$month/$year';
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Courier Management',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                _showAddCourierDialog,
            tooltip:
                'Add Courier',
            icon: const Icon(
              Icons
                  .person_add_alt_1,
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _showAddCourierDialog,
        icon: const Icon(
          Icons.add,
        ),
        label:
            const Text(
          'Add Courier',
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<
              Map<String,
                  dynamic>>>(
        stream: _firestore
            .collection(
              'couriers',
            )
            .orderBy(
              'createdAt',
              descending: true,
            )
            .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  24,
                ),
                child: Text(
                  'Unable to load couriers.\n\n'
                  '${snapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot.data?.docs ??
                  [];

          return ListView(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ),
            children: [
              _buildOrderAssignmentSection(),

              if (docs.isEmpty)
                const Padding(
                  padding:
                      EdgeInsets.all(
                    30,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons
                            .local_shipping_outlined,
                        size: 70,
                        color:
                            Colors.grey,
                      ),
                      SizedBox(
                        height: 16,
                      ),
                      Text(
                        'No couriers added yet',
                        style:
                            TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      Text(
                        'Tap Add Courier to create '
                        'the first courier account.',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

              ...docs.map(
                (doc) {
                  final data =
                      doc.data();

                  final name =
                      data['name']
                              ?.toString() ??
                          'Unnamed Courier';

                  final email =
                      data['email']
                              ?.toString() ??
                          '';

                  final phone =
                      data['phone']
                              ?.toString() ??
                          '';

                  final active =
                      data['active'] ==
                          true;

                  final createdAt =
                      data['createdAt'];

                  return Card(
                    margin:
                        const EdgeInsets.only(
                      bottom: 14,
                    ),
                    elevation: 2,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                    ),
                    child:
                        Padding(
                      padding:
                          const EdgeInsets
                              .all(
                        16,
                      ),
                      child:
                          Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius:
                                    27,
                                child:
                                    Icon(
                                  Icons
                                      .local_shipping_outlined,
                                  color: active
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(
                                width: 14,
                              ),
                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      name,
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            17,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(
                                      height:
                                          4,
                                    ),
                                    if (email
                                        .isNotEmpty)
                                      Text(
                                        email,
                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.black54,
                                        ),
                                      ),
                                    if (phone
                                        .isNotEmpty)
                                      Text(
                                        phone,
                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.black54,
                                        ),
                                      ),
                                    const SizedBox(
                                      height:
                                          3,
                                    ),
                                    Text(
                                      'Courier ID: ${doc.id}',
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            11,
                                        color:
                                            Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<
                                  String>(
                                onSelected:
                                    (value) {
                                  if (value ==
                                      'edit') {
                                    _showEditCourierDialog(
                                      doc.id,
                                      data,
                                    );
                                  }

                                  if (value ==
                                      'toggle') {
                                    _toggleCourier(
                                      doc.id,
                                      active,
                                    );
                                  }

                                  if (value ==
                                      'delete') {
                                    _deleteCourier(
                                      doc.id,
                                    );
                                  }
                                },
                                itemBuilder:
                                    (context) {
                                  return [
                                    const PopupMenuItem(
                                      value:
                                          'edit',
                                      child:
                                          Row(
                                        children: [
                                          Icon(
                                            Icons
                                                .edit_outlined,
                                          ),
                                          SizedBox(
                                            width:
                                                10,
                                          ),
                                          Text(
                                            'Edit',
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value:
                                          'toggle',
                                      child:
                                          Row(
                                        children: [
                                          Icon(
                                            active
                                                ? Icons
                                                    .block_outlined
                                                : Icons
                                                    .check_circle_outline,
                                          ),
                                          const SizedBox(
                                            width:
                                                10,
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
                                      value:
                                          'delete',
                                      child:
                                          Row(
                                        children: [
                                          Icon(
                                            Icons
                                                .delete_outline,
                                            color:
                                                Colors.red,
                                          ),
                                          SizedBox(
                                            width:
                                                10,
                                          ),
                                          Text(
                                            'Delete',
                                            style:
                                                TextStyle(
                                              color:
                                                  Colors.red,
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
                          const Divider(
                            height: 24,
                          ),
                          Row(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      10,
                                  vertical: 5,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: active
                                      ? Colors
                                          .green
                                          .shade50
                                      : Colors
                                          .red
                                          .shade50,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                                child:
                                    Text(
                                  active
                                      ? 'ACTIVE'
                                      : 'INACTIVE',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        11,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color: active
                                        ? Colors
                                            .green
                                            .shade700
                                        : Colors
                                            .red
                                            .shade700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (createdAt !=
                                  null)
                                Text(
                                  'Added: ${_dateText(createdAt)}',
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        12,
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
