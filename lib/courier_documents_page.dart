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

  final Map<String, Map<String, dynamic>> _documents = {};

  final Map<String, String> _documentTitles = {
    'profilePhoto': 'Profile Photo',
    'aadhaar': 'Aadhaar / ID Proof',
    'drivingLicence': 'Driving Licence',
    'vehicleRc': 'Vehicle RC',
    'addressProof': 'Address Proof',
  };

  final List<String> _requiredDocumentKeys = const [
    'profilePhoto',
    'aadhaar',
    'drivingLicence',
    'vehicleRc',
    'addressProof',
  ];

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
        // COURIER DOCUMENT MISSING
        // Recover profile from users collection.
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
      // DOCUMENTS
      // ----------------------------------------------------------

      _documents.clear();

      final documentsData =
          data['documents'];

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

  String _normalizeStatus(dynamic value) {
    return value
        ?.toString()
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_') ??
        '';
  }

  // ============================================================
  // CHECK IF EDITING IS ALLOWED
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
      title =
          'Documents Pending for Upload';

      message =
          'Aapka Courier registration successful hai. '
          'Sabhi required documents upload karke Admin approval ke liye submit karein.';

      icon =
          Icons.upload_file;

      color =
          Colors.orange;
    } else if (_status == 'pending_approval') {
      title =
          'Admin Approval Pending';

      message =
          'Aapke documents Admin approval ke liye submit ho chuke hain. '
          'Approval milne tak orders receive nahi honge.';

      icon =
          Icons.hourglass_top;

      color =
          Colors.orange;
    } else if (_status == 'rejected') {
      title =
          'Documents Rejected';

      message =
          'Admin ne documents reject kiye hain. '
          'Required documents ko replace karke dobara submit karein.';

      icon =
          Icons.cancel_outlined;

      color =
          Colors.red;
    } else if (_isApproved) {
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
        decoration: BoxDecoration(
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
              decoration: BoxDecoration(
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
              initialValue:
                  _registrationNo,
              enabled: editable,
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
        'Registration No. enter karein.',
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
    } finally {
      if (mounted) {
        setState(() {
          _savingDetails = false;
        });
      }
    }
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

    if (!_canEditDocuments) {
      _showMessage(
        'Abhi documents edit nahi kiye ja sakte.',
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

      if (fileSize >
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
          _storage.ref().child(
                storagePath,
              );

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
          await storageRef.getDownloadURL();

      if (downloadUrl.trim().isEmpty) {
        throw Exception(
          'Download URL nahi mila.',
        );
      }

      final oldDocument =
          _documents[key];

      // ----------------------------------------------------------
      // NEW DOCUMENT
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

      final courierRef =
          _firestore.collection('couriers').doc(_uid);

      final userRef =
          _firestore.collection('users').doc(_uid);

      final batch =
          _firestore.batch();

      batch.set(
        courierRef,
        {
          'documents.$key':
              documentData,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // ----------------------------------------------------------
      // If courier was previously rejected, keep user status
      // consistent. Final status becomes pending_approval only
      // after pressing Submit.
      // ----------------------------------------------------------

      batch.set(
        userRef,
        {
          'role': 'courier',
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // ----------------------------------------------------------
      // DELETE OLD STORAGE FILE AFTER NEW FILE IS SAFE
      // ----------------------------------------------------------

      if (oldDocument != null) {
        final oldPath =
            oldDocument['storagePath']
                ?.toString()
                .trim();

        if (oldPath != null &&
            oldPath.isNotEmpty &&
            oldPath != storagePath) {
          try {
            await _storage
                .ref(oldPath)
                .delete();
          } catch (_) {
            // Old file delete failure should not
            // make the new upload fail.
          }
        }
      }

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

    if (!_canEditDocuments) {
      _showMessage(
        'Abhi document delete nahi kiya ja sakta.',
        isError: true,
      );
      return;
    }

    final document =
        _documents[key];

    if (document == null) return;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'Delete Document',
          ),
          content:
              Text(
            '${_documentTitles[key]} ko delete karna chahte hain?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final storagePath =
          document['storagePath']
              ?.toString()
              .trim();

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

      final courierRef =
          _firestore.collection('couriers').doc(_uid);

      final userRef =
          _firestore.collection('users').doc(_uid);

      final batch =
          _firestore.batch();

      batch.set(
        courierRef,
        {
          'documents.$key':
              FieldValue.delete(),
          'documentsSubmitted':
              false,
          'status':
              'pending_documents',
          'registrationStatus':
              'pending_documents',
          'active': false,
          'approvedByAdmin':
              false,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        userRef,
        {
          'status':
              'pending_documents',
          'registrationStatus':
              'pending_documents',
          'active': false,
          'approvedByAdmin':
              false,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

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
  // CHECK ALL REQUIRED DOCUMENTS
  // ============================================================

  bool _allRequiredDocumentsUploaded() {
    for (final key
        in _requiredDocumentKeys) {
      final document =
          _documents[key];

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
        'Registration No. enter karein.',
        isError: true,
      );
      return;
    }

    if (!_allRequiredDocumentsUploaded()) {
      _showMessage(
        'Sabhi 5 required documents upload karna zaroori hai.',
        isError: true,
      );
      return;
    }

    try {
      setState(() {
        _uploading = true;
      });

      final courierRef =
          _firestore.collection('couriers').doc(_uid);

      final userRef =
          _firestore.collection('users').doc(_uid);

      final now =
          FieldValue.serverTimestamp();

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
              'Aapke documents Admin approval ke liye bhej diye gaye hain.\n\n'
              'Admin approval milne ke baad hi Courier account active hoga aur orders assign honge.',
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
          _uploading = false;
        });
      }
    }
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Widget _buildProgressCard() {
    int uploaded = 0;

    for (final key
        in _requiredDocumentKeys) {
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
        _requiredDocumentKeys.length;

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
  // DOCUMENT CARD
  // ============================================================

  Widget _buildDocumentCard(
    String key,
  ) {
    final title =
        _documentTitles[key] ?? key;

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
                ?.toString()
                .toLowerCase() ??
            '';

    final rejectionReason =
        document?['rejectionReason']
                ?.toString()
                .trim() ??
            '';

    final editable =
        _canEditDocuments;

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
          children: [
            Row(
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
                      const SizedBox(height: 6),
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
                    ],
                  ),
                ),
              ],
            ),

            if (isUploaded) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
                child: Image.network(
                  document['url']
                      .toString(),
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder:
                      (
                    context,
                    child,
                    loadingProgress,
                  ) {
                    if (loadingProgress ==
                        null) {
                      return child;
                    }

                    return const SizedBox(
                      height: 190,
                      child: Center(
                        child:
                            CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder:
                      (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Container(
                      height: 190,
                      alignment:
                          Alignment.center,
                      color:
                          Colors.grey.shade200,
                      child:
                          const Text(
                        'Document preview nahi ho paya.',
                      ),
                    );
                  },
                ),
              ),
            ],

            if (rejectionReason
                .isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.red.shade50,
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                child: Text(
                  'Rejection Reason:\n$rejectionReason',
                  style:
                      TextStyle(
                    color:
                        Colors.red.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            if (editable) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child:
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
                      label: Text(
                        isUploaded
                            ? 'Replace'
                            : 'Upload',
                      ),
                    ),
                  ),
                  if (isUploaded) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip:
                          'Delete',
                      onPressed:
                          _uploading
                              ? null
                              : () =>
                                  _deleteDocument(
                                    key,
                                  ),
                      icon:
                          const Icon(
                        Icons.delete_outline,
                        color:
                            Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DOCUMENT STATUS
  // ============================================================

  Color _documentStatusColor(
    String status,
  ) {
    switch (status) {
      case 'verified':
      case 'approved':
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
      case 'approved':
        return 'Verified';

      case 'rejected':
        return 'Rejected';

      case 'pending':
        return 'Pending Review';

      default:
        return 'Uploaded';
    }
  }

  // ============================================================
  // FIREBASE ERROR
  // ============================================================

  String _firebaseErrorMessage(
    FirebaseException e,
  ) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Firebase Rules check karein.';

      case 'unauthenticated':
        return 'Login session expire ho gaya. Dobara login karein.';

      case 'object-not-found':
        return 'File nahi mili.';

      case 'canceled':
        return 'Upload cancel ho gaya.';

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
        !_uploading;

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
                    'Sabhi 5 documents upload karna zaroori hai.',
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

                  ..._requiredDocumentKeys
                      .map(
                    _buildDocumentCard,
                  ),

                  const SizedBox(
                    height: 8,
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
            // UPLOAD / SUBMIT OVERLAY
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
