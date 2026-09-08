import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  static const List<String> requiredDocuments = [
    'pan',
    'aadhaar',
    'gst',
    'bank',
    'addressProof',
  ];

  // ============================================================
  // COMMON MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // AUTHORIZE VENDOR
  // ============================================================

  Future<void> _authorizeVendor({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final callable =
          _functions.httpsCallable('authorizeVendor');

      await callable.call({
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
      });

      _showMessage(
        'Vendor authorized successfully.',
      );
    } on FirebaseFunctionsException catch (e) {
      _showMessage(
        e.message ?? 'Unable to authorize vendor.',
      );
    } catch (e) {
      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ============================================================
  // UPDATE VENDOR STATUS
  // ============================================================

  Future<void> _updateVendorStatus({
    required String uid,
    required String status,
    String reason = '',
  }) async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final callable =
          _functions.httpsCallable('updateVendorStatus');

      await callable.call({
        'vendorUid': uid,
        'status': status,
        'reason': reason,
      });

      _showMessage(
        'Vendor status updated to ${status.toUpperCase()}.',
      );
    } on FirebaseFunctionsException catch (e) {
      _showMessage(
        e.message ?? 'Unable to update vendor status.',
      );
    } catch (e) {
      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ============================================================
  // UPDATE DOCUMENT STATUS
  // ============================================================

  Future<void> _updateDocumentStatus({
    required String uid,
    required String documentType,
    required String status,
    String reason = '',
  }) async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final callable = _functions.httpsCallable(
        'updateVendorDocumentStatus',
      );

      await callable.call({
        'vendorUid': uid,
        'documentType': documentType,
        'status': status,
        'reason': reason,
      });

      _showMessage(
        '${_documentTitle(documentType)} marked ${status.toUpperCase()}.',
      );
    } on FirebaseFunctionsException catch (e) {
      _showMessage(
        e.message ?? 'Unable to update document.',
      );
    } catch (e) {
      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ============================================================
  // DOCUMENT TITLE
  // ============================================================

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
      default:
        return type;
    }
  }

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      case 'suspended':
        return Colors.orange;

      case 'pending':
      case 'pending_documents':
      case 'pending_approval':
        return Colors.blue;

      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
        return Icons.check_circle_rounded;

      case 'rejected':
        return Icons.cancel_rounded;

      case 'suspended':
        return Icons.pause_circle_rounded;

      case 'pending':
      case 'pending_documents':
      case 'pending_approval':
        return Icons.pending_rounded;

      default:
        return Icons.help_outline_rounded;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    final text = status
        .replaceAll('_', ' ')
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(status),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DOCUMENT MAP
  // ============================================================

  Map<String, dynamic> _documentData(
    Map<String, dynamic> documents,
    String type,
  ) {
    final value = documents[type];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  String _documentUrl(
    Map<String, dynamic> document,
  ) {
    return (
      document['url'] ??
      document['downloadUrl'] ??
      document['fileUrl'] ??
      document['imageUrl'] ??
      ''
    ).toString();
  }

  String _documentStatus(
    Map<String, dynamic> document,
  ) {
    return (
      document['status'] ??
      'pending'
    ).toString().trim().toLowerCase();
  }

  int _verifiedDocuments(
    Map<String, dynamic> documents,
  ) {
    int count = 0;

    for (final type in requiredDocuments) {
      final document =
          _documentData(documents, type);

      if (_documentStatus(document) ==
          'verified') {
        count++;
      }
    }

    return count;
  }

  // ============================================================
  // VIEW DOCUMENT
  // ============================================================

  Future<void> _viewDocument({
    required String title,
    required String url,
  }) async {
    if (url.trim().isEmpty) {
      _showMessage(
        'Document file is not available.',
      );
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  16,
                  10,
                  10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (
                      context,
                      child,
                      progress,
                    ) {
                      if (progress == null) {
                        return child;
                      }

                      return const SizedBox(
                        height: 350,
                        child: Center(
                          child:
                              CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const SizedBox(
                        height: 300,
                        child: Center(
                          child: Text(
                            'Unable to load document.',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // VENDOR ACTION DIALOG
  // ============================================================

  Future<void> _vendorAction({
    required String uid,
    required String status,
  }) async {
    final controller =
        TextEditingController();

    final title = status == 'rejected'
        ? 'Reject Vendor'
        : status == 'suspended'
            ? 'Suspend Vendor'
            : 'Update Vendor';

    final reason =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason / Remark',
              hintText:
                  'Enter reason or remark',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
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

  // ============================================================
  // DOCUMENT ACTION
  // ============================================================

  Future<void> _documentAction({
    required String uid,
    required String type,
    required String currentStatus,
  }) async {
    String selectedStatus =
        currentStatus == 'verified'
            ? 'verified'
            : currentStatus == 'rejected'
                ? 'rejected'
                : 'pending';

    final controller =
        TextEditingController();

    final result =
        await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: Text(
                _documentTitle(type),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration:
                        const InputDecoration(
                      labelText: 'Status',
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
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(
                      labelText: 'Remark',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      {
                        'status': selectedStatus,
                        'reason':
                            controller.text.trim(),
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
      documentType: type,
      status: result['status'] ?? 'pending',
      reason: result['reason'] ?? '',
    );
  }

  // ============================================================
  // DOCUMENT CARD
  // ============================================================

  Widget _documentCard({
    required String uid,
    required String type,
    required Map<String, dynamic> document,
  }) {
    final status =
        _documentStatus(document);

    final url = _documentUrl(document);

    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.description_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _documentTitle(type),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                _statusChip(status),
              ],
            ),
          ),
          if (url.isNotEmpty)
            IconButton(
              tooltip: 'View',
              onPressed: () {
                _viewDocument(
                  title: _documentTitle(type),
                  url: url,
                );
              },
              icon: const Icon(
                Icons.visibility_outlined,
              ),
            ),
          IconButton(
            tooltip: 'Update',
            onPressed: _loading
                ? null
                : () {
                    _documentAction(
                      uid: uid,
                      type: type,
                      currentStatus: status,
                    );
                  },
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VENDOR CARD
  // ============================================================

  Widget _vendorCard(
    String uid,
    Map<String, dynamic> vendor,
  ) {
    final name = (
      vendor['name'] ??
      vendor['businessName'] ??
      vendor['shopName'] ??
      'Vendor'
    ).toString();

    final email =
        (vendor['email'] ?? '').toString();

    final phone = (
      vendor['phone'] ??
      vendor['mobile'] ??
      ''
    ).toString();

    final status = (
      vendor['status'] ??
      'pending'
    ).toString();

    final documents =
        vendor['documents'] is Map
            ? Map<String, dynamic>.from(
                vendor['documents'],
              )
            : <String, dynamic>{};

    final verified =
        _verifiedDocuments(documents);

    final approved =
        vendor['approvedByAdmin'] == true;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.fromLTRB(
          18,
          10,
          14,
          10,
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(
          18,
          0,
          18,
          18,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        collapsedShape:
            RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF111827),
                Color(0xFF374151),
              ],
            ),
            borderRadius:
                BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: 6,
          ),
          child: Text(
            email.isEmpty
                ? phone
                : email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: _statusChip(status),
        children: [
          // ------------------------------------
          // BASIC INFORMATION
          // ------------------------------------

          _sectionTitle(
            'Vendor Information',
            Icons.person_outline_rounded,
          ),

          _infoRow(
            'Vendor ID',
            uid,
          ),

          if (email.isNotEmpty)
            _infoRow(
              'Email',
              email,
            ),

          if (phone.isNotEmpty)
            _infoRow(
              'Mobile',
              phone,
            ),

          const SizedBox(height: 12),

          // ------------------------------------
          // DOCUMENT SUMMARY
          // ------------------------------------

          _sectionTitle(
            'Documents',
            Icons.folder_outlined,
          ),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$verified / ${requiredDocuments.length} required documents verified',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                CircularProgressIndicator(
                  value:
                      requiredDocuments.isEmpty
                          ? 0
                          : verified /
                              requiredDocuments.length,
                  strokeWidth: 5,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ------------------------------------
          // DOCUMENT LIST
          // ------------------------------------

          ...requiredDocuments.map(
            (type) {
              return _documentCard(
                uid: uid,
                type: type,
                document:
                    _documentData(
                  documents,
                  type,
                ),
              );
            },
          ),

          // ------------------------------------
          // ADMIN APPROVAL
          // ------------------------------------

          _sectionTitle(
            'Admin Approval',
            Icons.admin_panel_settings_outlined,
          ),

          Row(
            children: [
              Icon(
                approved
                    ? Icons.check_circle_rounded
                    : Icons.pending_rounded,
                color: approved
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 10),
              Text(
                approved
                    ? 'Approved by Admin'
                    : 'Not approved by Admin',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ------------------------------------
          // ACTION BUTTONS
          // ------------------------------------

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (status != 'approved')
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          _updateVendorStatus(
                            uid: uid,
                            status: 'approved',
                          );
                        },
                  icon: const Icon(
                    Icons.check_rounded,
                  ),
                  label: const Text(
                    'Approve',
                  ),
                ),

              if (status != 'rejected')
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          _vendorAction(
                            uid: uid,
                            status: 'rejected',
                          );
                        },
                  icon: const Icon(
                    Icons.close_rounded,
                  ),
                  label: const Text(
                    'Reject',
                  ),
                ),

              if (status != 'suspended')
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          _vendorAction(
                            uid: uid,
                            status: 'suspended',
                          );
                        },
                  icon: const Icon(
                    Icons.pause_rounded,
                  ),
                  label: const Text(
                    'Suspend',
                  ),
                ),

              if (status == 'suspended' ||
                  status == 'rejected')
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          _updateVendorStatus(
                            uid: uid,
                            status: 'pending_approval',
                          );
                        },
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label: const Text(
                    'Move to Review',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
        top: 4,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
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
            Icon(icon, size: 22),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
          'Vendor Management',
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('vendors')
            .snapshots(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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

          int pending = 0;
          int approved = 0;
          int rejected = 0;

          for (final doc in docs) {
            final data =
                doc.data() as Map<String, dynamic>;

            final status = (
              data['status'] ?? ''
            ).toString().toLowerCase();

            if (status == 'approved') {
              approved++;
            } else if (status == 'rejected') {
              rejected++;
            } else {
              pending++;
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(
                const Duration(milliseconds: 500),
              );
            },
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                30,
              ),
              children: [
                // --------------------------------------------
                // HEADER
                // --------------------------------------------

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF111827),
                        Color(0xFF374151),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(17),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vendor Control Center',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Review vendors and verify documents',
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

                // --------------------------------------------
                // STATISTICS
                // --------------------------------------------

                Row(
                  children: [
                    _statCard(
                      title: 'Total Vendors',
                      value: docs.length.toString(),
                      icon:
                          Icons.groups_rounded,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      title: 'Pending',
                      value: pending.toString(),
                      icon:
                          Icons.pending_actions_rounded,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      title: 'Approved',
                      value: approved.toString(),
                      icon:
                          Icons.verified_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$rejected vendor(s) rejected. '
                          'Open a vendor to review documents and update status.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --------------------------------------------
                // VENDOR LIST
                // --------------------------------------------

                if (docs.isEmpty)
                  Container(
                    padding:
                        const EdgeInsets.all(35),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 50,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No vendors found',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Vendor registrations will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...docs.map(
                    (doc) {
                      final data =
                          doc.data()
                              as Map<String, dynamic>;

                      return _vendorCard(
                        doc.id,
                        data,
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
