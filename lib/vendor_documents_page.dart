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
  State<VendorDocumentsPage> createState() => _VendorDocumentsPageState();
}

class _VendorDocumentsPageState extends State<VendorDocumentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  final Map<String, String> _documentNumbers = {};

  final Map<String, String> _documentTitles = {
    'pan': 'PAN Card',
    'aadhaar': 'Aadhaar / ID Proof',
    'gst': 'GST Number',
    'bank': 'Bank Account / Details',
    'addressProof': 'Address Proof',
  };

  final Map<String, String> _documentHints = {
    'pan': 'Example: ABCDE1234F',
    'aadhaar': 'Example: 123456789012',
    'gst': 'Example: 08ABCDE1234F1Z5',
    'bank': 'Example: Account Number / Bank Details',
    'addressProof': 'Example: Voter ID / Passport / Other ID No.',
  };

  final List<String> _requiredDocumentKeys = const [
    'pan',
    'aadhaar',
    'gst',
    'bank',
    'addressProof',
  ];

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();

    _uid = widget.vendorUid ?? _auth.currentUser?.uid;

    for (final key in _requiredDocumentKeys) {
      _controllers[key] = TextEditingController();
    }

    _loadVendorData();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

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
      final vendorRef = _firestore.collection('vendors').doc(_uid);
      final userRef = _firestore.collection('users').doc(_uid);

      final vendorSnapshot = await vendorRef.get();

      Map<String, dynamic> data = {};

      if (vendorSnapshot.exists) {
        data = vendorSnapshot.data() ?? {};
      } else {
        final userSnapshot = await userRef.get();
        final userData = userSnapshot.data() ?? {};

        final role =
            userData['role']?.toString().toLowerCase().trim() ?? '';

        if (role == 'vendor') {
          data = {
            'uid': _uid,
            'role': 'vendor',
            'name': userData['name'] ??
                _auth.currentUser?.displayName ??
                '',
            'phone': userData['phone'] ??
                _auth.currentUser?.phoneNumber ??
                '',
            'email': userData['email'] ??
                _auth.currentUser?.email ??
                '',
            'status': userData['status'] ?? 'pending_documents',
            'registrationStatus':
                userData['registrationStatus'] ?? 'pending_documents',
            'active': userData['active'] == true,
            'documentsSubmitted':
                userData['documentsSubmitted'] == true,
            'approvedByAdmin':
                userData['approvedByAdmin'] == true,
            'documents': {},
          };

          await vendorRef.set(
            {
              ...data,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      _vendorName = data['name']?.toString().trim() ?? '';
      _vendorPhone = data['phone']?.toString().trim() ?? '';
      _vendorEmail = data['email']?.toString().trim() ?? '';

      _status = _normalizeStatus(
        data['status'] ??
            data['registrationStatus'] ??
            'pending_documents',
      );

      _documentsSubmitted = data['documentsSubmitted'] == true;
      _active = data['active'] == true;
      _approvedByAdmin = data['approvedByAdmin'] == true;

      _rejectionReason =
          data['rejectionReason']?.toString().trim() ?? '';

      _documentNumbers.clear();

      final documentsData = data['documents'];

      if (documentsData is Map) {
        for (final key in _requiredDocumentKeys) {
          final document = documentsData[key];

          if (document is Map) {
            final number =
                document['number']?.toString().trim() ?? '';

            if (number.isNotEmpty) {
              _documentNumbers[key] = number;
            }
          } else if (document != null) {
            final number = document.toString().trim();

            if (number.isNotEmpty) {
              _documentNumbers[key] = number;
            }
          }
        }
      }

      for (final key in _requiredDocumentKeys) {
        _controllers[key]!.text = _documentNumbers[key] ?? '';
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
          'Vendor details load nahi ho paye.\n$e',
          isError: true,
        );
      }
    }
  }

  String _normalizeStatus(dynamic value) {
    return value
            ?.toString()
            .toLowerCase()
            .trim()
            .replaceAll(' ', '_') ??
        '';
  }

  bool get _isPendingApproval => _status == 'pending_approval';

  bool get _isApproved =>
      _status == 'approved' &&
      _active &&
      _approvedByAdmin;

  bool get _canEditDocuments {
    if (_isPendingApproval) return false;
    if (_isApproved) return false;
    return true;
  }

  Widget _buildStatusHeader() {
    String title;
    String message;
    IconData icon;
    Color color;

    if (_status == 'pending_documents' || !_documentsSubmitted) {
      title = 'KYC Details Pending';
      message =
          'Vendor registration successful hai. Sabhi required KYC details enter karke Admin approval ke liye submit karein.';
      icon = Icons.assignment_outlined;
      color = Colors.orange;
    } else if (_status == 'pending_approval') {
      title = 'Admin Approval Pending';
      message =
          'Aapki Vendor application Admin approval ke liye submit ho chuki hai. Approval milne tak Vendor account active nahi hoga.';
      icon = Icons.hourglass_top;
      color = Colors.orange;
    } else if (_status == 'rejected') {
      title = 'Application Rejected';
      message =
          'Admin ne application reject ki hai. Rejection reason check karke details correct karein aur dobara submit karein.';
      icon = Icons.cancel_outlined;
      color = Colors.red;
    } else if (_isApproved) {
      title = 'Vendor Approved';
      message =
          'Aapka Vendor account Admin dwara approved aur active hai.';
      icon = Icons.check_circle;
      color = Colors.green;
    } else {
      title = 'Application Status';
      message = 'Aapka Vendor application verification mein hai.';
      icon = Icons.info_outline;
      color = Colors.blue;
    }

    return Card(
      elevation: 3,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
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

  Widget _buildVendorProfileCard() {
    final firstLetter = _vendorName.isNotEmpty
        ? _vendorName[0].toUpperCase()
        : 'V';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 29,
              child: Text(
                firstLetter,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _vendorName.isEmpty ? 'Vendor' : _vendorName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_vendorPhone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _vendorPhone,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  if (_vendorEmail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _vendorEmail,
                        style: const TextStyle(
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

  Widget _buildDocumentCard(String key) {
    final controller = _controllers[key]!;
    final editable = _canEditDocuments && !_saving;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _documentTitles[key]!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              enabled: editable,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Enter ${_documentTitles[key]}',
                hintText: _documentHints[key],
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDocumentNumbers() async {
    if (_uid == null) return;

    for (final key in _requiredDocumentKeys) {
      if (_controllers[key]!.text.trim().isEmpty) {
        _showMessage(
          '${_documentTitles[key]} enter karein.',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> documents = {};

      for (final key in _requiredDocumentKeys) {
        final number = _controllers[key]!.text.trim();

        documents[key] = {
          'number': number,
          'status': 'pending',
          'rejectionReason': '',
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      await _firestore.collection('vendors').doc(_uid).update({
        'documents': documents,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _saving = false;
        });
      }

      _showMessage('KYC details save ho gayi hain.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }

      _showMessage(
        'KYC details save nahi ho payi.\n$e',
        isError: true,
      );
    }
  }

  Future<void> _submitForApproval() async {
    if (_uid == null) return;

    for (final key in _requiredDocumentKeys) {
      if (_controllers[key]!.text.trim().isEmpty) {
        _showMessage(
          '${_documentTitles[key]} enter karein.',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> documents = {};

      for (final key in _requiredDocumentKeys) {
        final number = _controllers[key]!.text.trim();

        documents[key] = {
          'number': number,
          'status': 'pending',
          'rejectionReason': '',
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      final batch = _firestore.batch();

      final vendorRef =
          _firestore.collection('vendors').doc(_uid);

      final userRef =
          _firestore.collection('users').doc(_uid);

      batch.update(vendorRef, {
        'documents': documents,
        'documentsSubmitted': true,
        'status': 'pending_approval',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(userRef, {
        'documentsSubmitted': true,
        'status': 'pending_approval',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _saving = false;
        _documentsSubmitted = true;
        _status = 'pending_approval';
      });

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Submitted Successfully'),
            content: const Text(
              'Aapki Vendor KYC details Admin approval ke liye submit ho gayi hain.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }

      _showMessage(
        'Application submit nahi ho payi.\n$e',
        isError: true,
      );
    }
  }

  Widget _buildProgressCard() {
    int completed = 0;

    for (final key in _requiredDocumentKeys) {
      if (_controllers[key]!.text.trim().isNotEmpty) {
        completed++;
      }
    }

    final total = _requiredDocumentKeys.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KYC Progress: $completed / $total',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionCard() {
    if (_status != 'rejected' || _rejectionReason.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.red.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rejection Reason',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_rejectionReason),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor KYC & Documents'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadVendorData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatusHeader(),
                  const SizedBox(height: 14),
                  _buildVendorProfileCard(),
                  const SizedBox(height: 14),
                  _buildRejectionCard(),
                  const SizedBox(height: 14),
                  _buildProgressCard(),
                  const SizedBox(height: 18),
                  const Text(
                    'Required KYC Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final key in _requiredDocumentKeys)
                    _buildDocumentCard(key),
                  const SizedBox(height: 8),
                  if (_canEditDocuments)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed:
                                _saving ? null : _saveDocumentNumbers,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _saving
                                  ? 'Saving...'
                                  : 'Save KYC Details',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed:
                                _saving ? null : _submitForApproval,
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_outlined,
                                  ),
                            label: Text(
                              _saving
                                  ? 'Submitting...'
                                  : 'Submit for Admin Approval',
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_isPendingApproval)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'KYC details submit ho chuki hain. Admin approval ka wait karein.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  if (_isApproved)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Vendor approved hai. KYC details ab locked hain.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(15),
                      child: Text(
                        'Security: Admin approval ke bina Vendor account active nahi hoga aur Vendor Panel access nahi milega.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
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
