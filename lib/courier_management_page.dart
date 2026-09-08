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
  // HELPERS
  // ============================================================

  String _stringValue(dynamic value) {
    if (value == null) return '';

    final text = value.toString().trim();

    if (text == 'null') return '';

    return text;
  }

  String _normalizeStatus(dynamic value) {
    final status =
        _stringValue(value).toLowerCase();

    switch (status) {
      case 'pending_documents':
      case 'pending documents':
        return 'pending_documents';

      case 'pending_approval':
      case 'pending approval':
        return 'pending_approval';

      case 'approved':
        return 'approved';

      case 'rejected':
        return 'rejected';

      default:
        return status;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_documents':
        return 'DOCUMENTS PENDING';

      case 'pending_approval':
        return 'PENDING APPROVAL';

      case 'approved':
        return 'APPROVED';

      case 'rejected':
        return 'REJECTED';

      default:
        return status.isEmpty
            ? 'NOT SUBMITTED'
            : status.toUpperCase();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_documents':
        return Colors.orange;

      case 'pending_approval':
        return Colors.blue;

      case 'approved':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  String _normalizeOrderStatus(dynamic value) {
    if (value == null) return 'Placed';

    final status = value.toString().trim();

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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // ADD COURIER
  // ============================================================

  Future<void> _addCourier() async {
    final name = nameController.text.trim();

    final email =
        emailController.text.trim().toLowerCase();

    final phone =
        phoneController.text.trim();

    final password =
        passwordController.text;

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

  // ============================================================
  // UPDATE COURIER
  // ============================================================

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
        'updatedAt': FieldValue.serverTimestamp(),
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

  // ============================================================
  // APPROVE COURIER
  // ============================================================

  Future<void> _approveCourier(
    String courierId,
    Map<String, dynamic> data,
  ) async {
    final name =
        _stringValue(data['name']).isNotEmpty
            ? _stringValue(data['name'])
            : 'Courier';

    final documentsSubmitted =
        data['documentsSubmitted'] == true;

    if (!documentsSubmitted) {
      _showMessage(
        '$name has not submitted all required documents.',
      );
      return;
    }

    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Approve Courier?',
          ),
          content: Text(
            'Approve $name as an active Preesho courier?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              icon: const Icon(
                Icons.check_circle,
              ),
              label:
                  const Text('Approve'),
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
          .update({
        'status': 'approved',
        'registrationStatus': 'approved',
        'active': true,
        'approvedByAdmin': true,
        'approvedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      // Keep users collection in sync.
      await _firestore
          .collection('users')
          .doc(courierId)
          .set({
        'uid': courierId,
        'role': 'courier',
        'name': name,
        'status': 'approved',
        'registrationStatus': 'approved',
        'active': true,
        'approvedByAdmin': true,
        'approvedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _showMessage(
          '$name approved successfully. Courier is now ACTIVE.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to approve courier.\n$e',
        );
      }
    }
  }

  // ============================================================
  // REJECT COURIER
  // ============================================================

  Future<void> _rejectCourier(
    String courierId,
    Map<String, dynamic> data,
  ) async {
    final name =
        _stringValue(data['name']).isNotEmpty
            ? _stringValue(data['name'])
            : 'Courier';

    final reasonController =
        TextEditingController();

    final reason =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Reject Courier',
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Reason for rejecting $name',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              TextField(
                controller:
                    reasonController,
                maxLines: 4,
                decoration:
                    const InputDecoration(
                  hintText:
                      'Example: Driving licence is not clear.',
                  border:
                      OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed: () {
                final reason =
                    reasonController
                        .text
                        .trim();

                Navigator.pop(
                  context,
                  reason.isEmpty
                      ? 'Documents/details need correction.'
                      : reason,
                );
              },
              child:
                  const Text('Reject'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null) return;

    try {
      await _firestore
          .collection('couriers')
          .doc(courierId)
          .update({
        'status': 'rejected',
        'registrationStatus': 'rejected',
        'active': false,
        'approvedByAdmin': false,
        'rejectionReason': reason,
        'rejectedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('users')
          .doc(courierId)
          .set({
        'status': 'rejected',
        'registrationStatus': 'rejected',
        'active': false,
        'approvedByAdmin': false,
        'rejectionReason': reason,
        'rejectedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _showMessage(
          '$name rejected. Courier can correct documents and resubmit.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to reject courier.\n$e',
        );
      }
    }
  }

  // ============================================================
  // DOCUMENT VIEWER
  // ============================================================

  void _showDocumentsDialog(
    String courierId,
    Map<String, dynamic> data,
  ) {
    final name =
        _stringValue(data['name']).isNotEmpty
            ? _stringValue(data['name'])
            : 'Courier';

    final documents =
        data['documents'] is Map
            ? Map<String, dynamic>.from(
                data['documents'] as Map,
              )
            : <String, dynamic>{};

    final registrationType =
        _stringValue(
      data['registrationType'],
    );

    final registrationNo =
        _stringValue(
      data['registrationNo'],
    );

    final rejectionReason =
        _stringValue(
      data['rejectionReason'],
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '$name - Documents',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width:
                double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  if (registrationType
                          .isNotEmpty ||
                      registrationNo
                          .isNotEmpty)
                    Card(
                      child:
                          Padding(
                        padding:
                            const EdgeInsets
                                .all(
                          12,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Registration Details',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            if (registrationType
                                .isNotEmpty)
                              Text(
                                'Type: $registrationType',
                              ),
                            if (registrationNo
                                .isNotEmpty)
                              Text(
                                'Number: $registrationNo',
                              ),
                          ],
                        ),
                      ),
                    ),

                  if (rejectionReason
                      .isNotEmpty)
                    Container(
                      width:
                          double.infinity,
                      margin:
                          const EdgeInsets
                              .only(
                        bottom: 12,
                      ),
                      padding:
                          const EdgeInsets
                              .all(
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
                        border:
                            Border.all(
                          color:
                              Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        'Previous rejection: $rejectionReason',
                        style:
                            TextStyle(
                          color:
                              Colors.red.shade800,
                        ),
                      ),
                    ),

                  const Text(
                    'Uploaded Documents',
                    style:
                        TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  _documentPreview(
                    'Profile Photo',
                    documents[
                        'profilePhoto'],
                  ),

                  _documentPreview(
                    'Aadhaar Card',
                    documents[
                        'aadhaar'],
                  ),

                  _documentPreview(
                    'Driving Licence',
                    documents[
                        'drivingLicence'],
                  ),

                  _documentPreview(
                    'Vehicle RC',
                    documents[
                        'vehicleRc'],
                  ),

                  _documentPreview(
                    'Address Proof',
                    documents[
                        'addressProof'],
                  ),
                ],
              ),
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

  Widget _documentPreview(
    String title,
    dynamic rawDocument,
  ) {
    Map<String, dynamic> document = {};

    if (rawDocument is Map) {
      document =
          Map<String, dynamic>.from(
        rawDocument,
      );
    }

    final url =
        _stringValue(
      document['url'],
    );

    final status =
        _stringValue(
      document['status'],
    );

    final rejectionReason =
        _stringValue(
      document['rejectionReason'],
    );

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          ListTile(
            dense: true,
            title: Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            trailing:
                status.isEmpty
                    ? null
                    : Text(
                        status.toUpperCase(),
                        style:
                            TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              status ==
                                      'approved'
                                  ? Colors
                                      .green
                                  : status ==
                                          'rejected'
                                      ? Colors
                                          .red
                                      : Colors
                                          .orange,
                        ),
                      ),
          ),

          if (url.isNotEmpty)
            SizedBox(
              height: 220,
              width:
                  double.infinity,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder:
                    (
                  context,
                  error,
                  stack,
                ) {
                  return const Center(
                    child: Text(
                      'Document image could not be loaded.',
                    ),
                  );
                },
                loadingBuilder:
                    (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress ==
                      null) {
                    return child;
                  }

                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                },
              ),
            )
          else
            const Padding(
              padding:
                  EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Document not uploaded',
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),
              ),
            ),

          if (rejectionReason
              .isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              child: Text(
                'Reason: $rejectionReason',
                style:
                    const TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // TOGGLE
  // ============================================================

  Future<void> _toggleCourier(
    String courierId,
    bool currentStatus,
  ) async {
    // Never allow an unapproved courier
    // to become active.
    if (!currentStatus) {
      final snapshot =
          await _firestore
              .collection('couriers')
              .doc(courierId)
              .get();

      final data =
          snapshot.data() ?? {};

      final approved =
          _normalizeStatus(
                data['status'],
              ) ==
              'approved' &&
          data['approvedByAdmin'] ==
              true;

      if (!approved) {
        _showMessage(
          'Courier must be approved by Admin before activation.',
        );
        return;
      }
    }

    await _updateCourier(
      courierId,
      {
        'active': !currentStatus,
      },
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteCourier(
    String courierId,
  ) async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Courier?',
          ),
          content: const Text(
            'The courier record will be removed from '
            'Courier Management. Firebase Authentication '
            'account and existing order history will not '
            'be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child:
                  const Text('Delete'),
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
        _showMessage(
          'Courier removed.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to delete courier.\n$e',
        );
      }
    }
  }

  // ============================================================
  // ADD DIALOG
  // ============================================================

  void _showAddCourierDialog() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();

    obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible:
          !saving,
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
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.bold,
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
                          TextCapitalization
                              .words,
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
                    const SizedBox(
                      height: 14,
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
                    const SizedBox(
                      height: 14,
                    ),
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
                    const SizedBox(
                      height: 14,
                    ),
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
                    const SizedBox(
                      height: 8,
                    ),
                    const Align(
                      alignment:
                          Alignment.centerLeft,
                      child: Text(
                        'Minimum 6 characters',
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
                  onPressed:
                      dialogSaving
                          ? null
                          : () =>
                              Navigator.pop(
                            context,
                          ),
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      dialogSaving
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
                            strokeWidth:
                                2,
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

  // ============================================================
  // EDIT DIALOG
  // ============================================================

  void _showEditCourierDialog(
    String courierId,
    Map<String, dynamic> data,
  ) {
    final editNameController =
        TextEditingController(
      text:
          _stringValue(
        data['name'],
      ),
    );

    final editEmailController =
        TextEditingController(
      text:
          _stringValue(
        data['email'],
      ),
    );

    final editPhoneController =
        TextEditingController(
      text:
          _stringValue(
        data['phone'],
      ),
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
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.bold,
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
                          TextCapitalization
                              .words,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Courier Name',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
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
                            'Courier Email',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
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
                  onPressed:
                      updating
                          ? null
                          : () =>
                              Navigator.pop(
                            context,
                          ),
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                FilledButton(
                  onPressed:
                      updating
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
                                  'name':
                                      name,
                                  'email':
                                      email,
                                  'phone':
                                      phone,
                                },
                              );

                              // Keep users name in sync.
                              await _firestore
                                  .collection(
                                    'users',
                                  )
                                  .doc(
                                    courierId,
                                  )
                                  .set({
                                'name':
                                    name,
                                'email':
                                    email,
                                'phone':
                                    phone,
                                'updatedAt':
                                    FieldValue
                                        .serverTimestamp(),
                              }, SetOptions(
                                merge:
                                    true,
                              ));

                              if (context
                                  .mounted) {
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
                            strokeWidth:
                                2,
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
  }

  // ============================================================
  // ORDER ASSIGNMENT
  // ============================================================

  Future<void> _assignOrderToCourier(
    String orderId,
    String courierId,
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

      if (mounted) {
        _showMessage(
          'Order assigned to courier successfully.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      String message =
          e.message ??
              'Unable to assign order to courier.';

      switch (e.code) {
        case 'unauthenticated':
          message =
              'Please login again as Admin.';
          break;

        case 'permission-denied':
          message =
              e.message ??
                  'Only Admin can assign courier.';
          break;

        case 'not-found':
          message =
              e.message ??
                  'Order or courier not found.';
          break;

        case 'failed-precondition':
          message =
              e.message ??
                  'This order is not eligible for courier assignment.';
          break;

        case 'invalid-argument':
          message =
              e.message ??
                  'Invalid order or courier details.';
          break;
      }

      _showMessage(message);
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

  Future<void> _showAssignOrderDialog(
    DocumentSnapshot<Map<String, dynamic>>
        orderDoc,
  ) async {
    final orderData =
        orderDoc.data() ?? {};

    final orderId =
        _stringValue(
              orderData['orderId'],
            ).isNotEmpty
            ? _stringValue(
                orderData['orderId'],
              )
            : orderDoc.id;

    final currentCourierId =
        _stringValue(
      orderData['courierId'],
    );

    final currentStatus =
        _normalizeOrderStatus(
      orderData['orderStatus'] ??
          orderData['status'],
    );

    if (currentStatus != 'Shipped') {
      _showMessage(
        'Only Shipped orders can be assigned to a courier.',
      );
      return;
    }

    try {
      // IMPORTANT:
      // Only ADMIN-APPROVED + ACTIVE couriers
      // can receive orders.
      final courierSnapshot =
          await _firestore
              .collection('couriers')
              .where(
                'active',
                isEqualTo: true,
              )
              .where(
                'status',
                isEqualTo: 'approved',
              )
              .where(
                'approvedByAdmin',
                isEqualTo: true,
              )
              .get();

      if (!mounted) return;

      final couriers =
          courierSnapshot.docs;

      if (couriers.isEmpty) {
        _showMessage(
          'No approved active couriers available.',
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
              width:
                  double.maxFinite,
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
                      _stringValue(
                                data['name'],
                              )
                              .isNotEmpty
                          ? _stringValue(
                              data['name'],
                            )
                          : 'Courier';

                  final email =
                      _stringValue(
                    data['email'],
                  );

                  final phone =
                      _stringValue(
                    data['phone'],
                  );

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
                    trailing:
                        selected
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
                        orderId,
                        courier.id,
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
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to load approved couriers.\n$e',
      );
    }
  }

  // ============================================================
  // ORDER ASSIGNMENT SECTION
  // ============================================================

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
                        _stringValue(
                              data['orderId'],
                            ).isNotEmpty
                            ? _stringValue(
                                data['orderId'],
                              )
                            : doc.id;

                    final customer =
                        _stringValue(
                              data[
                                  'customerName'],
                            ).isNotEmpty
                            ? _stringValue(
                                data[
                                    'customerName'],
                              )
                            : _stringValue(
                                  data['name'],
                                ).isNotEmpty
                                ? _stringValue(
                                    data['name'],
                                  )
                                : 'Customer';

                    final assignedCourierId =
                        _stringValue(
                      data['courierId'],
                    );

                    final assignedName =
                        _stringValue(
                      data[
                          'courierPersonName'],
                    );

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

  // ============================================================
  // PENDING COURIER APPROVAL
  // ============================================================

  Widget _buildApprovalSection(
    List<QueryDocumentSnapshot<
            Map<String, dynamic>>>
        docs,
  ) {
    final pending =
        docs.where((doc) {
      final data = doc.data();

      final status =
          _normalizeStatus(
        data['status'],
      );

      return status ==
          'pending_approval';
    }).toList();

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
            Row(
              children: [
                const Icon(
                  Icons
                      .verified_user_outlined,
                ),
                const SizedBox(
                  width: 10,
                ),
                const Expanded(
                  child: Text(
                    'Courier Approval',
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        pending.isEmpty
                            ? Colors
                                .grey
                                .shade100
                            : Colors
                                .orange
                                .shade100,
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                  ),
                  child: Text(
                    '${pending.length} Pending',
                    style:
                        TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          pending.isEmpty
                              ? Colors.grey
                              : Colors.orange
                                  .shade800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Courier documents submitted for Admin approval.',
              style: TextStyle(
                color:
                    Colors.black54,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            if (pending.isEmpty)
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .all(
                  18,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey.shade50,
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
                child:
                    const Row(
                  children: [
                    Icon(
                      Icons
                          .check_circle_outline,
                      color:
                          Colors.grey,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        'No courier is waiting for approval.',
                        style:
                            TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...pending.map(
                (doc) {
                  final data =
                      doc.data();

                  final name =
                      _stringValue(
                                data[
                                    'name'],
                              )
                              .isNotEmpty
                          ? _stringValue(
                              data[
                                  'name'],
                            )
                          : 'Unnamed Courier';

                  final email =
                      _stringValue(
                    data['email'],
                  );

                  final phone =
                      _stringValue(
                    data['phone'],
                  );

                  final documentsSubmitted =
                      data[
                              'documentsSubmitted'] ==
                          true;

                  return Container(
                    margin:
                        const EdgeInsets
                            .only(
                      bottom: 12,
                    ),
                    padding:
                        const EdgeInsets
                            .all(
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      border: Border.all(
                        color: Colors
                            .orange
                            .shade200,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              child:
                                  const Icon(
                                Icons
                                    .local_shipping_outlined,
                              ),
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
                                    name,
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          16,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
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
                                ],
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    8,
                                vertical:
                                    4,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.blue
                                        .shade50,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                              ),
                              child:
                                  const Text(
                                'PENDING',
                                style:
                                    TextStyle(
                                  fontSize:
                                      10,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  color:
                                      Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Row(
                          children: [
                            Expanded(
                              child:
                                  OutlinedButton
                                      .icon(
                                onPressed:
                                    () {
                                  _showDocumentsDialog(
                                    doc.id,
                                    data,
                                  );
                                },
                                icon:
                                    const Icon(
                                  Icons
                                      .description_outlined,
                                ),
                                label:
                                    const Text(
                                  'View Documents',
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child:
                                  FilledButton
                                      .icon(
                                onPressed:
                                    documentsSubmitted
                                        ? () {
                                            _approveCourier(
                                              doc.id,
                                              data,
                                            );
                                          }
                                        : null,
                                icon:
                                    const Icon(
                                  Icons
                                      .check_circle_outline,
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
                                () {
                              _rejectCourier(
                                doc.id,
                                data,
                              );
                            },
                            icon:
                                const Icon(
                              Icons
                                  .cancel_outlined,
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
              // ==================================================
              // APPROVAL
              // ==================================================

              _buildApprovalSection(
                docs,
              ),

              // ==================================================
              // ORDER ASSIGNMENT
              // ==================================================

              _buildOrderAssignmentSection(),

              // ==================================================
              // ALL COURIERS
              // ==================================================

              const Padding(
                padding:
                    EdgeInsets.only(
                  bottom: 12,
                ),
                child: Text(
                  'All Couriers',
                  style:
                      TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

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

                  // IMPORTANT:
                  // Always use the name stored in
                  // couriers/{uid}.name.
                  final name =
                      _stringValue(
                                data['name'],
                              )
                              .isNotEmpty
                          ? _stringValue(
                              data['name'],
                            )
                          : 'Unnamed Courier';

                  final email =
                      _stringValue(
                    data['email'],
                  );

                  final phone =
                      _stringValue(
                    data['phone'],
                  );

                  final active =
                      data['active'] ==
                          true;

                  final approved =
                      _normalizeStatus(
                            data['status'],
                          ) ==
                          'approved';

                  final approvedByAdmin =
                      data[
                              'approvedByAdmin'] ==
                          true;

                  final status =
                      _normalizeStatus(
                    data['status'],
                  );

                  final createdAt =
                      data['createdAt'];

                  final documentsSubmitted =
                      data[
                              'documentsSubmitted'] ==
                          true;

                  final rejectionReason =
                      _stringValue(
                    data[
                        'rejectionReason'],
                  );

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
                                  color: approved &&
                                          active
                                      ? Colors
                                          .green
                                      : _statusColor(
                                          status,
                                        ),
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
                                      'documents') {
                                    _showDocumentsDialog(
                                      doc.id,
                                      data,
                                    );
                                  }

                                  if (value ==
                                      'approve') {
                                    _approveCourier(
                                      doc.id,
                                      data,
                                    );
                                  }

                                  if (value ==
                                      'reject') {
                                    _rejectCourier(
                                      doc.id,
                                      data,
                                    );
                                  }

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
                                  final items =
                                      <PopupMenuEntry<
                                          String>>[
                                    const PopupMenuItem(
                                      value:
                                          'documents',
                                      child:
                                          Row(
                                        children: [
                                          Icon(
                                            Icons
                                                .description_outlined,
                                          ),
                                          SizedBox(
                                            width:
                                                10,
                                          ),
                                          Text(
                                            'View Documents',
                                          ),
                                        ],
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
                                            Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .check_circle_outline,
                                              color:
                                                  Colors.green,
                                            ),
                                            SizedBox(
                                              width:
                                                  10,
                                            ),
                                            Text(
                                              'Approve',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    items.add(
                                      const PopupMenuItem(
                                        value:
                                            'reject',
                                        child:
                                            Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .cancel_outlined,
                                              color:
                                                  Colors.red,
                                            ),
                                            SizedBox(
                                              width:
                                                  10,
                                            ),
                                            Text(
                                              'Reject',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  items.add(
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
                                  );

                                  items.add(
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
                                  );

                                  items.add(
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
                                  );

                                  return items;
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
                                  color:
                                      _statusColor(
                                    status,
                                  ).withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                                child:
                                    Text(
                                  _statusLabel(
                                    status,
                                  ),
                                  style:
                                      TextStyle(
                                    fontSize:
                                        10,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color:
                                        _statusColor(
                                      status,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              if (approvedByAdmin)
                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        8,
                                    vertical:
                                        5,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        Colors
                                            .green
                                            .shade50,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      20,
                                    ),
                                  ),
                                  child:
                                      const Text(
                                    'ADMIN APPROVED',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          9,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      color:
                                          Colors
                                              .green,
                                    ),
                                  ),
                                ),

                              const Spacer(),

                              if (documentsSubmitted)
                                const Icon(
                                  Icons
                                      .description,
                                  size: 16,
                                  color:
                                      Colors.green,
                                ),

                              const SizedBox(
                                width: 6,
                              ),

                              if (active &&
                                  approved)
                                const Text(
                                  'ACTIVE',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        11,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color:
                                        Colors
                                            .green,
                                  ),
                                )
                              else if (createdAt !=
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

                          if (rejectionReason
                              .isNotEmpty)
                            Container(
                              width:
                                  double.infinity,
                              margin:
                                  const EdgeInsets
                                      .only(
                                top: 12,
                              ),
                              padding:
                                  const EdgeInsets
                                      .all(
                                10,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.red
                                        .shade50,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  10,
                                ),
                              ),
                              child:
                                  Text(
                                'Rejection reason: $rejectionReason',
                                style:
                                    TextStyle(
                                  fontSize:
                                      12,
                                  color:
                                      Colors.red
                                          .shade800,
                                ),
                              ),
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
