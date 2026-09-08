import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorDocumentsPage extends StatefulWidget {
  final String vendorUid;

  const VendorDocumentsPage({
    super.key,
    required this.vendorUid,
  });

  @override
  State<VendorDocumentsPage> createState() => _VendorDocumentsPageState();
}

class _VendorDocumentsPageState extends State<VendorDocumentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _panController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _bankController = TextEditingController();
  final TextEditingController _addressProofController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String _status = 'pending_documents';
  String _rejectionReason = '';

  Map<String, dynamic> _documents = {};

  String get _uid {
    if (widget.vendorUid.trim().isNotEmpty) {
      return widget.vendorUid.trim();
    }
    return _auth.currentUser?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _panController.dispose();
    _aadhaarController.dispose();
    _gstController.dispose();
    _bankController.dispose();
    _addressProofController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    if (_uid.isEmpty) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('vendors').doc(_uid).get();

      Map<String, dynamic> data = snapshot.data() ?? {};

      if (data.isEmpty) {
        final userSnapshot =
            await _firestore.collection('users').doc(_uid).get();

        data = userSnapshot.data() ?? {};
      }

      final documents = data['documents'];

      _documents = documents is Map
          ? Map<String, dynamic>.from(documents)
          : {};

      _status = data['status']?.toString() ??
          data['registrationStatus']?.toString() ??
          'pending_documents';

      _rejectionReason =
          data['rejectionReason']?.toString() ?? '';

      _setController(
        _panController,
        _readDocumentValue(
          'pan',
          data,
          const [
            'panNumber',
            'pan',
          ],
        ),
      );

      _setController(
        _aadhaarController,
        _readDocumentValue(
          'aadhaar',
          data,
          const [
            'aadhaarNumber',
            'aadharNumber',
            'aadhaar',
          ],
        ),
      );

      _setController(
        _gstController,
        _readDocumentValue(
          'gst',
          data,
          const [
            'gstNumber',
            'gstin',
            'gst',
          ],
        ),
      );

      _setController(
        _bankController,
        _readDocumentValue(
          'bank',
          data,
          const [
            'bankAccountNumber',
            'accountNumber',
            'bank',
          ],
        ),
      );

      _setController(
        _addressProofController,
        _readDocumentValue(
          'addressProof',
          data,
          const [
            'addressProofNumber',
            'addressProof',
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to load vendor documents.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _setController(
    TextEditingController controller,
    String value,
  ) {
    controller.text = value;
  }

  String _readDocumentValue(
    String key,
    Map<String, dynamic> data,
    List<String> flatKeys,
  ) {
    final nested = _documents[key];

    if (nested is Map) {
      final value = nested['number'] ??
          nested['documentNumber'] ??
          nested['value'] ??
          nested['details'];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    for (final flatKey in flatKeys) {
      final value = data[flatKey];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }

  bool get _isApproved {
    return _status == 'approved';
  }

  bool get _isPendingApproval {
    return _status == 'pending_approval';
  }

  bool get _isRejected {
    return _status == 'rejected';
  }

  bool get _isLocked {
    return _isApproved || _isPendingApproval;
  }

  String _documentStatus(String key) {
    final document = _documents[key];

    if (document is Map) {
      return document['status']?.toString() ?? '';
    }

    return '';
  }

  String _documentRejectionReason(String key) {
    final document = _documents[key];

    if (document is Map) {
      return document['rejectionReason']?.toString() ?? '';
    }

    return '';
  }

  bool _documentApproved(String key) {
    return _documentStatus(key).toLowerCase() == 'approved';
  }

  bool _documentRejected(String key) {
    return _documentStatus(key).toLowerCase() == 'rejected';
  }

  Future<void> _saveDocuments({
    required bool submit,
  }) async {
    if (_uid.isEmpty) {
      _showMessage(
        'Vendor account not found.',
        error: true,
      );
      return;
    }

    if (submit && !_formKey.currentState!.validate()) {
      return;
    }

    if (_isLocked && submit) {
      _showMessage(
        'Documents are already under Admin review.',
        error: true,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final now = FieldValue.serverTimestamp();

      final documents = <String, dynamic>{
        'pan': {
          'number': _panController.text.trim().toUpperCase(),
          'status': submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'aadhaar': {
          'number': _aadhaarController.text.trim(),
          'status': submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'gst': {
          'number': _gstController.text.trim().toUpperCase(),
          'status': submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'bank': {
          'number': _bankController.text.trim(),
          'status': submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'addressProof': {
          'number': _addressProofController.text.trim(),
          'status': submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
      };

      final vendorUpdate = <String, dynamic>{
        'documents': documents,

        'panNumber': _panController.text.trim().toUpperCase(),
        'aadhaarNumber': _aadhaarController.text.trim(),
        'gstNumber': _gstController.text.trim().toUpperCase(),
        'bankAccountNumber': _bankController.text.trim(),
        'addressProofNumber': _addressProofController.text.trim(),

        'updatedAt': now,
      };

      if (submit) {
        vendorUpdate.addAll({
          'documentsSubmitted': true,
          'documentsSubmittedAt': now,
          'status': 'pending_approval',
          'registrationStatus': 'pending_approval',
          'approvedByAdmin': false,
          'active': false,
          'rejectionReason': '',
        });
      } else {
        vendorUpdate.addAll({
          'documentsSubmitted': false,
        });
      }

      await _firestore
          .collection('vendors')
          .doc(_uid)
          .set(
            vendorUpdate,
            SetOptions(merge: true),
          );

      await _firestore
          .collection('users')
          .doc(_uid)
          .set(
            {
              'documents': documents,
              'panNumber':
                  _panController.text.trim().toUpperCase(),
              'aadhaarNumber':
                  _aadhaarController.text.trim(),
              'gstNumber':
                  _gstController.text.trim().toUpperCase(),
              'bankAccountNumber':
                  _bankController.text.trim(),
              'addressProofNumber':
                  _addressProofController.text.trim(),
              'updatedAt': now,
              if (submit) ...{
                'documentsSubmitted': true,
                'documentsSubmittedAt': now,
                'status': 'pending_approval',
                'registrationStatus': 'pending_approval',
                'approvedByAdmin': false,
                'active': false,
                'rejectionReason': '',
              },
            },
            SetOptions(merge: true),
          );

      if (!mounted) return;

      setState(() {
        _documents = documents;
        if (submit) {
          _status = 'pending_approval';
          _rejectionReason = '';
        }
      });

      _showMessage(
        submit
            ? 'Documents submitted successfully for Admin approval.'
            : 'Documents saved as draft.',
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to save documents. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _requiredValidator(
    String? value,
    String label,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }

    return null;
  }

  String? _panValidator(String? value) {
    final text = value?.trim().toUpperCase() ?? '';

    if (text.isEmpty) {
      return 'PAN Number is required';
    }

    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(text)) {
      return 'Enter a valid PAN Number';
    }

    return null;
  }

  String? _aadhaarValidator(String? value) {
    final text = value?.replaceAll(' ', '').trim() ?? '';

    if (text.isEmpty) {
      return 'Aadhaar Number is required';
    }

    if (!RegExp(r'^\d{12}$').hasMatch(text)) {
      return 'Aadhaar Number must contain 12 digits';
    }

    return null;
  }

  String? _gstValidator(String? value) {
    final text = value?.trim().toUpperCase() ?? '';

    if (text.isEmpty) {
      return 'GST Number is required';
    }

    if (!RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
    ).hasMatch(text)) {
      return 'Enter a valid GST Number';
    }

    return null;
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.indigo,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  Widget _documentField({
    required String title,
    required String subtitle,
    required String key,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
  }) {
    final approved = _documentApproved(key);
    final rejected = _documentRejected(key);

    final reason = _documentRejectionReason(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rejected
              ? Colors.red.shade200
              : approved
                  ? Colors.green.shade200
                  : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (approved)
                _statusBadge(
                  'Approved',
                  Colors.green,
                )
              else if (rejected)
                _statusBadge(
                  'Rejected',
                  Colors.red,
                )
              else if (_isPendingApproval)
                _statusBadge(
                  'Under Review',
                  Colors.orange,
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller,
            enabled: !_isLocked,
            obscureText: obscure,
            keyboardType: keyboardType,
            textCapitalization: TextCapitalization.characters,
            validator: validator,
            decoration: _inputDecoration(
              title,
              icon,
            ),
          ),
          if (rejected && reason.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.red,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f7fb),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Vendor Documents',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadDocuments,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  35,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xff1a237e),
                          Color(0xff3949ab),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vendor Verification',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Complete your business details for approval',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_isRejected)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.red.shade200,
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
                                  'Documents Rejected',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (_rejectionReason
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    _rejectionReason,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 5),
                                const Text(
                                  'Please correct the details and resubmit.',
                                  style: TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_isPendingApproval)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.orange.shade200,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.hourglass_top_rounded,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your documents have been submitted and are under Admin review.',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_isApproved)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.green.shade200,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: Colors.green,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your vendor documents are approved. Details are locked.',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  _documentField(
                    title: 'PAN Number',
                    subtitle: 'Enter your business/person PAN',
                    key: 'pan',
                    controller: _panController,
                    icon: Icons.badge_outlined,
                    validator: _panValidator,
                  ),

                  _documentField(
                    title: 'Aadhaar Number',
                    subtitle: 'Enter 12 digit Aadhaar Number',
                    key: 'aadhaar',
                    controller: _aadhaarController,
                    icon: Icons.fingerprint,
                    keyboardType: TextInputType.number,
                    validator: _aadhaarValidator,
                  ),

                  _documentField(
                    title: 'GST Number',
                    subtitle: 'Enter your GSTIN',
                    key: 'gst',
                    controller: _gstController,
                    icon: Icons.receipt_long_outlined,
                    validator: _gstValidator,
                  ),

                  _documentField(
                    title: 'Bank Account Number',
                    subtitle: 'Enter the bank account used for business',
                    key: 'bank',
                    controller: _bankController,
                    icon: Icons.account_balance_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        _requiredValidator(
                          value,
                          'Bank Account Number',
                        ),
                  ),

                  _documentField(
                    title: 'Address Proof Number / Details',
                    subtitle:
                        'Enter address proof document number or details',
                    key: 'addressProof',
                    controller: _addressProofController,
                    icon: Icons.home_work_outlined,
                    validator: (value) =>
                        _requiredValidator(
                          value,
                          'Address Proof',
                        ),
                  ),

                  const SizedBox(height: 8),

                  if (!_isLocked)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _saveDocuments(
                                      submit: false,
                                    ),
                            icon: const Icon(
                              Icons.save_outlined,
                            ),
                            label: const Text(
                              'Save Draft',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _saveDocuments(
                                      submit: true,
                                    ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                  ),
                            label: Text(
                              _isRejected
                                  ? 'Resubmit for Admin Approval'
                                  : 'Submit for Admin Approval',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (_isLocked)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isApproved
                                ? Icons.lock_outline
                                : Icons.hourglass_top_outlined,
                            color: Colors.grey.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isApproved
                                ? 'Documents Locked'
                                : 'Documents Under Admin Review',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
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
