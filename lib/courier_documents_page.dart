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

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final ImagePicker _picker =
      ImagePicker();

  bool _loading = true;
  bool _uploading = false;

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

  final Map<String, Map<String, dynamic>>
      _documents = {};

  final Map<String, String>
      _documentTitles = {
    'profilePhoto': 'Profile Photo',
    'aadhaar': 'Aadhaar / ID Proof',
    'drivingLicence': 'Driving Licence',
    'vehicleRc': 'Vehicle RC',
    'addressProof': 'Address Proof',
  };

  final Map<String, bool>
      _requiredDocuments = {
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
        _auth.currentUser?.uid;

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
      final courierRef = _firestore
          .collection('couriers')
          .doc(_uid);

      final courierSnapshot =
          await courierRef.get();

      Map<String, dynamic> data = {};

      if (courierSnapshot.exists) {
        data =
            courierSnapshot.data() ?? {};
      } else {
        // --------------------------------------------------------
        // Courier document missing.
        // Users profile se basic data recover.
        // --------------------------------------------------------

        final userSnapshot =
            await _firestore
                .collection('users')
                .doc(_uid)
                .get();

        final userData =
            userSnapshot.data() ?? {};

        final role =
            userData['role']
                    ?.toString()
                    .toLowerCase() ??
                '';

        if (role == 'courier') {
          data = {
            'uid': _uid,
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
            'role': 'courier',
            'status':
                'pending_documents',
            'active': false,
            'documentsSubmitted': false,
            'approvedByAdmin': false,
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
            SetOptions(
              merge: true,
            ),
          );
        }
      }

      // ----------------------------------------------------------
      // BASIC COURIER INFORMATION
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
          data['status']
                  ?.toString()
                  .toLowerCase() ??
              'pending_documents';

      _documentsSubmitted =
          data['documentsSubmitted'] == true;

      _active =
          data['active'] == true;

      _approvedByAdmin =
          data['approvedByAdmin'] == true;

      _registrationType =
          data['registrationType']
                  ?.toString() ??
              '';

      _registrationNo =
          data['registrationNo']
                  ?.toString() ??
              '';

      _rejectionReason =
          data['rejectionReason']
                  ?.toString() ??
              '';

      // ----------------------------------------------------------
      // DOCUMENTS
      // ----------------------------------------------------------

      final documentsData =
          data['documents'];

      _documents.clear();

      if (documentsData is Map) {
        for (final entry
            in documentsData.entries) {
          final key =
              entry.key.toString();

          if (entry.value is Map) {
            _documents[key] =
                Map<String, dynamic>.from(
              entry.value as Map,
            );
          }
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
          'Courier details load nahi ho paye.\n$e',
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
      title =
          'Documents Pending for Upload';

      message =
          'Aapka Courier registration successful hai. '
          'Ab sabhi required documents upload karein.';

      icon =
          Icons.upload_file;

      color =
          Colors.orange;
    } else if (_status ==
        'pending_approval') {
      title =
          'Admin Approval Pending';

      message =
          'Aapke sabhi documents Admin approval ke liye submit ho chuke hain. '
          'Approval milne tak Courier Panel aur orders available nahi honge.';

      icon =
          Icons.hourglass_top;

      color =
          Colors.orange;
    } else if (_status ==
        'rejected') {
      title =
          'Documents Rejected';

      message =
          'Admin ne documents reject kiye hain. '
          'Rejected documents ko replace karke dobara submit karein.';

      icon =
          Icons.cancel_outlined;

      color =
          Colors.red;
    } else if (_status ==
            'approved' &&
        _active &&
        _approvedByAdmin) {
      title =
          'Courier Approved';

      message =
          'Aapka Courier account Admin dwara approved aur active hai.';

      icon =
          Icons.check_circle;

      color =
          Colors.green;
    } else {
      title =
          'Application Status';

      message =
          'Aapka Courier application verification mein hai.';

      icon =
          Icons.info_outline;

      color =
          Colors.blue;
    }

    return Card(
      elevation: 3,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(18),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color:
                color.withValues(
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
              decoration:
                  BoxDecoration(
                color:
                    color.withValues(
                  alpha: 0.12,
                ),
                shape:
                    BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(
              width: 14,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(
                    height: 7,
                  ),
                  Text(
                    message,
                    style:
                        const TextStyle(
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
  // COURIER PROFILE CARD
  // ============================================================

  Widget _buildCourierProfileCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                _courierName.isNotEmpty
                    ? _courierName[0]
                        .toUpperCase()
                    : 'C',
                style:
                    const TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(
              width: 14,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _courierName.isEmpty
                        ? 'Courier'
                        : _courierName,
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  if (_courierPhone
                      .isNotEmpty)
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
                  if (_courierEmail
                      .isNotEmpty)
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
  // PICK & UPLOAD DOCUMENT
  // ============================================================

  Future<void> _pickAndUploadDocument(
    String key,
  ) async {
    if (_uid == null) {
      _showMessage(
        'Courier account nahi mila.',
        isError: true,
      );
      return;
    }

    if (_uploading) return;

    try {
      final XFile? pickedFile =
          await _picker.pickImage(
        source:
            ImageSource.gallery,
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

      final file =
          File(pickedFile.path);

      if (!await file.exists()) {
        throw Exception(
          'Selected image file nahi mili.',
        );
      }

      final fileSize =
          await file.length();

      if (fileSize >=
          10 * 1024 * 1024) {
        throw Exception(
          'File size 10 MB se kam honi chahiye.',
        );
      }

      final timestamp =
          DateTime.now()
              .millisecondsSinceEpoch;

      final fileName =
          '${timestamp}_$key.jpg';

      final storagePath =
          'courier_documents/$_uid/$fileName';

      final storageRef =
          _storage
              .ref()
              .child(storagePath);

      final metadata =
          SettableMetadata(
        contentType:
            'image/jpeg',
        customMetadata: {
          'courierUid':
              _uid!,
          'documentType':
              key,
        },
      );

      await storageRef.putFile(
        file,
        metadata,
      );

      final downloadUrl =
          await storageRef
              .getDownloadURL();

      if (downloadUrl.isEmpty) {
        throw Exception(
          'Download URL nahi mila.',
        );
      }

      // ----------------------------------------------------------
      // IMPORTANT:
      // Replace/re-upload hone par document status "pending"
      // rahega, taaki Admin dobara review kare.
      // ----------------------------------------------------------

      final documentData = {
        'status': 'pending',
        'url': downloadUrl,
        'fileName': fileName,
        'storagePath':
            storagePath,
        'uploadedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
        'rejectionReason': '',
      };

      await _firestore
          .collection('couriers')
          .doc(_uid)
          .set(
        {
          'documents.$key':
              documentData,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) return;

      setState(() {
        _documents[key] = {
          'status': 'pending',
          'url': downloadUrl,
          'fileName': fileName,
          'storagePath':
              storagePath,
          'uploadedAt':
              Timestamp.now(),
          'updatedAt':
              Timestamp.now(),
          'rejectionReason': '',
        };

        // Agar rejected document replace hua hai,
        // to final submit ke baad hi pending approval hoga.
        if (_status == 'rejected') {
          _documentsSubmitted = false;
        }
      });

      _showMessage(
        '${_documentTitles[key]} successfully upload ho gaya.',
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
    String key,
  ) async {
    if (_uid == null) return;

    final document =
        _documents[key];

    if (document == null) return;

    final status =
        document['status']
                ?.toString() ??
            '';

    if (status == 'verified') {
      _showMessage(
        'Verified document delete nahi kiya ja sakta.',
        isError: true,
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'Delete Document',
          ),
          content: Text(
            '${_documentTitles[key]} ko delete karna chahte hain?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final storagePath =
          document['storagePath']
              ?.toString();

      if (storagePath != null &&
          storagePath.isNotEmpty) {
        try {
          await _storage
              .ref(storagePath)
              .delete();
        } on FirebaseException catch (e) {
          if (e.code !=
              'object-not-found') {
            rethrow;
          }
        }
      }

      await _firestore
          .collection('couriers')
          .doc(_uid)
          .set(
        {
          'documents.$key':
              FieldValue.delete(),
          'documentsSubmitted':
              false,
          'status':
              'pending_documents',
          'active': false,
          'approvedByAdmin':
              false,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (mounted) {
        setState(() {
          _documents.remove(key);
          _documentsSubmitted =
              false;
          _status =
              'pending_documents';
          _active = false;
          _approvedByAdmin =
              false;
        });
      }

      _showMessage(
        'Document delete ho gaya.',
      );
    } on FirebaseException catch (e) {
      _showMessage(
        _firebaseErrorMessage(e),
        isError: true,
      );
    } catch (e) {
      _showMessage(
        'Document delete nahi ho paya.\n$e',
        isError: true,
      );
    }
  }

  // ============================================================
  // SAVE REGISTRATION DETAILS
  // ============================================================

  Future<void>
      _saveRegistrationDetails() async {
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
        'Registration No. enter karein.',
        isError: true,
      );
      return;
    }

    try {
      await _firestore
          .collection('couriers')
          .doc(_uid)
          .set(
        {
          'registrationType':
              type,
          'registrationNo':
              number,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      _showMessage(
        'Registration details save ho gayi.',
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
    }
  }

  // ============================================================
  // CHECK REQUIRED DOCUMENTS
  // ============================================================

  bool _allRequiredDocumentsUploaded() {
    for (final entry
        in _requiredDocuments.entries) {
      if (entry.value != true) {
        continue;
      }

      final document =
          _documents[entry.key];

      if (document == null) {
        return false;
      }

      final url =
          document['url']
                  ?.toString()
                  .trim() ??
              '';

      if (url.isEmpty) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // SUBMIT FOR ADMIN APPROVAL
  // ============================================================

  Future<void> _submitForApproval() async {
    if (_uid == null) return;

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
        'Registration No. enter karein.',
        isError: true,
      );
      return;
    }

    if (!_allRequiredDocumentsUploaded()) {
      _showMessage(
        'Sabhi required documents upload karna zaroori hai.',
        isError: true,
      );
      return;
    }

    try {
      setState(() {
        _uploading = true;
      });

      // ----------------------------------------------------------
      // COURIER DOCUMENT
      // ----------------------------------------------------------

      await _firestore
          .collection('couriers')
          .doc(_uid)
          .set(
        {
          'registrationType':
              _registrationType
                  .trim(),
          'registrationNo':
              _registrationNo
                  .trim(),
          'documentsSubmitted':
              true,
          'status':
              'pending_approval',
          'registrationStatus':
              'pending_approval',
          'active': false,
          'approvedByAdmin':
              false,
          'rejectionReason':
              '',
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      // ----------------------------------------------------------
      // USER PROFILE
      //
      // update() ki jagah set(merge:true) rakha hai.
      // Isse users document missing hone par bhi error nahi aayega.
      // ----------------------------------------------------------

      await _firestore
          .collection('users')
          .doc(_uid)
          .set(
        {
          'uid': _uid,
          'role': 'courier',
          'name': _courierName,
          'phone': _courierPhone,
          'email': _courierEmail,
          'status':
              'pending_approval',
          'registrationStatus':
              'pending_approval',
          'active': false,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

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
        barrierDismissible:
            false,
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
              'Aapke documents Admin approval ke liye bhej diye gaye hain.\n\n'
              'Admin approval milne ke baad hi Courier account active hoga aur orders assign honge.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
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
          _uploading = false;
        });
      }
    }
  }

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  Color _documentStatusColor(
    String status,
  ) {
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

  String _documentStatusText(
    String status,
  ) {
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
    String key,
  ) {
    final title =
        _documentTitles[key] ??
            key;

    final document =
        _documents[key];

    final isUploaded =
        document != null &&
        (document['url']
                ?.toString()
                .trim()
                .isNotEmpty ??
            false);

    final status =
        document?['status']
                ?.toString() ??
            '';

    final isRequired =
        _requiredDocuments[key] ==
            true;

    final rejectionReason =
        document?[
                    'rejectionReason']
                ?.toString() ??
            '';

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration:
                  BoxDecoration(
                color:
                    isUploaded
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
                isUploaded
                    ? Icons.description
                    : Icons.upload_file,
                color: isUploaded
                    ? Colors.green
                    : Colors.grey
                        .shade700,
              ),
            ),
            const SizedBox(
              width: 14,
            ),
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
                          style:
                              TextStyle(
                            color:
                                Colors.red,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  if (isUploaded)
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color:
                              _documentStatusColor(
                            status,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          _documentStatusText(
                            status,
                          ),
                          style:
                              TextStyle(
                            color:
                                _documentStatusColor(
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
                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                  if (rejectionReason
                      .trim()
                      .isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        top: 6,
                      ),
                      child: Text(
                        'Reason: $rejectionReason',
                        style:
                            const TextStyle(
                          color:
                              Colors.red,
                          fontSize:
                              12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed:
                      _uploading
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
                  label:
                      Text(
                    isUploaded
                        ? 'Replace'
                        : 'Upload',
                  ),
                ),
                if (isUploaded &&
                    status !=
                        'verified')
                  TextButton(
                    onPressed:
                        _uploading
                            ? null
                            : () =>
                                _deleteDocument(
                                  key,
                                ),
                    child:
                        const Text(
                      'Delete',
                      style:
                          TextStyle(
                        color:
                            Colors.red,
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
                  .trim()
                  .isNotEmpty ??
              false)) {
        uploaded++;
      }
    }

    final total =
        _requiredDocuments.length;

    final progress =
        total == 0
            ? 0.0
            : uploaded / total;

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
            const SizedBox(
              height: 12,
            ),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              '$uploaded / $total required documents uploaded',
              style:
                  TextStyle(
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
            const SizedBox(
              height: 14,
            ),

            DropdownButtonFormField<
                String>(
              value:
                  _registrationType
                          .isEmpty
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
                  value:
                      'Private',
                  child:
                      Text('Private'),
                ),
                DropdownMenuItem(
                  value:
                      'Commercial',
                  child:
                      Text('Commercial'),
                ),
                DropdownMenuItem(
                  value:
                      'Other',
                  child:
                      Text('Other'),
                ),
              ],
              onChanged:
                  _uploading ||
                          _status ==
                              'pending_approval'
                      ? null
                      : (value) {
                          setState(() {
                            _registrationType =
                                value ??
                                    '';
                          });
                        },
            ),

            const SizedBox(
              height: 14,
            ),

            TextFormField(
              initialValue:
                  _registrationNo,
              textCapitalization:
                  TextCapitalization.characters,
              enabled:
                  !_uploading &&
                      _status !=
                          'pending_approval',
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

            const SizedBox(
              height: 12,
            ),

            SizedBox(
              width:
                  double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed:
                    _uploading ||
                            _status ==
                                'pending_approval'
                        ? null
                        : _saveRegistrationDetails,
                icon:
                    const Icon(
                  Icons.save_outlined,
                ),
                label:
                    const Text(
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
  // FIREBASE ERROR MESSAGE
  // ============================================================

  String _firebaseErrorMessage(
    FirebaseException e,
  ) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Firebase Rules check karein.';

      case 'unauthorized':
        return 'Aapko is action ki permission nahi hai.';

      case 'object-not-found':
        return 'File nahi mili.';

      case 'canceled':
        return 'Upload cancel ho gaya.';

      case 'unauthenticated':
        return 'Login session expire ho gaya.';

      case 'network-request-failed':
        return 'Internet connection check karein.';

      case 'quota-exceeded':
        return 'Firebase Storage quota exceed ho gaya.';

      case 'retry-limit-exceeded':
        return 'Upload baar-baar fail hua. Dobara try karein.';

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
            'Courier Documents',
          ),
        ),
        body: const Center(
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
        _status == 'approved' &&
            _active &&
            _approvedByAdmin;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Courier Documents',
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
                  // ==================================================
                  // STATUS
                  // ==================================================

                  _buildStatusHeader(),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // COURIER PROFILE
                  // ==================================================

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
                          Colors.red
                              .withValues(
                        alpha: 0.06,
                      ),
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

                  // ==================================================
                  // PROGRESS
                  // ==================================================

                  _buildProgressCard(),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // REGISTRATION
                  // ==================================================

                  _buildRegistrationDetails(),

                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // DOCUMENTS
                  // ==================================================

                  const Text(
                    'Required Documents',
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
                    'Sabhi marked (*) documents upload karna zaroori hai.',
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  ..._requiredDocuments
                      .keys
                      .map(
                        _buildDocumentCard,
                      ),

                  const SizedBox(
                    height: 8,
                  ),

                  // ==================================================
                  // SUBMIT BUTTON
                  // ==================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height: 52,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _uploading ||
                                  isPendingApproval ||
                                  isApproved
                              ? null
                              : _submitForApproval,
                      icon:
                          Icon(
                        isPendingApproval
                            ? Icons.hourglass_top
                            : isApproved
                                ? Icons.check_circle
                                : Icons.send,
                        color:
                            Colors.white,
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
                    height: 24,
                  ),

                  // ==================================================
                  // APPROVAL INFORMATION
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
                            Icons
                                .security,
                            color:
                                Colors.blue.shade700,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          const Expanded(
                            child:
                                Text(
                              'Admin approval ke bina Courier account active nahi hoga aur koi order/task assign nahi kiya ja sakega.',
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
            // UPLOAD OVERLAY
            // ========================================================

            if (_uploading)
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
                            'Document upload ho raha hai...',
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
