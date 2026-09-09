import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

  // ============================================================
  // BACK NAVIGATION
  // ============================================================

  void _goBack() {
    if (saving) return;

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  Future<bool> _handleBack() async {
    if (saving) {
      return false;
    }

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      return true;
    }

    navigator.pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );

    return false;
  }

  // ============================================================
  // REQUIRED COURIER DOCUMENT NUMBERS
  // ============================================================

  static const List<String> requiredDocumentKeys = [
    'pan',
    'aadhaar',
    'drivingLicence',
    'vehicleRc',
    'addressProof',
  ];

  String _documentTitle(String key) {
    switch (key) {
      case 'pan':
        return 'PAN Number';
      case 'aadhaar':
        return 'Aadhaar Number';
      case 'drivingLicence':
        return 'Driving Licence Number';
      case 'vehicleRc':
        return 'Vehicle RC Number';
      case 'addressProof':
        return 'Address Proof Number / Details';
      default:
        return key;
    }
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalizeStatus(dynamic value) {
    return _stringValue(value)
        .toLowerCase()
        .replaceAll(' ', '_');
  }

  String _statusLabel(dynamic value) {
    final status = _normalizeStatus(value);

    switch (status) {
      case 'approved':
        return 'Approved';
      case 'pending_approval':
        return 'Pending Approval';
      case 'pending_documents':
        return 'Documents Pending';
      case 'rejected':
        return 'Rejected';
      case 'suspended':
        return 'Suspended';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  Color _statusColor(dynamic value) {
    final status = _normalizeStatus(value);

    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending_approval':
        return Colors.orange;
      case 'pending_documents':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'suspended':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  String _normalizeOrderStatus(dynamic value) {
    return _stringValue(value)
        .toLowerCase()
        .replaceAll(' ', '_');
  }

  String _dateText(dynamic value) {
    if (value == null) return '-';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '-';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              error ? Colors.red : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // GET DOCUMENT NUMBERS
  // ============================================================

  Map<String, String> _getDocumentNumbers(
    Map<String, dynamic> courierData,
  ) {
    final result = <String, String>{};

    final documents = courierData['documents'];

    if (documents is Map) {
      for (final key in requiredDocumentKeys) {
        final value = documents[key];

        if (value is Map) {
          result[key] = _stringValue(
            value['number'] ??
                value['value'] ??
                value['details'],
          );
        } else {
          result[key] = _stringValue(value);
        }
      }
    }

    // Legacy / flat fields support.
    result['pan'] = result['pan']!.isEmpty
        ? _stringValue(
            courierData['panNumber'] ??
                courierData['pan'],
          )
        : result['pan']!;

    result['aadhaar'] = result['aadhaar']!.isEmpty
        ? _stringValue(
            courierData['aadhaarNumber'] ??
                courierData['aadhaar'],
          )
        : result['aadhaar']!;

    result['drivingLicence'] =
        result['drivingLicence']!.isEmpty
            ? _stringValue(
                courierData['drivingLicenceNumber'] ??
                    courierData['drivingLicence'] ??
                    courierData['dlNumber'],
              )
            : result['drivingLicence']!;

    result['vehicleRc'] =
        result['vehicleRc']!.isEmpty
            ? _stringValue(
                courierData['vehicleRcNumber'] ??
                    courierData['vehicleRc'] ??
                    courierData['rcNumber'],
              )
            : result['vehicleRc']!;

    result['addressProof'] =
        result['addressProof']!.isEmpty
            ? _stringValue(
                courierData['addressProofNumber'] ??
                    courierData['addressProof'],
              )
            : result['addressProof']!;

    return result;
  }

  bool _documentsComplete(
    Map<String, dynamic> courierData,
  ) {
    final numbers = _getDocumentNumbers(
      courierData,
    );

    return requiredDocumentKeys.every(
      (key) => (numbers[key] ?? '').isNotEmpty,
    );
  }

  int _completedDocumentCount(
    Map<String, dynamic> courierData,
  ) {
    final numbers = _getDocumentNumbers(
      courierData,
    );

    int count = 0;

    for (final key in requiredDocumentKeys) {
      if ((numbers[key] ?? '').isNotEmpty) {
        count++;
      }
    }

    return count;
  }

  // ============================================================
  // ADD COURIER
  // ============================================================

  Future<bool> _addCourier() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Courier name enter karein.',
        error: true,
      );
      return false;
    }

    if (email.isEmpty || !email.contains('@')) {
      _showMessage(
        'Valid email enter karein.',
        error: true,
      );
      return false;
    }

    if (phone.isEmpty) {
      _showMessage(
        'Mobile number enter karein.',
        error: true,
      );
      return false;
    }

    if (password.length < 6) {
      _showMessage(
        'Password minimum 6 characters ka hona chahiye.',
        error: true,
      );
      return false;
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

      final data = result.data;

      String courierId = '';

      if (data is Map) {
        courierId = _stringValue(
          data['uid'] ??
              data['courierId'] ??
              data['userId'],
        );
      }

      if (!mounted) return false;

      _showMessage(
        courierId.isEmpty
            ? 'Courier successfully create ho gaya.'
            : 'Courier successfully create ho gaya. ID: $courierId',
      );

      nameController.clear();
      emailController.clear();
      phoneController.clear();
      passwordController.clear();

      return true;
    } on FirebaseFunctionsException catch (e) {
      _showMessage(
        e.message ??
            'Courier create karte waqt error aaya.',
        error: true,
      );
      return false;
    } catch (e) {
      _showMessage(
        'Courier create karte waqt error aaya: $e',
        error: true,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ============================================================
  // APPROVE COURIER
  // ============================================================

  Future<void> _approveCourier(
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    if (!_documentsComplete(courierData)) {
      _showMessage(
        'Approval se pehle PAN, Aadhaar, Driving Licence, Vehicle RC aur Address Proof details complete honi chahiye.',
        error: true,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Approve Courier',
          ),
          content: Text(
            'Kya aap "${_stringValue(courierData['name'])}" ko approve karna chahte hain?\n\n'
            'Approval ke baad courier active hokar orders receive kar sakta hai.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final courierRef =
          _firestore
              .collection('couriers')
              .doc(courierId);

      final userRef =
          _firestore
              .collection('users')
              .doc(courierId);

      final now =
          FieldValue.serverTimestamp();

      final batch = _firestore.batch();

      batch.set(
        courierRef,
        {
          'status': 'approved',
          'registrationStatus': 'approved',
          'active': true,
          'approvedByAdmin': true,
          'approvedAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      batch.set(
        userRef,
        {
          'uid': courierId,
          'role': 'courier',
          'name':
              _stringValue(courierData['name']),
          'email':
              _stringValue(courierData['email']),
          'phone':
              _stringValue(courierData['phone']),
          'status': 'approved',
          'registrationStatus': 'approved',
          'active': true,
          'approvedByAdmin': true,
          'approvedAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      _showMessage(
        'Courier successfully approved.',
      );
    } catch (e) {
      _showMessage(
        'Courier approve karte waqt error aaya: $e',
        error: true,
      );
    }
  }

  // ============================================================
  // REJECT COURIER
  // ============================================================

  Future<void> _rejectCourier(
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    final reasonController =
        TextEditingController();

    final reason =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Reject Courier',
          ),
          content: TextField(
            controller: reasonController,
            maxLines: 4,
            decoration:
                const InputDecoration(
              labelText: 'Rejection Reason',
              hintText:
                  'Reason enter karein',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
              ),
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () {
                final reason =
                    reasonController
                        .text
                        .trim();

                if (reason.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  reason,
                );
              },
              child: const Text(
                'Reject',
              ),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null ||
        reason.trim().isEmpty) {
      return;
    }

    try {
      final courierRef =
          _firestore
              .collection('couriers')
              .doc(courierId);

      final userRef =
          _firestore
              .collection('users')
              .doc(courierId);

      final now =
          FieldValue.serverTimestamp();

      final batch =
          _firestore.batch();

      batch.set(
        courierRef,
        {
          'status': 'rejected',
          'registrationStatus':
              'rejected',
          'active': false,
          'approvedByAdmin': false,
          'rejectionReason':
              reason.trim(),
          'rejectedAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      batch.set(
        userRef,
        {
          'uid': courierId,
          'role': 'courier',
          'name':
              _stringValue(
            courierData['name'],
          ),
          'email':
              _stringValue(
            courierData['email'],
          ),
          'phone':
              _stringValue(
            courierData['phone'],
          ),
          'status': 'rejected',
          'registrationStatus':
              'rejected',
          'active': false,
          'approvedByAdmin': false,
          'rejectionReason':
              reason.trim(),
          'rejectedAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      _showMessage(
        'Courier rejected.',
      );
    } catch (e) {
      _showMessage(
        'Courier reject karte waqt error aaya: $e',
        error: true,
      );
    }
  }

  // ============================================================
  // VIEW COURIER DOCUMENT NUMBERS
  // ============================================================

  Future<void> _showDocumentsDialog(
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    final numbers =
        _getDocumentNumbers(
      courierData,
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.description_outlined,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_stringValue(courierData['name']).isEmpty ? 'Courier' : _stringValue(courierData['name'])} - Documents',
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _infoRow(
                    'Courier ID',
                    courierId,
                  ),
                  const SizedBox(height: 8),

                  ...requiredDocumentKeys
                      .map(
                    (key) {
                      final value =
                          numbers[key] ?? '';

                      final completed =
                          value.isNotEmpty;

                      return Container(
                        width:
                            double.infinity,
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
                          color: completed
                              ? Colors.green
                                  .withOpacity(
                                  0.06,
                                )
                              : Colors.red
                                  .withOpacity(
                                  0.06,
                                ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                          border:
                              Border.all(
                            color: completed
                                ? Colors
                                    .green
                                    .withOpacity(
                                    0.25,
                                  )
                                : Colors
                                    .red
                                    .withOpacity(
                                    0.25,
                                  ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Icon(
                              completed
                                  ? Icons
                                      .check_circle
                                  : Icons
                                      .cancel,
                              color: completed
                                  ? Colors
                                      .green
                                  : Colors
                                      .red,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    _documentTitle(
                                      key,
                                    ),
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Text(
                                    completed
                                        ? value
                                        : 'Not submitted',
                                    style:
                                        TextStyle(
                                      color: completed
                                          ? Colors
                                              .black87
                                          : Colors
                                              .red,
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
                      );
                    },
                  ),

                  if (_stringValue(
                    courierData[
                        'rejectionReason'],
                  ).isNotEmpty)
                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.red.shade50,
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      child: Text(
                        'Previous Rejection:\n'
                        '${_stringValue(courierData['rejectionReason'])}',
                        style: TextStyle(
                          color: Colors
                              .red.shade800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
              ),
              child: const Text(
                'Close',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(
    String title,
    String value,
  ) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              '$title:',
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOGGLE COURIER
  // ============================================================

  Future<void> _toggleCourier(
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    final currentActive =
        courierData['active'] == true;

    if (!currentActive) {
      final status =
          _normalizeStatus(
        courierData['status'],
      );

      final approvedByAdmin =
          courierData[
                  'approvedByAdmin'] ==
              true;

      if (status != 'approved' ||
          !approvedByAdmin) {
        _showMessage(
          'Courier ko active karne se pehle Admin approval zaroori hai.',
          error: true,
        );
        return;
      }
    }

    try {
      final courierRef =
          _firestore
              .collection('couriers')
              .doc(courierId);

      final userRef =
          _firestore
              .collection('users')
              .doc(courierId);

      final updateData = {
        'active': !currentActive,
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      final batch =
          _firestore.batch();

      batch.set(
        courierRef,
        updateData,
        SetOptions(merge: true),
      );

      batch.set(
        userRef,
        updateData,
        SetOptions(merge: true),
      );

      await batch.commit();

      _showMessage(
        currentActive
            ? 'Courier deactivated.'
            : 'Courier activated.',
      );
    } catch (e) {
      _showMessage(
        'Courier status update error: $e',
        error: true,
      );
    }
  }

  // ============================================================
  // DELETE COURIER
  // ============================================================

  Future<void> _deleteCourier(
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    final name =
        _stringValue(
      courierData['name'],
    );

    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Courier',
          ),
          content: Text(
            'Kya aap "$name" ko courier list se delete karna chahte hain?\n\n'
            'Firebase Authentication account automatically delete nahi hoga.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child: const Text(
                'Delete',
              ),
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

      _showMessage(
        'Courier profile deleted.',
      );
    } catch (e) {
      _showMessage(
        'Courier delete karte waqt error aaya: $e',
        error: true,
      );
    }
  }

  // ============================================================
  // EDIT COURIER
  // ============================================================

  Future<void> _showEditCourierDialog(
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    final editNameController =
        TextEditingController(
      text: _stringValue(
        courierData['name'],
      ),
    );

    final editEmailController =
        TextEditingController(
      text: _stringValue(
        courierData['email'],
      ),
    );

    final editPhoneController =
        TextEditingController(
      text: _stringValue(
        courierData['phone'],
      ),
    );

    bool editSaving = false;

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              context,
              setDialogState,
            ) {
              return AlertDialog(
                title: const Text(
                  'Edit Courier',
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
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Name',
                          prefixIcon:
                              Icon(
                            Icons.person,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller:
                            editEmailController,
                        keyboardType:
                            TextInputType
                                .emailAddress,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Email',
                          prefixIcon:
                              Icon(
                            Icons.email,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller:
                            editPhoneController,
                        keyboardType:
                            TextInputType.phone,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Phone',
                          prefixIcon:
                              Icon(
                            Icons.phone,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        editSaving
                            ? null
                            : () =>
                                Navigator.pop(
                              dialogContext,
                            ),
                    child:
                        const Text(
                      'Cancel',
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        editSaving
                            ? null
                            : () async {
                                final name =
                                    editNameController
                                        .text
                                        .trim();

                                final email =
                                    editEmailController
                                        .text
                                        .trim();

                                final phone =
                                    editPhoneController
                                        .text
                                        .trim();

                                if (name.isEmpty ||
                                    email.isEmpty ||
                                    phone.isEmpty) {
                                  _showMessage(
                                    'All fields required hain.',
                                    error:
                                        true,
                                  );
                                  return;
                                }

                                setDialogState(
                                  () {
                                    editSaving =
                                        true;
                                  },
                                );

                                try {
                                  final courierRef =
                                      _firestore
                                          .collection(
                                            'couriers',
                                          )
                                          .doc(
                                            courierId,
                                          );

                                  final userRef =
                                      _firestore
                                          .collection(
                                            'users',
                                          )
                                          .doc(
                                            courierId,
                                          );

                                  final updateData =
                                      {
                                    'name':
                                        name,
                                    'email':
                                        email,
                                    'phone':
                                        phone,
                                    'updatedAt':
                                        FieldValue
                                            .serverTimestamp(),
                                  };

                                  final batch =
                                      _firestore
                                          .batch();

                                  batch.set(
                                    courierRef,
                                    updateData,
                                    SetOptions(
                                      merge:
                                          true,
                                    ),
                                  );

                                  batch.set(
                                    userRef,
                                    updateData,
                                    SetOptions(
                                      merge:
                                          true,
                                    ),
                                  );

                                  await batch
                                      .commit();

                                  if (dialogContext
                                      .mounted) {
                                    Navigator.pop(
                                      dialogContext,
                                    );
                                  }

                                  _showMessage(
                                    'Courier details updated.',
                                  );
                                } catch (e) {
                                  _showMessage(
                                    'Courier update error: $e',
                                    error:
                                        true,
                                  );

                                  if (context
                                      .mounted) {
                                    setDialogState(
                                      () {
                                        editSaving =
                                            false;
                                      },
                                    );
                                  }
                                }
                              },
                    child: editSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save',
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      editNameController.dispose();
      editEmailController.dispose();
      editPhoneController.dispose();
    }
  }

  // ============================================================
  // ADD COURIER DIALOG
  // ============================================================

  Future<void> _showAddCourierDialog() async {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();

    bool dialogSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.delivery_dining,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Add Courier',
                  ),
                ],
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
                          TextCapitalization
                              .words,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Courier Name',
                        prefixIcon:
                            Icon(
                          Icons.person,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    TextField(
                      controller:
                          emailController,
                      keyboardType:
                          TextInputType
                              .emailAddress,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Email',
                        prefixIcon:
                            Icon(
                          Icons.email,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    TextField(
                      controller:
                          phoneController,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Mobile Number',
                        prefixIcon:
                            Icon(
                          Icons.phone,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    TextField(
                      controller:
                          passwordController,
                      obscureText:
                          obscurePassword,
                      decoration:
                          InputDecoration(
                        labelText:
                            'Password',
                        prefixIcon:
                            const Icon(
                          Icons.lock,
                        ),
                        border:
                            const OutlineInputBorder(),
                        suffixIcon:
                            IconButton(
                          onPressed: () {
                            setDialogState(
                              () {
                                obscurePassword =
                                    !obscurePassword;
                              },
                            );
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons
                                    .visibility
                                : Icons
                                    .visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Align(
                      alignment:
                          Alignment.centerLeft,
                      child: Text(
                        'Courier account create hone ke baad courier '
                        'same email/password se login karega. '
                        'Documents courier login ke baad number form mein submit karega.',
                        style:
                            TextStyle(
                          fontSize: 12,
                          color:
                              Colors.grey,
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
                        dialogContext,
                      ),
                  child: const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton(
                  onPressed: dialogSaving
                      ? null
                      : () async {
                          setDialogState(
                            () {
                              dialogSaving =
                                  true;
                            },
                          );

                          final created =
                              await _addCourier();

                          if (!mounted) {
                            return;
                          }

                          setDialogState(
                            () {
                              dialogSaving =
                                  false;
                            },
                          );

                          if (created &&
                              dialogContext
                                  .mounted) {
                            Navigator.pop(
                              dialogContext,
                            );
                          }
                        },
                  child: dialogSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Courier',
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // ORDER ASSIGNMENT
  // ============================================================

  Future<void> _assignOrderToCourier(
    String orderId,
    String courierId,
    String courierName,
  ) async {
    try {
      final callable =
          _functions.httpsCallable(
        'assignOrderToCourier',
      );

      await callable.call({
        'orderId': orderId,
        'courierId': courierId,
      });

      _showMessage(
        'Order assigned to $courierName.',
      );
    } on FirebaseFunctionsException catch (e) {
      _showMessage(
        e.message ??
            'Order assign karte waqt error aaya.',
        error: true,
      );
    } catch (e) {
      _showMessage(
        'Order assign error: $e',
        error: true,
      );
    }
  }

  Future<void> _showAssignOrderDialog(
    String orderId,
  ) async {
    try {
      final courierSnapshot =
          await _firestore
              .collection('couriers')
              .where(
                'active',
                isEqualTo: true,
              )
              .get();

      final couriers =
          courierSnapshot.docs.where(
        (doc) {
          final data = doc.data();

          final status =
              _normalizeStatus(
            data['status'],
          );

          final approvedByAdmin =
              data['approvedByAdmin'] ==
                  true;

          return status ==
                  'approved' &&
              approvedByAdmin;
        },
      ).toList();

      if (!mounted) return;

      if (couriers.isEmpty) {
        _showMessage(
          'Koi approved aur active courier available nahi hai.',
          error: true,
        );
        return;
      }

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Assign Order',
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView
                  .separated(
                shrinkWrap: true,
                itemCount:
                    couriers.length,
                separatorBuilder:
                    (_, __) =>
                        const Divider(
                  height: 1,
                ),
                itemBuilder:
                    (context, index) {
                  final doc =
                      couriers[index];

                  final data =
                      doc.data();

                  final name =
                      _stringValue(
                    data['name'],
                  );

                  final phone =
                      _stringValue(
                    data['phone'],
                  );

                  return ListTile(
                    leading:
                        const CircleAvatar(
                      child: Icon(
                        Icons
                            .delivery_dining,
                      ),
                    ),
                    title: Text(
                      name.isEmpty
                          ? 'Courier'
                          : name,
                    ),
                    subtitle:
                        Text(
                      phone.isEmpty
                          ? 'Approved & Active'
                          : '$phone\nApproved & Active',
                    ),
                    isThreeLine:
                        phone.isNotEmpty,
                    trailing:
                        const Icon(
                      Icons
                          .arrow_forward_ios,
                      size: 16,
                    ),
                    onTap: () async {
                      Navigator.pop(
                        dialogContext,
                      );

                      await _assignOrderToCourier(
                        orderId,
                        doc.id,
                        name.isEmpty
                            ? 'Courier'
                            : name,
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
                  dialogContext,
                ),
                child: const Text(
                  'Cancel',
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showMessage(
        'Courier list load karte waqt error: $e',
        error: true,
      );
    }
  }

  // ============================================================
  // PENDING APPROVAL SECTION
  // ============================================================

  Widget _buildApprovalSection(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        docs,
  ) {
    final pendingCouriers =
        docs.where(
      (doc) {
        final data = doc.data();

        return _normalizeStatus(
              data['status'],
            ) ==
            'pending_approval';
      },
    ).toList();

    if (pendingCouriers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin:
          const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        8,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.pending_actions,
                  color:
                      Colors.orange,
                ),
                const SizedBox(
                  width: 8,
                ),
                const Expanded(
                  child: Text(
                    'Courier Approval Pending',
                    style:
                        TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      Colors.orange,
                  child: Text(
                    '${pendingCouriers.length}',
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            ...pendingCouriers.map(
              (doc) {
                final data =
                    doc.data();

                final name =
                    _stringValue(
                  data['name'],
                );

                final email =
                    _stringValue(
                  data['email'],
                );

                final phone =
                    _stringValue(
                  data['phone'],
                );

                final completed =
                    _completedDocumentCount(
                  data,
                );

                return Container(
                  margin:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),
                  padding:
                      const EdgeInsets.all(
                    10,
                  ),
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                    border:
                        Border.all(
                      color: Colors
                          .orange
                          .shade200,
                    ),
                    color: Colors
                        .orange
                        .shade50,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        name.isEmpty
                            ? 'Courier'
                            : name,
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(email),
                      if (phone.isNotEmpty)
                        Text(phone),
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        'Documents completed: $completed/${requiredDocumentKeys.length}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child:
                                OutlinedButton.icon(
                              onPressed:
                                  () =>
                                      _showDocumentsDialog(
                                doc.id,
                                data,
                              ),
                              icon:
                                  const Icon(
                                Icons
                                    .description,
                              ),
                              label:
                                  const Text(
                                'Documents',
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child:
                                ElevatedButton.icon(
                              onPressed:
                                  _documentsComplete(
                                data,
                              )
                                      ? () =>
                                          _approveCourier(
                                            doc.id,
                                            data,
                                          )
                                      : null,
                              icon:
                                  const Icon(
                                Icons.check,
                              ),
                              label:
                                  const Text(
                                'Approve',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            OutlinedButton
                                .icon(
                          style:
                              OutlinedButton
                                  .styleFrom(
                            foregroundColor:
                                Colors.red,
                          ),
                          onPressed:
                              () =>
                                  _rejectCourier(
                            doc.id,
                            data,
                          ),
                          icon:
                              const Icon(
                            Icons.close,
                          ),
                          label:
                              const Text(
                            'Reject',
                          ),
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
  }

  // ============================================================
  // ORDER ASSIGNMENT SECTION
  // ============================================================

  Widget _buildOrderAssignmentSection() {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: _firestore
          .collection('orders')
          .where(
            'orderStatus',
            isEqualTo: 'Shipped',
          )
          .snapshots(),
      builder:
          (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            margin:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(
                14,
              ),
              child: Text(
                'Orders load error: ${snapshot.error}',
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding:
                EdgeInsets.all(20),
            child: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        final orders =
            snapshot.data!.docs;

        if (orders.isEmpty) {
          return const SizedBox
              .shrink();
        }

        return Card(
          margin:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(
              14,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons
                          .local_shipping,
                      color: Colors.blue,
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Text(
                      'Shipped Orders',
                      style:
                          TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                ...orders.map(
                  (doc) {
                    final data =
                        doc.data();

                    final orderId =
                        _stringValue(
                      data['orderId'],
                    ).isEmpty
                            ? doc.id
                            : _stringValue(
                                data[
                                    'orderId'],
                              );

                    final assignedCourier =
                        _stringValue(
                      data[
                          'courierPersonName'],
                    );

                    final courierId =
                        _stringValue(
                      data[
                          'courierId'],
                    );

                    return Container(
                      margin:
                          const EdgeInsets
                              .only(
                        bottom: 8,
                      ),
                      padding:
                          const EdgeInsets
                              .all(
                        10,
                      ),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                        border:
                            Border.all(
                          color: Colors
                              .grey
                              .shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .inventory_2,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Order: $orderId',
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  assignedCourier
                                          .isEmpty
                                      ? 'Not Assigned'
                                      : 'Courier: $assignedCourier',
                                ),
                                if (courierId
                                    .isNotEmpty)
                                  Text(
                                    'Courier ID: $courierId',
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
                          ElevatedButton(
                            onPressed: () =>
                                _showAssignOrderDialog(
                              doc.id,
                            ),
                            child: Text(
                              assignedCourier
                                      .isEmpty
                                  ? 'Assign'
                                  : 'Change',
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

  // ============================================================
  // COURIER CARD
  // ============================================================

  Widget _buildCourierCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final data = doc.data();

    final courierId = doc.id;

    final name =
        _stringValue(data['name']);

    final email =
        _stringValue(data['email']);

    final phone =
        _stringValue(data['phone']);

    final status =
        _normalizeStatus(
      data['status'],
    );

    final active =
        data['active'] == true;

    final approvedByAdmin =
        data['approvedByAdmin'] ==
            true;

    final completed =
        _completedDocumentCount(
      data,
    );

    final statusColor =
        _statusColor(status);

    return Card(
      margin:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const CircleAvatar(
                  radius: 25,
                  child: Icon(
                    Icons
                        .delivery_dining,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        name.isEmpty
                            ? 'Courier'
                            : name,
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      if (email
                          .isNotEmpty)
                        Text(
                          email,
                          style:
                              const TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      if (phone
                          .isNotEmpty)
                        Text(phone),
                    ],
                  ),
                ),
                PopupMenuButton<
                    String>(
                  onSelected:
                      (value) async {
                    switch (value) {
                      case 'documents':
                        await _showDocumentsDialog(
                          courierId,
                          data,
                        );
                        break;

                      case 'approve':
                        await _approveCourier(
                          courierId,
                          data,
                        );
                        break;

                      case 'reject':
                        await _rejectCourier(
                          courierId,
                          data,
                        );
                        break;

                      case 'edit':
                        await _showEditCourierDialog(
                          courierId,
                          data,
                        );
                        break;

                      case 'toggle':
                        await _toggleCourier(
                          courierId,
                          data,
                        );
                        break;

                      case 'delete':
                        await _deleteCourier(
                          courierId,
                          data,
                        );
                        break;
                    }
                  },
                  itemBuilder:
                      (context) {
                    final items =
                        <PopupMenuEntry<
                            String>>[
                      const PopupMenuItem(
                        value:
                            'documents',
                        child:
                            ListTile(
                          contentPadding:
                              EdgeInsets
                                  .zero,
                          leading:
                              Icon(
                            Icons
                                .description,
                          ),
                          title:
                              Text(
                            'View Documents',
                          ),
                        ),
                      ),
                    ];

                    if (status ==
                        'pending_approval') {
                      items.add(
                        const PopupMenuItem(
                          value:
                              'approve',
                          child:
                              ListTile(
                            contentPadding:
                                EdgeInsets
                                    .zero,
                            leading:
                                Icon(
                              Icons.check,
                              color:
                                  Colors.green,
                            ),
                            title:
                                Text(
                              'Approve',
                            ),
                          ),
                        ),
                      );

                      items.add(
                        const PopupMenuItem(
                          value:
                              'reject',
                          child:
                              ListTile(
                            contentPadding:
                                EdgeInsets
                                    .zero,
                            leading:
                                Icon(
                              Icons.close,
                              color:
                                  Colors.red,
                            ),
                            title:
                                Text(
                              'Reject',
                            ),
                          ),
                        ),
                      );
                    }

                    items.add(
                      const PopupMenuItem(
                        value:
                            'edit',
                        child:
                            ListTile(
                          contentPadding:
                              EdgeInsets
                                  .zero,
                          leading:
                              Icon(
                            Icons.edit,
                          ),
                          title:
                              Text(
                            'Edit',
                          ),
                        ),
                      ),
                    );

                    items.add(
                      PopupMenuItem(
                        value:
                            'toggle',
                        child:
                            ListTile(
                          contentPadding:
                              EdgeInsets
                                  .zero,
                          leading:
                              Icon(
                            active
                                ? Icons
                                    .toggle_off
                                : Icons
                                    .toggle_on,
                          ),
                          title:
                              Text(
                            active
                                ? 'Deactivate'
                                : 'Activate',
                          ),
                        ),
                      ),
                    );

                    items.add(
                      const PopupMenuItem(
                        value:
                            'delete',
                        child:
                            ListTile(
                          contentPadding:
                              EdgeInsets
                                  .zero,
                          leading:
                              Icon(
                            Icons.delete,
                            color:
                                Colors.red,
                          ),
                          title:
                              Text(
                            'Delete',
                          ),
                        ),
                      ),
                    );

                    return items;
                  },
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    _statusLabel(
                      status,
                    ),
                  ),
                  backgroundColor:
                      statusColor
                          .withOpacity(
                    0.12,
                  ),
                  labelStyle:
                      TextStyle(
                    color:
                        statusColor,
                    fontWeight:
                        FontWeight
                            .bold,
                  ),
                ),

                Chip(
                  avatar:
                      Icon(
                    completed ==
                            requiredDocumentKeys
                                .length
                        ? Icons
                            .check_circle
                        : Icons
                            .pending,
                    size: 18,
                    color: completed ==
                            requiredDocumentKeys
                                .length
                        ? Colors.green
                        : Colors.orange,
                  ),
                  label: Text(
                    'Docs $completed/${requiredDocumentKeys.length}',
                  ),
                ),

                if (approvedByAdmin)
                  const Chip(
                    avatar:
                        Icon(
                      Icons.verified,
                      size: 18,
                      color:
                          Colors.green,
                    ),
                    label: Text(
                      'ADMIN APPROVED',
                    ),
                  ),

                if (active &&
                    status ==
                        'approved' &&
                    approvedByAdmin)
                  const Chip(
                    avatar:
                        Icon(
                      Icons.circle,
                      size: 12,
                      color:
                          Colors.green,
                    ),
                    label: Text(
                      'ACTIVE',
                    ),
                  ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Courier ID: $courierId',
              style:
                  const TextStyle(
                fontSize: 12,
                color:
                    Colors.grey,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            if (_stringValue(
              data['registrationType'],
            ).isNotEmpty)
              Text(
                'Registration Type: '
                '${_stringValue(data['registrationType'])}',
                style:
                    const TextStyle(
                  fontSize: 12,
                ),
              ),

            if (_stringValue(
              data['registrationNo'],
            ).isNotEmpty)
              Text(
                'Registration No: '
                '${_stringValue(data['registrationNo'])}',
                style:
                    const TextStyle(
                  fontSize: 12,
                ),
              ),

            if (data['createdAt'] !=
                null)
              Text(
                'Added: ${_dateText(data['createdAt'])}',
                style:
                    const TextStyle(
                  fontSize: 12,
                  color:
                      Colors.grey,
                ),
              ),

            if (_stringValue(
              data['rejectionReason'],
            ).isNotEmpty) ...[
              const SizedBox(
                height: 8,
              ),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.red.shade50,
                  borderRadius:
                      BorderRadius
                          .circular(
                    8,
                  ),
                ),
                child: Text(
                  'Rejection Reason: '
                  '${_stringValue(data['rejectionReason'])}',
                  style:
                      TextStyle(
                    color: Colors
                        .red.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _goBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
            ),
          ),
          title: const Text(
            'Courier Management',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip:
                  'Add Courier',
              onPressed:
                  _showAddCourierDialog,
              icon: const Icon(
                Icons.person_add,
              ),
            ),
          ],
        ),

        floatingActionButton:
            FloatingActionButton
                .extended(
          onPressed:
              _showAddCourierDialog,
          icon: const Icon(
            Icons.add,
          ),
          label: const Text(
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
              .snapshots(),
          builder:
              (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .all(
                    20,
                  ),
                  child: Text(
                    'Courier data load error:\n${snapshot.error}',
                    textAlign:
                        TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot
                    .connectionState ==
                ConnectionState
                    .waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            final docs =
                snapshot.data?.docs ??
                    [];

            return RefreshIndicator(
              onRefresh: () async {
                await _firestore
                    .collection(
                      'couriers',
                    )
                    .limit(1)
                    .get();
              },
              child: ListView(
                padding:
                    const EdgeInsets
                        .only(
                  top: 4,
                  bottom: 90,
                ),
                children: [
                  _buildApprovalSection(
                    docs,
                  ),
                  _buildOrderAssignmentSection(),

                  if (docs.isEmpty)
                    const Padding(
                      padding:
                          EdgeInsets
                              .all(
                        40,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons
                                .delivery_dining,
                            size: 60,
                            color:
                                Colors.grey,
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          Text(
                            'Abhi koi courier available nahi hai.',
                            textAlign:
                                TextAlign
                                    .center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...docs.map(
                      (doc) =>
                          _buildCourierCard(
                        doc,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
