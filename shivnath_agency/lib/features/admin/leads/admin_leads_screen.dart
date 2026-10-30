import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/lead_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/services/followup_service.dart';
import '../../../core/utils/contact_action_helper.dart';

class AdminLeadsScreen extends StatefulWidget {
  const AdminLeadsScreen({super.key});

  @override
  State<AdminLeadsScreen> createState() => _AdminLeadsScreenState();
}

class _AdminLeadsScreenState extends State<AdminLeadsScreen> {
  final List<Map<String, dynamic>> leads = [];

  final LeadService _leadService = LeadService();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  @override
  void initState() {
    super.initState();

    _loadLeads();
  }

  String searchText = '';
  String selectedStatus = 'All';
  String selectedScore = 'All';

  List<Map<String, dynamic>> get filteredLeads {
    final search = searchText.trim().toLowerCase();

    return leads.where((lead) {
      final name = (lead['name'] ?? '').toString().toLowerCase();

      final phone = (lead['phone'] ?? '').toString().toLowerCase();

      final city = (lead['city'] ?? '').toString().toLowerCase();

      final status = (lead['status'] ?? '').toString();

      final score = (lead['score'] ?? '').toString();

      final email = (lead['email'] ?? '').toString().toLowerCase();
      final source = (lead['source'] ?? '').toString().toLowerCase();
      final notes = (lead['notes'] ?? '').toString().toLowerCase();

      final matchesSearch =
          search.isEmpty ||
          name.contains(search) ||
          phone.contains(search) ||
          email.contains(search) ||
          source.contains(search) ||
          notes.contains(search) ||
          city.contains(search);

      final matchesStatus = selectedStatus == 'All' || status == selectedStatus;

      final matchesScore = selectedScore == 'All' || score == selectedScore;

      return matchesSearch && matchesStatus && matchesScore;
    }).toList();
  }

  int get hotLeads {
    return leads
        .where(
          (lead) => (lead['score'] ?? '').toString().toUpperCase() == 'HOT',
        )
        .length;
  }

  int get interestedLeads {
    return leads.where((lead) => lead['status'] == 'Interested').length;
  }

  int get siteVisits {
    return leads
        .where((lead) => lead['status'] == 'Site Visit Scheduled')
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Container(
          color: const Color(0xFFF5F7FB),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(desktop),

                    const SizedBox(height: 22),

                    _stats(desktop),

                    const SizedBox(height: 20),

                    _filters(desktop),

                    const SizedBox(height: 16),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_hasError)
                      _errorView()
                    else if (desktop)
                      _desktopTable()
                    else
                      _mobileList(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _errorView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626), size: 48),
          const SizedBox(height: 12),
          const Text(
            'Unable to Load Leads',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage.isNotEmpty ? _errorMessage : 'The server connection timed out or is unavailable.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry Connection', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: _loadLeads,
          ),
        ],
      ),
    );
  }

  Future<void> _loadLeads() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final result = await _leadService.getLeads();

    if (!mounted) {
      return;
    }

    if (result['success'] == true) {
      final dynamic response = result['data'];

      final List<dynamic> items = response is Map
          ? (response['leads'] as List? ??
              response['results'] as List? ??
              response['data'] as List? ??
              [])
          : (response is List ? response : []);

      setState(() {
        _hasError = false;
        _errorMessage = '';
        leads.clear();

        leads.addAll(
          items.map(
            (item) => _leadService.mapLead(Map<String, dynamic>.from(item)),
          ),
        );

        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = result['message'] ?? 'Unable to connect to backend server. Please verify network or backend.';
      });

      AppToast.error(
        context,
        _errorMessage,
        title: 'Unable to Load Leads',
      );
    }
  }
  // =========================================================
  // HEADER
  // =========================================================

  Widget _header(bool desktop) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leads',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Manage franchise enquiries and sales pipeline',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),

        if (desktop)
          SizedBox(
            width: 135,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                _openLeadForm();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Lead'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                maximumSize: const Size(135, 44),
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  // =========================================================
  // STATS
  // =========================================================

  Widget _stats(bool desktop) {
    final items = [
      {
        'title': 'Total Leads',
        'value': '${leads.length}',
        'onTap': () => setState(() {
          selectedStatus = 'All';
          selectedScore = 'All';
        }),
      },
      {
        'title': 'Hot Leads',
        'value': '$hotLeads',
        'onTap': () => setState(() {
          selectedScore = 'Hot';
          selectedStatus = 'All';
        }),
      },
      {
        'title': 'Interested',
        'value': '$interestedLeads',
        'onTap': () => setState(() {
          selectedStatus = 'Interested';
          selectedScore = 'All';
        }),
      },
      {
        'title': 'Site Visits',
        'value': '$siteVisits',
        'onTap': () => setState(() {
          selectedStatus = 'Site Visit Scheduled';
          selectedScore = 'All';
        }),
      },
    ];

    if (desktop) {
      return Row(
        children: List.generate(items.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : 14,
              ),
              child: _LeadStatCard(
                title: items[index]['title']! as String,
                value: items[index]['value']! as String,
                onTap: items[index]['onTap'] as VoidCallback?,
              ),
            ),
          );
        }),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        return _LeadStatCard(
          title: items[index]['title']! as String,
          value: items[index]['value']! as String,
          onTap: items[index]['onTap'] as VoidCallback?,
        );
      },
    );
  }

  // =========================================================
  // FILTERS
  // =========================================================

  Widget _filters(bool desktop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(child: _searchField()),

                const SizedBox(width: 14),

                const Icon(Icons.filter_alt_outlined, color: Color(0xFF64748B)),

                const SizedBox(width: 10),

                SizedBox(width: 210, child: _statusDropdown()),

                const SizedBox(width: 10),

                SizedBox(width: 140, child: _scoreDropdown()),
              ],
            )
          : Column(
              children: [
                _searchField(),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: _statusDropdown()),
                    const SizedBox(width: 10),
                    Expanded(child: _scoreDropdown()),
                  ],
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _openLeadForm();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Lead'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: (value) {
          setState(() {
            searchText = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search name, phone or city...',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF0284C7)),
          ),
        ),
      ),
    );
  }

  Widget _statusDropdown() {
    const items = [
      DropdownMenuItem(value: 'All', child: Text('All Status')),
      DropdownMenuItem(value: 'New Lead', child: Text('New Lead')),
      DropdownMenuItem(value: 'Contacted', child: Text('Contacted')),
      DropdownMenuItem(value: 'Follow-up 1', child: Text('Follow-up 1')),
      DropdownMenuItem(value: 'Follow-up 2', child: Text('Follow-up 2')),
      DropdownMenuItem(value: 'Interested', child: Text('Interested')),
      DropdownMenuItem(
        value: 'Site Visit Scheduled',
        child: Text('Site Visit Scheduled'),
      ),
      DropdownMenuItem(
        value: 'Agreement Pending',
        child: Text('Agreement Pending'),
      ),
      DropdownMenuItem(
        value: 'Franchise Confirmed',
        child: Text('Franchise Confirmed'),
      ),
      DropdownMenuItem(value: 'Converted', child: Text('Converted')),
      DropdownMenuItem(value: 'Not Interested', child: Text('Not Interested')),
      DropdownMenuItem(value: 'Lost', child: Text('Lost')),
    ];
    final validValues = items.map((e) => e.value).toSet();
    final safeValue = validValues.contains(selectedStatus)
        ? selectedStatus
        : 'All';

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      items: items,
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          selectedStatus = value;
        });
      },
    );
  }

  Widget _scoreDropdown() {
    const items = [
      DropdownMenuItem(value: 'All', child: Text('All Score')),
      DropdownMenuItem(value: 'Hot', child: Text('Hot')),
      DropdownMenuItem(value: 'Warm', child: Text('Warm')),
      DropdownMenuItem(value: 'Cold', child: Text('Cold')),
    ];
    final validValues = items.map((e) => e.value).toSet();
    final safeValue = validValues.contains(selectedScore)
        ? selectedScore
        : 'All';

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      items: items,
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          selectedScore = value;
        });
      },
    );
  }

  // =========================================================
  // DESKTOP TABLE
  // =========================================================

  Widget _desktopTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _tableHeader(),

          if (filteredLeads.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 55),
              child: Text(
                'No leads found.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...filteredLeads.map(_tableRow),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('LEAD', style: _leadHeaderStyle)),
          Expanded(child: Text('LOCATION', style: _leadHeaderStyle)),
          Expanded(child: Text('BUDGET', style: _leadHeaderStyle)),
          Expanded(child: Text('SCORE', style: _leadHeaderStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: _leadHeaderStyle)),
          Expanded(flex: 2, child: Text('EXECUTIVE', style: _leadHeaderStyle)),
          Expanded(
            flex: 2,
            child: Text('NEXT FOLLOW-UP', style: _leadHeaderStyle),
          ),
          SizedBox(width: 205, child: Text('ACTIONS', style: _leadHeaderStyle)),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> lead) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _avatar('${lead['name']}'),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${lead['name']}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${lead['phone']}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lead['city']}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${lead['district']}',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          Expanded(
            child: Text(
              '₹${lead['budget']}',
              style: const TextStyle(fontSize: 10),
            ),
          ),

          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _scoreBadge('${lead['score']}'),
            ),
          ),

          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusBadge('${lead['status']}'),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              '${lead['executive'] ?? '-'}',
              style: const TextStyle(fontSize: 10),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              '${lead['followup'] ?? '-'}',
              style: const TextStyle(fontSize: 10),
            ),
          ),

          SizedBox(
            width: 205,
            child: Row(
              children: [
                _actionButton(
                  icon: Icons.published_with_changes_rounded,
                  tooltip: 'Update CRM Status',
                  onTap: () {
                    _showUpdateLeadCrmDialog(lead);
                  },
                ),
                _actionButton(
                  icon: Icons.call_outlined,
                  tooltip: 'Call',
                  onTap: () {
                    ContactActionHelper.makePhoneCall(context, '${lead['phone']}');
                  },
                ),
                _actionButton(
                  icon: Icons.chat_outlined,
                  tooltip: 'Chat / WhatsApp',
                  onTap: () {
                    ContactActionHelper.openMessagingChooser(
                      context,
                      phone: '${lead['phone']}',
                      contactName: '${lead['name']}',
                    );
                  },
                ),
                _actionButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View',
                  onTap: () {
                    _viewLead(lead);
                  },
                ),
                _actionButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onTap: () {
                    _openLeadForm(lead: lead);
                  },
                ),
                _actionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  danger: true,
                  onTap: () {
                    _deleteLead(lead);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MOBILE
  // =========================================================

  Widget _mobileList() {
    if (filteredLeads.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(35),
        alignment: Alignment.center,
        child: const Text('No leads found.'),
      );
    }
    return Column(
      children: filteredLeads.map((lead) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _viewLead(lead),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _avatar('${lead['name']}'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${lead['name']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${lead['phone']}${((lead['email'] ?? '').toString().isNotEmpty) ? ' • ${lead['email']}' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _scoreBadge('${lead['score']}'),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Source and Territory Row
                    Row(
                      children: [
                        if ((lead['source'] ?? '').toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (lead['source'] == 'PUBLIC_CHATBOT' || (lead['source'] ?? '').toString().contains('CHATBOT'))
                                  ? const Color(0xFFEDE9FE)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (lead['source'] == 'PUBLIC_CHATBOT' || (lead['source'] ?? '').toString().contains('CHATBOT'))
                                    ? const Color(0xFF8B5CF6)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (lead['source'] == 'PUBLIC_CHATBOT' || (lead['source'] ?? '').toString().contains('CHATBOT'))
                                      ? Icons.smart_toy_outlined
                                      : Icons.campaign_outlined,
                                  size: 11,
                                  color: (lead['source'] == 'PUBLIC_CHATBOT' || (lead['source'] ?? '').toString().contains('CHATBOT'))
                                      ? const Color(0xFF6D28D9)
                                      : const Color(0xFF475569),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  lead['source'] == 'PUBLIC_CHATBOT' ? 'PUBLIC CHATBOT' : '${lead['source']}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: (lead['source'] == 'PUBLIC_CHATBOT' || (lead['source'] ?? '').toString().contains('CHATBOT'))
                                        ? const Color(0xFF6D28D9)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            '${lead['city']}, ${lead['district']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),

                    if ((lead['notes'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Inquiry: ${(lead['notes'] ?? '').toString().split('\n').first}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _statusBadge('${lead['status']}'),
                        Text(
                          'Executive: ${lead['executive']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if ((lead['created_at'] ?? '').toString().isNotEmpty)
                          Text(
                            'Created: ${lead['created_at'].toString().split('T').first}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Call Lead',
                          onPressed: () {
                            ContactActionHelper.makePhoneCall(context, '${lead['phone']}');
                          },
                          icon: const Icon(
                            Icons.call_outlined,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Chat / Message',
                          onPressed: () {
                            ContactActionHelper.openMessagingChooser(
                              context,
                              phone: '${lead['phone']}',
                              contactName: '${lead['name']}',
                            );
                          },
                          icon: const Icon(
                            Icons.chat_outlined,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Update CRM',
                          onPressed: () {
                            _showUpdateLeadCrmDialog(lead);
                          },
                          icon: const Icon(
                            Icons.published_with_changes_rounded,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        IconButton(
                          tooltip: 'View Details',
                          onPressed: () {
                            _viewLead(lead);
                          },
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                        IconButton(
                          tooltip: 'Edit Lead',
                          onPressed: () {
                            _openLeadForm(lead: lead);
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete Lead',
                          onPressed: () {
                            _deleteLead(lead);
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // =========================================================
  // CRM STATUS & FOLLOW-UP DIALOGS
  // =========================================================

  Future<void> _showUpdateLeadCrmDialog(Map<String, dynamic> lead) async {
    final leadId = int.tryParse(lead['id']?.toString() ?? '');
    if (leadId == null) return;

    String currentStatus = lead['status']?.toString() ?? 'New Lead';
    String currentScore = lead['score']?.toString() ?? 'Warm';
    bool siteVisitPlanned = lead['site_visit_planned'] == true;
    bool siteVisitCompleted = lead['site_visit_completed'] == true;
    final siteVisitDateCtrl = TextEditingController(
      text: lead['site_visit_date']?.toString() ?? '',
    );
    final siteVisitNotesCtrl = TextEditingController(
      text: lead['site_visit_notes']?.toString() ?? '',
    );
    final notesCtrl = TextEditingController(
      text: lead['notes']?.toString() ?? '',
    );
    bool isSaving = false;

    final statuses = [
      'New Lead',
      'Contacted',
      'Interested',
      'Hot Lead',
      'Follow-up 1',
      'Follow-up 2',
      'Follow-up Required',
      'Site Visit Scheduled',
      'Site Visit Completed',
      'Agreement Pending',
      'Franchise Confirmed',
      'Converted',
      'Lost',
      'Not Interested',
    ];

    final scores = ['Hot', 'Warm', 'Cold'];

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.published_with_changes_rounded,
                color: Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Update CRM: ${lead['name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pipeline Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: statuses.contains(currentStatus)
                        ? currentStatus
                        : statuses.first,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: statuses
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          currentStatus = val;
                          if (val == 'Site Visit Scheduled') {
                            siteVisitPlanned = true;
                          }
                          if (val == 'Site Visit Completed') {
                            siteVisitPlanned = true;
                            siteVisitCompleted = true;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Interest Level / Score',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: scores.contains(currentScore)
                        ? currentScore
                        : scores.first,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: scores
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => currentScore = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Site Visit Planned',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: siteVisitPlanned,
                    onChanged: (v) =>
                        setModalState(() => siteVisitPlanned = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Site Visit Completed',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: siteVisitCompleted,
                    onChanged: (v) =>
                        setModalState(() => siteVisitCompleted = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: siteVisitDateCtrl,
                    decoration: InputDecoration(
                      labelText: 'Site Visit Date (YYYY-MM-DD)',
                      hintText: 'e.g. 2026-09-25',
                      prefixIcon: const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: siteVisitNotesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Site Visit / Location Notes',
                      hintText: 'Road access, land size, water source...',
                      prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'CRM & Discussion Notes',
                      hintText: 'Summary of discussions, next steps...',
                      prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      final payload = {
                        'status': currentStatus,
                        'score': currentScore,
                        'interest_level': currentScore,
                        'site_visit_planned': siteVisitPlanned,
                        'site_visit_completed': siteVisitCompleted,
                        'site_visit_date': siteVisitDateCtrl.text.trim(),
                        'site_visit_notes': siteVisitNotesCtrl.text.trim(),
                        'notes': notesCtrl.text.trim(),
                      };
                      final res = await _leadService.updateLead(
                        leadId,
                        payload,
                      );
                      if (!dialogCtx.mounted) return;
                      setModalState(() => isSaving = false);
                      if (res['success'] == true) {
                        Navigator.pop(dialogCtx);
                        AppToast.success(
                          context,
                          'Lead CRM status updated successfully',
                        );
                        await _loadLeads();
                      } else {
                        AppToast.error(
                          context,
                          res['message'] ?? 'Failed to update CRM status',
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save CRM Updates'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showScheduleFollowupDialog(Map<String, dynamic> lead) async {
    final leadId = int.tryParse(lead['id']?.toString() ?? '');
    if (leadId == null) return;

    String followupType = 'Phone Call';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    final noteCtrl = TextEditingController();
    bool isSaving = false;

    final types = [
      'Phone Call',
      'WhatsApp',
      'Email',
      'Meeting',
      'Site Visit',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.add_alarm_rounded, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Schedule Follow-up: ${lead['name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Follow-up Method',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: followupType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: types
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => followupType = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                          ),
                          label: Text(
                            selectedDate.toIso8601String().substring(0, 10),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) {
                              setModalState(() => selectedDate = d);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time_rounded, size: 16),
                          label: Text(selectedTime.format(context)),
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (t != null) {
                              setModalState(() => selectedTime = t);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Follow-up Agenda / Note',
                      hintText: 'What needs to be discussed or checked...',
                      prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      final dt = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      final res = await FollowupService().createFollowup(
                        leadId: leadId,
                        dateTime: dt,
                        type: followupType,
                        note: noteCtrl.text.trim().isEmpty
                            ? 'Scheduled follow-up'
                            : noteCtrl.text.trim(),
                      );
                      if (!dialogCtx.mounted) return;
                      setModalState(() => isSaving = false);
                      if (res['success'] == true) {
                        Navigator.pop(dialogCtx);
                        AppToast.success(
                          context,
                          'Follow-up scheduled successfully',
                        );
                      } else {
                        AppToast.error(
                          context,
                          res['message'] ?? 'Failed to schedule follow-up',
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Schedule Follow-up'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ADD / EDIT PROFESSIONAL FORM
  // =========================================================

  Future<void> _openLeadForm({Map<String, dynamic>? lead}) async {
    final editing = lead != null;

    final nameController = TextEditingController(text: lead?['name'] ?? '');

    final phoneController = TextEditingController(text: lead?['phone'] ?? '');

    final cityController = TextEditingController(text: lead?['city'] ?? '');

    final districtController = TextEditingController(
      text: lead?['district'] ?? '',
    );

    final experienceController = TextEditingController(
      text: lead?['experience'] ?? '',
    );

    final locationController = TextEditingController(
      text: lead?['location'] ?? '',
    );

    final followupController = TextEditingController(
      text: lead?['followup'] ?? '',
    );

    String budget = lead?['budget'] ?? '';

    String existingBusiness = lead?['existingBusiness'] ?? 'No';

    String commercialSpace = lead?['commercialSpace'] ?? 'No';

    String score = lead?['score'] ?? 'Warm';

    String status = lead?['status'] ?? 'New Lead';

    String executive = lead?['executive'] ?? '';

    bool saved = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;

            final desktop = screenWidth >= 900;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: desktop ? 70 : 14,
                vertical: desktop ? 28 : 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: desktop ? 920 : 600,
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // HEADER
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_outlined,
                                color: Color(0xFF0284C7),
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    editing ? 'Edit Lead' : 'Add New Lead',
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    editing
                                        ? 'Update franchise enquiry and lead details'
                                        : 'Create and qualify a new franchise enquiry',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              tooltip: 'Close',
                              onPressed: () {
                                Navigator.pop(dialogContext);
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // BODY
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(desktop ? 22 : 16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final twoColumns = constraints.maxWidth >= 700;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _leadFormSection(
                                    title: 'Contact Information',
                                    subtitle:
                                        'Basic contact and location details',
                                    icon: Icons.person_outline,
                                    child: twoColumns
                                        ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  children: [
                                                    _professionalField(
                                                      controller:
                                                          nameController,
                                                      label: 'Full Name',
                                                      hint: 'Enter full name',
                                                      icon:
                                                          Icons.person_outline,
                                                      requiredField: true,
                                                    ),
                                                    const SizedBox(height: 14),
                                                    _professionalField(
                                                      controller:
                                                          cityController,
                                                      label: 'City',
                                                      hint: 'Enter city',
                                                      icon: Icons
                                                          .location_city_outlined,
                                                      requiredField: true,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  children: [
                                                    _professionalField(
                                                      controller:
                                                          phoneController,
                                                      label: 'Mobile Number',
                                                      hint:
                                                          'Enter mobile number',
                                                      icon:
                                                          Icons.phone_outlined,
                                                      keyboardType:
                                                          TextInputType.phone,
                                                      requiredField: true,
                                                    ),
                                                    const SizedBox(height: 14),
                                                    _professionalField(
                                                      controller:
                                                          districtController,
                                                      label: 'District',
                                                      hint: 'Enter district',
                                                      icon: Icons.map_outlined,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              _professionalField(
                                                controller: nameController,
                                                label: 'Full Name',
                                                hint: 'Enter full name',
                                                icon: Icons.person_outline,
                                                requiredField: true,
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalField(
                                                controller: phoneController,
                                                label: 'Mobile Number',
                                                hint: 'Enter mobile number',
                                                icon: Icons.phone_outlined,
                                                keyboardType:
                                                    TextInputType.phone,
                                                requiredField: true,
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalField(
                                                controller: cityController,
                                                label: 'City',
                                                hint: 'Enter city',
                                                icon: Icons
                                                    .location_city_outlined,
                                                requiredField: true,
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalField(
                                                controller: districtController,
                                                label: 'District',
                                                hint: 'Enter district',
                                                icon: Icons.map_outlined,
                                              ),
                                            ],
                                          ),
                                  ),

                                  const SizedBox(height: 18),

                                  _leadFormSection(
                                    title: 'Business & Franchise Details',
                                    subtitle:
                                        'Investment, business background and location preference',
                                    icon: Icons.business_center_outlined,
                                    child: twoColumns
                                        ? Column(
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: _professionalDropdown(
                                                      label:
                                                          'Investment Budget',
                                                      value: budget,
                                                      items: const [
                                                        '',
                                                        '₹2 Lakh - ₹3 Lakh',
                                                        '₹3 Lakh - ₹5 Lakh',
                                                        '₹5 Lakh - ₹10 Lakh',
                                                        '₹10 Lakh+',
                                                        '2-5 Lakh',
                                                        '5-8 Lakh',
                                                        '8-10 Lakh',
                                                        '10-15 Lakh',
                                                        '15-20 Lakh',
                                                        '20-25 Lakh',
                                                        '25+ Lakh',
                                                      ],
                                                      onChanged: (value) {
                                                        setDialogState(() {
                                                          budget = value ?? '';
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: _professionalDropdown(
                                                      label:
                                                          'Existing Business',
                                                      value: existingBusiness,
                                                      items: const [
                                                        'No',
                                                        'Yes',
                                                      ],
                                                      onChanged: (value) {
                                                        setDialogState(() {
                                                          existingBusiness =
                                                              value ?? 'No';
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: _professionalDropdown(
                                                      label: 'Commercial Space',
                                                      value: commercialSpace,
                                                      items: const [
                                                        'No',
                                                        'Available',
                                                        'Searching',
                                                      ],
                                                      onChanged: (value) {
                                                        setDialogState(() {
                                                          commercialSpace =
                                                              value ?? 'No';
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: _professionalField(
                                                      controller:
                                                          experienceController,
                                                      label:
                                                          'Previous Experience',
                                                      hint: 'Example: 3 Years',
                                                      icon: Icons.work_outline,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalField(
                                                controller: locationController,
                                                label:
                                                    'Preferred Franchise Location',
                                                hint:
                                                    'Enter preferred location',
                                                icon: Icons.place_outlined,
                                              ),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              _professionalDropdown(
                                                label: 'Investment Budget',
                                                value: budget,
                                                items: const [
                                                  '',
                                                  '2-5 Lakh',
                                                  '5-8 Lakh',
                                                  '8-10 Lakh',
                                                  '10-15 Lakh',
                                                  '15-20 Lakh',
                                                  '20-25 Lakh',
                                                  '25+ Lakh',
                                                ],
                                                onChanged: (value) {
                                                  setDialogState(() {
                                                    budget = value ?? '';
                                                  });
                                                },
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalDropdown(
                                                label: 'Existing Business',
                                                value: existingBusiness,
                                                items: const ['No', 'Yes'],
                                                onChanged: (value) {
                                                  setDialogState(() {
                                                    existingBusiness =
                                                        value ?? 'No';
                                                  });
                                                },
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalDropdown(
                                                label: 'Commercial Space',
                                                value: commercialSpace,
                                                items: const [
                                                  'No',
                                                  'Available',
                                                  'Searching',
                                                ],
                                                onChanged: (value) {
                                                  setDialogState(() {
                                                    commercialSpace =
                                                        value ?? 'No';
                                                  });
                                                },
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalField(
                                                controller:
                                                    experienceController,
                                                label: 'Previous Experience',
                                                hint: 'Example: 3 Years',
                                                icon: Icons.work_outline,
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalField(
                                                controller: locationController,
                                                label:
                                                    'Preferred Franchise Location',
                                                hint:
                                                    'Enter preferred location',
                                                icon: Icons.place_outlined,
                                              ),
                                            ],
                                          ),
                                  ),

                                  const SizedBox(height: 18),

                                  _leadFormSection(
                                    title: 'Lead Management',
                                    subtitle:
                                        'Lead qualification, status and follow-up assignment',
                                    icon: Icons.track_changes_outlined,
                                    child: twoColumns
                                        ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  children: [
                                                    _professionalDropdown(
                                                      label: 'Lead Score',
                                                      value: score,
                                                      items: const [
                                                        'Hot',
                                                        'Warm',
                                                        'Cold',
                                                      ],
                                                      onChanged: (value) {
                                                        setDialogState(() {
                                                          score =
                                                              value ?? 'Warm';
                                                        });
                                                      },
                                                    ),
                                                    const SizedBox(height: 14),
                                                    _professionalDropdown(
                                                      label: 'Lead Status',
                                                      value: status,
                                                      items: const [
                                                        'New Lead',
                                                        'Contacted',
                                                        'Follow-up 1',
                                                        'Follow-up 2',
                                                        'Follow-up Required',
                                                        'Interested',
                                                        'Hot Lead',
                                                        'Site Visit Scheduled',
                                                        'Site Visit Completed',
                                                        'Agreement Pending',
                                                        'Franchise Confirmed',
                                                        'Converted',
                                                        'Not Interested',
                                                        'Lost',
                                                      ],
                                                      onChanged: (value) {
                                                        setDialogState(() {
                                                          status =
                                                              value ??
                                                              'New Lead';
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  children: [
                                                    _professionalDropdown(
                                                      label:
                                                          'Assigned Executive',
                                                      value: executive,
                                                      items: const [
                                                        '',
                                                        'Aman Verma',
                                                        'Riya Sharma',
                                                        'Neha Patel',
                                                      ],
                                                      onChanged: (value) {
                                                        setDialogState(() {
                                                          executive =
                                                              value ?? '';
                                                        });
                                                      },
                                                    ),
                                                    const SizedBox(height: 14),
                                                    _professionalField(
                                                      controller:
                                                          followupController,
                                                      label: 'Next Follow-up',
                                                      hint:
                                                          'Select Follow-up Date',
                                                      icon: Icons
                                                          .calendar_today_outlined,
                                                      readOnly: true,
                                                      onTap: () {
                                                        _pickFollowupDate(
                                                          followupController,
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              _professionalDropdown(
                                                label: 'Lead Score',
                                                value: score,
                                                items: const [
                                                  'Hot',
                                                  'Warm',
                                                  'Cold',
                                                ],
                                                onChanged: (value) {
                                                  setDialogState(() {
                                                    score = value ?? 'Warm';
                                                  });
                                                },
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalDropdown(
                                                label: 'Lead Status',
                                                value: status,
                                                items: const [
                                                  'New Lead',
                                                  'Contacted',
                                                  'Follow-up 1',
                                                  'Follow-up 2',
                                                  'Follow-up Required',
                                                  'Interested',
                                                  'Hot Lead',
                                                  'Site Visit Scheduled',
                                                  'Site Visit Completed',
                                                  'Agreement Pending',
                                                  'Franchise Confirmed',
                                                  'Converted',
                                                  'Not Interested',
                                                  'Lost',
                                                ],
                                                onChanged: (value) {
                                                  setDialogState(() {
                                                    status =
                                                        value ?? 'New Lead';
                                                  });
                                                },
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalDropdown(
                                                label: 'Assigned Executive',
                                                value: executive,
                                                items: const [
                                                  '',
                                                  'Aman Verma',
                                                  'Riya Sharma',
                                                  'Neha Patel',
                                                ],
                                                onChanged: (value) {
                                                  setDialogState(() {
                                                    executive = value ?? '';
                                                  });
                                                },
                                              ),
                                              const SizedBox(height: 14),
                                              _professionalField(
                                                controller: followupController,
                                                label: 'Next Follow-up',
                                                hint: 'Select Follow-up Date',
                                                icon: Icons
                                                    .calendar_today_outlined,
                                                readOnly: true,
                                                onTap: () => _pickFollowupDate(
                                                  followupController,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      // FOOTER
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 15,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(18),
                          ),
                          border: Border(
                            top: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 95,
                              height: 44,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  maximumSize: const Size(95, 44),
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: const Text('Cancel'),
                              ),
                            ),

                            const SizedBox(width: 10),

                            SizedBox(
                              width: 145,
                              height: 44,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  maximumSize: const Size(145, 44),
                                ),
                                onPressed: () async {
                                  final name = nameController.text.trim();

                                  final phone = phoneController.text.trim();

                                  final city = cityController.text.trim();

                                  if (name.isEmpty) {
                                    AppToast.error(
                                      context,
                                      'Full name is required.',
                                      title: 'Validation Error',
                                    );
                                    return;
                                  }

                                  if (phone.length < 10) {
                                    AppToast.error(
                                      context,
                                      'Please enter a valid mobile number.',
                                      title: 'Invalid Mobile',
                                    );
                                    return;
                                  }

                                  if (city.isEmpty) {
                                    AppToast.error(
                                      context,
                                      'City is required.',
                                      title: 'Validation Error',
                                    );
                                    return;
                                  }

                                  print(
                                    "FOLLOWUP CONTROLLER = ${followupController.text}",
                                  );
                                  final data = <String, dynamic>{
                                    'name': name,
                                    'phone': phone,

                                    'city': city,

                                    'district': districtController.text.trim(),

                                    'budget': budget,

                                    'existingBusiness': existingBusiness,

                                    'commercialSpace': commercialSpace,

                                    'experience': experienceController.text
                                        .trim(),

                                    'location': locationController.text.trim(),

                                    'score': score,

                                    'status': status,

                                    'executive': executive,

                                    'followup': followupController.text.trim(),

                                    'source': lead?['source'] ?? '',

                                    'notes': lead?['notes'] ?? '',
                                  };

                                  Map<String, dynamic> result;

                                  if (editing) {
                                    result = await _leadService.updateLead(
                                      lead['id'],
                                      data,
                                    );
                                  } else {
                                    result = await _leadService.createLead(
                                      data,
                                    );
                                  }

                                  if (result['success'] == true) {
                                    saved = true;

                                    if (context.mounted) {
                                      Navigator.pop(dialogContext);
                                    }

                                    await _loadLeads();
                                  } else {
                                    AppToast.error(
                                      context,
                                      result['message'] ??
                                          'Unable to save lead.',
                                      title: editing
                                          ? 'Update Failed'
                                          : 'Create Failed',
                                    );
                                  }
                                },

                                icon: const Icon(Icons.save_outlined, size: 18),
                                label: Text(
                                  editing ? 'Update Lead' : 'Save Lead',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved && mounted) {
      AppToast.success(
        context,
        editing
            ? '${nameController.text.trim()} updated successfully.'
            : '${nameController.text.trim()} added successfully.',
        title: editing ? 'Lead Updated' : 'Lead Added',
      );
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      nameController.dispose();
      phoneController.dispose();
      cityController.dispose();
      districtController.dispose();
      experienceController.dispose();
      locationController.dispose();
      followupController.dispose();
    });
  }

  Widget _professionalField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool requiredField = false,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: requiredField ? "$label *" : label,

        hintText: hint,

        prefixIcon: Icon(icon),

        floatingLabelBehavior: FloatingLabelBehavior.always,

        filled: true,
        fillColor: const Color(0xFFF8FAFC),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
        ),
      ),
    );
  }

  Future<void> _pickFollowupDate(TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      if (text.contains('/')) {
        final p = text.split('/');
        if (p.length == 3) {
          final d = int.tryParse(p[0]);
          final m = int.tryParse(p[1]);
          final y = int.tryParse(p[2]);
          if (d != null && m != null && y != null) {
            initialDate = DateTime(y, m, d);
          }
        }
      } else {
        final parsed = DateTime.tryParse(text);
        if (parsed != null) initialDate = parsed;
      }
    }
    final firstDate = initialDate.isBefore(DateTime(2020))
        ? initialDate
        : DateTime(2020);
    final lastDate = DateTime(2035);
    final safeInitial = initialDate.isBefore(firstDate)
        ? firstDate
        : (initialDate.isAfter(lastDate) ? lastDate : initialDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Follow-up Date',
    );

    if (picked != null) {
      controller.text =
          "${picked.day.toString().padLeft(2, '0')}/"
          "${picked.month.toString().padLeft(2, '0')}/"
          "${picked.year}";
    }
  }
  // =========================================================
  // PROFESSIONAL FORM HELPERS
  // =========================================================

  Widget _leadFormSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF0284C7)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
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
          ),

          const SizedBox(height: 18),

          child,
        ],
      ),
    );
  }

  Widget _professionalDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // 1. Ensure distinct non-null strings
    final List<String> effectiveItems = items.toSet().toList();

    // 2. If current value is not empty and not in the items list, insert it at the top
    // so DropdownButton never crashes with an assertion failure
    if (value.isNotEmpty && !effectiveItems.contains(value)) {
      effectiveItems.insert(0, value);
    } else if (value.isEmpty && !effectiveItems.contains('')) {
      effectiveItems.insert(0, '');
    }

    final safeValue = effectiveItems.contains(value)
        ? value
        : (effectiveItems.isNotEmpty ? effectiveItems.first : null);

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
        ),
      ),
      items: effectiveItems.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item.isEmpty ? 'Select' : item,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  // =========================================================
  // VIEW
  // =========================================================

  Future<void> _viewLead(Map<String, dynamic> lead) async {
    final leadId = int.tryParse(lead['id']?.toString() ?? '');

    if (leadId == null) {
      return;
    }

    final activities = await _loadLeadActivities(leadId);

    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(context).size.width;

        final mobile = screenWidth < 700;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: mobile ? 14 : 40,
            vertical: mobile ? 18 : 30,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ===============================
                  // HEADER
                  // ===============================
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lead Details',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Lead information and complete activity history',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          tooltip: 'Close',
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ===============================
                  // BODY
                  // ===============================
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(mobile ? 16 : 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // PROFILE
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                _avatar('${lead['name']}', large: true),

                                const SizedBox(width: 14),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${lead['name']}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${lead['phone']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                _scoreBadge('${lead['score']}'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // DETAILS
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: Color(0xFF0284C7),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Lead Information',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                _detailGrid(lead),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // ACTIVITY TIMELINE
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.history_rounded,
                                        size: 18,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Activity Timeline',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Calls, WhatsApp, notes, meetings and documents',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 18),

                                if (activities.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 25,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'No activity found.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  )
                                else
                                  ...List.generate(activities.length, (index) {
                                    return _activityTimelineItem(
                                      activities[index],
                                      isLast: index == activities.length - 1,
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ===============================
                  // FOOTER
                  // ===============================
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showUpdateLeadCrmDialog(lead);
                          },
                          icon: const Icon(
                            Icons.published_with_changes_rounded,
                            size: 18,
                          ),
                          label: const Text('Update Status & CRM'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: dialogContext,
                              builder: (c) => AlertDialog(
                                title: const Text('Convert to Customer'),
                                content: Text(
                                  'Convert ${lead['name']} to an active customer? This will link their profile and mark the lead as Converted.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Confirm Conversion'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final res = await _leadService.convertLead(
                                lead['id'] as int,
                                'convert_to_customer',
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (res['success'] == true) {
                                await _loadLeads();
                                if (mounted) {
                                  AppToast.success(
                                    context,
                                    'Lead successfully converted to Customer!',
                                    title: 'Converted',
                                  );
                                }
                              } else {
                                if (mounted) {
                                  AppToast.error(
                                    context,
                                    res['message'] ?? 'Failed to convert lead',
                                    title: 'Error',
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 18,
                          ),
                          label: const Text('Convert to Customer'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: dialogContext,
                              builder: (c) => AlertDialog(
                                title: const Text('Start Franchise Onboarding'),
                                content: Text(
                                  'Start official franchise onboarding for ${lead['name']}? Status will move to Agreement Pending and onboarding will initialize.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C3AED),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Start Onboarding'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final res = await _leadService.convertLead(
                                lead['id'] as int,
                                'start_franchise_onboarding',
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (res['success'] == true) {
                                await _loadLeads();
                                if (mounted) {
                                  AppToast.success(
                                    context,
                                    'Franchise onboarding started successfully!',
                                    title: 'Onboarding',
                                  );
                                }
                              } else {
                                if (mounted) {
                                  AppToast.error(
                                    context,
                                    res['message'] ??
                                        'Failed to start onboarding',
                                    title: 'Error',
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.storefront_rounded, size: 18),
                          label: const Text('Start Franchise Onboarding'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showScheduleFollowupDialog(lead);
                          },
                          icon: const Icon(Icons.add_alarm_rounded, size: 18),
                          label: const Text('+ Schedule Follow-up'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            ContactActionHelper.makePhoneCall(context, '${lead['phone']}');
                          },
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: const Text('Call Lead'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            final phone = '${lead['phone']}';
                            final name = '${lead['name']}';
                            ContactActionHelper.openMessagingChooser(
                              context,
                              phone: phone,
                              contactName: name,
                              defaultMessage: WhatsAppService.getWelcomeMessage(leadName: name),
                            );
                          },
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('Chat / Message'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _activityTimelineItem(
    Map<String, dynamic> activity, {
    required bool isLast,
  }) {
    final type = activity['type'].toString();

    IconData icon;
    Color color;
    Color background;

    switch (type) {
      case 'call':
        icon = Icons.call_outlined;
        color = const Color(0xFF2563EB);
        background = const Color(0xFFEFF6FF);
        break;

      case 'whatsapp':
        icon = Icons.chat_outlined;
        color = const Color(0xFF16A34A);
        background = const Color(0xFFF0FDF4);
        break;

      case 'meeting':
        icon = Icons.calendar_month_outlined;
        color = const Color(0xFF7C3AED);
        background = const Color(0xFFF5F3FF);
        break;

      case 'document':
        icon = Icons.description_outlined;
        color = const Color(0xFFEA580C);
        background = const Color(0xFFFFF7ED);
        break;

      default:
        icon = Icons.note_alt_outlined;
        color = const Color(0xFF475569);
        background = const Color(0xFFF1F5F9);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: color),
              ),

              if (!isLast)
                Container(
                  width: 1.5,
                  height: 58,
                  color: const Color(0xFFE2E8F0),
                ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity['title'].toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Text(
                        activity['date'].toString(),
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    activity['description'].toString(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      height: 1.45,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailGrid(Map<String, dynamic> lead) {
    final details = [
      ['Source', (lead['source'] == 'PUBLIC_CHATBOT' ? '🤖 PUBLIC CHATBOT' : '${lead['source'] ?? '-'}')],
      ['Email', '${lead['email'] ?? '-'}'],
      ['Inquiry Notes / Intent', '${lead['notes'] ?? '-'}'],
      ['City', '${lead['city'] ?? '-'}'],
      ['District', '${lead['district'] ?? '-'}'],
      ['Investment', '₹${lead['budget'] ?? '-'}'],
      ['Existing Business', '${lead['existingBusiness'] ?? '-'}'],
      ['Commercial Space', '${lead['commercialSpace'] ?? '-'}'],
      ['Experience', '${lead['experience'] ?? '-'}'],
      ['Preferred Location', '${lead['location'] ?? '-'}'],
      ['Executive', '${lead['executive'] ?? '-'}'],
      ['Status', '${lead['status'] ?? '-'}'],
      ['Created At', '${lead['created_at'] ?? '-'}'],
      ['Next Follow-up', '${lead['followup'] ?? '-'}'],
      ['Site Visit Planned', lead['site_visit_planned'] == true ? 'Yes' : 'No'],
      [
        'Site Visit Completed',
        lead['site_visit_completed'] == true ? 'Yes' : 'No',
      ],
      if ((lead['site_visit_date'] ?? '').toString().isNotEmpty)
        ['Site Visit Date', '${lead['site_visit_date']}'],
      if ((lead['site_visit_notes'] ?? '').toString().isNotEmpty)
        ['Site Visit Notes', '${lead['site_visit_notes']}'],
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: details.map((item) {
        return Container(
          width: 245,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item[0],
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 4),
              Text(
                item[1],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> _deleteLead(Map<String, dynamic> lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Lead?'),
          content: Text(
            'Are you sure you want to delete '
            '${lead['name']}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final id = lead['id'];

    if (id == null) {
      return;
    }

    final result = await _leadService.deleteLead(id as int);

    if (!mounted) {
      return;
    }

    if (result['success'] == true) {
      AppToast.success(
        context,
        '${lead['name']} deleted successfully.',
        title: 'Lead Deleted',
      );

      await _loadLeads();
    } else {
      AppToast.error(
        context,
        result['message'] ?? 'Unable to delete lead.',
        title: 'Delete Failed',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadLeadActivities(int leadId) async {
    final result = await _leadService.getActivities(leadId);

    if (result['success'] != true) {
      return [];
    }

    final response = result['data'];

    final List<dynamic> raw = response['activities'] ?? [];

    return raw.map((item) {
      final map = Map<String, dynamic>.from(item);

      return {
        'id': map['id'],

        'type': map['activity_type']?.toString() ?? 'note',

        'title': map['title']?.toString() ?? '',

        'description': map['description']?.toString() ?? '',

        'date': _formatActivityDate(map['created_at']),
      };
    }).toList();
  }

  String _formatActivityDate(dynamic value) {
    if (value == null) {
      return '';
    }

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      final hour = date.hour > 12
          ? date.hour - 12
          : date.hour == 0
          ? 12
          : date.hour;

      final minute = date.minute.toString().padLeft(2, '0');

      final amPm = date.hour >= 12 ? 'PM' : 'AM';

      return '${date.day.toString().padLeft(2, '0')} '
          '${months[date.month]} '
          '${date.year} • '
          '$hour:$minute $amPm';
    } catch (_) {
      return value.toString();
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  Widget _avatar(String name, {bool large = false}) {
    final words = name
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    String initials = '';

    for (final word in words.take(2)) {
      initials += word[0].toUpperCase();
    }

    return CircleAvatar(
      radius: large ? 28 : 19,
      backgroundColor: const Color(0xFFE0F2FE),
      child: Text(
        initials,
        style: TextStyle(
          color: const Color(0xFF0284C7),
          fontSize: large ? 16 : 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _scoreBadge(String score) {
    Color bg;
    Color fg;

    if (score == 'Hot') {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
    } else if (score == 'Warm') {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C);
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        score,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Color(0xFF0284C7),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 16,
          color: danger ? Colors.red : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _LeadStatCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _LeadStatCard({required this.title, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: card,
        ),
      );
    }
    return card;
  }
}

const TextStyle _leadHeaderStyle = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
  letterSpacing: 0.3,
);
