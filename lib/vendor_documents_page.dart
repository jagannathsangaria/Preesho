import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  final ImagePicker _picker =
      ImagePicker();

  bool _loading = false;

  final List<_DocumentType> _documents = const [
    _DocumentType(
      key: 'pan',
      title: 'PAN Card',
      subtitle: 'Upload clear PAN card',
      icon: Icons.credit_card,
      required: true,
    ),
    _DocumentType(
      key: 'aadhaar',
      title: 'Aadhaar Card',
      subtitle: 'Upload Aadhaar document',
      icon: Icons.badge_outlined,
      required: true,
    ),
    _DocumentType(
      key: 'gst',
      title: 'GST Certificate',
      subtitle: 'Upload GST registration certificate',
      icon: Icons.receipt_long_outlined,
      required: true,
    ),
    _DocumentType(
      key: 'bank',
      title: 'Bank / Cancelled Cheque',
      subtitle: 'Upload cancelled cheque or bank proof',
      icon: Icons.account_balance_outlined,
      required: true,
    ),
    _DocumentType(
      key: 'addressProof',
      title: 'Address Proof',
      subtitle: 'Upload valid business/address proof',
      icon: Icons.location_on_outlined,
      required: true,
    ),
    _DocumentType(
      key: 'other',
      title: 'Other Document',
      subtitle: 'Optional supporting document',
      icon: Icons.description_outlined,
      required: false,
    ),
  ];

  String get _uid {
    final passedUid =
        widget.vendorUid?.trim();

    if (passedUid != null &&
        passedUid.isNotEmpty) {
      return passedUid;
    }

    return FirebaseAuth
            .instance
            .currentUser
            ?.uid ??
        '';
  }

  Map<String, dynamic> _documentsMap(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _documentData(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  // ============================================================
  // UPLOAD DOCUMENT
  // ============================================================

  Future<void> _uploadDocument(
    _DocumentType document,
  ) async {
    if (_uid.isEmpty) {
      _showMessage(
        'Vendor account not found.',
      );
      return;
    }

    if (_loading) return;

    try {
      // --------------------------------------------------------
      // CHECK VENDOR STATUS
      // --------------------------------------------------------

      final vendorSnapshot =
          await _firestore
              .collection('vendors')
              .doc(_uid)
              .get();

      if (!vendorSnapshot.exists) {
        _showMessage(
          'Vendor profile not found.',
        );
        return;
      }

      final vendorData =
          vendorSnapshot.data() ??
              <String, dynamic>{};

      final status =
          (vendorData['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (status == 'approved') {
        _showMessage(
          'Vendor is already approved. Documents are locked.',
        );
        return;
      }

      final XFile? picked =
          await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      if (!mounted) return;

      setState(() {
        _loading = true;
      });

      final File file =
          File(picked.path);

      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${document.key}.jpg';

      final Reference storageRef =
          _storage
              .ref()
              .child('vendor_documents')
              .child(_uid)
              .child(fileName);

      final UploadTask uploadTask =
          storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
        ),
      );

      final TaskSnapshot snapshot =
          await uploadTask;

      final String downloadUrl =
          await snapshot.ref
              .getDownloadURL();

      final DocumentReference<
              Map<String, dynamic>>
          vendorRef =
          _firestore
              .collection('vendors')
              .doc(_uid);

      final DocumentSnapshot<
              Map<String, dynamic>>
          latestSnapshot =
          await vendorRef.get();

      final Map<String, dynamic>
          latestVendorData =
          latestSnapshot.data() ??
              <String, dynamic>{};

      final Map<String, dynamic>
          documents =
          _documentsMap(
        latestVendorData['documents'],
      );

      // --------------------------------------------------------
      // NEW UPLOAD = PENDING
      // --------------------------------------------------------

      documents[document.key] = {
        'status': 'pending',
        'url': downloadUrl,
        'fileName': fileName,
        'uploadedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
        'rejectionReason': '',
      };

      await vendorRef.update({
        'documents': documents,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage(
        '${document.title} uploaded successfully.',
      );
    } catch (e) {
      debugPrint(
        'Vendor document upload error: $e',
      );

      if (mounted) {
        _showMessage(
          'Upload failed. Please try again.',
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

  // ============================================================
  // DELETE DOCUMENT
  // ============================================================

  Future<void> _deleteDocument(
    _DocumentType document,
  ) async {
    if (_uid.isEmpty) {
      _showMessage(
        'Vendor account not found.',
      );
      return;
    }

    if (_loading) return;

    try {
      setState(() {
        _loading = true;
      });

      final DocumentReference<
              Map<String, dynamic>>
          vendorRef =
          _firestore
              .collection('vendors')
              .doc(_uid);

      final DocumentSnapshot<
              Map<String, dynamic>>
          vendorSnapshot =
          await vendorRef.get();

      if (!vendorSnapshot.exists) {
        _showMessage(
          'Vendor profile not found.',
        );
        return;
      }

      final Map<String, dynamic>
          data =
          vendorSnapshot.data() ??
              <String, dynamic>{};

      final Map<String, dynamic>
          documents =
          _documentsMap(
        data['documents'],
      );

      final Map<String, dynamic>
          documentData =
          _documentData(
        documents[document.key],
      );

      final String status =
          (documentData['status'] ??
                  'pending')
              .toString()
              .trim()
              .toLowerCase();

      // --------------------------------------------------------
      // VERIFIED DOCUMENT CANNOT BE DELETED
      // --------------------------------------------------------

      if (status == 'verified') {
        if (mounted) {
          _showMessage(
            'Verified document cannot be removed.',
          );
        }
        return;
      }

      final String url =
          (documentData['url'] ?? '')
              .toString();

      if (url.isNotEmpty) {
        try {
          await _storage
              .refFromURL(url)
              .delete();
        } catch (_) {
          // Continue with Firestore cleanup.
        }
      }

      documents[document.key] = {
        'status': 'pending',
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      await vendorRef.update({
        'documents': documents,
        'documentsSubmitted': false,
        'status': 'pending_documents',
        'active': false,
        'approvedByAdmin': false,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      // Keep users document status synchronized.
      await _firestore
          .collection('users')
          .doc(_uid)
          .update({
        'status': 'pending_documents',
        'active': false,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage(
        '${document.title} removed.',
      );
    } catch (e) {
      debugPrint(
        'Vendor document delete error: $e',
      );

      if (mounted) {
        _showMessage(
          'Unable to remove document.',
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

  // ============================================================
  // SUBMIT FOR ADMIN APPROVAL
  // ============================================================

  Future<void> _submitForApproval() async {
    if (_uid.isEmpty) {
      _showMessage(
        'Vendor account not found.',
      );
      return;
    }

    if (_loading) return;

    try {
      setState(() {
        _loading = true;
      });

      // --------------------------------------------------------
      // GET VENDOR
      // --------------------------------------------------------

      final vendorRef =
          _firestore
              .collection('vendors')
              .doc(_uid);

      final vendorSnapshot =
          await vendorRef.get();

      if (!vendorSnapshot.exists) {
        _showMessage(
          'Vendor profile not found.',
        );
        return;
      }

      final vendorData =
          vendorSnapshot.data() ??
              <String, dynamic>{};

      final currentStatus =
          (vendorData['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      final alreadySubmitted =
          vendorData['documentsSubmitted'] ==
              true;

      // --------------------------------------------------------
      // ALREADY SUBMITTED
      // --------------------------------------------------------

      if (alreadySubmitted &&
          currentStatus ==
              'pending_approval') {
        _showMessage(
          'Documents are already submitted and waiting for Admin approval.',
        );
        return;
      }

      if (currentStatus ==
          'approved') {
        _showMessage(
          'Vendor is already approved.',
        );
        return;
      }

      // --------------------------------------------------------
      // CHECK REQUIRED DOCUMENTS
      // --------------------------------------------------------

      final Map<String, dynamic>
          documents =
          _documentsMap(
        vendorData['documents'],
      );

      final List<String>
          missingDocuments = [];

      final List<String>
          rejectedDocuments = [];

      for (final document
          in _documents) {
        if (!document.required) {
          continue;
        }

        final Map<String, dynamic>
            documentData =
            _documentData(
          documents[document.key],
        );

        final String status =
            (documentData['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        final String url =
            (documentData['url'] ?? '')
                .toString();

        if (url.isEmpty) {
          missingDocuments.add(
            document.title,
          );
        } else if (status ==
            'rejected') {
          rejectedDocuments.add(
            document.title,
          );
        }
      }

      // --------------------------------------------------------
      // MISSING DOCUMENT
      // --------------------------------------------------------

      if (missingDocuments.isNotEmpty) {
        _showMessage(
          'Please upload: ${missingDocuments.join(', ')}',
        );
        return;
      }

      // --------------------------------------------------------
      // REJECTED DOCUMENT
      // --------------------------------------------------------

      if (rejectedDocuments.isNotEmpty) {
        _showMessage(
          'Please replace rejected document(s): ${rejectedDocuments.join(', ')}',
        );
        return;
      }

      // --------------------------------------------------------
      // ALL REQUIRED DOCUMENTS UPLOADED
      // --------------------------------------------------------

      await vendorRef.update({
        'documentsSubmitted': true,
        'status': 'pending_approval',
        'active': false,
        'approvedByAdmin': false,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      // --------------------------------------------------------
      // UPDATE USERS DOCUMENT
      // --------------------------------------------------------

      await _firestore
          .collection('users')
          .doc(_uid)
          .update({
        'status': 'pending_approval',
        'active': false,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await _showApprovalDialog();
    } catch (e) {
      debugPrint(
        'Vendor submit approval error: $e',
      );

      if (mounted) {
        _showMessage(
          'Unable to submit documents. Please try again.',
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

  // ============================================================
  // APPROVAL DIALOG
  // ============================================================

  Future<void> _showApprovalDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            size: 50,
            color: Colors.green,
          ),
          title: const Text(
            'Documents Submitted',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Your Vendor documents have been submitted successfully.\n\n'
            'Your account is now waiting for Admin verification and approval.\n\n'
            'You will not be able to access the Vendor Panel until Admin approves your account.',
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context)
                      .pop();

                  Navigator.of(context)
                      .pop();
                },
                child: const Text(
                  'Done',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      case 'pending':
      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String _statusText(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'verified':
        return 'VERIFIED';

      case 'rejected':
        return 'REJECTED';

      case 'pending':
      default:
        return 'PENDING';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Vendor Documents',
          ),
        ),
        body: const Center(
          child: Text(
            'Vendor account not found.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vendor Documents',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream: _firestore
            .collection('vendors')
            .doc(_uid)
            .snapshots(),

        builder:
            (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final Map<String, dynamic>
              vendorData =
              snapshot.data?.data() ??
                  <String, dynamic>{};

          final Map<String, dynamic>
              documents =
              _documentsMap(
            vendorData['documents'],
          );

          final String vendorStatus =
              (vendorData['status'] ??
                      'pending_documents')
                  .toString()
                  .trim()
                  .toLowerCase();

          final bool documentsSubmitted =
              vendorData[
                      'documentsSubmitted'] ==
                  true;

          int verifiedCount = 0;
          int uploadedCount = 0;

          for (final document
              in _documents) {
            if (!document.required) {
              continue;
            }

            final Map<String, dynamic>
                documentData =
                _documentData(
              documents[document.key],
            );

            final String status =
                (documentData['status'] ??
                        '')
                    .toString()
                    .trim()
                    .toLowerCase();

            final String url =
                (documentData['url'] ??
                        '')
                    .toString();

            if (url.isNotEmpty) {
              uploadedCount++;
            }

            if (status == 'verified') {
              verifiedCount++;
            }
          }

          final bool allUploaded =
              uploadedCount == 5;

          final bool allVerified =
              verifiedCount == 5;

          final bool canSubmit =
              allUploaded &&
              vendorStatus !=
                  'pending_approval' &&
              vendorStatus !=
                  'approved';

          return Stack(
            children: [
              ListView(
                padding:
                    const EdgeInsets.all(16),

                children: [
                  // ==================================================
                  // STATUS CARD
                  // ==================================================

                  _buildAccountStatusCard(
                    vendorStatus,
                    documentsSubmitted,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // PROGRESS
                  // ==================================================

                  _buildProgressCard(
                    uploadedCount,
                    verifiedCount,
                    allUploaded,
                    allVerified,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  const Text(
                    'Vendor KYC & Documents',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  const Text(
                    'Upload all required documents for Admin verification.',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // ==================================================
                  // DOCUMENT LIST
                  // ==================================================

                  ..._documents.map(
                    (document) {
                      final Map<
                              String,
                              dynamic>
                          documentData =
                          _documentData(
                        documents[
                            document.key],
                      );

                      return _buildDocumentCard(
                        document,
                        documentData,
                        vendorStatus,
                      );
                    },
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  // ==================================================
                  // SUBMIT BUTTON
                  // ==================================================

                  if (vendorStatus ==
                      'pending_documents') ...[
                    _buildSubmitCard(
                      allUploaded,
                      canSubmit,
                    ),
                  ],

                  // ==================================================
                  // WAITING FOR ADMIN
                  // ==================================================

                  if (vendorStatus ==
                      'pending_approval') ...[
                    _buildWaitingCard(),
                  ],

                  // ==================================================
                  // APPROVED
                  // ==================================================

                  if (vendorStatus ==
                      'approved') ...[
                    _buildApprovedCard(),
                  ],

                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // INFO
                  // ==================================================

                  Container(
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.blue
                          .withOpacity(
                        0.08,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            'After submission, your documents will be reviewed by Preesho Admin. Your Vendor account remains inactive until Admin approval.',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),
                ],
              ),

              // ====================================================
              // LOADING OVERLAY
              // ====================================================

              if (_loading)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding:
                            EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(
                              height: 16,
                            ),
                            Text(
                              'Processing document...',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // ACCOUNT STATUS CARD
  // ============================================================

  Widget _buildAccountStatusCard(
    String status,
    bool submitted,
  ) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (status) {
      case 'pending_approval':
        icon = Icons.hourglass_top;
        color = Colors.orange;
        title = 'Waiting for Admin Approval';
        subtitle =
            'Your documents have been submitted and are under review.';
        break;

      case 'approved':
        icon = Icons.verified;
        color = Colors.green;
        title = 'Vendor Approved';
        subtitle =
            'Your Vendor account has been approved by Admin.';
        break;

      case 'rejected':
        icon = Icons.cancel_outlined;
        color = Colors.red;
        title = 'Vendor Rejected';
        subtitle =
            'Please check the document rejection details.';
        break;

      default:
        icon = Icons.upload_file;
        color = Colors.blue;
        title = 'Documents Required';
        subtitle =
            'Upload all required documents and submit for approval.';
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor:
                  color.withOpacity(0.10),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
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
  // PROGRESS CARD
  // ============================================================

  Widget _buildProgressCard(
    int uploadedCount,
    int verifiedCount,
    bool allUploaded,
    bool allVerified,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allVerified
                      ? Icons.verified
                      : Icons.fact_check_outlined,
                  size: 30,
                  color: allVerified
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(
                  width: 12,
                ),
                const Expanded(
                  child: Text(
                    'Document Verification',
                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              '$uploadedCount of 5 required documents uploaded',
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            LinearProgressIndicator(
              value:
                  uploadedCount / 5,
              minHeight: 8,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              '$verifiedCount of 5 required documents verified',
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            LinearProgressIndicator(
              value:
                  verifiedCount / 5,
              minHeight: 8,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DOCUMENT CARD
  // ============================================================

  Widget _buildDocumentCard(
    _DocumentType document,
    Map<String, dynamic> data,
    String vendorStatus,
  ) {
    final String status =
        (data['status'] ??
                'pending')
            .toString()
            .trim()
            .toLowerCase();

    final String url =
        (data['url'] ?? '')
            .toString();

    final String rejectionReason =
        (data['rejectionReason'] ??
                '')
            .toString();

    final bool uploaded =
        url.isNotEmpty;

    final bool verified =
        status == 'verified';

    final bool approved =
        vendorStatus == 'approved';

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                CircleAvatar(
                  child: Icon(
                    document.icon,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              document.title,
                              style:
                                  const TextStyle(
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),

                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  8,
                              vertical: 4,
                            ),
                            decoration:
                                BoxDecoration(
                              color: document
                                      .required
                                  ? Colors
                                      .red
                                      .withOpacity(
                                      0.08,
                                    )
                                  : Colors
                                      .blue
                                      .withOpacity(
                                      0.08,
                                    ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                6,
                              ),
                            ),
                            child: Text(
                              document
                                      .required
                                  ? 'REQUIRED'
                                  : 'OPTIONAL',
                              style:
                                  TextStyle(
                                fontSize:
                                    10,
                                fontWeight:
                                    FontWeight
                                        .bold,
                                color: document
                                        .required
                                    ? Colors.red
                                    : Colors
                                        .blue,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        document.subtitle,
                        style:
                            const TextStyle(
                          color:
                              Colors.grey,
                          fontSize:
                              13,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  9,
                              vertical: 5,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  _statusColor(
                                status,
                              ).withOpacity(
                                0.10,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                8,
                              ),
                            ),
                            child: Text(
                              _statusText(
                                status,
                              ),
                              style:
                                  TextStyle(
                                color:
                                    _statusColor(
                                  status,
                                ),
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),

                          if (uploaded) ...[
                            const SizedBox(
                              width: 8,
                            ),
                            const Icon(
                              Icons.attach_file,
                              size: 16,
                            ),
                            const SizedBox(
                              width: 3,
                            ),
                            const Text(
                              'Uploaded',
                              style:
                                  TextStyle(
                                fontSize:
                                    12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ==================================================
            // REJECTION
            // ==================================================

            if (status ==
                'rejected') ...[
              const SizedBox(
                height: 10,
              ),

              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.red
                      .withOpacity(
                    0.06,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
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
                              .error_outline,
                          color:
                              Colors.red,
                          size: 18,
                        ),
                        SizedBox(
                          width: 6,
                        ),
                        Text(
                          'Document Rejected',
                          style:
                              TextStyle(
                            color:
                                Colors.red,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),

                    if (rejectionReason
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        'Reason: $rejectionReason',
                        style:
                            const TextStyle(
                          color:
                              Colors.red,
                          fontSize:
                              12,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 6,
                    ),

                    const Text(
                      'Please upload a corrected document.',
                      style:
                          TextStyle(
                        color:
                            Colors.red,
                        fontSize:
                            12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ==================================================
            // VERIFIED
            // ==================================================

            if (verified) ...[
              const SizedBox(
                height: 10,
              ),

              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.green
                      .withOpacity(
                    0.06,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified,
                      color:
                          Colors.green,
                      size: 18,
                    ),
                    SizedBox(
                      width: 7,
                    ),
                    Expanded(
                      child: Text(
                        'Verified by Preesho Admin. This document is locked.',
                        style:
                            TextStyle(
                          color:
                              Colors.green,
                          fontSize:
                              12,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(
              height: 12,
            ),

            // ==================================================
            // UPLOAD / REPLACE / DELETE
            // ==================================================

            if (!approved &&
                !verified)
              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton
                            .icon(
                      onPressed:
                          _loading
                              ? null
                              : () =>
                                  _uploadDocument(
                                document,
                              ),
                      icon:
                          const Icon(
                        Icons
                            .upload_file,
                      ),
                      label: Text(
                        uploaded
                            ? 'Replace'
                            : 'Upload',
                      ),
                    ),
                  ),

                  if (uploaded) ...[
                    const SizedBox(
                      width: 8,
                    ),
                    IconButton(
                      tooltip:
                          'Remove',
                      onPressed:
                          _loading
                              ? null
                              : () =>
                                  _deleteDocument(
                                document,
                              ),
                      icon:
                          const Icon(
                        Icons
                            .delete_outline,
                        color:
                            Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUBMIT CARD
  // ============================================================

  Widget _buildSubmitCard(
    bool allUploaded,
    bool canSubmit,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.send_outlined,
              size: 36,
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'Ready for Admin Review?',
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              allUploaded
                  ? 'All required documents have been uploaded. Submit them for Admin approval.'
                  : 'Please upload all 5 required documents before submitting.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.grey,
                fontSize:
                    13,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            SizedBox(
              width:
                  double.infinity,
              height: 50,
              child:
                  FilledButton.icon(
                onPressed:
                    canSubmit
                        ? _submitForApproval
                        : null,
                icon:
                    const Icon(
                  Icons.send,
                ),
                label:
                    const Text(
                  'Submit for Admin Approval',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WAITING CARD
  // ============================================================

  Widget _buildWaitingCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.hourglass_top,
              size: 42,
              color: Colors.orange,
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'Waiting for Admin Approval',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Your Vendor documents have been submitted successfully. Admin will review them before activating your account.',
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
    );
  }

  // ============================================================
  // APPROVED CARD
  // ============================================================

  Widget _buildApprovedCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.verified,
              size: 46,
              color: Colors.green,
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'Vendor Account Approved',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Your Vendor account has been approved by Admin.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// DOCUMENT TYPE
// ================================================================

class _DocumentType {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool required;

  const _DocumentType({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.required,
  });
}
