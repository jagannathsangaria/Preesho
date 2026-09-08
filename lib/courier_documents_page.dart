import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController _panController =
      TextEditingController();

  final TextEditingController _aadhaarController =
      TextEditingController();

  final TextEditingController _dlController =
      TextEditingController();

  final TextEditingController _rcController =
      TextEditingController();

  final TextEditingController _addressProofController =
      TextEditingController();

  String? _uid;

  bool _loading = true;
  bool _saving = false;

  String _status = 'pending_documents';
  bool _documentsSubmitted = false;
  bool _approvedByAdmin = false;
  bool _active = false;

  String _rejectionReason = '';

  final Map<String, String> _documentStatuses = {
    'pan': 'pending',
    'aadhaar': 'pending',
    'drivingLicence': 'pending',
    'vehicleRc': 'pending',
    'addressProof': 'pending',
  };

  final Map<String, String> _documentReasons = {};

  @override
  void initState() {
    super.initState();

    _uid = widget.courierUid ??
        _auth.currentUser?.uid;

    _loadCourier();
  }

  @override
  void dispose() {
    _panController.dispose();
    _aadhaarController.dispose();
    _dlController.dispose();
    _rcController.dispose();
    _addressProofController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD COURIER DATA
  // ============================================================

  Future<void> _loadCourier() async {
    if (_uid == null || _uid!.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final courierDoc = await _firestore
          .collection('couriers')
          .doc(_uid)
          .get();

      Map<String, dynamic> data = {};

      if (courierDoc.exists) {
        data = courierDoc.data() ?? {};
      } else {
        final userDoc = await _firestore
            .collection('users')
            .doc(_uid)
            .get();

        if (userDoc.exists) {
          data = userDoc.data() ?? {};
        }
      }

      _status = _normalizeStatus(
        data['status'] ??
            data['registrationStatus'] ??
            'pending_documents',
      );

      _documentsSubmitted =
          data['documentsSubmitted'] == true;

      _approvedByAdmin =
          data['approvedByAdmin'] == true;

      _active = data['active'] == true;

      _rejectionReason =
          _clean(data['rejectionReason']);

      final documents = data['documents'];

      if (documents is Map) {
        _loadDocument(
          documents,
          'pan',
          _panController,
        );

        _loadDocument(
          documents,
          'aadhaar',
          _aadhaarController,
        );

        _loadDocument(
          documents,
          'drivingLicence',
          _dlController,
        );

        _loadDocument(
          documents,
          'vehicleRc',
          _rcController,
        );

        _loadDocument(
          documents,
          'addressProof',
          _addressProofController,
        );
      }

      // Also support old flat fields if present.
      if (_panController.text.isEmpty) {
        _panController.text =
            _clean(data['panNumber']);
      }

      if (_aadhaarController.text.isEmpty) {
        _aadhaarController.text =
            _clean(data['aadhaarNumber']);
      }

      if (_dlController.text.isEmpty) {
        _dlController.text =
            _clean(data['drivingLicenceNumber']);
      }

      if (_rcController.text.isEmpty) {
        _rcController.text =
            _clean(data['vehicleRcNumber']);
      }

      if (_addressProofController.text.isEmpty) {
        _addressProofController.text =
            _clean(data['addressProofNumber']);
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _message(
        'Courier details load nahi ho paye.\n$e',
        error: true,
      );
    }
  }

  void _loadDocument(
    Map documents,
    String key,
    TextEditingController controller,
  ) {
    final raw = documents[key];

    if (raw is Map) {
      controller.text =
          _clean(
        raw['number'] ??
            raw['documentNumber'] ??
            raw['value'],
      );

      final status =
          _normalizeStatus(
        raw['status'] ?? 'pending',
      );

      _documentStatuses[key] =
          status.isEmpty
              ? 'pending'
              : status;

      _documentReasons[key] =
          _clean(
        raw['rejectionReason'],
      );
    } else if (raw is String) {
      controller.text = raw;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _clean(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  String _normalizeStatus(dynamic value) {
    return _clean(value)
        .toLowerCase()
        .replaceAll(' ', '_');
  }

  bool _isAccountApproved() {
    return _status == 'approved' &&
        _approvedByAdmin &&
        _active;
  }

  bool _isDocumentApproved(String key) {
    return _documentStatuses[key] ==
        'approved';
  }

  bool _isDocumentRejected(String key) {
    return _documentStatuses[key] ==
        'rejected';
  }

  bool _isLocked(String key) {
    if (_isAccountApproved()) {
      return true;
    }

    return _isDocumentApproved(key);
  }

  void _message(
    String text, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor:
            error
                ? Colors.red.shade700
                : Colors.green.shade700,
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // SAVE DOCUMENT NUMBERS
  // ============================================================

  Future<void> _saveDocumentNumbers({
    bool submit = false,
  }) async {
    if (_uid == null) {
      _message(
        'Courier login session nahi mili.',
        error: true,
      );
      return;
    }

    if (_isAccountApproved()) {
      _message(
        'Courier account already approved hai.',
        error: true,
      );
      return;
    }

    if (!_validateDocuments()) {
      return;
    }

    try {
      setState(() {
        _saving = true;
      });

      final now =
          FieldValue.serverTimestamp();

      final documents =
          <String, dynamic>{
        'pan': {
          'number':
              _panController.text.trim(),
          'status':
              submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'aadhaar': {
          'number':
              _aadhaarController.text.trim(),
          'status':
              submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'drivingLicence': {
          'number':
              _dlController.text.trim(),
          'status':
              submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'vehicleRc': {
          'number':
              _rcController.text.trim(),
          'status':
              submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
        'addressProof': {
          'number':
              _addressProofController
                  .text
                  .trim(),
          'status':
              submit ? 'pending' : 'draft',
          'rejectionReason': '',
          'updatedAt': now,
        },
      };

      final courierData =
          <String, dynamic>{
        'documents': documents,
        'panNumber':
            _panController.text.trim(),
        'aadhaarNumber':
            _aadhaarController.text.trim(),
        'drivingLicenceNumber':
            _dlController.text.trim(),
        'vehicleRcNumber':
            _rcController.text.trim(),
        'addressProofNumber':
            _addressProofController
                .text
                .trim(),
        'updatedAt': now,
      };

      if (submit) {
        courierData.addAll({
          'documentsSubmitted': true,
          'status': 'pending_approval',
          'registrationStatus':
              'pending_approval',
          'approvedByAdmin': false,
          'active': false,
          'rejectionReason': '',
          'documentsSubmittedAt': now,
        });
      } else {
        courierData.addAll({
          'documentsSubmitted': false,
          'status': 'pending_documents',
          'registrationStatus':
              'pending_documents',
          'approvedByAdmin': false,
          'active': false,
        });
      }

      await _firestore
          .collection('couriers')
          .doc(_uid)
          .set(
        courierData,
        SetOptions(merge: true),
      );

      // Keep users collection synchronized.
      final userData =
          <String, dynamic>{
        'documentsSubmitted':
            submit,
        'status': submit
            ? 'pending_approval'
            : 'pending_documents',
        'registrationStatus':
            submit
                ? 'pending_approval'
                : 'pending_documents',
        'approvedByAdmin': false,
        'active': false,
        'updatedAt': now,
      };

      if (submit) {
        userData['documentsSubmittedAt'] =
            now;
        userData['rejectionReason'] = '';
      }

      await _firestore
          .collection('users')
          .doc(_uid)
          .set(
        userData,
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _documentsSubmitted = submit;
        _status = submit
            ? 'pending_approval'
            : 'pending_documents';
        _approvedByAdmin = false;
        _active = false;
        _saving = false;

        if (submit) {
          for (final key
              in _documentStatuses.keys) {
            _documentStatuses[key] =
                'pending';
          }
        }
      });

      _message(
        submit
            ? 'Documents Admin approval ke liye submit ho gaye.'
            : 'Document details save ho gayi.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _message(
        'Save failed.\n$e',
        error: true,
      );
    }
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _validateDocuments() {
    final pan =
        _panController.text.trim();

    final aadhaar =
        _aadhaarController.text.trim();

    final dl =
        _dlController.text.trim();

    final rc =
        _rcController.text.trim();

    final address =
        _addressProofController
            .text
            .trim();

    if (pan.isEmpty) {
      _message(
        'PAN Number enter karein.',
        error: true,
      );
      return false;
    }

    if (pan.length != 10) {
      _message(
        'PAN Number 10 characters ka hona chahiye.',
        error: true,
      );
      return false;
    }

    if (aadhaar.isEmpty) {
      _message(
        'Aadhaar Number enter karein.',
        error: true,
      );
      return false;
    }

    if (aadhaar.length != 12 ||
        int.tryParse(aadhaar) == null) {
      _message(
        'Aadhaar Number 12 digit ka hona chahiye.',
        error: true,
      );
      return false;
    }

    if (dl.isEmpty) {
      _message(
        'Driving Licence Number enter karein.',
        error: true,
      );
      return false;
    }

    if (rc.isEmpty) {
      _message(
        'Vehicle RC Number enter karein.',
        error: true,
      );
      return false;
    }

    if (address.isEmpty) {
      _message(
        'Address Proof Number/Details enter karein.',
        error: true,
      );
      return false;
    }

    return true;
  }

  // ============================================================
  // FIELD
  // ============================================================

  Widget _documentField({
    required String key,
    required String title,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType =
        TextInputType.text,
    bool obscure = false,
    int? maxLength,
  }) {
    final approved =
        _isDocumentApproved(key);

    final rejected =
        _isDocumentRejected(key);

    final locked =
        _isLocked(key);

    final reason =
        _documentReasons[key] ?? '';

    return Container(
      margin:
          const EdgeInsets.only(bottom: 16),
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: rejected
              ? Colors.red.shade200
              : approved
                  ? Colors.green.shade200
                  : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.035),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: approved
                      ? Colors.green
                          .withOpacity(.10)
                      : rejected
                          ? Colors.red
                              .withOpacity(.10)
                          : const Color(
                              0xff5B35D5,
                            ).withOpacity(.10),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: approved
                      ? Colors.green
                      : rejected
                          ? Colors.red
                          : const Color(
                              0xff5B35D5,
                            ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              if (approved)
                const Icon(
                  Icons.lock_rounded,
                  color: Colors.green,
                ),
              if (rejected)
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                ),
            ],
          ),

          const SizedBox(height: 14),

          TextField(
            controller: controller,
            enabled:
                !locked && !_saving,
            keyboardType:
                keyboardType,
            obscureText:
                obscure,
            maxLength:
                maxLength,
            textCapitalization:
                TextCapitalization.characters,
            decoration:
                InputDecoration(
              labelText: title,
              hintText: hint,
              counterText: '',
              prefixIcon:
                  const Icon(
                Icons.edit_document,
              ),
              suffixIcon:
                  approved
                      ? const Icon(
                          Icons.lock_rounded,
                          color:
                              Colors.green,
                        )
                      : null,
              filled: true,
              fillColor:
                  locked
                      ? Colors.grey.shade100
                      : Colors.grey.shade50,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
              ),
            ),
          ),

          if (approved)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 9,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    'Admin Approved • Locked',
                    style: TextStyle(
                      color:
                          Colors.green.shade700,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          if (rejected) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color:
                    Colors.red.shade50,
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Text(
                reason.isEmpty
                    ? 'Admin ne document reject kiya hai. Details dobara enter karein.'
                    : 'Admin Reason: $reason',
                style: TextStyle(
                  color:
                      Colors.red.shade800,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================

  Widget _statusCard() {
    if (_isAccountApproved()) {
      return _infoCard(
        color: Colors.green,
        icon:
            Icons.verified_rounded,
        title:
            'Courier Account Approved',
        text:
            'Aapka Courier account Admin ne approve kar diya hai. Approved document numbers ab locked hain.',
      );
    }

    if (_status ==
            'pending_approval' &&
        _documentsSubmitted) {
      return _infoCard(
        color: Colors.orange,
        icon:
            Icons.hourglass_top_rounded,
        title:
            'Under Admin Review',
        text:
            'Aapke document numbers Admin verification ke liye submit ho chuke hain.',
      );
    }

    if (_status == 'rejected') {
      return _infoCard(
        color: Colors.red,
        icon:
            Icons.cancel_outlined,
        title:
            'Documents Rejected',
        text: _rejectionReason.isEmpty
            ? 'Rejected details ko correct karke dobara submit karein.'
            : _rejectionReason,
      );
    }

    return _infoCard(
      color:
          const Color(0xff5B35D5),
      icon:
          Icons.description_rounded,
      title:
          'Complete Courier KYC',
      text:
          'Neeche required document numbers enter karke Admin approval ke liye submit karein.',
    );
  }

  Widget _infoCard({
    required Color color,
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            color.withOpacity(.08),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              color.withOpacity(.18),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 27,
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
                      TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  text,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight:
                        FontWeight.w500,
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
  // PROGRESS
  // ============================================================

  Widget _progressCard() {
    final controllers = [
      _panController,
      _aadhaarController,
      _dlController,
      _rcController,
      _addressProofController,
    ];

    int completed = 0;

    for (final controller
        in controllers) {
      if (controller.text
          .trim()
          .isNotEmpty) {
        completed++;
      }
    }

    const total = 5;

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xff5B35D5),
            Color(0xff4323A8),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'KYC Progress',
                  style:
                      TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$completed/$total',
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(10),
            child:
                LinearProgressIndicator(
              value:
                  completed / total,
              minHeight: 8,
              backgroundColor:
                  Colors.white
                      .withOpacity(.20),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                Colors.white,
              ),
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            completed == total
                ? 'All document numbers complete.'
                : '${total - completed} document details remaining.',
            style:
                const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
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

    return Scaffold(
      backgroundColor:
          const Color(0xfff5f6fa),
      appBar: AppBar(
        title: const Text(
          'Courier Documents',
          style:
              TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        backgroundColor:
            const Color(0xfff5f6fa),
        foregroundColor:
            Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed:
                _saving
                    ? null
                    : _loadCourier,
            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh:
              _loadCourier,
          child: ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              16,
              6,
              16,
              35,
            ),
            children: [
              _statusCard(),

              const SizedBox(
                height: 14,
              ),

              _progressCard(),

              const SizedBox(
                height: 22,
              ),

              const Text(
                'Enter Document Numbers',
                style:
                    TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                'Document ki copy/photo upload nahi karni hai. Sirf document number/details enter karein.',
                style:
                    TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),

              const SizedBox(
                height: 17,
              ),

              _documentField(
                key: 'pan',
                title: 'PAN Number',
                hint: 'ABCDE1234F',
                icon:
                    Icons.badge_rounded,
                controller:
                    _panController,
                maxLength: 10,
              ),

              _documentField(
                key: 'aadhaar',
                title: 'Aadhaar Number',
                hint: '12 digit Aadhaar Number',
                icon:
                    Icons.credit_card_rounded,
                controller:
                    _aadhaarController,
                keyboardType:
                    TextInputType.number,
                maxLength: 12,
              ),

              _documentField(
                key: 'drivingLicence',
                title:
                    'Driving Licence Number',
                hint:
                    'Driving Licence Number',
                icon:
                    Icons.drive_eta_rounded,
                controller:
                    _dlController,
                maxLength: 30,
              ),

              _documentField(
                key: 'vehicleRc',
                title:
                    'Vehicle RC Number',
                hint:
                    'RJ14AB1234',
                icon:
                    Icons.directions_car_rounded,
                controller:
                    _rcController,
                maxLength: 30,
              ),

              _documentField(
                key: 'addressProof',
                title:
                    'Address Proof Number / Details',
                hint:
                    'Address proof number/details',
                icon:
                    Icons.home_rounded,
                controller:
                    _addressProofController,
                maxLength: 100,
              ),

              const SizedBox(
                height: 8,
              ),

              if (!_isAccountApproved() &&
                  _status !=
                      'pending_approval') ...[
                SizedBox(
                  height: 52,
                  width:
                      double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _saving
                            ? null
                            : () =>
                                _saveDocumentNumbers(),
                    icon:
                        const Icon(
                      Icons.save_rounded,
                    ),
                    label:
                        const Text(
                      'Save Details',
                      style:
                          TextStyle(
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
                          15,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                SizedBox(
                  height: 55,
                  width:
                      double.infinity,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        _saving
                            ? null
                            : () =>
                                _saveDocumentNumbers(
                                  submit: true,
                                ),
                    icon: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                          ),
                    label:
                        Text(
                      _saving
                          ? 'Processing...'
                          : _status ==
                                  'rejected'
                              ? 'Resubmit for Approval'
                              : 'Submit for Admin Approval',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xff5B35D5,
                      ),
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              if (_status ==
                      'pending_approval' &&
                  _documentsSubmitted) ...[
                const SizedBox(
                  height: 15,
                ),
                _infoCard(
                  color:
                      Colors.orange,
                  icon:
                      Icons.lock_clock_rounded,
                  title:
                      'Editing Locked',
                  text:
                      'Admin approval/rejection ka wait karein. Verification complete hone tak submitted details edit nahi hongi.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
