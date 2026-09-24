import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/followup_service.dart';
import '../../../core/utils/contact_action_helper.dart';

class CompletedFollowupsScreen extends StatefulWidget {
  const CompletedFollowupsScreen({super.key});

  @override
  State<CompletedFollowupsScreen> createState() => _CompletedFollowupsScreenState();
}

class _CompletedFollowupsScreenState extends State<CompletedFollowupsScreen> {
  final FollowupService _followupService = FollowupService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _completedList = [];
  String _activePeriod = 'today'; // today, yesterday, this_week, this_month, custom
  String _searchQuery = '';
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    String? startStr;
    String? endStr;
    if (_activePeriod == 'custom' && _customDateRange != null) {
      startStr = DateFormat('yyyy-MM-dd').format(_customDateRange!.start);
      endStr = DateFormat('yyyy-MM-dd').format(_customDateRange!.end);
    }

    final res = await _followupService.getCompletedFollowups(
      period: _activePeriod,
      search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
      startDate: startStr,
      endDate: endStr,
    );

    if (mounted) {
      if (res['success'] == true) {
        final dynamic raw = res['data'] is Map ? (res['data']['followups'] ?? res['data']) : res['data'];
        if (raw is List) {
          _completedList = List<Map<String, dynamic>>.from(
            raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          );
        } else {
          _completedList = [];
        }
      } else {
        _completedList = [];
      }
      setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(dynamic val) {
    if (val == null || val.toString().isEmpty) return '-';
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return val.toString();
    }
  }

  String _formatDate(dynamic val) {
    if (val == null || val.toString().isEmpty) return '-';
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return val.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Completed Follow-ups',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: Column(
            children: [
              // Search & Filter Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search lead, phone, city, notes...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                        _loadData();
                      },
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('Today', 'today'),
                          const SizedBox(width: 8),
                          _filterChip('Yesterday', 'yesterday'),
                          const SizedBox(width: 8),
                          _filterChip('This Week', 'this_week'),
                          const SizedBox(width: 8),
                          _filterChip('This Month', 'this_month'),
                          const SizedBox(width: 8),
                          _filterChip(
                            _customDateRange != null
                                ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}'
                                : 'Custom Range',
                            'custom',
                            isCustom: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Summary Count Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF1F5F9),
                child: Text(
                  '${_completedList.length} completed records found',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),

              // Content List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _completedList.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_turned_in_outlined, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No completed follow-ups found',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Try selecting a different filter range or keyword.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _completedList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, index) {
                              final item = _completedList[index];
                              return _buildCompletedCard(item);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String period, {bool isCustom = false}) {
    final isSelected = _activePeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) async {
        if (!selected && !isCustom) return;
        if (isCustom) {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2023),
            lastDate: DateTime(2030),
            initialDateRange: _customDateRange ??
                DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 7)),
                  end: DateTime.now(),
                ),
          );
          if (picked != null) {
            setState(() {
              _customDateRange = picked;
              _activePeriod = 'custom';
            });
            _loadData();
          }
        } else {
          setState(() => _activePeriod = period);
          _loadData();
        }
      },
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }

  Widget _buildCompletedCard(Map<String, dynamic> item) {
    final leadName = item['lead_name'] ?? item['lead'] ?? 'Lead #${item['lead_id'] ?? ''}';
    final customerOrFranchise = item['customer_or_franchise'] ?? item['lead_type'] ?? 'Franchise';
    final phone = item['lead_phone'] ?? item['phone'] ?? '';
    final followupDate = item['followup_datetime'] ?? item['date'];
    final completedAt = item['completed_at'];
    final completedByName = item['completed_by_name'] ?? 'Admin';
    final assignedExecutive = item['assigned_to_name'] ?? item['executive'] ?? '-';
    final outcomeNotes = item['outcome_notes'] ?? item['outcome'] ?? item['note'] ?? 'Marked as completed';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Lead Name & Status Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leadName.toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            customerOrFranchise.toString().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ),
                        if (phone.toString().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            phone.toString(),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      'COMPLETED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Row 2: Dates & Assigned Details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scheduled Date', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(followupDate),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Completed At', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(completedAt),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Completed By: ',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    children: [
                      TextSpan(
                        text: completedByName.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Assigned: ',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    children: [
                      TextSpan(
                        text: assignedExecutive.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 3: Outcome / Notes
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Outcome / Notes:',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 3),
                Text(
                  outcomeNotes.toString(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),

          // Row 4: Call & Chat Actions
          if (phone.toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 34),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF2563EB)),
                  label: const Text('Call', style: TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                  onPressed: () => ContactActionHelper.makePhoneCall(context, phone.toString()),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 34),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 15, color: Color(0xFF16A34A)),
                  label: const Text('Chat', style: TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                  onPressed: () => ContactActionHelper.openMessagingChooser(
                    context,
                    phone: phone.toString(),
                    contactName: leadName.toString(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
