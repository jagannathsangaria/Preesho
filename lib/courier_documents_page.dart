import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _uploading = false;

  String? _uid;

  String _status = 'pending_documents';

  bool _documentsSubmitted = false;
  bool _active = false;
  bool _approvedByAdmin = false;

  String _registrationType = '';
  String _registrationNo = '';

  final Map<String, Map<String, dynamic>> _documents = {};

  final Map<String, String> _documentTitles = {
    'profilePhoto': 'Profile Photo',
    'aadhaar': 'Aadhaar / ID Proof',
    'drivingLicence': 'Driving Licence',
    'vehicleRc': 'Vehicle RC',
    'addressProof': 'Address Proof',
  };

  final Map<String, bool> _requiredDocuments = {
    'profilePhoto': true,
    'aadhaar': true,
    'drivingLicence': true,
    'vehicleRc': true,
    'addressProof': true,
  };

  @override
  void initState() {
    super.initState();

    _uid = widget.courierUid ??
        FirebaseAuth.instance.currentUser?.uid;

    _loadCourierData();
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
      final doc = await _firestore
          .collection('couriers')
          .doc(_uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        _status =
            data['status']?.toString() ??
                'pending_documents';

        _documentsSubmitted =
            data['documentsSubmitted'] == true;

        _active =
            data['active'] == true;

        _approvedByAdmin =
            data['approvedByAdmin'] == true;

        final documentsData =
            data['documents'];

        if (documentsData is Map) {
          _documents.clear();

          for (final entry
              in documentsData.entries) {
            final key = entry.key.toString();

            if (entry.value is Map) {
              _documents[key] =
                  Map<String, dynamic>.from(
                entry.value as Map,
              );
            }
          }
        }

        _registrationType =
            data['registrationType']?.toString() ?? '';

        _registrationNo =
            data['registrationNo']?.toString() ?? '';
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
          'Courier details load नहीं हो पाए।\n$e',
          isError: true,
        );
      }
    }
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
      title = 'Documents Pending for Upload';
      message =
          'आपका Courier registration सफल हो गया है। '
          'अब सभी required documents upload करें। '
          'Documents complete होने के बाद Admin approval के लिए submit करें।';
      icon = Icons.upload_file;
      color = Colors.orange;
    } else if (_status == 'pending_approval') {
      title = 'Documents Submitted';
      message =
          'आपके सभी documents Admin approval के लिए submit हो चुके हैं। '
          'Approval मिलने तक Courier Panel access नहीं मिलेगा।';
      icon = Icons.hourglass_top;
      color = Colors.orange;
    } else if (_status == 'rejected') {
      title = 'Documents Rejected';
      message =
          'Admin ने आपके documents reject किए हैं। '
          'कृपया rejected documents check करके उन्हें update करें और फिर से submit करें।';
      icon = Icons.cancel_outlined;
      color = Colors.red;
    } else if (_status == 'approved' &&
        _active &&
        _approvedByAdmin) {
      title = 'Courier Approved';
      message =
          'आपका Courier account Admin द्वारा approved और active है।';
      icon = Icons.check_circle;
      color = Colors.green;
    } else {
      title = 'Application Status';
      message =
          'आपका Courier application अभी Admin verification में है।';
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
          crossAxisAlignment:
              CrossAxisAlignment.start,
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
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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

  // ============================================================
  // PICK & UPLOAD DOCUMENT
  // ============================================================

  Future<void> _pickAndUploadDocument(
      String key) async {
    if (_uid == null) {
      _showMessage(
        'Courier account नहीं मिला।',
        isError: true,
      );
      return;
    }

    if (_uploading) return;

    try {
      final XFile? pickedFile =
          await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (pickedFile == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _uploading = true;
      });

      final file = File(pickedFile.path);

      if (!await file.exists()) {
        throw Exception(
          'Selected image file नहीं मिली। कृपया दूसरी image select करें।',
        );
      }

      final fileSize = await file.length();

      if (fileSize >= 10 * 1024 * 1024) {
        throw Exception(
          'File size 10 MB से कम होनी चाहिए।',
        );
      }

      final timestamp =
          DateTime.now().millisecondsSinceEpoch;

      final fileName =
          '${timestamp}_$key.jpg';

      final storagePath =
          'courier_documents/$_uid/$fileName';

      final storageRef =
          _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'courierUid': _uid!,
          'documentType': key,
        },
      );

      final uploadTask =
          storageRef.putFile(
        file,
        metadata,
      );

      await uploadTask;

      final downloadUrl =
          await storageRef.getDownloadURL();

      if (downloadUrl.isEmpty) {
        throw Exception(
          'Upload complete हुआ लेकिन download URL नहीं मिला।',
        );
      }

      final documentData = {
        'status': 'pending',
        'url': downloadUrl,
        'fileName': fileName,
        'storagePath': storagePath,
        'uploadedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
        'rejectionReason': '',
      };

      await _firestore
          .collection('couriers')
          .doc(_uid)
          .update({
        'documents.$key': documentData,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _documents[key] = {
          'status': 'pending',
          'url': downloadUrl,
          'fileName': fileName,
          'storagePath': storagePath,
          'uploadedAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'rejectionReason': '',
        };
      });

      _showMessage(
        '${_documentTitles[key]} successfully upload हो गया।',
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        _showMessage(
          _firebaseErrorMessage(e),
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Document upload failed.\n$e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE DOCUMENT
  // ============================================================

  Future<void> _deleteDocument(
      String key) async {
    if (_uid == null) return;

    final document = _documents[key];

    if (document == null) return;

    final status =
        document['status']?.toString() ?? '';

    if (status == 'verified') {
      _showMessage(
        'Verified document delete नहीं किया जा सकता।',
        isError: true,
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('Delete Document'),
          content: Text(
            '${_documentTitles[key]} को delete करना चाहते हैं?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final storagePath =
          document['storagePath']?.toString();

      final fileName =
          document['fileName']?.toString();

      if (storagePath != null &&
          storagePath.isNotEmpty) {
        try {
          await _storage
              .ref(storagePath)
              .delete();
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found') {
            rethrow;
          }
        }
      } else if (fileName != null &&
          fileName.isNotEmpty) {
        try {
          await _storage
              .ref()
              .child('courier_documents')
              .child(_uid!)
              .child(fileName)
              .delete();
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found') {
            rethrow;
          }
        }
      }

      await _firestore
          .collection('couriers')
          .doc(_uid)
          .update({
        'documents.$key':
            FieldValue.delete(),
        'documentsSubmitted': false,
        'status': 'pending_documents',
        'active': false,
        'approvedByAdmin': false,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _documents.remove(key);
          _documentsSubmitted = false;
          _status = 'pending_documents';
          _active = false;
          _approvedByAdmin = false;
        });
      }

      _showMessage(
        'Document delete हो गया।',
      );
    } on FirebaseException catch (e) {
      _showMessage(
        _firebaseErrorMessage(e),
        isError: true,
      );
    } catch (e) {
      _showMessage(
        'Document delete नहीं हो पाया.\n$e',
        isError: true,
      );
    }
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
        'Registration Type select करें।',
        isError: true,
      );
      return;
    }

    if (number.isEmpty) {
      _showMessage(
        'Registration No. दर्ज करें।',
        isError: true,
      );
      return;
    }

    try {
      await _firestore
          .collection('couriers')
          .doc(_uid)
          .update({
        'registrationType': type,
        'registrationNo': number,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      _showMessage(
        'Registration details save हो गईं।',
      );
    } on FirebaseException catch (e) {
      _showMessage(
        _firebaseErrorMessage(e),
        isError: true,
      );
    } catch (e) {
      _showMessage(
        'Details save नहीं हो पाईं.\n$e',
        isError: true,
      );
    }
  }

  // ============================================================
  // REQUIRED DOCUMENT CHECK
  // ============================================================

  bool _allRequiredDocumentsUploaded() {
    for (final entry
        in _requiredDocuments.entries) {
      if (entry.value == true) {
        final document =
            _documents[entry.key];

        if (document == null) {
          return false;
        }

        final url =
            document['url']?.toString() ?? '';

        if (url.isEmpty) {
          return false;
        }
      }
    }

    return true;
  }

  // ============================================================
  // SUBMIT FOR APPROVAL
  // ============================================================

  Future<void> _submitForApproval() async {
    if (_uid == null) return;

    if (_registrationType.trim().isEmpty) {
      _showMessage(
        'Registration Type select करें।',
        isError: true,
      );
      return;
    }

    if (_registrationNo.trim().isEmpty) {
      _showMessage(
        'Registration No. दर्ज करें।',
        isError: true,
      );
      return;
    }

    if (!_allRequiredDocumentsUploaded()) {
      _showMessage(
        'सभी required documents upload करना जरूरी है।',
        isError: true,
      );
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _uploading = true;
        });
      }

      await _firestore
          .collection('couriers')
          .doc(_uid)
          .update({
        'registrationType':
            _registrationType.trim(),
        'registrationNo':
            _registrationNo.trim(),
        'documentsSubmitted': true,
        'status': 'pending_approval',
        'active': false,
        'approvedByAdmin': false,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

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

      setState(() {
        _documentsSubmitted = true;
        _status = 'pending_approval';
        _active = false;
        _approvedByAdmin = false;
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Submitted Successfully',
                  ),
                ),
              ],
            ),
            content: const Text(
              'आपके documents Admin approval के लिए भेज दिए गए हैं.\n\n'
              'Admin approval मिलने के बाद ही आपका Courier account active होगा और आप orders प्राप्त कर सकेंगे.',
            ),
            actions: [
              ElevatedButton(
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
          _uploading = false;
        });
      }
    }
  }

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending Review';
      default:
        return 'Not Uploaded';
    }
  }

  // ============================================================
  // DOCUMENT CARD
  // ============================================================

  Widget _buildDocumentCard(
      String key) {
    final title =
        _documentTitles[key] ?? key;

    final document =
        _documents[key];

    final isUploaded =
        document != null &&
        (document['url']
                ?.toString()
                .isNotEmpty ??
            false);

    final status =
        document?['status']?.toString() ?? '';

    final isRequired =
        _requiredDocuments[key] == true;

    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isUploaded
                    ? Colors.green
                        .withValues(
                            alpha: 0.10)
                    : Colors.grey
                        .withValues(
                            alpha: 0.10),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                isUploaded
                    ? Icons.description
                    : Icons.upload_file,
                color: isUploaded
                    ? Colors.green
                    : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
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
                      if (isRequired)
                        const Text(
                          ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isUploaded)
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color:
                              _statusColor(
                            status,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          _statusText(
                            status,
                          ),
                          style: TextStyle(
                            color:
                                _statusColor(
                              status,
                            ),
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Not uploaded',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  if (status == 'rejected' &&
                      (document?[
                                  'rejectionReason']
                              ?.toString()
                              .isNotEmpty ??
                          false))
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 5,
                      ),
                      child: Text(
                        'Reason: ${document!['rejectionReason']}',
                        style:
                            const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () =>
                          _pickAndUploadDocument(
                            key,
                          ),
                  icon: Icon(
                    isUploaded
                        ? Icons.refresh
                        : Icons.upload,
                    size: 18,
                  ),
                  label: Text(
                    isUploaded
                        ? 'Replace'
                        : 'Upload',
                  ),
                ),
                if (isUploaded &&
                    status != 'verified')
                  TextButton(
                    onPressed: _uploading
                        ? null
                        : () =>
                            _deleteDocument(
                              key,
                            ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROGRESS CARD
  // ============================================================

  Widget _buildProgressCard() {
    int uploaded = 0;

    for (final key
        in _requiredDocuments.keys) {
      final document =
          _documents[key];

      if (document != null &&
          (document['url']
                  ?.toString()
                  .isNotEmpty ??
              false)) {
        uploaded++;
      }
    }

    final total =
        _requiredDocuments.length;

    final progress =
        total == 0 ? 0.0 : uploaded / total;

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
              'Document Progress',
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
                  BorderRadius.circular(10),
            ),
            const SizedBox(height: 10),
            Text(
              '$uploaded / $total required documents uploaded',
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
  // REGISTRATION DETAILS
  // ============================================================

  Widget _buildRegistrationDetails() {
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
              onChanged: _uploading
                  ? null
                  : (value) {
                      setState(() {
                        _registrationType =
                            value ?? '';
                      });
                    },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: ValueKey(
                _registrationNo,
              ),
              initialValue:
                  _registrationNo,
              textCapitalization:
                  TextCapitalization.characters,
              decoration:
                  const InputDecoration(
                labelText:
                    'Registration No.',
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
                    value;
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed: _uploading
                    ? null
                    : _saveRegistrationDetails,
                icon: const Icon(
                  Icons.save_outlined,
                ),
                label: const Text(
                  'Save Registration Details',
                ),
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
      FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied.\n'
            'Firebase Storage Rules या Firestore Rules check करें।';

      case 'unauthorized':
        return 'आपको इस action की permission नहीं है।';

      case 'object-not-found':
        return 'File नहीं मिली।\n'
            'Storage upload/path check करें।';

      case 'canceled':
        return 'Upload cancel हो गया।';

      case 'unauthenticated':
        return 'आपका login session समाप्त हो गया।';

      case 'network-request-failed':
        return 'Internet connection check करें।';

      case 'quota-exceeded':
        return 'Firebase Storage quota exceed हो गया।';

      case 'retry-limit-exceeded':
        return 'Upload बार-बार fail हुआ। Internet connection check करके फिर कोशिश करें।';

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
        content: Text(message),
        backgroundColor:
            isError
                ? Colors.red
                : Colors.green,
        duration:
            const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
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
          title: const Text(
            'Courier Documents',
          ),
        ),
        body: const Center(
          child: Text(
            'Courier account नहीं मिला।',
            style:
                TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Courier Documents',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding:
                  const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // MAIN STATUS
                  // ==================================================

                  _buildStatusHeader(),

                  const SizedBox(height: 16),

                  // ==================================================
                  // PROGRESS
                  // ==================================================

                  _buildProgressCard(),

                  const SizedBox(height: 16),

                  // ==================================================
                  // REGISTRATION
                  // ==================================================

                  _buildRegistrationDetails(),

                  const SizedBox(height: 20),

                  // ==================================================
                  // DOCUMENTS
                  // ==================================================

                  const Text(
                    'Required Documents',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'सभी marked (*) documents upload करना जरूरी है।',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 12),

                  ..._requiredDocuments
                      .keys
                      .map(
                        _buildDocumentCard,
                      ),

                  const SizedBox(height: 8),

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
                          _uploading ||
                                  _status ==
                                      'pending_approval'
                              ? null
                              : _submitForApproval,
                      icon: const Icon(
                        Icons.send,
                        color:
                            Colors.white,
                      ),
                      label:
                          Text(
                        _status ==
                                'pending_approval'
                            ? 'Waiting for Admin Approval'
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

                  const SizedBox(height: 24),

                  const Text(
                    'Security: Admin approval के बिना Courier account active नहीं होगा और कोई order/task assign नहीं किया जा सकेगा।',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),

            if (_uploading)
              Container(
                color: Colors.black
                    .withValues(
                  alpha: 0.35,
                ),
                child:
                    const Center(
                  child: Card(
                    child: Padding(
                      padding:
                          EdgeInsets.all(
                        24,
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(
                            height: 16,
                          ),
                          Text(
                            'Document upload हो रहा है...',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w600,
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
