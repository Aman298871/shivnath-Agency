import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() =>
      _AdminReportsScreenState();
}

class _AdminReportsScreenState
    extends State<AdminReportsScreen> {
  String period = 'This Month';

  final List<Map<String, dynamic>> monthlySales = [
    {
      'month': 'Apr',
      'amount': 145000,
    },
    {
      'month': 'May',
      'amount': 178000,
    },
    {
      'month': 'Jun',
      'amount': 210000,
    },
    {
      'month': 'Jul',
      'amount': 235000,
    },
    {
      'month': 'Aug',
      'amount': 278000,
    },
    {
      'month': 'Sep',
      'amount': 315000,
    },
  ];

  final List<Map<String, dynamic>> cities = [
    {
      'city': 'Raipur',
      'franchises': 8,
      'sales': 425000,
    },
    {
      'city': 'Bhilai',
      'franchises': 5,
      'sales': 286000,
    },
    {
      'city': 'Bilaspur',
      'franchises': 4,
      'sales': 232000,
    },
    {
      'city': 'Durg',
      'franchises': 4,
      'sales': 198000,
    },
    {
      'city': 'Rajnandgaon',
      'franchises': 3,
      'sales': 147000,
    },
  ];

  final List<Map<String, dynamic>> executives = [
    {
      'name': 'Aman Verma',
      'leads': 84,
      'followups': 52,
      'confirmed': 12,
      'sales': 480000,
      'conversion': 14.3,
    },
    {
      'name': 'Riya Sharma',
      'leads': 72,
      'followups': 46,
      'confirmed': 9,
      'sales': 365000,
      'conversion': 12.5,
    },
    {
      'name': 'Neha Patel',
      'leads': 58,
      'followups': 38,
      'confirmed': 7,
      'sales': 295000,
      'conversion': 12.1,
    },
  ];

  final List<Map<String, dynamic>> productSales = [
    {
      'product': '250ml Water Bottle',
      'quantity': 1280,
      'revenue': 64000,
    },
    {
      'product': '500ml Water Bottle',
      'quantity': 2150,
      'revenue': 215000,
    },
    {
      'product': '1 Litre Water Bottle',
      'quantity': 1480,
      'revenue': 296000,
    },
    {
      'product': '2 Litre Water Bottle',
      'quantity': 760,
      'revenue': 266000,
    },
    {
      'product': '5 Litre Water Jar',
      'quantity': 420,
      'revenue': 315000,
    },
    {
      'product': '20 Litre Water Jar',
      'quantity': 290,
      'revenue': 348000,
    },
  ];

  final List<Map<String, dynamic>> franchisePerformance = [
    {
      'name': 'Rahul Sharma',
      'city': 'Raipur',
      'orders': 28,
      'sales': 285000,
      'outstanding': 22000,
      'status': 'Excellent',
    },
    {
      'name': 'Aqua Point',
      'city': 'Bhilai',
      'orders': 22,
      'sales': 218000,
      'outstanding': 17996,
      'status': 'Good',
    },
    {
      'name': 'Shiv Water',
      'city': 'Bilaspur',
      'orders': 19,
      'sales': 184000,
      'outstanding': 0,
      'status': 'Good',
    },
    {
      'name': 'Pure Aqua Agency',
      'city': 'Durg',
      'orders': 14,
      'sales': 126000,
      'outstanding': 46504,
      'status': 'Average',
    },
  ];

  // =========================================================
  // REPORT VALUES
  // =========================================================

  int get totalRevenue {
    return monthlySales.fold<int>(
      0,
      (sum, item) =>
          sum +
          ((item['amount'] as num).toInt()),
    );
  }

  int get productRevenue {
    return productSales.fold<int>(
      0,
      (sum, item) =>
          sum +
          ((item['revenue'] as num).toInt()),
    );
  }

  int get totalExecutiveSales {
    return executives.fold<int>(
      0,
      (sum, item) =>
          sum +
          ((item['sales'] as num).toInt()),
    );
  }

  int get totalFranchises {
    return cities.fold<int>(
      0,
      (sum, item) =>
          sum +
          ((item['franchises'] as num).toInt()),
    );
  }

  int get franchiseSales {
    return franchisePerformance.fold<int>(
      0,
      (sum, item) =>
          sum +
          ((item['sales'] as num).toInt()),
    );
  }

  int get franchiseOutstanding {
    return franchisePerformance.fold<int>(
      0,
      (sum, item) =>
          sum +
          ((item['outstanding'] as num).toInt()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= 900;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5F7FB),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              desktop ? 28 : 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1400,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _header(desktop),

                    const SizedBox(height: 22),

                    _summaryCards(desktop),

                    const SizedBox(height: 20),

                    _monthlySalesCard(),

                    const SizedBox(height: 20),

                    if (desktop)
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child:
                                _cityReport(),
                          ),
                          const SizedBox(
                            width: 18,
                          ),
                          Expanded(
                            child:
                                _revenueAnalysis(),
                          ),
                        ],
                      )
                    else ...[
                      _cityReport(),
                      const SizedBox(height: 16),
                      _revenueAnalysis(),
                    ],

                    const SizedBox(height: 20),

                    _executivePerformance(),

                    const SizedBox(height: 20),

                    _productSalesReport(),

                    const SizedBox(height: 20),

                    _franchisePerformance(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _header(bool desktop) {
    if (!desktop) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports & Analytics',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Business performance, sales, lead, franchise and inventory analytics.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 14),

          _periodDropdown(),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize:
                    const Size(0, 44),
              ),
              onPressed: _exportReport,
              icon: const Icon(
                Icons.download_outlined,
              ),
              label:
                  const Text('Export Report'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Reports & Analytics',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF111827),
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Business performance, sales, lead, franchise and inventory analytics.',
                style: TextStyle(
                  color:
                      Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          width: 180,
          child: _periodDropdown(),
        ),

        const SizedBox(width: 12),

        SizedBox(
          width: 155,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize:
                  const Size(0, 44),
              maximumSize:
                  const Size(155, 44),
            ),
            onPressed: _exportReport,
            icon: const Icon(
              Icons.download_outlined,
            ),
            label:
                const Text('Export Report'),
          ),
        ),
      ],
    );
  }

  Widget _periodDropdown() {
    return DropdownButtonFormField<String>(
      value: period,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
        ),
      ),
      items: const [
        'This Month',
        'Last Month',
        'Last 3 Months',
        'This Year',
      ].map(
        (value) {
          return DropdownMenuItem(
            value: value,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
              ),
            ),
          );
        },
      ).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          period = value;
        });
      },
    );
  }

  // =========================================================
  // SUMMARY CARDS
  // =========================================================

  Widget _summaryCards(bool desktop) {
    final data = [
      {
        'title': 'Today\'s Leads',
        'value': '24',
        'subtitle': '+8 from yesterday',
        'icon': Icons.people_outline,
      },
      {
        'title': 'Conversion Rate',
        'value': '11.8%',
        'subtitle': 'Lead to franchise',
        'icon':
            Icons.trending_up_outlined,
      },
      {
        'title': 'Cost Per Lead',
        'value': '₹186',
        'subtitle': 'Marketing cost / leads',
        'icon':
            Icons.ads_click_outlined,
      },
      {
        'title': 'Pending Follow-ups',
        'value': '18',
        'subtitle': 'Need attention',
        'icon':
            Icons.schedule_outlined,
      },
      {
        'title': 'Monthly Sales',
        'value': '₹3.15L',
        'subtitle': 'September',
        'icon':
            Icons.currency_rupee,
      },
      {
        'title': 'Inventory Value',
        'value': '₹4.72L',
        'subtitle': 'Current stock value',
        'icon':
            Icons.inventory_2_outlined,
      },
      {
        'title':
            'Outstanding Payments',
        'value': '₹86,500',
        'subtitle':
            'Pending collection',
        'icon':
            Icons.account_balance_wallet_outlined,
      },
      {
        'title': 'Total Revenue',
        'value':
            _compactCurrency(totalRevenue),
        'subtitle': 'Revenue analysis',
        'icon':
            Icons.analytics_outlined,
      },
    ];

    if (!desktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics:
            const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.08,
        ),
        itemBuilder: (_, index) {
          return _statCard(
            data[index],
          );
        },
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: data.map(
        (item) {
          return SizedBox(
            width: 320,
            child: _statCard(item),
          );
        },
      ).toList(),
    );
  }

  Widget _statCard(
    Map<String, dynamic> item,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFE0F2FE),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              item['icon'] as IconData,
              color:
                  const Color(0xFF0284C7),
              size: 20,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color:
                        Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item['value'].toString(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['subtitle']
                      .toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color:
                        Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MONTHLY SALES
  // =========================================================

  Widget _monthlySalesCard() {
    final maxValue = monthlySales.fold<int>(
      0,
      (max, item) {
        final value =
            (item['amount'] as num).toInt();

        return value > max
            ? value
            : max;
      },
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.bar_chart_rounded,
            'Monthly Sales',
            'Month-wise sales performance',
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 230,
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: monthlySales.map(
                (item) {
                  final amount =
                      (item['amount']
                              as num)
                          .toInt();

                  final ratio =
                      maxValue == 0
                          ? 0.0
                          : amount /
                              maxValue;

                  return Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 7,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .end,
                        children: [
                          Text(
                            _compactCurrency(
                              amount,
                            ),
                            style:
                                const TextStyle(
                              fontSize: 8,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          Container(
                            width:
                                double.infinity,
                            height:
                                155 *
                                    ratio,
                            constraints:
                                const BoxConstraints(
                              minHeight: 8,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFF0284C7,
                              ),
                              borderRadius:
                                  const BorderRadius
                                      .vertical(
                                top: Radius
                                    .circular(
                                  7,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          Text(
                            item['month']
                                .toString(),
                            style:
                                const TextStyle(
                              fontSize: 10,
                              color:
                                  Color(
                                0xFF64748B,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CITY REPORT
  // =========================================================

  Widget _cityReport() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.location_city_outlined,
            'City-wise Franchise Distribution',
            'Franchise network by city',
          ),

          const SizedBox(height: 18),

          ...cities.map(
            (item) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                decoration:
                    const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          Color(
                        0xFFF1F5F9,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['city']
                            .toString(),
                        style:
                            const TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),
                    ),
                    Text(
                      '${item['franchises']} Franchise',
                      style:
                          const TextStyle(
                        fontSize: 9,
                        color:
                            Color(
                          0xFF64748B,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 15,
                    ),
                    SizedBox(
                      width: 75,
                      child: Text(
                        _compactCurrency(
                          (item['sales']
                                  as num)
                              .toInt(),
                        ),
                        textAlign:
                            TextAlign.right,
                        style:
                            const TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================
  // REVENUE ANALYSIS
  // =========================================================

  Widget _revenueAnalysis() {
    final latestMonth =
        (monthlySales.last['amount']
                as num)
            .toInt();

    final previousMonth =
        (monthlySales[
                    monthlySales.length -
                        2]['amount']
                as num)
            .toInt();

    final growth =
        previousMonth == 0
            ? 0.0
            : ((latestMonth -
                        previousMonth) /
                    previousMonth) *
                100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.insights_outlined,
            'Revenue Analysis',
            'Overall revenue performance',
          ),

          const SizedBox(height: 20),

          _analysisRow(
            'Total Revenue',
            _currency(totalRevenue),
          ),

          _analysisRow(
            'Current Month',
            _currency(latestMonth),
          ),

          _analysisRow(
            'Previous Month',
            _currency(previousMonth),
          ),

          _analysisRow(
            'Monthly Growth',
            '${growth.toStringAsFixed(1)}%',
          ),

          _analysisRow(
            'Product Revenue',
            _currency(productRevenue),
          ),

          _analysisRow(
            'Executive Sales',
            _currency(totalExecutiveSales),
          ),
        ],
      ),
    );
  }

  Widget _analysisRow(
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color:
                    Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EXECUTIVE PERFORMANCE
  // =========================================================

  Widget _executivePerformance() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.all(20),
            child: _sectionTitle(
              Icons.groups_outlined,
              'Sales Executive Performance',
              'Executive-wise leads, conversion and sales',
            ),
          ),

          const Divider(height: 1),

          SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            child: SizedBox(
              width: 1050,
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color:
                        const Color(
                      0xFFF8FAFC,
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'EXECUTIVE',
                            style:
                                _reportHeader,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'LEADS',
                            style:
                                _reportHeader,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'FOLLOW-UPS',
                            style:
                                _reportHeader,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'CONFIRMED',
                            style:
                                _reportHeader,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'CONVERSION',
                            style:
                                _reportHeader,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'SALES',
                            style:
                                _reportHeader,
                          ),
                        ),
                      ],
                    ),
                  ),

                  ...executives.map(
                    (item) =>
                        _executiveRow(
                      item,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _executiveRow(
    Map<String, dynamic> item,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              item['name'].toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item['leads'].toString(),
              style: _reportCell,
            ),
          ),
          Expanded(
            child: Text(
              item['followups']
                  .toString(),
              style: _reportCell,
            ),
          ),
          Expanded(
            child: Text(
              item['confirmed']
                  .toString(),
              style: _reportCell,
            ),
          ),
          Expanded(
            child: Text(
              '${item['conversion']}%',
              style: _reportCell,
            ),
          ),
          Expanded(
            child: Text(
              _currency(
                (item['sales']
                        as num)
                    .toInt(),
              ),
              style: const TextStyle(
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PRODUCT SALES
  // =========================================================

  Widget _productSalesReport() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.all(20),
            child: _sectionTitle(
              Icons.local_drink_outlined,
              'Product-wise Sales',
              'Product quantity and revenue contribution',
            ),
          ),

          const Divider(height: 1),

          ...productSales.map(
            (item) {
              final revenue =
                  (item['revenue']
                          as num)
                      .toInt();

              final percentage =
                  productRevenue == 0
                      ? 0.0
                      : revenue /
                          productRevenue *
                          100;

              return Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  18,
                  14,
                  18,
                  14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item['product']
                            .toString(),
                        style:
                            const TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Text(
                        '${item['quantity']} Qty',
                        style:
                            _reportCell,
                      ),
                    ),

                    Expanded(
                      child: Text(
                        _currency(
                          revenue,
                        ),
                        style:
                            const TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style:
                            _reportCell,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FRANCHISE PERFORMANCE
  // =========================================================

  Widget _franchisePerformance() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.all(20),
            child: _sectionTitle(
              Icons.storefront_outlined,
              'Franchise Performance',
              'Sales, orders and outstanding by franchise',
            ),
          ),

          const Divider(height: 1),

          SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            child: SizedBox(
              width: 1050,
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color:
                        const Color(
                      0xFFF8FAFC,
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'FRANCHISE',
                            style:
                                _reportHeader,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'CITY',
                            style:
                                _reportHeader,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'ORDERS',
                            style:
                                _reportHeader,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'SALES',
                            style:
                                _reportHeader,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'OUTSTANDING',
                            style:
                                _reportHeader,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'PERFORMANCE',
                            style:
                                _reportHeader,
                          ),
                        ),
                      ],
                    ),
                  ),

                  ...franchisePerformance
                      .map(
                    (item) =>
                        _franchiseRow(
                      item,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _franchiseRow(
    Map<String, dynamic> item,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              item['name'].toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item['city'].toString(),
              style: _reportCell,
            ),
          ),
          Expanded(
            child: Text(
              item['orders'].toString(),
              style: _reportCell,
            ),
          ),
          Expanded(
            child: Text(
              _currency(
                (item['sales']
                        as num)
                    .toInt(),
              ),
              style: _reportCell,
            ),
          ),
          Expanded(
            child: Text(
              _currency(
                (item['outstanding']
                        as num)
                    .toInt(),
              ),
              style: TextStyle(
                fontSize: 10,
                color:
                    (item['outstanding']
                                as num)
                            .toInt() >
                        0
                    ? const Color(
                        0xFFDC2626,
                      )
                    : const Color(
                        0xFF15803D,
                      ),
              ),
            ),
          ),
          Expanded(
            child: _performanceBadge(
              item['status'].toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _performanceBadge(
    String status,
  ) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Excellent':
        bg =
            const Color(0xFFECFDF5);
        fg =
            const Color(0xFF15803D);
        break;

      case 'Good':
        bg =
            const Color(0xFFE0F2FE);
        fg =
            const Color(0xFF0284C7);
        break;

      default:
        bg =
            const Color(0xFFFFF7ED);
        fg =
            const Color(0xFFEA580C);
    }

    return Align(
      alignment:
          Alignment.centerLeft,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 8,
            fontWeight:
                FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // ACTUAL CSV EXPORT
  // =========================================================

  Future<void> _exportReport() async {
    try {
      final buffer = StringBuffer();

      buffer.writeln(
        'BUSINESS REPORT - $period',
      );

      buffer.writeln();

      buffer.writeln('SUMMARY');
      buffer.writeln(
        'Metric,Value',
      );
      buffer.writeln(
        'Today Leads,24',
      );
      buffer.writeln(
        'Lead Conversion Rate,11.8%',
      );
      buffer.writeln(
        'Cost Per Lead,186',
      );
      buffer.writeln(
        'Pending Follow-ups,18',
      );
      buffer.writeln(
        'Monthly Sales,315000',
      );
      buffer.writeln(
        'Inventory Value,472000',
      );
      buffer.writeln(
        'Outstanding Payments,86500',
      );
      buffer.writeln(
        'Total Revenue,$totalRevenue',
      );

      buffer.writeln();
      buffer.writeln(
        'MONTHLY SALES',
      );
      buffer.writeln(
        'Month,Amount',
      );

      for (final item
          in monthlySales) {
        buffer.writeln(
          '${item['month']},${item['amount']}',
        );
      }

      buffer.writeln();
      buffer.writeln(
        'CITY-WISE FRANCHISE',
      );
      buffer.writeln(
        'City,Franchises,Sales',
      );

      for (final item in cities) {
        buffer.writeln(
          '${item['city']},${item['franchises']},${item['sales']}',
        );
      }

      buffer.writeln();
      buffer.writeln(
        'EXECUTIVE PERFORMANCE',
      );

      buffer.writeln(
        'Executive,Leads,Follow-ups,Confirmed,Conversion,Sales',
      );

      for (final item
          in executives) {
        buffer.writeln(
          '${item['name']},'
          '${item['leads']},'
          '${item['followups']},'
          '${item['confirmed']},'
          '${item['conversion']}%,'
          '${item['sales']}',
        );
      }

      buffer.writeln();
      buffer.writeln(
        'PRODUCT-WISE SALES',
      );

      buffer.writeln(
        'Product,Quantity,Revenue',
      );

      for (final item
          in productSales) {
        buffer.writeln(
          '"${item['product']}",'
          '${item['quantity']},'
          '${item['revenue']}',
        );
      }

      buffer.writeln();
      buffer.writeln(
        'FRANCHISE PERFORMANCE',
      );

      buffer.writeln(
        'Franchise,City,Orders,Sales,Outstanding,Performance',
      );

      for (final item
          in franchisePerformance) {
        buffer.writeln(
          '"${item['name']}",'
          '${item['city']},'
          '${item['orders']},'
          '${item['sales']},'
          '${item['outstanding']},'
          '${item['status']}',
        );
      }

      final bytes = Uint8List.fromList(
        utf8.encode(
          buffer.toString(),
        ),
      );

      final now = DateTime.now();

      final fileName =
          'business_report_'
          '${now.year}_'
          '${now.month.toString().padLeft(2, '0')}_'
          '${now.day.toString().padLeft(2, '0')}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      if (!mounted) return;

      AppToast.success(
        context,
        '$period report exported successfully.',
        title: 'Report Exported',
      );
    } catch (e) {
      if (!mounted) return;

      AppToast.error(
        context,
        'Unable to export report.',
        title: 'Export Failed',
      );
    }
  }

  // =========================================================
  // COMMON HELPERS
  // =========================================================

  Widget _sectionTitle(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color:
                const Color(0xFFE0F2FE),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 19,
            color:
                const Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF111827),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 9.5,
                  color:
                      Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _currency(int value) {
    final text = value.toString();

    if (text.length <= 3) {
      return '₹$text';
    }

    final lastThree = text.substring(
      text.length - 3,
    );

    String remaining = text.substring(
      0,
      text.length - 3,
    );

    final buffer = StringBuffer();

    while (remaining.length > 2) {
      buffer.write(
        ',${remaining.substring(remaining.length - 2)}',
      );

      remaining = remaining.substring(
        0,
        remaining.length - 2,
      );
    }

    return '₹$remaining'
        '${buffer.toString().split(',').reversed.where((e) => e.isNotEmpty).map((e) => ',$e').join()}'
        ',$lastThree';
  }

  String _compactCurrency(int value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)}Cr';
    }

    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L';
    }

    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }

    return '₹$value';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(14),
      border: Border.all(
        color:
            const Color(0xFFE5E7EB),
      ),
    );
  }
}

const TextStyle _reportHeader =
    TextStyle(
  fontSize: 8.5,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
  letterSpacing: .3,
);

const TextStyle _reportCell =
    TextStyle(
  fontSize: 10,
  color: Color(0xFF475569),
);