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

class _CourierDocumentsPageState extends State<CourierDocumentsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController panController = TextEditingController();
  final TextEditingController aadhaarController = TextEditingController();
  final TextEditingController drivingLicenceController =
      TextEditingController();
  final TextEditingController vehicleRcController =
      TextEditingController();
  final TextEditingController addressProofController =
      TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  bool documentsSubmitted = false;
  bool approvedByAdmin = false;
  bool active = false;

  String status = 'pending_documents';
  String rejectionReason = '';

  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = widget.courierUid ?? _auth.currentUser?.uid;
    _loadCourierData();
  }

  @override
  void dispose() {
    panController.dispose();
    aadhaarController.dispose();
    drivingLicenceController.dispose();
    vehicleRcController.dispose();
    addressProofController.dispose();
    super.dispose();
  }

  void _message(
    String text, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _loadCourierData() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      _message(
        'Courier login session nahi mili. Please login again.',
        error: true,
      );
      return;
    }

    if (_uid == null || _uid!.isEmpty) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      _message(
        'Courier UID nahi mila. Please login again.',
        error: true,
      );
      return;
    }

    if (currentUser.uid != _uid) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      _message(
        'Courier login session invalid hai. Please login again.',
        error: true,
      );
      return;
    }

    try {
      Map<String, dynamic>? data;

      final courierSnapshot =
          await _firestore.collection('couriers').doc(_uid).get();

      if (courierSnapshot.exists) {
        data = courierSnapshot.data();
      }

      if (data == null) {
        final userSnapshot =
            await _firestore.collection('users').doc(_uid).get();

        if (userSnapshot.exists) {
          data = userSnapshot.data();
        }
      }

      data ??= <String, dynamic>{};

      final dynamic nestedDocuments = data['documents'];

      Map<String, dynamic> documents = {};

      if (nestedDocuments is Map) {
        documents = Map<String, dynamic>.from(nestedDocuments);
      }

      final pan = _readDocumentNumber(
        documents,
        data,
        'pan',
        'panNumber',
      );

      final aadhaar = _readDocumentNumber(
        documents,
        data,
        'aadhaar',
        'aadhaarNumber',
      );

      final drivingLicence = _readDocumentNumber(
        documents,
        data,
        'drivingLicence',
        'drivingLicenceNumber',
      );

      final vehicleRc = _readDocumentNumber(
        documents,
        data,
        'vehicleRc',
        'vehicleRcNumber',
      );

      final addressProof = _readDocumentNumber(
        documents,
        data,
        'addressProof',
        'addressProofNumber',
      );

      panController.text = pan;
      aadhaarController.text = aadhaar;
      drivingLicenceController.text = drivingLicence;
      vehicleRcController.text = vehicleRc;
      addressProofController.text = addressProof;

      if (!mounted) return;

      setState(() {
        documentsSubmitted =
            data?['documentsSubmitted'] == true;

        approvedByAdmin =
            data?['approvedByAdmin'] == true;

        active =
            data?['active'] == true;

        status = (
          data?['status'] ??
          data?['registrationStatus'] ??
          data?['approvalStatus'] ??
          'pending_documents'
        )
            .toString()
            .toLowerCase()
            .trim();

        rejectionReason =
            (data?['rejectionReason'] ?? '').toString();

        isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }

      _message(
        'Data load failed.\nCode: ${e.code}\n${e.message ?? ''}',
        error: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }

      _message(
        'Courier documents load nahi ho paaye.',
        error: true,
      );
    }
  }

  String _readDocumentNumber(
    Map<String, dynamic> documents,
    Map<String, dynamic> data,
    String nestedKey,
    String legacyKey,
  ) {
    final nested = documents[nestedKey];

    if (nested is Map) {
      final value = nested['number'];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    final legacy = data[legacyKey];

    if (legacy != null) {
      return legacy.toString();
    }

    return '';
  }

  bool get _isLocked {
    return approvedByAdmin ||
        active ||
        status == 'pending_approval' ||
        status == 'approved' ||
        status == 'active' ||
        status == 'verified';
  }

  bool get _isRejected {
    return status == 'rejected';
  }

  bool get _canEdit {
    if (approvedByAdmin || active) {
      return false;
    }

    if (status == 'pending_approval') {
      return false;
    }

    return true;
  }

  bool _validateDocuments() {
    if (panController.text.trim().isEmpty) {
      _message(
        'Please enter PAN number.',
        error: true,
      );
      return false;
    }

    if (aadhaarController.text.trim().isEmpty) {
      _message(
        'Please enter Aadhaar number.',
        error: true,
      );
      return false;
    }

    if (drivingLicenceController.text.trim().isEmpty) {
      _message(
        'Please enter Driving Licence number.',
        error: true,
      );
      return false;
    }

    if (vehicleRcController.text.trim().isEmpty) {
      _message(
        'Please enter Vehicle RC number.',
        error: true,
      );
      return false;
    }

    if (addressProofController.text.trim().isEmpty) {
      _message(
        'Please enter Address Proof number.',
        error: true,
      );
      return false;
    }

    return true;
  }

  Future<void> _saveDocumentNumbers({
    bool submit = false,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      _message(
        'Please login again.',
        error: true,
      );
      return;
    }

    if (_uid == null || _uid!.isEmpty) {
      _message(
        'Courier UID missing.',
        error: true,
      );
      return;
    }

    if (currentUser.uid != _uid) {
      _message(
        'Courier login session invalid hai. Please login again.',
        error: true,
      );
      return;
    }

    if (approvedByAdmin || active) {
      _message(
        'Approved courier documents cannot be changed.',
        error: true,
      );
      return;
    }

    if (status == 'pending_approval' && !submit) {
      _message(
        'Documents are already submitted for admin approval.',
        error: true,
      );
      return;
    }

    if (submit && status == 'pending_approval') {
      _message(
        'Documents are already submitted for approval.',
        error: true,
      );
      return;
    }

    if (!_validateDocuments()) {
      return;
    }

    setState(() => isSaving = true);

    try {
      final now = FieldValue.serverTimestamp();

      final documents = <String, dynamic>{
        'pan': {
          'number': panController.text.trim(),
          'status': submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'aadhaar': {
          'number': aadhaarController.text.trim(),
          'status': submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'drivingLicence': {
          'number': drivingLicenceController.text.trim(),
          'status': submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'vehicleRc': {
          'number': vehicleRcController.text.trim(),
          'status': submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'addressProof': {
          'number': addressProofController.text.trim(),
          'status': submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
      };

      final newStatus = submit
          ? 'pending_approval'
          : 'pending_documents';

      /*
       * IMPORTANT:
       * uid + role are deliberately written here.
       *
       * This also fixes old courier documents where uid
       * was missing.
       */
      final courierData = <String, dynamic>{
        'uid': _uid,
        'role': 'courier',

        'documents': documents,

        // Legacy flat fields
        'panNumber': panController.text.trim(),
        'aadhaarNumber': aadhaarController.text.trim(),
        'drivingLicenceNumber':
            drivingLicenceController.text.trim(),
        'vehicleRcNumber':
            vehicleRcController.text.trim(),
        'addressProofNumber':
            addressProofController.text.trim(),

        'documentsSubmitted': submit,
        'status': newStatus,
        'registrationStatus': newStatus,

        /*
         * Courier cannot approve itself.
         */
        'approvedByAdmin': false,
        'active': false,

        'rejectionReason': '',

        'updatedAt': now,
      };

      if (submit) {
        courierData['documentsSubmittedAt'] = now;
      }

      /*
       * First save courier document.
       */
      await _firestore
          .collection('couriers')
          .doc(_uid)
          .set(
            courierData,
            SetOptions(merge: true),
          );

      /*
       * Keep users/{uid} synchronized because login_page
       * checks the user's role/status.
       */
      final userData = <String, dynamic>{
        'uid': _uid,
        'role': 'courier',

        'documentsSubmitted': submit,
        'status': newStatus,
        'registrationStatus': newStatus,

        'approvedByAdmin': false,
        'active': false,

        'rejectionReason': '',

        'updatedAt': now,
      };

      if (submit) {
        userData['documentsSubmittedAt'] = now;
      }

      await _firestore
          .collection('users')
          .doc(_uid)
          .set(
            userData,
            SetOptions(merge: true),
          );

      if (!mounted) return;

      setState(() {
        documentsSubmitted = submit;
        status = newStatus;
        approvedByAdmin = false;
        active = false;
        rejectionReason = '';
      });

      _message(
        submit
            ? 'Documents submitted successfully for admin approval.'
            : 'Documents saved successfully.',
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        _message(
          'Save failed.\nCode: ${e.code}\n${e.message ?? ''}',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _message(
          'Unable to save courier documents.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF5B35D5),
          width: 2,
        ),
      ),
    );
  }

  Widget _documentField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        enabled: _canEdit,
        textCapitalization: TextCapitalization.characters,
        decoration: _decoration(label, icon),
      ),
    );
  }

  Widget _statusCard() {
    Color background;
    Color foreground;
    String title;
    String subtitle;

    if (approvedByAdmin || active) {
      background = Colors.green.shade50;
      foreground = Colors.green.shade800;
      title = 'Courier Approved';
      subtitle =
          'Your courier account has been approved by admin.';
    } else if (status == 'pending_approval') {
      background = Colors.orange.shade50;
      foreground = Colors.orange.shade900;
      title = 'Documents Under Review';
      subtitle =
          'Your documents have been submitted and are waiting for admin approval.';
    } else if (status == 'rejected') {
      background = Colors.red.shade50;
      foreground = Colors.red.shade800;
      title = 'Documents Rejected';
      subtitle = rejectionReason.isEmpty
          ? 'Please update your documents and submit again.'
          : rejectionReason;
    } else {
      background = Colors.blue.shade50;
      foreground = Colors.blue.shade800;
      title = 'Documents Required';
      subtitle =
          'Complete all document details and submit them for approval.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            approvedByAdmin || active
                ? Icons.verified
                : status == 'rejected'
                    ? Icons.error_outline
                    : status == 'pending_approval'
                        ? Icons.hourglass_top
                        : Icons.description_outlined,
            color: foreground,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: foreground,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Courier Documents',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Complete Courier Verification',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your document details carefully. These details will be reviewed by the admin.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _statusCard(),

                    if (_isRejected)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(
                          bottom: 20,
                        ),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Text(
                          rejectionReason.isEmpty
                              ? 'Your previous submission was rejected. You can edit and resubmit.'
                              : 'Reason: $rejectionReason',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    _documentField(
                      controller: panController,
                      label: 'PAN Number',
                      icon: Icons.badge_outlined,
                    ),

                    _documentField(
                      controller: aadhaarController,
                      label: 'Aadhaar Number',
                      icon: Icons.credit_card_outlined,
                    ),

                    _documentField(
                      controller:
                          drivingLicenceController,
                      label: 'Driving Licence Number',
                      icon: Icons.drive_eta_outlined,
                    ),

                    _documentField(
                      controller: vehicleRcController,
                      label: 'Vehicle RC Number',
                      icon: Icons.directions_car_outlined,
                    ),

                    _documentField(
                      controller:
                          addressProofController,
                      label: 'Address Proof Number',
                      icon: Icons.home_outlined,
                    ),

                    const SizedBox(height: 8),

                    if (_isLocked)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Documents are locked because they are already submitted or approved.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    if (!_isLocked) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: isSaving
                              ? null
                              : () => _saveDocumentNumbers(
                                    submit: false,
                                  ),
                          child: isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save Documents',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () => _saveDocumentNumbers(
                                    submit: true,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF5B35D5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Submit for Approval',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
