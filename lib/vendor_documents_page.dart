import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CourierDocumentsPage extends StatefulWidget {
  final String? courierUid;

  const CourierDocumentsPage({
    super.key,
    this.courierUid,
  });

  @override
  State<CourierDocumentsPage> createState() =>
      _CourierDocumentsPageState();
}

class _CourierDocumentsPageState
    extends State<CourierDocumentsPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  bool _loading = true;
  bool _saving = false;
  bool _savingDetails = false;

  String? _uid;

  String _courierName = '';
  String _courierPhone = '';
  String _courierEmail = '';

  String _status = 'pending_documents';

  bool _documentsSubmitted = false;
  bool _active = false;
  bool _approvedByAdmin = false;

  String _registrationType = '';
  String _registrationNo = '';

  String _rejectionReason = '';

  final Map<String, String> _documentNumbers = {};

  final Map<String, String> _documentTitles = {
    'aadhaar': 'Aadhaar / ID Proof',
    'drivingLicence': 'Driving Licence',
    'vehicleRc': 'Vehicle RC',
    'addressProof': 'Address Proof',
    'pan': 'PAN Card',
  };

  final Map<String, String> _documentHints = {
    'aadhaar': 'Example: 123456789012',
    'drivingLicence': 'Example: RJ14 20260012345',
    'vehicleRc': 'Example: RJ01AB1234',
    'addressProof': 'Example: Voter ID / Passport / Other ID No.',
    'pan': 'Example: ABCDE1234F',
  };

  final List<String> _requiredDocumentKeys = const [
    'aadhaar',
    'drivingLicence',
    'vehicleRc',
    'addressProof',
    'pan',
  ];

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();

    _uid = widget.courierUid ??
        _auth.currentUser?.uid;

    for (final key in _requiredDocumentKeys) {
      _controllers[key] =
          TextEditingController();
    }

    _loadCourierData();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // LOAD COURIER DATA
  // ============================================================

  Future<void> _loadCourierData() async {
    if (_uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final courierRef =
          _firestore.collection('couriers').doc(_uid);

      final userRef =
          _firestore.collection('users').doc(_uid);

      final courierSnapshot =
          await courierRef.get();

      Map<String, dynamic> data = {};

      if (courierSnapshot.exists) {
        data = courierSnapshot.data() ?? {};
      } else {
        // --------------------------------------------------------
        // Recover courier profile from users collection.
        // --------------------------------------------------------

        final userSnapshot =
            await userRef.get();

        final userData =
            userSnapshot.data() ?? {};

        final role =
            userData['role']
                    ?.toString()
                    .toLowerCase()
                    .trim() ??
                '';

        if (role == 'courier') {
          data = {
            'uid': _uid,
            'role': 'courier',
            'name':
                userData['name'] ??
                    _auth.currentUser?.displayName ??
                    '',
            'phone':
                userData['phone'] ??
                    _auth.currentUser?.phoneNumber ??
                    '',
            'email':
                userData['email'] ??
                    _auth.currentUser?.email ??
                    '',
            'status':
                userData['status'] ??
                    'pending_documents',
            'registrationStatus':
                userData['registrationStatus'] ??
                    'pending_documents',
            'active':
                userData['active'] == true,
            'documentsSubmitted':
                userData['documentsSubmitted'] == true,
            'approvedByAdmin':
                userData['approvedByAdmin'] == true,
            'documents': {},
          };

          await courierRef.set(
            {
              ...data,
              'createdAt':
                  FieldValue.serverTimestamp(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      // ----------------------------------------------------------
      // BASIC INFORMATION
      // ----------------------------------------------------------

      _courierName =
          data['name']
                  ?.toString()
                  .trim() ??
              '';

      _courierPhone =
          data['phone']
                  ?.toString()
                  .trim() ??
              '';

      _courierEmail =
          data['email']
                  ?.toString()
                  .trim() ??
              '';

      _status =
          _normalizeStatus(
        data['status'] ??
            data['registrationStatus'] ??
            'pending_documents',
      );

      _documentsSubmitted =
          data['documentsSubmitted'] == true;

      _active =
          data['active'] == true;

      _approvedByAdmin =
          data['approvedByAdmin'] == true;

      _registrationType =
          data['registrationType']
                  ?.toString()
                  .trim() ??
              '';

      _registrationNo =
          data['registrationNo']
                  ?.toString()
                  .trim() ??
              '';

      _rejectionReason =
          data['rejectionReason']
                  ?.toString()
                  .trim() ??
              '';

      // ----------------------------------------------------------
      // LOAD DOCUMENT NUMBERS
      // ----------------------------------------------------------

      _documentNumbers.clear();

      final documentsData =
          data['documents'];

      if (documentsData is Map) {
        for (final key in _requiredDocumentKeys) {
          final document =
              documentsData[key];

          if (document is Map) {
            final number =
                document['number']
                        ?.toString()
                        .trim() ??
                    '';

            if (number.isNotEmpty) {
              _documentNumbers[key] =
                  number;
            }
          } else if (document != null) {
            // Compatibility with a simple string format.
            final number =
                document.toString().trim();

            if (number.isNotEmpty) {
              _documentNumbers[key] =
                  number;
            }
          }
        }
      }

      // ----------------------------------------------------------
      // SET CONTROLLERS
      // ----------------------------------------------------------

      for (final key in _requiredDocumentKeys) {
        _controllers[key]!.text =
            _documentNumbers[key] ?? '';
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });

        _showMessage(
          'Courier details load nahi ho paye.\n$e',
          isError: true,
        );
      }
    }
  }

  // ============================================================
  // NORMALIZE STATUS
  // ============================================================

  String _normalizeStatus(dynamic value) {
    return value
            ?.toString()
            .toLowerCase()
            .trim()
            .replaceAll(' ', '_') ??
        '';
  }

  // ============================================================
  // EDIT PERMISSION
  // ============================================================

  bool get _isPendingApproval =>
      _status == 'pending_approval';

  bool get _isApproved =>
      _status == 'approved' &&
      _active &&
      _approvedByAdmin;

  bool get _canEditDocuments {
    if (_isPendingApproval) {
      return false;
    }

    if (_isApproved) {
      return false;
    }

    return true;
  }

  // ============================================================
  // STATUS HEADER
  // ============================================================

  Widget _buildStatusHeader() {
    String title;
    String message;
    IconData icon;
    Color color;

    if (_status == 'pending_documents' ||
        !_documentsSubmitted) {
      title = 'Document Details Pending';

      message =
          'Courier registration successful hai. '
          'Sabhi required document numbers enter karke Admin approval ke liye submit karein.';

      icon = Icons.assignment_outlined;
      color = Colors.orange;
    } else if (_status == 'pending_approval') {
      title = 'Admin Approval Pending';

      message =
          'Aapki application Admin approval ke liye submit ho chuki hai. '
          'Approval milne tak Courier account active nahi hoga.';

      icon = Icons.hourglass_top;
      color = Colors.orange;
    } else if (_status == 'rejected') {
      title = 'Application Rejected';

      message =
          'Admin ne application reject ki hai. '
          'Rejection reason check karke details correct karein aur dobara submit karein.';

      icon = Icons.cancel_outlined;
      color = Colors.red;
    } else if (_isApproved) {
      title = 'Courier Approved';

      message =
          'Aapka Courier account Admin dwara approved aur active hai.';

      icon = Icons.check_circle;
      color = Colors.green;
    } else {
      title = 'Application Status';

      message =
          'Aapka Courier application verification mein hai.';

      icon = Icons.info_outline;
      color = Colors.blue;
    }

    return Card(
      elevation: 3,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(
              alpha: 0.35,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE CARD
  // ============================================================

  Widget _buildCourierProfileCard() {
    final firstLetter =
        _courierName.isNotEmpty
            ? _courierName[0].toUpperCase()
            : 'C';

    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 29,
              child: Text(
                firstLetter,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _courierName.isEmpty
                        ? 'Courier'
                        : _courierName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  if (_courierPhone.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 4,
                      ),
                      child: Text(
                        _courierPhone,
                        style:
                            const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  if (_courierEmail.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 2,
                      ),
                      child: Text(
                        _courierEmail,
                        style:
                            const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REGISTRATION DETAILS
  // ============================================================

  Widget _buildRegistrationDetails() {
    final editable =
        _canEditDocuments &&
        !_savingDetails;

    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Vehicle Registration Details',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _registrationType.isEmpty
                  ? null
                  : _registrationType,
              decoration:
                  const InputDecoration(
                labelText:
                    'Registration Type',
                border:
                    OutlineInputBorder(),
                prefixIcon:
                    Icon(
                  Icons.badge_outlined,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Private',
                  child:
                      Text('Private'),
                ),
                DropdownMenuItem(
                  value: 'Commercial',
                  child:
                      Text('Commercial'),
                ),
                DropdownMenuItem(
                  value: 'Other',
                  child:
                      Text('Other'),
                ),
              ],
              onChanged:
                  editable
                      ? (value) {
                          setState(() {
                            _registrationType =
                                value ?? '';
                          });
                        }
                      : null,
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller:
                  TextEditingController(
                text: _registrationNo,
              ),
              enabled: editable,
              textCapitalization:
                  TextCapitalization.characters,
              decoration:
                  const InputDecoration(
                labelText:
                    'Vehicle Registration No.',
                hintText:
                    'Example: RJ01AB1234',
                border:
                    OutlineInputBorder(),
                prefixIcon:
                    Icon(
                  Icons.confirmation_number_outlined,
                ),
              ),
              onChanged: (value) {
                _registrationNo =
                    value.trim();
              },
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed:
                    editable
                        ? _saveRegistrationDetails
                        : null,
                icon:
                    _savingDetails
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.save_outlined,
                          ),
                label: Text(
                  _savingDetails
                      ? 'Saving...'
                      : 'Save Registration Details',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SAVE REGISTRATION DETAILS
  // ============================================================

  Future<void> _saveRegistrationDetails() async {
    if (_uid == null) return;

    final type =
        _registrationType.trim();

    final number =
        _registrationNo.trim();

    if (type.isEmpty) {
      _showMessage(
        'Registration Type select karein.',
        isError: true,
      );
      return;
    }

    if (number.isEmpty) {
      _showMessage(
        'Vehicle Registration No. enter karein.',
        isError: true,
      );
      return;
    }

    if (mounted) {
      setState(() {
        _savingDetails = true;
      });
    }

    try {
      final courierRef =
          _firestore.collection('couriers').doc(_uid);

      final userRef =
          _firestore.collection('users').doc(_uid);

      final updateData = {
        'registrationType': type,
        'registrationNo': number,
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

      _registrationType = type;
      _registrationNo = number;

      _showMessage(
        'Vehicle registration details save ho gayi.',
      );
    } on FirebaseException catch (e) {
      _showMessage(
        _firebaseErrorMessage(e),
        isError: true,
      );
    } catch (e) {
      _showMessage(
        'Details save nahi ho payi.\n$e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingDetails = false;
        });
      }
    }
  }

  // ============================================================
  // DOCUMENT NUMBER CARD
  // ============================================================

  Widget _buildDocumentCard(
    String key,
  ) {
    final title =
        _documentTitles[key] ?? key;

    final hint =
        _documentHints[key] ?? '';

    final controller =
        _controllers[key]!;

    final editable =
        _canEditDocuments;

    final value =
        controller.text.trim();

    final hasValue =
        value.isNotEmpty;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      BoxDecoration(
                    color:
                        hasValue
                            ? Colors.green
                                .withValues(
                                alpha: 0.10,
                              )
                            : Colors.grey
                                .withValues(
                                alpha: 0.10,
                              ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    hasValue
                        ? Icons.verified_outlined
                        : Icons.badge_outlined,
                    color:
                        hasValue
                            ? Colors.green
                            : Colors.grey
                                .shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                const Text(
                  '*',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextField(
              controller: controller,
              enabled: editable,
              textCapitalization:
                  TextCapitalization.characters,
              keyboardType:
                  TextInputType.text,
              decoration:
                  InputDecoration(
                labelText:
                    '$title Number',
                hintText: hint,
                border:
                    const OutlineInputBorder(),
                prefixIcon:
                    const Icon(
                  Icons.numbers,
                ),
                suffixIcon:
                    hasValue
                        ? const Icon(
                            Icons.check_circle,
                            color:
                                Colors.green,
                          )
                        : null,
              ),
              onChanged: (value) {
                setState(() {
                  _documentNumbers[key] =
                      value.trim();
                });
              },
            ),

            const SizedBox(height: 7),

            Text(
              'Document ki photo upload karne ki zarurat nahi hai.',
              style: TextStyle(
                fontSize: 12,
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CHECK REQUIRED NUMBERS
  // ============================================================

  bool _allRequiredNumbersEntered() {
    for (final key in _requiredDocumentKeys) {
      final value =
          _controllers[key]!
              .text
              .trim();

      if (value.isEmpty) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // SAVE DOCUMENT NUMBERS
  // ============================================================

  Future<void> _saveDocumentNumbers() async {
    if (_uid == null) return;

    if (!_canEditDocuments) {
      _showMessage(
        'Abhi document details edit nahi ki ja sakti.',
        isError: true,
      );
      return;
    }

    if (!_allRequiredNumbersEntered()) {
      _showMessage(
        'Sabhi required document numbers enter karein.',
        isError: true,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final courierRef =
          _firestore.collection('couriers').doc(_uid);

      final userRef =
          _firestore.collection('users').doc(_uid);

      final Map<String, dynamic>
          documents = {};

      for (final key in _requiredDocumentKeys) {
        final number =
            _controllers[key]!
                .text
                .trim();

        documents[key] = {
          'number': number,
          'status': 'pending',
          'updatedAt':
              FieldValue.serverTimestamp(),
          'rejectionReason': '',
        };

        _documentNumbers[key] =
            number;
      }

      final batch =
          _firestore.batch();

      batch.set(
        courierRef,
        {
          'documents': documents,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        userRef,
        {
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      _showMessage(
        'Sabhi document details save ho gayi.',
      );
    } on FirebaseException catch (e) {
      _showMessage(
        _firebaseErrorMessage(e),
        isError: true,
      );
    } catch (e) {
      _showMessage(
        'Document details save nahi ho payi.\n$e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // SUBMIT FOR ADMIN APPROVAL
  // ============================================================

  Future<void> _submitForApproval() async {
    if (_uid == null) return;

    if (!_canEditDocuments) {
      _showMessage(
        'Abhi application submit nahi ki ja sakti.',
        isError: true,
      );
      return;
    }

    if (_registrationType
        .trim()
        .isEmpty) {
      _showMessage(
        'Registration Type select karein.',
        isError: true,
      );
      return;
    }

    if (_registrationNo
        .trim()
        .isEmpty) {
      _showMessage(
        'Vehicle Registration No. enter karein.',
        isError: true,
      );
      return;
    }

    if (!_allRequiredNumbersEntered()) {
      _showMessage(
        'Sabhi 5 required document numbers enter karna zaroori hai.',
        isError: true,
      );
      return;
    }

    try {
      setState(() {
        _saving = true;
      });

      final courierRef =
          _firestore.collection('couriers').doc(_uid);

      final userRef =
          _firestore.collection('users').doc(_uid);

      final now =
          FieldValue.serverTimestamp();

      final Map<String, dynamic>
          documents = {};

      for (final key in _requiredDocumentKeys) {
        final number =
            _controllers[key]!
                .text
                .trim();

        documents[key] = {
          'number': number,
          'status': 'pending',
          'rejectionReason': '',
          'updatedAt': now,
        };
      }

      final batch =
          _firestore.batch();

      // ----------------------------------------------------------
      // COURIER
      // ----------------------------------------------------------

      batch.set(
        courierRef,
        {
          'uid': _uid,
          'role': 'courier',
          'name': _courierName,
          'phone': _courierPhone,
          'email': _courierEmail,
          'registrationType':
              _registrationType.trim(),
          'registrationNo':
              _registrationNo.trim(),
          'documents':
              documents,
          'documentsSubmitted':
              true,
          'status':
              'pending_approval',
          'registrationStatus':
              'pending_approval',
          'active': false,
          'approvedByAdmin':
              false,
          'rejectionReason': '',
          'submittedAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      // ----------------------------------------------------------
      // USERS
      // ----------------------------------------------------------

      batch.set(
        userRef,
        {
          'uid': _uid,
          'role': 'courier',
          'name': _courierName,
          'phone': _courierPhone,
          'email': _courierEmail,
          'registrationType':
              _registrationType.trim(),
          'registrationNo':
              _registrationNo.trim(),
          'documents':
              documents,
          'documentsSubmitted':
              true,
          'status':
              'pending_approval',
          'registrationStatus':
              'pending_approval',
          'active': false,
          'approvedByAdmin':
              false,
          'rejectionReason': '',
          'submittedAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _documentsSubmitted =
            true;
        _status =
            'pending_approval';
        _active = false;
        _approvedByAdmin =
            false;
        _rejectionReason = '';
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) {
          return AlertDialog(
            title:
                const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color:
                      Colors.green,
                ),
                SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    'Submitted Successfully',
                  ),
                ),
              ],
            ),
            content:
                const Text(
              'Aapki Courier details Admin approval ke liye bhej di gayi hain.\n\n'
              'Admin approval ke baad hi Courier account active hoga aur orders assign honge.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(
                  dialogContext,
                ),
                child:
                    const Text('OK'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      _showMessage(
        _firebaseErrorMessage(e),
        isError: true,
      );
    } catch (e) {
      _showMessage(
        'Approval submission failed.\n$e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Widget _buildProgressCard() {
    int completed = 0;

    for (final key in _requiredDocumentKeys) {
      if (_controllers[key]!
          .text
          .trim()
          .isNotEmpty) {
        completed++;
      }
    }

    final total =
        _requiredDocumentKeys.length;

    final progress =
        total == 0
            ? 0.0
            : completed / total;

    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Document Details Progress',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$completed / $total required document numbers entered',
              style: TextStyle(
                color:
                    Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FIREBASE ERROR
  // ============================================================

  String _firebaseErrorMessage(
    FirebaseException e,
  ) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Firebase Firestore Rules check karein.';

      case 'unauthenticated':
        return 'Login session expire ho gaya. Dobara login karein.';

      case 'network-request-failed':
        return 'Internet connection check karein.';

      case 'quota-exceeded':
        return 'Firebase quota exceed ho gaya.';

      default:
        return 'Firebase error: ${e.message ?? e.code}';
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
        backgroundColor:
            isError
                ? Colors.red
                : Colors.green,
        duration:
            const Duration(
          seconds: 4,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_uid == null) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text(
            'Courier Details',
          ),
        ),
        body:
            const Center(
          child: Text(
            'Courier account nahi mila.',
            style:
                TextStyle(
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final isPendingApproval =
        _status ==
            'pending_approval';

    final isApproved =
        _isApproved;

    final canSubmit =
        _canEditDocuments &&
        !_saving;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Courier Verification',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(),

                  const SizedBox(
                    height: 16,
                  ),

                  _buildCourierProfileCard(),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // REJECTION REASON
                  // ==================================================

                  if (_status ==
                          'rejected' &&
                      _rejectionReason
                          .trim()
                          .isNotEmpty)
                    Card(
                      color:
                          Colors.red.shade50,
                      child:
                          Padding(
                        padding:
                            const EdgeInsets.all(
                          14,
                        ),
                        child:
                            Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color:
                                  Colors.red,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Admin Rejection Reason',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          Colors.red,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Text(
                                    _rejectionReason,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_status ==
                          'rejected')
                    const SizedBox(
                      height: 12,
                    ),

                  _buildProgressCard(),

                  const SizedBox(
                    height: 16,
                  ),

                  _buildRegistrationDetails(),

                  const SizedBox(
                    height: 20,
                  ),

                  const Text(
                    'Required Document Numbers',
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  const Text(
                    'Neeche diye gaye 5 document numbers enter karein. Ab kisi document ki photo upload karne ki zarurat nahi hai.',
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  ..._requiredDocumentKeys
                      .map(
                    _buildDocumentCard,
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  // ==================================================
                  // SAVE DETAILS
                  // ==================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height: 48,
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          _canEditDocuments &&
                                  !_saving
                              ? _saveDocumentNumbers
                              : null,
                      icon:
                          _saving
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
                                  Icons.save_outlined,
                                ),
                      label:
                          Text(
                        _saving
                            ? 'Saving...'
                            : 'Save Document Details',
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ==================================================
                  // SUBMIT
                  // ==================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height: 52,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          canSubmit
                              ? _submitForApproval
                              : null,
                      icon:
                          Icon(
                        isPendingApproval
                            ? Icons.hourglass_top
                            : isApproved
                                ? Icons.check_circle
                                : Icons.send,
                      ),
                      label:
                          Text(
                        isPendingApproval
                            ? 'Waiting for Admin Approval'
                            : isApproved
                                ? 'Courier Approved'
                                : 'Submit for Admin Approval',
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // SECURITY INFORMATION
                  // ==================================================

                  Card(
                    child:
                        Padding(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),
                      child:
                          Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.security,
                            color:
                                Colors.blue.shade700,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          const Expanded(
                            child:
                                Text(
                              'Admin approval ke bina Courier account active nahi hoga aur koi order assign nahi kiya jayega.',
                              style:
                                  TextStyle(
                                fontSize:
                                    12,
                                height:
                                    1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),
                ],
              ),
            ),

            // ========================================================
            // SAVING OVERLAY
            // ========================================================

            if (_saving)
              Container(
                color:
                    Colors.black
                        .withValues(
                  alpha: 0.35,
                ),
                child:
                    const Center(
                  child:
                      Card(
                    child:
                        Padding(
                      padding:
                          EdgeInsets.all(
                        24,
                      ),
                      child:
                          Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(
                            height: 16,
                          ),
                          Text(
                            'Please wait...',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
