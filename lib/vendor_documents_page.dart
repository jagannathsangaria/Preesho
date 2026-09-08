import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorDocumentsPage extends StatefulWidget {
  final String? vendorUid;

  const VendorDocumentsPage({
    super.key,
    this.vendorUid,
  });

  @override
  State<VendorDocumentsPage> createState() =>
      _VendorDocumentsPageState();
}

class _VendorDocumentsPageState
    extends State<VendorDocumentsPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  bool _loading = true;
  bool _saving = false;

  String? _uid;

  String _vendorName = '';
  String _vendorPhone = '';
  String _vendorEmail = '';

  String _status = 'pending_documents';

  bool _documentsSubmitted = false;
  bool _active = false;
  bool _approvedByAdmin = false;

  String _rejectionReason = '';

  final Map<String, TextEditingController>
      _controllers = {};

  final Map<String, String>
      _documentTitles = {
    'pan': 'PAN Card',
    'aadhaar': 'Aadhaar / ID Proof',
    'gst': 'GST Number',
    'bank': 'Bank Account / Details',
    'addressProof': 'Address Proof',
  };

  final Map<String, String>
      _documentHints = {
    'pan': 'ABCDE1234F',
    'aadhaar': '123456789012',
    'gst': '08ABCDE1234F1Z5',
    'bank': 'Account Number / Bank Details',
    'addressProof':
        'Voter ID / Passport / Other ID Number',
  };

  final List<String>
      _requiredDocumentKeys = const [
    'pan',
    'aadhaar',
    'gst',
    'bank',
    'addressProof',
  ];

  @override
  void initState() {
    super.initState();

    _uid = widget.vendorUid ??
        _auth.currentUser?.uid;

    for (final key in _requiredDocumentKeys) {
      _controllers[key] =
          TextEditingController();
    }

    _loadVendorData();
  }

  @override
  void dispose() {
    for (final controller
        in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // LOAD VENDOR
  // ============================================================

  Future<void> _loadVendorData() async {
    if (_uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final vendorRef =
          _firestore.collection('vendors').doc(_uid);

      final userRef =
          _firestore.collection('users').doc(_uid);

      final vendorSnapshot =
          await vendorRef.get();

      Map<String, dynamic> data = {};

      if (vendorSnapshot.exists) {
        data =
            vendorSnapshot.data() ?? {};
      } else {
        final userSnapshot =
            await userRef.get();

        final userData =
            userSnapshot.data() ?? {};

        final role =
            (userData['role'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (role == 'vendor') {
          data = {
            'uid': _uid,
            'role': 'vendor',
            'name':
                userData['name'] ??
                    _auth.currentUser
                        ?.displayName ??
                    '',
            'phone':
                userData['phone'] ??
                    _auth.currentUser
                        ?.phoneNumber ??
                    '',
            'email':
                userData['email'] ??
                    _auth.currentUser
                        ?.email ??
                    '',
            'status':
                userData['status'] ??
                    'pending_documents',
            'registrationStatus':
                userData[
                        'registrationStatus'] ??
                    'pending_documents',
            'active':
                userData['active'] == true,
            'documentsSubmitted':
                userData[
                        'documentsSubmitted'] ==
                    true,
            'approvedByAdmin':
                userData[
                        'approvedByAdmin'] ==
                    true,
            'documents': {},
          };

          await vendorRef.set(
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

      _vendorName =
          (data['name'] ?? '')
              .toString()
              .trim();

      _vendorPhone =
          (data['phone'] ?? '')
              .toString()
              .trim();

      _vendorEmail =
          (data['email'] ?? '')
              .toString()
              .trim();

      _status = _normalizeStatus(
        data['status'] ??
            data['registrationStatus'] ??
            'pending_documents',
      );

      _documentsSubmitted =
          data['documentsSubmitted'] ==
              true;

      _active =
          data['active'] == true;

      _approvedByAdmin =
          data['approvedByAdmin'] ==
              true;

      _rejectionReason =
          (data['rejectionReason'] ?? '')
              .toString()
              .trim();

      final documents =
          data['documents'];

      if (documents is Map) {
        for (final key
            in _requiredDocumentKeys) {
          final document =
              documents[key];

          String number = '';

          if (document is Map) {
            number =
                (document['number'] ?? '')
                    .toString()
                    .trim();
          } else if (document != null) {
            number =
                document.toString().trim();
          }

          _controllers[key]!.text =
              number;
        }
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
          'Vendor details load nahi ho paye.',
          error: true,
        );
      }
    }
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _normalizeStatus(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');
  }

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
  // STATUS INFORMATION
  // ============================================================

  String get _statusTitle {
    if (_status == 'pending_documents' ||
        !_documentsSubmitted) {
      return 'KYC Details Required';
    }

    if (_status == 'pending_approval') {
      return 'Admin Approval Pending';
    }

    if (_status == 'rejected') {
      return 'Application Rejected';
    }

    if (_isApproved) {
      return 'Vendor Approved';
    }

    return 'Application Under Review';
  }

  String get _statusMessage {
    if (_status == 'pending_documents' ||
        !_documentsSubmitted) {
      return 'Required KYC details complete karke '
          'Admin approval ke liye submit karein.';
    }

    if (_status == 'pending_approval') {
      return 'Aapki KYC details Admin ko bhej di gayi hain. '
          'Approval ka wait karein.';
    }

    if (_status == 'rejected') {
      return 'Admin ne application reject ki hai. '
          'Reason check karke details correct karein.';
    }

    if (_isApproved) {
      return 'Aapka Vendor account Admin dwara '
          'approved aur active hai.';
    }

    return 'Aapka Vendor application verification mein hai.';
  }

  Color get _statusColor {
    if (_status == 'rejected') {
      return Colors.red;
    }

    if (_isApproved) {
      return Colors.green;
    }

    if (_status == 'pending_approval') {
      return Colors.orange;
    }

    return Colors.blue;
  }

  IconData get _statusIcon {
    if (_status == 'rejected') {
      return Icons.cancel_rounded;
    }

    if (_isApproved) {
      return Icons.verified_rounded;
    }

    if (_status == 'pending_approval') {
      return Icons.hourglass_top_rounded;
    }

    return Icons.assignment_rounded;
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  int get _completedDocuments {
    int count = 0;

    for (final key
        in _requiredDocumentKeys) {
      if (_controllers[key]!
          .text
          .trim()
          .isNotEmpty) {
        count++;
      }
    }

    return count;
  }

  double get _progress {
    if (_requiredDocumentKeys.isEmpty) {
      return 0;
    }

    return _completedDocuments /
        _requiredDocumentKeys.length;
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveKycDetails() async {
    if (_uid == null) {
      return;
    }

    for (final key
        in _requiredDocumentKeys) {
      if (_controllers[key]!
          .text
          .trim()
          .isEmpty) {
        _showMessage(
          '${_documentTitles[key]} enter karein.',
          error: true,
        );
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic>
          documents = {};

      for (final key
          in _requiredDocumentKeys) {
        documents[key] = {
          'number':
              _controllers[key]!
                  .text
                  .trim(),
          'status': 'pending',
          'rejectionReason': '',
          'updatedAt':
              FieldValue.serverTimestamp(),
        };
      }

      await _firestore
          .collection('vendors')
          .doc(_uid)
          .set(
        {
          'documents': documents,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage(
        'KYC details save ho gayi hain.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage(
        'KYC details save nahi ho payi.',
        error: true,
      );
    }
  }

  // ============================================================
  // SUBMIT FOR ADMIN APPROVAL
  // ============================================================

  Future<void> _submitForApproval() async {
    if (_uid == null) {
      return;
    }

    for (final key
        in _requiredDocumentKeys) {
      if (_controllers[key]!
          .text
          .trim()
          .isEmpty) {
        _showMessage(
          '${_documentTitles[key]} enter karein.',
          error: true,
        );
        return;
      }
    }

    final shouldSubmit =
        await _confirmSubmit();

    if (!shouldSubmit) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic>
          documents = {};

      for (final key
          in _requiredDocumentKeys) {
        documents[key] = {
          'number':
              _controllers[key]!
                  .text
                  .trim(),
          'status': 'pending',
          'rejectionReason': '',
          'updatedAt':
              FieldValue.serverTimestamp(),
        };
      }

      final batch =
          _firestore.batch();

      final vendorRef =
          _firestore
              .collection('vendors')
              .doc(_uid);

      final userRef =
          _firestore
              .collection('users')
              .doc(_uid);

      batch.set(
        vendorRef,
        {
          'documents': documents,
          'documentsSubmitted': true,
          'status': 'pending_approval',
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        userRef,
        {
          'documentsSubmitted': true,
          'status': 'pending_approval',
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _saving = false;
        _documentsSubmitted = true;
        _status = 'pending_approval';
      });

      await _showSubmittedDialog();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage(
        'Application submit nahi ho payi.',
        error: true,
      );
    }
  }

  // ============================================================
  // CONFIRM SUBMIT
  // ============================================================

  Future<bool> _confirmSubmit() async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          title: const Text(
            'Submit KYC?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'KYC details Admin approval ke liye '
            'submit karne ke baad details temporarily lock ho jayengi.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  Future<void> _showSubmittedDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 55,
          ),
          title: const Text(
            'Submitted Successfully',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'Aapki Vendor KYC details Admin approval ke liye submit ho gayi hain.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _statusColor,
            _statusColor.withOpacity(0.75),
          ],
        ),
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 8),
            color:
                _statusColor.withOpacity(0.18),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(0.18),
              borderRadius:
                  BorderRadius.circular(17),
            ),
            child: Icon(
              _statusIcon,
              color: Colors.white,
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
                  _statusTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VENDOR PROFILE
  // ============================================================

  Widget _buildVendorCard() {
    final letter =
        _vendorName.isEmpty
            ? 'V'
            : _vendorName[0]
                .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 7),
            color:
                Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF111827),
                  Color(0xFF374151),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
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
                  _vendorName.isEmpty
                      ? 'Vendor'
                      : _vendorName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (_vendorPhone.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 5,
                    ),
                    child: Text(
                      _vendorPhone,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (_vendorEmail.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 2,
                    ),
                    child: Text(
                      _vendorEmail,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESS CARD
  // ============================================================

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                size: 22,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'KYC Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$_completedDocuments/${_requiredDocumentKeys.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 9,
              backgroundColor:
                  Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _completedDocuments ==
                    _requiredDocumentKeys.length
                ? 'All required details completed'
                : 'Sabhi required details complete karein',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REJECTION CARD
  // ============================================================

  Widget _buildRejectionCard() {
    if (_status != 'rejected' ||
        _rejectionReason.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.07),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.red.withOpacity(0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Remark',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _rejectionReason,
                  style: const TextStyle(
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DOCUMENT FIELD
  // ============================================================

  Widget _buildDocumentField(
    String key,
    int index,
  ) {
    final controller =
        _controllers[key]!;

    final editable =
        _canEditDocuments &&
            !_saving;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFF1F5F9),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _documentTitles[key]!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          TextField(
            controller: controller,
            enabled: editable,
            textCapitalization:
                TextCapitalization.characters,
            decoration: InputDecoration(
              labelText:
                  _documentTitles[key],
              hintText:
                  _documentHints[key],
              prefixIcon: const Icon(
                Icons.badge_outlined,
              ),
              filled: true,
              fillColor:
                  const Color(0xFFF8F9FC),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(15),
                borderSide:
                    BorderSide.none,
              ),
              disabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(15),
                borderSide:
                    BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

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
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          backgroundColor:
              error
                  ? Colors.red.shade700
                  : Colors.green.shade700,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Vendor KYC',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor:
            Colors.transparent,
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadVendorData,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  35,
                ),
                children: [
                  // HEADER
                  _buildStatusCard(),

                  const SizedBox(height: 14),

                  // PROFILE
                  _buildVendorCard(),

                  const SizedBox(height: 14),

                  // REJECTION
                  _buildRejectionCard(),

                  if (_status == 'rejected' &&
                      _rejectionReason.isNotEmpty)
                    const SizedBox(height: 14),

                  // PROGRESS
                  _buildProgressCard(),

                  const SizedBox(height: 22),

                  const Text(
                    'Required KYC Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Neeche sabhi required details carefully enter karein.',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // DOCUMENT FIELDS
                  for (int i = 0;
                      i <
                          _requiredDocumentKeys
                              .length;
                      i++)
                    _buildDocumentField(
                      _requiredDocumentKeys[i],
                      i,
                    ),

                  const SizedBox(height: 4),

                  // ACTIONS
                  if (_canEditDocuments) ...[
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : _saveKycDetails,
                        icon: const Icon(
                          Icons.save_outlined,
                        ),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : 'Save KYC Details',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        style:
                            OutlinedButton.styleFrom(
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : _submitForApproval,
                        icon: _saving
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                              ),
                        label: Text(
                          _saving
                              ? 'Submitting...'
                              : 'Submit for Admin Approval',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        style:
                            FilledButton.styleFrom(
                          backgroundColor:
                              const Color(
                            0xFF111827,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // PENDING
                  if (_isPendingApproval)
                    Container(
                      margin:
                          const EdgeInsets.only(
                        top: 8,
                      ),
                      padding:
                          const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange
                            .withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                        border: Border.all(
                          color: Colors.orange
                              .withOpacity(0.20),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons
                                .hourglass_top_rounded,
                            color:
                                Colors.orange,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'KYC submit ho chuki hai. Admin approval ka wait karein.',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // APPROVED
                  if (_isApproved)
                    Container(
                      margin:
                          const EdgeInsets.only(
                        top: 8,
                      ),
                      padding:
                          const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green
                            .withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                        border: Border.all(
                          color: Colors.green
                              .withOpacity(0.20),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons
                                .verified_rounded,
                            color:
                                Colors.green,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Vendor approved hai. KYC details locked hain.',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 18),

                  // SECURITY
                  Container(
                    padding:
                        const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      border: Border.all(
                        color:
                            Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons
                              .security_rounded,
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Security: Admin approval ke bina Vendor account active nahi hoga aur Vendor Panel access nahi milega.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors
                                  .grey.shade700,
                              height: 1.45,
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
}
