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
        if (data is Map<String, dynamic> && data['results'] is List) {
          userList = List<Map<String, dynamic>>.from(data['results']);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Directory & Roles'),
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
                    hintText: 'Search by name, email, phone, or franchise...',
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
                          separatorBuilder: (_, __) =>
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
                            final franchiseName =
                                (u['franchise_name'] ?? '').toString();
                            final territory =
                                (u['territory'] ?? u['city'] ?? '').toString();
                            final dateJoined =
                                (u['date_joined'] ?? '').toString();

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(role)
                                                .withAlpha(30),
                                            borderRadius:
                                                BorderRadius.circular(8),
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
                                    if (territory.isNotEmpty) ...[
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
                                            'Territory: $territory',
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
                                    if (dateJoined.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          'Joined: ${_formatDate(dateJoined)}',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
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
