import 'package:flutter/material.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  final String amount;
  final String status;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(orderId.startsWith('#') ? orderId : '#$orderId'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 50,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Order Total: $amount',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Order Tracking',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 15),
          const _TrackingStep(
            title: 'Order Placed',
            subtitle: 'Your order has been received',
            completed: true,
          ),
          const _TrackingStep(
            title: 'Processing',
            subtitle: 'Order is being prepared',
            completed: true,
          ),
          _TrackingStep(
            title: 'Dispatched',
            subtitle: 'Order sent for delivery',
            completed:
                status == 'Dispatched' || status == 'Delivered',
          ),
          _TrackingStep(
            title: 'Delivered',
            subtitle: 'Order delivered successfully',
            completed: status == 'Delivered',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _TrackingStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool completed;
  final bool last;

  const _TrackingStep({
    required this.title,
    required this.subtitle,
    required this.completed,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: completed
                  ? const Color(0xFF0284C7)
                  : const Color(0xFFE2E8F0),
              child: Icon(
                completed ? Icons.check : Icons.circle,
                size: 14,
                color: Colors.white,
              ),
            ),
            if (!last)
              Container(
                width: 2,
                height: 55,
                color: completed
                    ? const Color(0xFF0284C7)
                    : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: completed
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}