import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../models/user_model.dart';

class FranchiseTerritoryScreen extends StatefulWidget {
  const FranchiseTerritoryScreen({super.key});

  @override
  State<FranchiseTerritoryScreen> createState() =>
      _FranchiseTerritoryScreenState();
}

class _FranchiseTerritoryScreenState extends State<FranchiseTerritoryScreen> {
  final SessionService _sessionService = SessionService();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final user = await _sessionService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final franchiseId = _currentUser?.id != null ? 'FR-${_currentUser!.id}' : 'FR-Pending';
    const userCity = 'Assigned on Verification';
    const userState = 'Chhattisgarh';
    const userStatus = 'Active Partner';

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: desktop
              ? null
              : AppBar(
                  title: const Text('Territory'),
                ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1050,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desktop) ...[
                      const Text(
                        'Territory',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'View your assigned franchise territory.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        children: [
                          _TerritoryRow(
                            Icons.badge_outlined,
                            'Franchise ID',
                            franchiseId,
                          ),
                          const Divider(),
                          _TerritoryRow(
                            Icons.location_city_outlined,
                            'City / Region',
                            userCity,
                          ),
                          const Divider(),
                          _TerritoryRow(
                            Icons.pin_drop_outlined,
                            'State',
                            userState,
                          ),
                          const Divider(),
                          _TerritoryRow(
                            Icons.location_on_outlined,
                            'Radius Type',
                            'Exclusive Territory (5 KM Radius)',
                          ),
                          const Divider(),
                          _TerritoryRow(
                            Icons.check_circle_outline,
                            'Status',
                            userStatus,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_rounded,
                            size: 56,
                            color: Color(0xFF0284C7),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Territory Geo-Boundary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Assigned territory boundary for distribution orders.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TerritoryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _TerritoryRow(
    this.icon,
    this.title,
    this.value,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF0284C7),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}