import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_functions/firebase_functions.dart';
import 'package:flutter/material.dart';

class VendorManagementPage extends StatefulWidget {
  const VendorManagementPage({super.key});

  @override
  State<VendorManagementPage> createState() =>
      _VendorManagementPageState();
}

class _VendorManagementPageState
    extends State<VendorManagementPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  bool _loading = false;

  Future<void> _authorizeVendor({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    setState(() {
      _loading = true;
    });

    try {
      final callable =
          _functions.httpsCallable('authorizeVendor');

      await callable.call({
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vendor authorized successfully.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to authorize vendor.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateVendorStatus({
    required String uid,
    required String status,
    String reason = '',
  }) async {
    setState(() {
      _loading = true;
    });

    try {
      final callable =
          _functions.httpsCallable('updateVendorStatus');

      await callable.call({
        'vendorUid': uid,
        'status': status,
        'reason': reason,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vendor status updated to ${status.toUpperCase()}.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to update vendor status.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateDocumentStatus({
    required String uid,
    required String documentType,
    required String status,
    String reason = '',
  }) async {
    setState(() {
      _loading = true;
    });

    try {
      final callable =
          _functions.httpsCallable(
        'updateVendorDocumentStatus',
      );

      await callable.call({
        'vendorUid': uid,
        'documentType': documentType,
        'status': status,
        'reason': reason,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_documentTitle(documentType)} marked ${status.toUpperCase()}.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                'Unable to update document status.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _documentTitle(String type) {
    switch (type) {
      case 'pan':
        return 'PAN Card';
      case 'aadhaar':
        return 'Aadhaar Card';
      case 'gst':
        return 'GST Certificate';
      case 'bank':
        return 'Bank / Cancelled Cheque';
      case 'addressProof':
        return 'Address Proof';
      case 'other':
        return 'Other Document';
      default:
        return type;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'suspended':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _showReasonDialog({
    required String uid,
    required String status,
  }) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            status == 'rejected'
                ? 'Rejection Reason'
                : 'Reason',
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter reason',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null) return;

    await _updateVendorStatus(
      uid: uid,
      status: status,
      reason: reason,
    );
  }

  Future<void> _showDocumentActionDialog({
    required String uid,
    required String documentType,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        String selectedStatus = 'verified';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                _documentTitle(documentType),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Document Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'verified',
                        child: Text('Verified'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason / Remark',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      {
                        'status': selectedStatus,
                        'reason': controller.text.trim(),
                      },
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    await _updateDocumentStatus(
      uid: uid,
      documentType: documentType,
      status: result['status'] ?? 'pending',
      reason: result['reason'] ?? '',
    );
  }

  Widget _documentRow({
    required String uid,
    required String documentType,
    required Map<String, dynamic> document,
  }) {
    final status =
        String(document['status'] ?? 'pending');

    final fileUrl =
        String(document['url'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.description_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _documentTitle(documentType),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _statusChip(status),
                  if (fileUrl.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Document uploaded',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Verify / Reject',
              icon: const Icon(
                Icons.verified_outlined,
              ),
              onPressed: _loading
                  ? null
                  : () {
                      _showDocumentActionDialog(
                        uid: uid,
                        documentType: documentType,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _vendorCard(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    final uid = doc.id;

    final name =
        String(data['name'] ?? 'Unknown Vendor');

    final email =
        String(data['email'] ?? '');

    final phone =
        String(data['phone'] ?? '');

    final status =
        String(data['status'] ?? 'pending');

    final active =
        data['active'] == true;

    final documents =
        Map<String, dynamic>.from(
      data['documents'] ?? {},
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text(
            name.isNotEmpty
                ? name[0].toUpperCase()
                : 'V',
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: 5,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (email.isNotEmpty)
                Text(email),
              if (phone.isNotEmpty)
                Text(phone),
              const SizedBox(height: 5),
              Row(
                children: [
                  _statusChip(status),
                  const SizedBox(width: 8),
                  if (active)
                    const Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      'Inactive',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        children: [
          const Divider(),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Vendor ID',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          const SizedBox(height: 4),

          SelectableText(uid),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.check_circle_outline,
                  ),
                  label: const Text('Approve'),
                  onPressed: _loading
                      ? null
                      : () {
                          _updateVendorStatus(
                            uid: uid,
                            status: 'approved',
                          );
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.close,
                  ),
                  label: const Text('Reject'),
                  onPressed: _loading
                      ? null
                      : () {
                          _showReasonDialog(
                            uid: uid,
                            status: 'rejected',
                          );
                        },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.pause_circle_outline,
                  ),
                  label: const Text('Suspend'),
                  onPressed: _loading
                      ? null
                      : () {
                          _showReasonDialog(
                            uid: uid,
                            status: 'suspended',
                          );
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.pending_outlined,
                  ),
                  label: const Text('Pending'),
                  onPressed: _loading
                      ? null
                      : () {
                          _updateVendorStatus(
                            uid: uid,
                            status: 'pending',
                          );
                        },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Vendor Documents',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 10),

          ...[
            'pan',
            'aadhaar',
            'gst',
            'bank',
            'addressProof',
            'other',
          ].map(
            (type) {
              final document =
                  Map<String, dynamic>.from(
                documents[type] ?? {},
              );

              return _documentRow(
                uid: uid,
                documentType: type,
                document: document,
              );
            },
          ),

          const SizedBox(height: 8),

          if (status == 'approved')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified,
                    color: Colors.green,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vendor is approved by Admin.',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
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

  Future<void> _showAuthorizeDialog() async {
    final uidController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    final result =
        await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Authorize Vendor',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: uidController,
                  decoration: const InputDecoration(
                    labelText: 'Firebase User UID',
                    hintText: 'Enter existing user UID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Vendor Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  {
                    'uid': uidController.text.trim(),
                    'name': nameController.text.trim(),
                    'email':
                        emailController.text.trim(),
                    'phone':
                        phoneController.text.trim(),
                  },
                );
              },
              child: const Text('Authorize'),
            ),
          ],
        );
      },
    );

    uidController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();

    if (result == null) return;

    final uid = result['uid'] ?? '';

    if (uid.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Firebase User UID is required.',
          ),
        ),
      );

      return;
    }

    await _authorizeVendor(
      uid: uid,
      name: result['name'] ?? '',
      email: result['email'] ?? '',
      phone: result['phone'] ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vendor Management',
        ),
        actions: [
          IconButton(
            tooltip: 'Authorize Vendor',
            icon: const Icon(
              Icons.person_add_alt_1,
            ),
            onPressed:
                _loading ? null : _showAuthorizeDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('vendors')
                .orderBy(
                  'createdAt',
                  descending: true,
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load vendors.\n\n${snapshot.error}',
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
                return RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Icon(
                        Icons.storefront_outlined,
                        size: 70,
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No vendors found.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Tap + to authorize a vendor.',
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  return _vendorCard(docs[index]);
                },
              );
            },
          ),

          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.08,
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
