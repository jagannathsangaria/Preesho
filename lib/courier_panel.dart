import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CourierPanel extends StatefulWidget {
  const CourierPanel({super.key});

  @override
  State<CourierPanel> createState() => _CourierPanelState();
}

class _CourierPanelState extends State<CourierPanel> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  static const Color primary =
      Color(0xFF5B35D5);

  static const Color primaryDark =
      Color(0xFF4323A8);

  final List<String> _courierStatuses = const [
    'Shipped',
    'Picked by Courier',
    'Out for Delivery',
    'Delivered',
  ];

  String _normalizeStatus(dynamic value) {
    if (value == null) {
      return 'Shipped';
    }

    final status =
        value.toString().trim();

    switch (status.toLowerCase()) {
      case 'shipped':
        return 'Shipped';

      case 'picked by courier':
      case 'picked_by_courier':
      case 'picked':
        return 'Picked by Courier';

      case 'out for delivery':
      case 'out_for_delivery':
      case 'outfordelivery':
        return 'Out for Delivery';

      case 'delivered':
        return 'Delivered';

      default:
        return status;
    }
  }

  String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }

    final text =
        value.toString().trim();

    if (text == 'null') {
      return '';
    }

    return text;
  }

  int _statusIndex(String status) {
    return _courierStatuses.indexOf(
      _normalizeStatus(status),
    );
  }

  bool _isCourierOrder(String status) {
    return _courierStatuses.contains(
      _normalizeStatus(status),
    );
  }

  String _nextStatus(String status) {
    final index =
        _statusIndex(status);

    if (index < 0 ||
        index >=
            _courierStatuses.length - 1) {
      return '';
    }

    return _courierStatuses[index + 1];
  }

  String _timestampText(dynamic value) {
    if (value == null) {
      return 'Not updated';
    }

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) {
      return 'Not updated';
    }

    final local =
        date.toLocal();

    final day =
        local.day.toString().padLeft(2, '0');

    final month =
        local.month.toString().padLeft(2, '0');

    final year =
        local.year.toString();

    int hour = local.hour;

    final minute =
        local.minute.toString().padLeft(2, '0');

    final period =
        hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    return '$day/$month/$year  '
        '$hour:$minute $period';
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
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
            Colors.red.shade600,
        behavior:
            SnackBarBehavior.floating,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
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
            Colors.green.shade600,
        behavior:
            SnackBarBehavior.floating,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================

  Future<void> _updateCourierStatus(
    DocumentSnapshot<Map<String, dynamic>>
        orderDoc,
    String requestedStatus,
  ) async {
    final courierUser =
        FirebaseAuth.instance.currentUser;

    if (courierUser == null) {
      _showError(
        'Courier login session not found.',
      );
      return;
    }

    final data =
        orderDoc.data() ?? {};

    final orderId =
        _stringValue(
          data['orderId'],
        ).isNotEmpty
            ? _stringValue(
                data['orderId'],
              )
            : orderDoc.id;

    try {
      final callable =
          _functions.httpsCallable(
        'updateCourierOrderStatus',
      );

      // IMPORTANT:
      // Backend expects "status".
      await callable.call({
        'orderId': orderId,
        'status': requestedStatus,
      });

      if (!mounted) return;

      _showSuccess(
        'Order status updated to $requestedStatus',
      );
    } on FirebaseFunctionsException catch (e) {
      _showError(
        e.message ??
            'Unable to update order status.',
      );
    } catch (e) {
      String message =
          e.toString();

      if (message.startsWith(
        'Exception: ',
      )) {
        message =
            message.substring(
          'Exception: '.length,
        );
      }

      _showError(message);
    }
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    IconData icon,
    String title,
    dynamic value,
  ) {
    final text =
        value == null ||
                value.toString()
                    .trim()
                    .isEmpty
            ? 'Not available'
            : value.toString();

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 30,
            width: 30,
            decoration:
                BoxDecoration(
              color:
                  primary.withOpacity(.08),
              borderRadius:
                  BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: primary,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Padding(
              padding:
                  const EdgeInsets.only(
                top: 5,
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Colors.grey.shade600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.only(
                top: 5,
              ),
              child: Text(
                text,
                style:
                    const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _statusChip(
    String status,
  ) {
    Color color;
    IconData icon;

    switch (_normalizeStatus(status)) {
      case 'Shipped':
        color = Colors.blue;
        icon =
            Icons.local_shipping_outlined;
        break;

      case 'Picked by Courier':
        color = Colors.orange;
        icon =
            Icons.inventory_2_outlined;
        break;

      case 'Out for Delivery':
        color = Colors.deepPurple;
        icon =
            Icons.delivery_dining;
        break;

      case 'Delivered':
        color = Colors.green;
        icon =
            Icons.check_circle_outline;
        break;

      default:
        color = Colors.grey;
        icon =
            Icons.info_outline;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(.10),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            _normalizeStatus(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DELIVERY STAGE
  // ============================================================

  Widget _stageTile(
    String title,
    dynamic timestamp,
    bool completed,
    bool current,
    bool last,
  ) {
    final active =
        completed || current;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 21,
              height: 21,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    active
                        ? Colors.green
                        : Colors.grey
                            .shade300,
              ),
              child: active
                  ? const Icon(
                      Icons.check,
                      size: 13,
                      color:
                          Colors.white,
                    )
                  : null,
            ),
            if (!last)
              Container(
                width: 2,
                height: 38,
                color:
                    completed
                        ? Colors.green
                        : Colors.grey
                            .shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(
              bottom: 14,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        current
                            ? FontWeight.w900
                            : FontWeight.w700,
                    color:
                        current
                            ? Colors.green
                            : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  timestamp == null
                      ? 'Pending'
                      : _timestampText(
                          timestamp,
                        ),
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        timestamp == null
                            ? Colors.grey
                            : Colors.grey
                                .shade600,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ORDER CARD
  // ============================================================

  Widget _buildOrderCard(
    DocumentSnapshot<Map<String, dynamic>>
        orderDoc,
  ) {
    final data =
        orderDoc.data() ?? {};

    final status =
        _normalizeStatus(
      data['orderStatus'] ??
          data['status'],
    );

    if (!_isCourierOrder(status)) {
      return const SizedBox.shrink();
    }

    final currentIndex =
        _statusIndex(status);

    final nextStatus =
        _nextStatus(status);

    final orderId =
        _stringValue(
          data['orderId'],
        ).isNotEmpty
            ? _stringValue(
                data['orderId'],
              )
            : orderDoc.id;

    final customerName =
        _stringValue(
          data['customerName'],
        ).isNotEmpty
            ? _stringValue(
                data['customerName'],
              )
            : _stringValue(
                data['name'],
              ).isNotEmpty
                ? _stringValue(
                    data['name'],
                  )
                : 'Customer';

    final customerPhone =
        _stringValue(
          data['customerPhone'],
        ).isNotEmpty
            ? _stringValue(
                data['customerPhone'],
              )
            : _stringValue(
                data['phone'],
              );

    final customerAddress =
        _stringValue(
          data['deliveryAddress'],
        ).isNotEmpty
            ? _stringValue(
                data['deliveryAddress'],
              )
            : _stringValue(
                data['address'],
              );

    final courierPartner =
        _stringValue(
          data['courierPartner'],
        ).isNotEmpty
            ? _stringValue(
                data['courierPartner'],
              )
            : _stringValue(
                data['courierName'],
              ).isNotEmpty
                ? _stringValue(
                    data['courierName'],
                  )
                : 'Preesho Courier';

    final courierPersonName =
        _stringValue(
          data['courierPersonName'],
        ).isNotEmpty
            ? _stringValue(
                data['courierPersonName'],
              )
            : _stringValue(
                data['courierName'],
              );

    final courierPhone =
        _stringValue(
          data['courierPhone'],
        ).isNotEmpty
            ? _stringValue(
                data['courierPhone'],
              )
            : _stringValue(
                data['courierMobile'],
              );

    final courierId =
        _stringValue(
      data['courierId'],
    );

    final trackingNumber =
        _stringValue(
      data['trackingNumber'],
    );

    final trackingUrl =
        _stringValue(
      data['trackingUrl'],
    );

    final total =
        data['grandTotal'] ??
            data['totalAmount'] ??
            data['total'] ??
            data['codAmount'];

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.055),
            blurRadius: 22,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  height: 45,
                  width: 45,
                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        primary,
                        primaryDark,
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .shopping_bag_rounded,
                    color:
                        Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        'Order #$orderId',
                        style:
                            const TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                          height: 3),
                      Text(
                        'Delivery assignment',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(status),
              ],
            ),

            const SizedBox(height: 17),

            // Amount
            if (total != null)
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  13,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      primary.withOpacity(.055),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .payments_outlined,
                      color: primary,
                      size: 20,
                    ),
                    const SizedBox(
                        width: 8),
                    const Text(
                      'COD Amount',
                      style:
                          TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${_formatAmount(total)}',
                      style:
                          const TextStyle(
                        fontSize: 17,
                        color: primary,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            const Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(height: 12),

            _infoRow(
              Icons.person_outline,
              'Customer',
              customerName,
            ),

            if (customerPhone.isNotEmpty)
              _infoRow(
                Icons.phone_outlined,
                'Phone',
                customerPhone,
              ),

            if (customerAddress
                .isNotEmpty)
              _infoRow(
                Icons
                    .location_on_outlined,
                'Address',
                customerAddress,
              ),

            const Divider(
              height: 25,
            ),

            const Text(
              'Courier Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(height: 12),

            _infoRow(
              Icons
                  .business_outlined,
              'Partner',
              courierPartner,
            ),

            if (courierPersonName
                .isNotEmpty)
              _infoRow(
                Icons.person_outline,
                'Courier',
                courierPersonName,
              ),

            if (courierPhone
                .isNotEmpty)
              _infoRow(
                Icons.phone_outlined,
                'Courier Phone',
                courierPhone,
              ),

            if (courierId.isNotEmpty)
              _infoRow(
                Icons.badge_outlined,
                'Courier ID',
                courierId,
              ),

            if (trackingNumber
                .isNotEmpty)
              _infoRow(
                Icons.qr_code_2_outlined,
                'Tracking',
                trackingNumber,
              ),

            if (trackingUrl
                .isNotEmpty)
              _infoRow(
                Icons.link_outlined,
                'Tracking URL',
                trackingUrl,
              ),

            const Divider(
              height: 25,
            ),

            const Text(
              'Delivery Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(height: 14),

            _stageTile(
              'Shipped',
              data['shippedAt'],
              currentIndex >= 0,
              status == 'Shipped',
              false,
            ),

            _stageTile(
              'Picked by Courier',
              data['courierPickedAt'],
              currentIndex >= 1,
              status ==
                  'Picked by Courier',
              false,
            ),

            _stageTile(
              'Out for Delivery',
              data['outForDeliveryAt'],
              currentIndex >= 2,
              status ==
                  'Out for Delivery',
              false,
            ),

            _stageTile(
              'Delivered',
              data['deliveredAt'],
              currentIndex >= 3,
              status == 'Delivered',
              true,
            ),

            const SizedBox(height: 3),

            if (nextStatus.isNotEmpty)
              SizedBox(
                width:
                    double.infinity,
                height: 51,
                child:
                    ElevatedButton.icon(
                  onPressed: () {
                    _confirmStatusUpdate(
                      orderDoc,
                      nextStatus,
                    );
                  },
                  icon: Icon(
                    nextStatus ==
                            'Delivered'
                        ? Icons
                            .done_all_rounded
                        : Icons
                            .arrow_forward_rounded,
                  ),
                  label: Text(
                    'Mark as $nextStatus',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        primary,
                    foregroundColor:
                        Colors.white,
                    elevation: 1,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.green.shade50,
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Icon(
                      Icons
                          .check_circle_rounded,
                      color:
                          Colors.green,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Order Delivered Successfully',
                      style:
                          TextStyle(
                        color:
                            Colors.green,
                        fontWeight:
                            FontWeight.w900,
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
  // CONFIRM STATUS
  // ============================================================

  Future<void> _confirmStatusUpdate(
    DocumentSnapshot<Map<String, dynamic>>
        orderDoc,
    String nextStatus,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          title:
              const Text(
            'Update Order Status?',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: Text(
            'Order ko "$nextStatus" status par update karna hai?',
            style: const TextStyle(
              height: 1.4,
            ),
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
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primary,
                foregroundColor:
                    Colors.white,
              ),
              child:
                  const Text(
                'Confirm',
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _updateCourierStatus(
        orderDoc,
        nextStatus,
      );
    }
  }

  // ============================================================
  // AMOUNT FORMAT
  // ============================================================

  String _formatAmount(
    dynamic value,
  ) {
    if (value == null) {
      return '0';
    }

    if (value is num) {
      return value
          .toDouble()
          .toStringAsFixed(0);
    }

    final parsed =
        double.tryParse(
      value
          .toString()
          .replaceAll(',', '')
          .replaceAll('₹', '')
          .trim(),
    );

    if (parsed == null) {
      return value.toString();
    }

    return parsed
        .toStringAsFixed(0);
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              height: 100,
              width: 100,
              decoration:
                  BoxDecoration(
                color:
                    primary.withOpacity(.08),
                shape:
                    BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .local_shipping_outlined,
                color: primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Orders Assigned',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Abhi aapko koi delivery order assign nahi hua hai.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
    int activeOrders,
    int deliveredOrders,
  ) {
    final user =
        FirebaseAuth.instance.currentUser;

    final name =
        user?.displayName
                ?.trim()
                .isNotEmpty ==
            true
        ? user!.displayName!
        : 'Courier Partner';

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(19),
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            primary,
            primaryDark,
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color:
                primary.withOpacity(.20),
            blurRadius: 22,
            offset:
                const Offset(0, 9),
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
                height: 53,
                width: 53,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white
                          .withOpacity(.16),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .delivery_dining_rounded,
                  color:
                      Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      'Welcome back',
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                        height: 3),
                    Text(
                      name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child:
                    _headerStat(
                  Icons
                      .local_shipping_outlined,
                  '$activeOrders',
                  'Active Orders',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child:
                    _headerStat(
                  Icons
                      .check_circle_outline,
                  '$deliveredOrders',
                  'Delivered',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white.withOpacity(.12),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                Colors.white,
            size: 20,
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              Text(
                label,
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
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
    final courierUid =
        FirebaseAuth
                .instance
                .currentUser
                ?.uid ??
            '';

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
          'Courier Panel',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip:
                'Refresh',
            onPressed: () {
              setState(() {});
            },
            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),

      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream: _firestore
            .collection('orders')
            .snapshots(),

        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons
                          .error_outline_rounded,
                      color: Colors.red,
                      size: 50,
                    ),
                    const SizedBox(
                        height: 15),
                    const Text(
                      'Unable to load orders',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                        height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(
                color: primary,
              ),
            );
          }

          final docs =
              snapshot.data?.docs ??
                  [];

          // Only orders assigned to
          // currently logged-in courier.
          final courierOrders =
              docs.where((doc) {
            final data =
                doc.data();

            final status =
                _normalizeStatus(
              data['orderStatus'] ??
                  data['status'],
            );

            if (!_isCourierOrder(
              status,
            )) {
              return false;
            }

            final assignedCourierId =
                _stringValue(
              data['courierId'],
            );

            final assignedCourierUid =
                _stringValue(
              data['courierUid'],
            );

            final assignedTo =
                _stringValue(
              data['assignedCourierId'],
            );

            final currentCourier =
                courierUid;

            // If explicit courier ID
            // exists, it must match.
            if (assignedCourierId
                .isNotEmpty) {
              return assignedCourierId ==
                  currentCourier;
            }

            if (assignedCourierUid
                .isNotEmpty) {
              return assignedCourierUid ==
                  currentCourier;
            }

            if (assignedTo
                .isNotEmpty) {
              return assignedTo ==
                  currentCourier;
            }

            // Support courier assignment
            // stored in courierDetails map.
            final courierDetails =
                data['courierDetails'];

            if (courierDetails
                is Map) {
              final detailUid =
                  _stringValue(
                courierDetails[
                    'uid'],
              );

              if (detailUid
                  .isNotEmpty) {
                return detailUid ==
                    currentCourier;
              }
            }

            return false;
          }).toList();

          courierOrders.sort(
            (a, b) {
              final aData =
                  a.data();

              final bData =
                  b.data();

              final aTime =
                  aData['updatedAt'] ??
                      aData['createdAt'];

              final bTime =
                  bData['updatedAt'] ??
                      bData['createdAt'];

              if (aTime is Timestamp &&
                  bTime is Timestamp) {
                return bTime.compareTo(
                  aTime,
                );
              }

              return 0;
            },
          );

          int activeOrders = 0;
          int deliveredOrders = 0;

          for (final order
              in courierOrders) {
            final status =
                _normalizeStatus(
              order.data()[
                      'orderStatus'] ??
                  order.data()[
                      'status'],
            );

            if (status ==
                    'Delivered') {
              deliveredOrders++;
            } else {
              activeOrders++;
            }
          }

          return RefreshIndicator(
            color: primary,
            onRefresh: () async {
              setState(() {});
              await Future.delayed(
                const Duration(
                  milliseconds: 500,
                ),
              );
            },
            child: courierOrders.isEmpty
                ? ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(
                        height: 25,
                      ),
                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                        ),
                        child:
                            _buildHeader(
                          activeOrders,
                          deliveredOrders,
                        ),
                      ),
                      const SizedBox(
                          height: 100),
                      _emptyState(),
                    ],
                  )
                : ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      15,
                      16,
                      30,
                    ),
                    children: [
                      _buildHeader(
                        activeOrders,
                        deliveredOrders,
                      ),

                      const SizedBox(
                          height: 22),

                      Row(
                        children: [
                          const Expanded(
                            child:
                                Text(
                              'My Deliveries',
                              style:
                                  TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  primary.withOpacity(.10),
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                            ),
                            child:
                                Text(
                              '${courierOrders.length} Orders',
                              style:
                                  const TextStyle(
                                color:
                                    primary,
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                          height: 13),

                      ...courierOrders.map(
                        _buildOrderCard,
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
