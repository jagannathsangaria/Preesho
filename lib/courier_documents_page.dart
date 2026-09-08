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

  late final TextEditingController _registrationController;

  static const Color primary = Color(0xFF5B35D5);
  static const Color primaryDark = Color(0xFF4323A8);

  @override
  void initState() {
    super.initState();

    _registrationController =
        TextEditingController();

    _uid = widget.courierUid ??
        _auth.currentUser?.uid;

    _loadCourierData();
  }

  @override
  void dispose() {
    _registrationController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _clean(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  bool _isTrue(dynamic value) {
    if (value is bool) {
      return value;
    }

    return _clean(value).toLowerCase() == 'true';
  }

  String _normalizeStatus(dynamic value) {
    return _clean(value)
        .toLowerCase()
        .replaceAll(' ', '_');
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor:
            isError
                ? Colors.red.shade600
                : Colors.green.shade600,
        behavior:
            SnackBarBehavior.floating,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
        duration:
            const Duration(seconds: 4),
      ),
    );
  }

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
          _firestore
              .collection('couriers')
              .doc(_uid);

      final userRef =
          _firestore
              .collection('users')
              .doc(_uid);

      final courierSnapshot =
          await courierRef.get();

      Map<String, dynamic> data = {};

      if (courierSnapshot.exists) {
        data =
            courierSnapshot.data() ?? {};
      } else {
        final userSnapshot =
            await userRef.get();

        final userData =
            userSnapshot.data() ?? {};

        final role =
            _clean(
              userData['role'],
            ).toLowerCase();

        if (role == 'courier') {
          final name =
              _clean(
                userData['name'],
              ).isNotEmpty
                  ? _clean(
                      userData['name'],
                    )
                  : _auth.currentUser
                          ?.displayName ??
                      '';

          final phone =
              _clean(
                userData['phone'],
              ).isNotEmpty
                  ? _clean(
                      userData['phone'],
                    )
                  : _clean(
                      userData['mobile'],
                    );

          final email =
              _clean(
                userData['email'],
              ).isNotEmpty
                  ? _clean(
                      userData['email'],
                    )
                  : _auth.currentUser
                          ?.email ??
                      '';

          data = {
            'uid': _uid,
            'role': 'courier',
            'name': name,
            'displayName': name,
            'phone': phone,
            'mobile': phone,
            'email': email,
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

      _courierName =
          _clean(data['name']);

      if (_courierName.isEmpty) {
        _courierName =
            _clean(
              data['displayName'],
            );
      }

      _courierPhone =
          _clean(data['phone']);

      if (_courierPhone.isEmpty) {
        _courierPhone =
            _clean(data['mobile']);
      }

      _courierEmail =
          _clean(data['email']);

      _status =
          _normalizeStatus(
        data['status'] ??
            data['registrationStatus'] ??
            'pending_documents',
      );

      _documentsSubmitted =
          _isTrue(
        data['documentsSubmitted'],
      );

      _active =
          _isTrue(data['active']);

      _approvedByAdmin =
          _isTrue(
        data['approvedByAdmin'],
      );

      _registrationType =
          _clean(
        data['registrationType'],
      );

      _registrationNo =
          _clean(
        data['registrationNo'],
      );

      _rejectionReason =
          _clean(
        data['rejectionReason'],
      );

      _registrationController.text =
          _registrationNo;

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

  // ============================================================
  // STATUS
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
  // STATUS CARD
  // ============================================================

  Widget _buildStatusHeader() {
    String title;
    String message;
    IconData icon;
    Color color;

    if (_status ==
            'pending_documents' ||
        !_documentsSubmitted) {
      title =
          'Documents Pending';

      message =
          'Registration successful hai. Sabhi required documents upload karke Admin approval ke liye submit karein.';

      icon =
          Icons.cloud_upload_rounded;

      color =
          Colors.orange;
    } else if (_status ==
        'pending_approval') {
      title =
          'Admin Approval Pending';

      message =
          'Aapke documents Admin approval ke liye submit ho chuke hain. Approval ke baad account active hoga.';

      icon =
          Icons.hourglass_top_rounded;

      color =
          Colors.orange;
    } else if (_status ==
        'rejected') {
      title =
          'Documents Rejected';

      message =
          'Admin ne documents reject kiye hain. Rejected documents ko replace karke dobara submit karein.';

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
          Icons.verified_rounded;

      color =
          Colors.green;
    } else {
      title =
          'Application Status';

      message =
          'Aapka Courier application verification mein hai.';

      icon =
          Icons.info_outline_rounded;

      color =
          Colors.blue;
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(.12),
            Colors.white,
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              color.withOpacity(.25),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 55,
            width: 55,
            decoration: BoxDecoration(
              color:
                  color.withOpacity(.13),
              shape:
                  BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 29,
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
                    color: color,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                    fontSize: 12,
                    height: 1.45,
                    fontWeight:
                        FontWeight.w600,
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
  // PROFILE
  // ============================================================

  Widget _buildCourierProfileCard() {
    final firstLetter =
        _courierName.isNotEmpty
            ? _courierName[0]
                .toUpperCase()
            : 'C';

    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.05),
            blurRadius: 20,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  primary,
                  primaryDark,
                ],
              ),
              shape:
                  BoxShape.circle,
            ),
            child: Center(
              child: Text(
                firstLetter,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w900,
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
                  _courierName.isEmpty
                      ? 'Courier'
                      : _courierName,
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                if (_courierPhone
                    .isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 5,
                    ),
                    child: Text(
                      _courierPhone,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (_courierEmail
                    .isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 3,
                    ),
                    child: Text(
                      _courierEmail,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 11,
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
  // REGISTRATION DETAILS
  // ============================================================

  Widget _buildRegistrationDetails() {
    final editable =
        _canEditDocuments &&
            !_savingDetails;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.045),
            blurRadius: 20,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color:
                      primary.withOpacity(.10),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons
                      .directions_car_outlined,
                  color: primary,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Vehicle Registration',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          DropdownButtonFormField<String>(
            value:
                _registrationType.isEmpty
                    ? null
                    : _registrationType,
            decoration:
                InputDecoration(
              labelText:
                  'Registration Type',
              prefixIcon:
                  const Icon(
                Icons.badge_outlined,
                color: primary,
              ),
              filled: true,
              fillColor:
                  Colors.grey.shade50,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(15),
                borderSide:
                    BorderSide(
                  color:
                      Colors.grey.shade200,
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(15),
                borderSide:
                    BorderSide(
                  color:
                      Colors.grey.shade200,
                ),
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

          const SizedBox(height: 13),

          TextField(
            controller:
                _registrationController,
            enabled: editable,
            textCapitalization:
                TextCapitalization.characters,
            decoration:
                InputDecoration(
              labelText:
                  'Registration Number',
              hintText:
                  'Example: RJ01AB1234',
              prefixIcon:
                  const Icon(
                Icons
                    .confirmation_number_outlined,
                color: primary,
              ),
              filled: true,
              fillColor:
                  Colors.grey.shade50,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(15),
                borderSide:
                    BorderSide(
                  color:
                      Colors.grey.shade200,
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(15),
                borderSide:
                    BorderSide(
                  color:
                      Colors.grey.shade200,
                ),
              ),
            ),
          ),

          const SizedBox(height: 13),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed:
                  editable
                      ? _saveRegistrationDetails
                      : null,
              icon:
                  _savingDetails
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .save_outlined,
                        ),
              label: Text(
                _savingDetails
                    ? 'Saving...'
                    : 'Save Registration Details',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    primary,
                side:
                    const BorderSide(
                  color: primary,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAVE REGISTRATION
  // ============================================================

  Future<void> _saveRegistrationDetails() async {
    if (_uid == null) return;

    final type =
        _registrationType.trim();

    final number =
        _registrationController.text
            .trim()
            .toUpperCase();

    if (type.isEmpty) {
      _showMessage(
        'Registration Type select karein.',
        isError: true,
      );
      return;
    }

    if (number.isEmpty) {
      _showMessage(
        'Registration Number enter karein.',
        isError: true,
      );
      return;
    }

    setState(() {
      _savingDetails = true;
    });

    try {
      final updateData = {
        'registrationType': type,
        'registrationNo': number,
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      final batch =
          _firestore.batch();

      batch.set(
        _firestore
            .collection('couriers')
            .doc(_uid),
        updateData,
        SetOptions(
          merge: true,
        ),
      );

      batch.set(
        _firestore
            .collection('users')
            .doc(_uid),
        updateData,
        SetOptions(
          merge: true,
        ),
      );

      await batch.commit();

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
  // PICK & UPLOAD
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
          _storage
              .ref()
              .child(storagePath);

      final metadata =
          SettableMetadata(
        contentType:
            'image/jpeg',
        customMetadata: {
          'courierUid': _uid!,
          'documentType': key,
        },
      );

      await storageRef.putFile(
        file,
        metadata,
      );

      final downloadUrl =
          await storageRef
              .getDownloadURL();

      if (downloadUrl.trim().isEmpty) {
        throw Exception(
          'Download URL nahi mila.',
        );
      }

      final oldDocument =
          _documents[key];

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

      final batch =
          _firestore.batch();

      batch.set(
        _firestore
            .collection('couriers')
            .doc(_uid),
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

      batch.set(
        _firestore
            .collection('users')
            .doc(_uid),
        {
          'role': 'courier',
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      await batch.commit();

      // Delete old storage file only after
      // new upload is safely stored.
      if (oldDocument != null) {
        final oldPath =
            _clean(
          oldDocument['storagePath'],
        );

        if (oldPath.isNotEmpty &&
            oldPath != storagePath) {
          try {
            await _storage
                .ref(oldPath)
                .delete();
          } catch (_) {}
        }
      }

      if (!mounted) return;

      setState(() {
        _documents[key] = {
          'status': 'pending',
          'url': downloadUrl,
          'fileName': fileName,
          'storagePath': storagePath,
          'uploadedAt':
              Timestamp.now(),
          'updatedAt':
              Timestamp.now(),
          'rejectionReason': '',
        };

        if (_status ==
            'rejected') {
          _documentsSubmitted =
              false;
          _status =
              'pending_documents';
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
  // DELETE
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
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title:
              const Text(
            'Delete Document?',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content:
              Text(
            '${_documentTitles[key]} ko delete karna chahte hain?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
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
          _clean(
        document['storagePath'],
      );

      if (storagePath.isNotEmpty) {
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

      final batch =
          _firestore.batch();

      batch.set(
        _firestore
            .collection('couriers')
            .doc(_uid),
        {
          'documents.$key':
              FieldValue.delete(),
          'documentsSubmitted': false,
          'status':
              'pending_documents',
          'registrationStatus':
              'pending_documents',
          'active': false,
          'approvedByAdmin': false,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      batch.set(
        _firestore
            .collection('users')
            .doc(_uid),
        {
          'status':
              'pending_documents',
          'registrationStatus':
              'pending_documents',
          'active': false,
          'approvedByAdmin': false,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
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
  // CHECK ALL DOCUMENTS
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
          _clean(
        document['url'],
      );

      if (url.isEmpty) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // SUBMIT
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

    final registrationNo =
        _registrationController.text
            .trim()
            .toUpperCase();

    if (registrationNo.isEmpty) {
      _showMessage(
        'Registration Number enter karein.',
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

      final now =
          FieldValue.serverTimestamp();

      final batch =
          _firestore.batch();

      final commonData = {
        'uid': _uid,
        'role': 'courier',
        'name': _courierName,
        'phone': _courierPhone,
        'email': _courierEmail,
        'registrationType':
            _registrationType.trim(),
        'registrationNo':
            registrationNo,
        'documentsSubmitted': true,
        'status':
            'pending_approval',
        'registrationStatus':
            'pending_approval',
        'active': false,
        'approvedByAdmin': false,
        'rejectionReason': '',
        'submittedAt': now,
        'updatedAt': now,
      };

      batch.set(
        _firestore
            .collection('couriers')
            .doc(_uid),
        commonData,
        SetOptions(
          merge: true,
        ),
      );

      batch.set(
        _firestore
            .collection('users')
            .doc(_uid),
        commonData,
        SetOptions(
          merge: true,
        ),
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
        builder: (dialogContext) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(20),
            ),
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
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            content:
                const Text(
              'Aapke documents Admin approval ke liye bhej diye gaye hain.\n\nAdmin approval ke baad Courier account active hoga aur orders assign honge.',
              style: TextStyle(
                height: 1.45,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(
                  dialogContext,
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      primary,
                  foregroundColor:
                      Colors.white,
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
          _clean(
            document['url'],
          ).isNotEmpty) {
        uploaded++;
      }
    }

    final total =
        _requiredDocumentKeys.length;

    final progress =
        total == 0
            ? 0.0
            : uploaded / total;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.045),
            blurRadius: 20,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Document Progress',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      primary.withOpacity(.10),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  '$uploaded/$total',
                  style:
                      const TextStyle(
                    color: primary,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child:
                LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor:
                  Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                primary,
              ),
            ),
          ),

          const SizedBox(height: 9),

          Text(
            uploaded == total
                ? 'All required documents uploaded.'
                : '$uploaded of $total required documents uploaded.',
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
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
        _clean(
          document['url'],
        ).isNotEmpty;

    final status =
        _clean(
          document?['status'],
        ).toLowerCase();

    final rejectionReason =
        _clean(
          document?['rejectionReason'],
        );

    final editable =
        _canEditDocuments;

    final statusColor =
        _documentStatusColor(
      status,
    );

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 13,
      ),
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              isUploaded
                  ? Colors.green
                      .withOpacity(.18)
                  : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.035),
            blurRadius: 16,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration:
                    BoxDecoration(
                  color:
                      isUploaded
                          ? Colors.green
                              .withOpacity(.10)
                          : primary
                              .withOpacity(.08),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Icon(
                  isUploaded
                      ? Icons
                          .description_rounded
                      : Icons
                          .upload_file_rounded,
                  color:
                      isUploaded
                          ? Colors.green
                          : primary,
                ),
              ),

              const SizedBox(width: 13),

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
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                        const Text(
                          ' *',
                          style:
                              TextStyle(
                            color: Colors.red,
                            fontWeight:
                                FontWeight.w900,
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
                            size: 8,
                            color:
                                statusColor,
                          ),
                          const SizedBox(
                              width: 6),
                          Text(
                            _documentStatusText(
                              status,
                            ),
                            style:
                                TextStyle(
                              color:
                                  statusColor,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Not uploaded',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (isUploaded) ...[
            const SizedBox(height: 13),

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(15),
              child: Image.network(
                document['url']
                    .toString(),
                height: 190,
                width:
                    double.infinity,
                fit: BoxFit.cover,
                loadingBuilder:
                    (
                  context,
                  child,
                  progress,
                ) {
                  if (progress == null) {
                    return child;
                  }

                  return Container(
                    height: 190,
                    color:
                        Colors.grey.shade100,
                    child:
                        const Center(
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                      ),
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
                    color:
                        Colors.grey.shade100,
                    child:
                        Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Icon(
                          Icons
                              .broken_image_outlined,
                          color:
                              Colors.grey.shade500,
                          size: 38,
                        ),
                        const SizedBox(
                            height: 7),
                        Text(
                          'Preview nahi ho paya.',
                          style:
                              TextStyle(
                            color:
                                Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          if (rejectionReason
              .isNotEmpty) ...[
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(
                color:
                    Colors.red.shade50,
                borderRadius:
                    BorderRadius.circular(13),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons
                        .error_outline_rounded,
                    color:
                        Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejection Reason:\n$rejectionReason',
                      style:
                          TextStyle(
                        color:
                            Colors.red.shade800,
                        fontSize: 11,
                        height: 1.4,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
                          ? Icons
                              .refresh_rounded
                          : Icons
                              .upload_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isUploaded
                          ? 'Replace'
                          : 'Upload',
                    ),
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          primary,
                      foregroundColor:
                          Colors.white,
                      elevation: 0,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          13,
                        ),
                      ),
                    ),
                  ),
                ),

                if (isUploaded) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 44,
                    width: 44,
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.red.shade50,
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                    child: IconButton(
                      onPressed:
                          _uploading
                              ? null
                              : () =>
                                  _deleteDocument(
                                    key,
                                  ),
                      icon:
                          const Icon(
                        Icons
                            .delete_outline_rounded,
                        color: Colors.red,
                        size: 21,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
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
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return Scaffold(
        backgroundColor:
            const Color(0xFFF7F7FA),
        body: const Center(
          child:
              CircularProgressIndicator(
            color: primary,
          ),
        ),
      );
    }

    if (_uid == null) {
      return Scaffold(
        backgroundColor:
            const Color(0xFFF7F7FA),
        appBar: AppBar(
          title:
              const Text(
            'Courier Documents',
          ),
        ),
        body: Center(
          child: Container(
            margin:
                const EdgeInsets.all(20),
            padding:
                const EdgeInsets.all(20),
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: const Text(
              'Courier account nahi mila.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
              ),
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
      backgroundColor:
          const Color(0xFFF7F7FA),

      appBar: AppBar(
        backgroundColor:
            Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title:
            const Text(
          'Courier Verification',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        centerTitle: false,
      ),

      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                35,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(),

                  const SizedBox(height: 15),

                  _buildCourierProfileCard(),

                  if (_status ==
                          'rejected' &&
                      _rejectionReason
                          .isNotEmpty) ...[
                    const SizedBox(
                        height: 15),

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        15,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.red.shade50,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                        border:
                            Border.all(
                          color:
                              Colors.red.shade100,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Icon(
                            Icons
                                .error_outline_rounded,
                            color:
                                Colors.red.shade700,
                          ),
                          const SizedBox(
                              width: 10),
                          Expanded(
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const Text(
                                  'Admin Rejection Reason',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.red,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(
                                    height: 5),
                                Text(
                                  _rejectionReason,
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.red.shade800,
                                    fontSize:
                                        12,
                                    height:
                                        1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 15),

                  _buildProgressCard(),

                  const SizedBox(height: 15),

                  _buildRegistrationDetails(),

                  const SizedBox(height: 23),

                  const Text(
                    'Required Documents',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Neeche diye gaye sabhi 5 documents upload karna zaroori hai.',
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 13),

                  ..._requiredDocumentKeys
                      .map(
                    _buildDocumentCard,
                  ),

                  const SizedBox(height: 5),

                  // Submit button
                  SizedBox(
                    width:
                        double.infinity,
                    height: 55,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          canSubmit
                              ? _submitForApproval
                              : null,
                      icon: Icon(
                        isPendingApproval
                            ? Icons
                                .hourglass_top_rounded
                            : isApproved
                                ? Icons
                                    .verified_rounded
                                : Icons
                                    .send_rounded,
                      ),
                      label: Text(
                        isPendingApproval
                            ? 'Waiting for Admin Approval'
                            : isApproved
                                ? 'Courier Approved'
                                : 'Submit for Admin Approval',
                        style:
                            const TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            primary,
                        foregroundColor:
                            Colors.white,
                        disabledBackgroundColor:
                            Colors.grey.shade300,
                        disabledForegroundColor:
                            Colors.grey.shade600,
                        elevation: 2,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            17,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 17),

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(
                      15,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.blue.shade50,
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      border:
                          Border.all(
                        color:
                            Colors.blue.shade100,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Icon(
                          Icons
                              .security_rounded,
                          color:
                              Colors.blue.shade700,
                        ),
                        const SizedBox(
                            width: 10),
                        Expanded(
                          child: Text(
                            'Aapke documents Firebase Storage mein securely store honge. Admin approval ke bina Courier account active nahi hoga.',
                            style:
                                TextStyle(
                              color:
                                  Colors.blue.shade900,
                              fontSize:
                                  11,
                              height:
                                  1.45,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: Text(
                      'Preesho Courier Verification',
                      style: TextStyle(
                        color:
                            Colors.grey.shade500,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Upload overlay
            if (_uploading)
              Positioned.fill(
                child: Container(
                  color:
                      Colors.black.withOpacity(
                    .38,
                  ),
                  child: Center(
                    child: Container(
                      margin:
                          const EdgeInsets.all(
                        30,
                      ),
                      padding:
                          const EdgeInsets.all(
                        25,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(
                          22,
                        ),
                      ),
                      child: const Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: primary,
                          ),
                          SizedBox(height: 17),
                          Text(
                            'Please wait...',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Document process ho raha hai.',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              color:
                                  Colors.grey,
                              fontSize: 11,
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
