import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const Color primaryBlue = Color(0xFF0284C7);
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _selectedRole = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final res = await _authService.getUsers(
      role: _selectedRole == 'all' ? null : _selectedRole,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    if (mounted) {
      List<Map<String, dynamic>> userList = [];
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        if (data is Map<String, dynamic>) {
          if (data['users'] is List) {
            userList = List<Map<String, dynamic>>.from(data['users']);
          } else if (data['results'] is List) {
            userList = List<Map<String, dynamic>>.from(data['results']);
          }
        } else if (data is List) {
          userList = List<Map<String, dynamic>>.from(data);
        }
      }
      setState(() {
        _users = userList;
        _isLoading = false;
      });
    }
  }

  void _showUserDetailsDialog(Map<String, dynamic> u) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final role = (u['role'] ?? 'customer').toString().toUpperCase();
    final name = (u['name'] ?? u['username'] ?? 'Pure Water User').toString();
    final email = (u['email'] ?? '').toString();
    final phone = (u['phone'] ?? '').toString();
    final customerCode = (u['customer_code'] ?? 'CUST-${u['id'] ?? ''}').toString();
    final city = (u['city'] ?? '').toString();
    final district = (u['district'] ?? '').toString();
    final address = (u['address'] ?? '').toString();
    final dateJoined = (u['date_joined'] ?? '').toString();
    final status = (u['status'] ?? (u['is_active'] == true ? 'active' : 'inactive')).toString();
    final orderCount = u['order_count'] ?? 0;
    final franchiseDetails = u['franchise_details'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _getRoleColor(role).withAlpha(40),
                    child: Icon(_getRoleIcon(role), color: _getRoleColor(role), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryBlue.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: primaryBlue.withAlpha(80)),
                              ),
                              child: Text(
                                customerCode,
                                style: const TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getRoleColor(role).withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  color: _getRoleColor(role),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: status == 'active'
                                    ? Colors.green.withAlpha(25)
                                    : Colors.orange.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: status == 'active' ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Registration & Contact Details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.phone_outlined, 'Mobile Number', phone.isNotEmpty ? phone : 'Not provided'),
              _buildDetailRow(Icons.email_outlined, 'Email Address', email.isNotEmpty ? email : 'Not provided'),
              _buildDetailRow(Icons.location_city_outlined, 'City', city.isNotEmpty ? city : 'Not provided'),
              if (district.isNotEmpty)
                _buildDetailRow(Icons.map_outlined, 'District', district),
              if (address.isNotEmpty)
                _buildDetailRow(Icons.home_outlined, 'Address / Landmark', address),
              _buildDetailRow(Icons.shopping_bag_outlined, 'Total Orders', '$orderCount orders placed'),
              _buildDetailRow(Icons.calendar_today_outlined, 'Registration Date', _formatDate(dateJoined)),
              if (franchiseDetails != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Franchise Details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                _buildDetailRow(Icons.storefront_outlined, 'Business Name', franchiseDetails['business_name']?.toString() ?? ''),
                _buildDetailRow(Icons.explore_outlined, 'Territory', franchiseDetails['territory']?.toString() ?? ''),
                if ((franchiseDetails['gst_number'] ?? '').toString().isNotEmpty)
                  _buildDetailRow(Icons.receipt_long_outlined, 'GST Number', franchiseDetails['gst_number'].toString()),
                _buildDetailRow(Icons.security_outlined, 'Deposit', '₹${franchiseDetails['security_deposit'] ?? 0}'),
                _buildDetailRow(Icons.percent_outlined, 'Commission Rate', '${franchiseDetails['commission_rate'] ?? 0}%'),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check),
                  label: const Text('Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer & User Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by ID, name, email, phone, city...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                    _fetchUsers();
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRoleFilterChip('All Accounts', 'all'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('Customers', 'customer'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('Franchises', 'franchise'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('Staff', 'staff'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('Admins', 'admin'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 56,
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No registered users found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchUsers,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _users.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final u = _users[idx];
                            final role = (u['role'] ?? 'customer')
                                .toString()
                                .toUpperCase();
                            final name = (u['name'] ??
                                    u['username'] ??
                                    'Pure Water User')
                                .toString();
                            final email = (u['email'] ?? '').toString();
                            final phone = (u['phone'] ?? '').toString();
                            final customerCode = (u['customer_code'] ?? 'CUST-${u['id'] ?? ''}').toString();
                            final franchiseName =
                                (u['franchise_name'] ?? (u['franchise_details'] != null ? u['franchise_details']['business_name'] : '') ?? '').toString();
                            final city = (u['city'] ?? '').toString();
                            final district = (u['district'] ?? '').toString();
                            final territory =
                                (u['territory'] ?? (city.isNotEmpty ? city : '')).toString();
                            final dateJoined =
                                (u['date_joined'] ?? '').toString();
                            final orderCount = u['order_count'] ?? 0;

                            return Card(
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showUserDetailsDialog(u),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor:
                                                    _getRoleColor(role)
                                                        .withAlpha(38),
                                                child: Icon(
                                                  _getRoleIcon(role),
                                                  color: _getRoleColor(role),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  if (franchiseName.isNotEmpty)
                                                    Text(
                                                      'Store: $franchiseName',
                                                      style: const TextStyle(
                                                        color: primaryBlue,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: primaryBlue.withAlpha(25),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  customerCode,
                                                  style: const TextStyle(
                                                    color: primaryBlue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getRoleColor(role)
                                                      .withAlpha(30),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  role,
                                                  style: TextStyle(
                                                    color: _getRoleColor(role),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (email.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.email_outlined,
                                              size: 16,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black45,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                email,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (phone.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone_outlined,
                                              size: 16,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black45,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              phone,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (city.isNotEmpty || territory.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 16,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black45,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              district.isNotEmpty ? '$city, $district' : (city.isNotEmpty ? city : territory),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white10 : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.shopping_bag_outlined, size: 14, color: primaryBlue),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$orderCount orders',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (dateJoined.isNotEmpty)
                                            Text(
                                              'Joined: ${_formatDate(dateJoined)}',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white38
                                                    : Colors.grey,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(String label, String value) {
    final isSelected = _selectedRole == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedRole = value);
        _fetchUsers();
      },
      selectedColor: primaryBlue.withAlpha(50),
      labelStyle: TextStyle(
        color: isSelected ? primaryBlue : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'franchise':
        return Colors.orange;
      case 'admin':
        return Colors.purple;
      case 'staff':
        return Colors.teal;
      case 'customer':
      default:
        return primaryBlue;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'franchise':
        return Icons.store_mall_directory;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'staff':
        return Icons.badge;
      case 'customer':
      default:
        return Icons.person;
    }
  }

  String _formatDate(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return ts;
    }
  }
}
