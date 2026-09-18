import 'package:flutter/material.dart';

import '../../../core/services/franchise_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/ai_chatbot_modal.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../profile/franchise_profile_screen.dart';

class FranchiseDashboardScreen extends StatefulWidget {
  const FranchiseDashboardScreen({super.key});

  @override
  State<FranchiseDashboardScreen> createState() =>
      _FranchiseDashboardScreenState();
}

class _FranchiseDashboardScreenState extends State<FranchiseDashboardScreen> {
  final SessionService _sessionService = SessionService();
  final FranchiseService _franchiseService = FranchiseService();
  UserModel? _currentUser;
  Map<String, dynamic> _stats = {
    'customers_served': 0,
    'registered_customers': 0,
    'active_stock': 0,
    'low_stock': 0,
    'on_hold': 0,
    'expired_stock': 0,
    'pending_orders': 0,
    'total_orders': 0,
  };
  bool _loadingStats = true;

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
    await _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final res = await _franchiseService.getDashboardStats();
    if (mounted && res['success'] == true && res['data'] is Map) {
      setState(() {
        _stats = Map<String, dynamic>.from(res['data']);
        _loadingStats = false;
      });
    } else if (mounted) {
      setState(() => _loadingStats = false);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout from Franchise Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _sessionService.logout();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.roleSelection,
        (_) => false,
      );
    }
  }

  String get _displayName {
    final name = _currentUser?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Franchise Partner';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: desktop
              ? null
              : AppBar(
                  title: const Text('Franchise Dashboard'),
                  actions: [
                    IconButton(
                      tooltip: 'AI Operations Assistant',
                      icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0077B6)),
                      onPressed: () => AiChatbotModal.show(context, mode: ChatbotMode.franchise),
                    ),
                    IconButton(
                      tooltip: 'My Profile',
                      icon: const Icon(Icons.person_outline_rounded),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FranchiseProfileScreen(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      icon: const Icon(Icons.logout_rounded, color: Colors.red),
                      onPressed: () => _confirmLogout(context),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0077B6),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('AI Assistant'),
            onPressed: () => AiChatbotModal.show(context, mode: ChatbotMode.franchise),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1250,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desktop) ...[
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome back, $_displayName. Here is your franchise overview.',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (_loadingStats)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(
                          backgroundColor: Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        ),
                      ),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: desktop ? 4 : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: desktop ? 2.1 : 1.15,
                      children: [
                        _StatCard(
                          title: 'Customers Served',
                          value: '${_stats['customers_served'] ?? 0}',
                          icon: Icons.people_outline_rounded,
                        ),
                        _StatCard(
                          title: 'Registered Cust.',
                          value: '${_stats['registered_customers'] ?? 0}',
                          icon: Icons.app_registration_rounded,
                        ),
                        _StatCard(
                          title: 'Active Stock',
                          value: '${_stats['active_stock'] ?? 0}',
                          icon: Icons.water_drop_outlined,
                        ),
                        _StatCard(
                          title: 'Low Stock Alerts',
                          value: '${_stats['low_stock'] ?? 0}',
                          icon: Icons.warning_amber_rounded,
                        ),
                        _StatCard(
                          title: 'Stock On Hold',
                          value: '${_stats['on_hold'] ?? 0}',
                          icon: Icons.pause_circle_outline_rounded,
                        ),
                        _StatCard(
                          title: 'Expired Stock',
                          value: '${_stats['expired_stock'] ?? 0}',
                          icon: Icons.history_toggle_off_rounded,
                        ),
                        _StatCard(
                          title: 'Pending Orders',
                          value: '${_stats['pending_orders'] ?? 0}',
                          icon: Icons.schedule_rounded,
                        ),
                        _StatCard(
                          title: 'Total Orders',
                          value: '${_stats['total_orders'] ?? 0}',
                          icon: Icons.shopping_bag_outlined,
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            flex: 2,
                            child: _RecentOrders(),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _AccountSummary(user: _currentUser),
                          ),
                        ],
                      )
                    else ...[
                      const _RecentOrders(),
                      const SizedBox(height: 16),
                      _AccountSummary(user: _currentUser),
                    ],
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0284C7),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
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
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders();

  @override
  Widget build(BuildContext context) {
    final List<List<String>> orders = [];

    return _Card(
      title: 'Recent Orders',
      child: orders.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Color(0xFFCBD5E1),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No recent orders yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Place your first franchise order from the Products tab.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: orders
                  .map(
                    (order) => Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE0F2FE),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          title: Text(
                            order[0],
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(order[2]),
                          trailing: Text(
                            order[1],
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  final UserModel? user;

  const _AccountSummary({this.user});

  @override
  Widget build(BuildContext context) {
    final franchiseId = user?.id != null ? 'FR-${user!.id}' : 'FR-Pending';
    final ownerName = user?.name.isNotEmpty == true ? user!.name : 'Franchise Partner';
    final email = user?.email.isNotEmpty == true ? user!.email : 'Not Provided';
    final status = 'Approved Partner';

    return _Card(
      title: 'Franchise Details',
      child: Column(
        children: [
          _Info('Franchise ID', franchiseId),
          const Divider(),
          _Info('Owner', ownerName),
          const Divider(),
          _Info('Email', email),
          const Divider(),
          _Info('Status', status),
          const Divider(),
          const _Info('Commission', '12%'),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String title;
  final String value;

  const _Info(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}