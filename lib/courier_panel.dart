import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourierPanel extends StatefulWidget {
  const CourierPanel({super.key});

  @override
  State<CourierPanel> createState() => _CourierPanelState();
}

class _CourierPanelState extends State<CourierPanel> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _courierStatuses = const [
    'Shipped',
    'Picked by Courier',
    'Out for Delivery',
    'Delivered',
  ];

  String _normalizeStatus(dynamic value) {
    if (value == null) return 'Shipped';

    final status = value.toString().trim();

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

  int _statusIndex(String status) {
    final normalized = _normalizeStatus(status);
    return _courierStatuses.indexOf(normalized);
  }

  bool _isCourierOrder(String status) {
    final normalized = _normalizeStatus(status);
    return _courierStatuses.contains(normalized);
  }

  String _nextStatus(String status) {
    final index = _statusIndex(status);

    if (index < 0 || index >= _courierStatuses.length - 1) {
      return '';
    }

    return _courierStatuses[index + 1];
  }

  String _timestampText(dynamic value) {
    if (value == null) return 'Not updated';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return 'Not updated';

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    int hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$day/$month/$year  $hour:$minute $period';
  }

  Future<void> _updateCourierStatus(
    DocumentSnapshot<Map<String, dynamic>> orderDoc,
    String requestedStatus,
  ) async {
    final docRef = orderDoc.reference;

    try {
      await _firestore.runTransaction((transaction) async {
        final freshSnapshot = await transaction.get(docRef);

        if (!freshSnapshot.exists) {
          throw Exception('Order not found.');
        }

        final data = freshSnapshot.data() ?? {};

        final currentStatus = _normalizeStatus(
          data['orderStatus'] ?? data['status'],
        );

        final currentIndex = _statusIndex(currentStatus);
        final requestedIndex = _statusIndex(requestedStatus);

        if (currentIndex < 0) {
          throw Exception(
            'This order is not currently eligible for courier processing.',
          );
        }

        if (requestedIndex != currentIndex + 1) {
          throw Exception(
            'Wrong status jump. Order must move from '
            '$currentStatus to ${_nextStatus(currentStatus)}.',
          );
        }

        final now = Timestamp.now();

        final history = <Map<String, dynamic>>[];

        final existingHistory = data['statusHistory'];

        if (existingHistory is List) {
          for (final item in existingHistory) {
            if (item is Map) {
              history.add(Map<String, dynamic>.from(item));
            }
          }
        }

        final courierUser = FirebaseAuth.instance.currentUser;

        history.add({
          'status': requestedStatus,
          'timestamp': now,
          'updatedBy': 'Courier',
          if (courierUser != null) 'updatedByUid': courierUser.uid,
        });

        final updateData = <String, dynamic>{
          'orderStatus': requestedStatus,
          'status': requestedStatus,
          'trackingStatus': requestedStatus,
          'trackingEnabled': requestedStatus != 'Delivered',
          'statusHistory': history,
          'updatedAt': now,
        };

        if (requestedStatus == 'Picked by Courier') {
          updateData['courierPickedAt'] = now;
        }

        if (requestedStatus == 'Out for Delivery') {
          updateData['outForDeliveryAt'] = now;
        }

        if (requestedStatus == 'Delivered') {
          updateData['deliveredAt'] = now;
          updateData['trackingEnabled'] = false;
        }

        transaction.update(docRef, updateData);
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $requestedStatus'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring('Exception: '.length);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _infoRow(String title, dynamic value) {
    final text = value == null || value.toString().trim().isEmpty
        ? 'Not available'
        : value.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageTile(
    String title,
    dynamic timestamp,
    bool completed,
    bool current,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed || current
                    ? Colors.green
                    : Colors.grey.shade300,
              ),
              child: completed || current
                  ? const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
            if (title != 'Delivered')
              Container(
                width: 2,
                height: 34,
                color: completed
                    ? Colors.green
                    : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight:
                        current ? FontWeight.bold : FontWeight.w600,
                    color: current ? Colors.green.shade700 : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  timestamp == null
                      ? 'Pending'
                      : _timestampText(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: timestamp == null
                        ? Colors.grey
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(
    DocumentSnapshot<Map<String, dynamic>> orderDoc,
  ) {
    final data = orderDoc.data() ?? {};

    final status = _normalizeStatus(
      data['orderStatus'] ?? data['status'],
    );

    if (!_isCourierOrder(status)) {
      return const SizedBox.shrink();
    }

    final nextStatus = _nextStatus(status);
    final currentIndex = _statusIndex(status);

    final orderId =
        data['orderId']?.toString() ?? orderDoc.id;

    final courierPartner =
        data['courierPartner']?.toString() ??
            data['courierName']?.toString() ??
            'Not assigned';

    final courierPersonName =
        data['courierPersonName']?.toString() ??
            '';

    final courierPhone =
        data['courierPhone']?.toString() ??
            data['courierMobile']?.toString() ??
            '';

    final trackingNumber =
        data['trackingNumber']?.toString() ?? '';

    final trackingUrl =
        data['trackingUrl']?.toString() ?? '';

    final customerName =
        data['customerName']?.toString() ??
            data['name']?.toString() ??
            'Customer';

    final customerPhone =
        data['customerPhone']?.toString() ??
            data['phone']?.toString() ??
            '';

    final customerAddress =
        data['address']?.toString() ??
            data['deliveryAddress']?.toString() ??
            '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$orderId',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _infoRow('Customer', customerName),
            if (customerPhone.isNotEmpty)
              _infoRow('Phone', customerPhone),
            if (customerAddress.isNotEmpty)
              _infoRow('Address', customerAddress),

            const Divider(height: 24),

            _infoRow('Courier Partner', courierPartner),

            if (courierPersonName.isNotEmpty)
              _infoRow('Courier Person', courierPersonName),

            if (courierPhone.isNotEmpty)
              _infoRow('Courier Phone', courierPhone),

            if (trackingNumber.isNotEmpty)
              _infoRow('Tracking No.', trackingNumber),

            if (trackingUrl.isNotEmpty)
              _infoRow('Tracking URL', trackingUrl),

            const SizedBox(height: 14),

            const Text(
              'Delivery Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _stageTile(
              'Shipped',
              data['shippedAt'],
              currentIndex >= 0,
              status == 'Shipped',
            ),

            _stageTile(
              'Picked by Courier',
              data['courierPickedAt'],
              currentIndex >= 1,
              status == 'Picked by Courier',
            ),

            _stageTile(
              'Out for Delivery',
              data['outForDeliveryAt'],
              currentIndex >= 2,
              status == 'Out for Delivery',
            ),

            _stageTile(
              'Delivered',
              data['deliveredAt'],
              currentIndex >= 3,
              status == 'Delivered',
            ),

            if (nextStatus.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _updateCourierStatus(
                      orderDoc,
                      nextStatus,
                    );
                  },
                  icon: Icon(
                    nextStatus == 'Delivered'
                        ? Icons.done_all
                        : Icons.arrow_forward,
                  ),
                  label: Text('Mark as $nextStatus'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Order Delivered',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Courier Panel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('orders')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load orders.\n\n${snapshot.error}',
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

          final docs = snapshot.data?.docs ?? [];

          final courierOrders = docs.where((doc) {
            final data = doc.data();

            final status = _normalizeStatus(
              data['orderStatus'] ?? data['status'],
            );

            return _isCourierOrder(status);
          }).toList();

          courierOrders.sort((a, b) {
            final aData = a.data();
            final bData = b.data();

            final aTime = aData['updatedAt'];
            final bTime = bData['updatedAt'];

            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }

            return 0;
          });

          if (courierOrders.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 70,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No courier orders available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Orders will appear here after they are Shipped.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: courierOrders.length,
              itemBuilder: (context, index) {
                return _buildOrderCard(
                  courierOrders[index],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
