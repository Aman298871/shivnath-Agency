import 'package:flutter/material.dart';

class WhatsAppLeadQualificationTab
    extends StatefulWidget {
  const WhatsAppLeadQualificationTab({
    super.key,
  });

  @override
  State<WhatsAppLeadQualificationTab>
      createState() =>
          _WhatsAppLeadQualificationTabState();
}

class _WhatsAppLeadQualificationTabState
    extends State<WhatsAppLeadQualificationTab> {
  String search = '';
  String filter = 'All';

  final searchController =
      TextEditingController();

  final List<Map<String, dynamic>> leads = [
    {
      'id': 1,
      'name': 'Rahul Sharma',
      'mobile': '+91 98765 43210',
      'city': 'Raipur',
      'district': 'Raipur',
      'budget': 1500000,
      'existingBusiness': 'Yes',
      'commercialSpace': 'Available',
      'experience': 'Yes',
      'preferredLocation': 'Raipur',
      'source': 'WhatsApp',
      'score': 88,
    },
    {
      'id': 2,
      'name': 'Amit Verma',
      'mobile': '+91 98261 23456',
      'city': 'Bilaspur',
      'district': 'Bilaspur',
      'budget': 800000,
      'existingBusiness': 'Yes',
      'commercialSpace': 'Not Confirmed',
      'experience': 'No',
      'preferredLocation': 'Bilaspur',
      'source': 'WhatsApp',
      'score': 64,
    },
    {
      'id': 3,
      'name': 'Suresh Patel',
      'mobile': '+91 97555 44556',
      'city': 'Durg',
      'district': 'Durg',
      'budget': 350000,
      'existingBusiness': 'No',
      'commercialSpace': 'No',
      'experience': 'No',
      'preferredLocation': 'Durg',
      'source': 'Facebook',
      'score': 31,
    },
    {
      'id': 4,
      'name': 'Neha Gupta',
      'mobile': '+91 98931 77889',
      'city': 'Bhilai',
      'district': 'Durg',
      'budget': 1200000,
      'existingBusiness': 'Yes',
      'commercialSpace': 'Available',
      'experience': 'Yes',
      'preferredLocation': 'Bhilai',
      'source': 'Website',
      'score': 82,
    },
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String temperature(
    int score,
  ) {
    if (score >= 75) {
      return 'Hot';
    }

    if (score >= 45) {
      return 'Warm';
    }

    return 'Cold';
  }

  List<Map<String, dynamic>>
      get filteredLeads {
    final query =
        search.trim().toLowerCase();

    return leads.where(
      (lead) {
        final temp =
            temperature(
          lead['score'] as int,
        );

        final searchMatch =
            lead['name']
                    .toString()
                    .toLowerCase()
                    .contains(query) ||
                lead['mobile']
                    .toString()
                    .toLowerCase()
                    .contains(query) ||
                lead['city']
                    .toString()
                    .toLowerCase()
                    .contains(query);

        final filterMatch =
            filter == 'All' ||
                filter == temp;

        return searchMatch &&
            filterMatch;
      },
    ).toList();
  }

  int count(
    String type,
  ) {
    return leads.where(
      (lead) {
        return temperature(
              lead['score'] as int,
            ) ==
            type;
      },
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final desktop =
            constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(
            desktop ? 28 : 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1350,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  _header(),

                  const SizedBox(
                    height: 20,
                  ),

                  _stats(desktop),

                  const SizedBox(
                    height: 20,
                  ),

                  Container(
                    decoration:
                        _cardDecoration(),
                    child: Column(
                      children: [
                        _toolbar(
                          desktop,
                        ),
                        const Divider(
                          height: 1,
                        ),
                        desktop
                            ? _desktopTable()
                            : _mobileList(),
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

  Widget _header() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'AI Lead Qualification',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Analyse and prioritize franchise enquiries using AI scoring.',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 7,
          ),
          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFFF3E8FF,
            ),
            borderRadius:
                BorderRadius
                    .circular(
              18,
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons
                    .psychology_outlined,
                size: 16,
                color:
                    Color(
                  0xFF7C3AED,
                ),
              ),
              SizedBox(
                width: 6,
              ),
              Text(
                'AI Scoring Active',
                style:
                    TextStyle(
                  fontSize: 9,
                  fontWeight:
                      FontWeight
                          .w700,
                  color:
                      Color(
                    0xFF7C3AED,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stats(bool desktop) {
    final items = [
      {
        'title':
            'Total Qualified Leads',
        'value':
            '${leads.length}',
        'icon':
            Icons.people_outline,
        'type': 'Total',
      },
      {
        'title': 'Hot Leads',
        'value':
            '${count('Hot')}',
        'icon':
            Icons.local_fire_department_outlined,
        'type': 'Hot',
      },
      {
        'title': 'Warm Leads',
        'value':
            '${count('Warm')}',
        'icon':
            Icons.thermostat_outlined,
        'type': 'Warm',
      },
      {
        'title': 'Cold Leads',
        'value':
            '${count('Cold')}',
        'icon':
            Icons.ac_unit_outlined,
        'type': 'Cold',
      },
    ];

    if (!desktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics:
            const NeverScrollableScrollPhysics(),
        itemCount:
            items.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
        ),
        itemBuilder: (
          context,
          index,
        ) {
          return _statCard(
            items[index],
          );
        },
      );
    }

    return Row(
      children:
          List.generate(
        items.length,
        (index) {
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(
                right: index ==
                        items.length -
                            1
                    ? 0
                    : 14,
              ),
              child:
                  _statCard(
                items[index],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(
    Map<String, dynamic> item,
  ) {
    final colors =
        _temperatureColors(
      item['type'].toString(),
    );

    return Container(
      height: 100,
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color: colors.$1,
              borderRadius:
                  BorderRadius
                      .circular(
                10,
              ),
            ),
            child: Icon(
              item['icon']
                  as IconData,
              color: colors.$2,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  item['title']
                      .toString(),
                  style:
                      const TextStyle(
                    fontSize: 9,
                    color:
                        Color(
                      0xFF64748B,
                    ),
                  ),
                ),
                Text(
                  item['value']
                      .toString(),
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(bool desktop) {
    return Padding(
      padding:
          const EdgeInsets.all(
        16,
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(
                  child:
                      TextField(
                    controller:
                        searchController,
                    onChanged:
                        (value) {
                      setState(() {
                        search =
                            value;
                      });
                    },
                    decoration:
                        const InputDecoration(
                      hintText:
                          'Search lead...',
                      prefixIcon:
                          Icon(
                        Icons.search,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                SizedBox(
                  width: 160,
                  child:
                      _filter(),
                ),
              ],
            )
          : Column(
              children: [
                TextField(
                  controller:
                      searchController,
                  onChanged:
                      (value) {
                    setState(() {
                      search =
                          value;
                    });
                  },
                  decoration:
                      const InputDecoration(
                    hintText:
                        'Search lead...',
                    prefixIcon:
                        Icon(
                      Icons.search,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                _filter(),
              ],
            ),
    );
  }

  Widget _filter() {
    return DropdownButtonFormField<String>(
      initialValue: filter,
      isExpanded: true,
      items: const [
        'All',
        'Hot',
        'Warm',
        'Cold',
      ].map(
        (value) {
          return DropdownMenuItem(
            value: value,
            child: Text(value, overflow: TextOverflow.ellipsis, maxLines: 1),
          );
        },
      ).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          filter = value;
        });
      },
    );
  }

  Widget _desktopTable() {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,
      child: SizedBox(
        width: 1100,
        child: Column(
          children: [
            Container(
              color:
                  const Color(
                0xFFF8FAFC,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child:
                  const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child:
                        Text(
                      'LEAD',
                      style:
                          _leadHeader,
                    ),
                  ),
                  Expanded(
                    child:
                        Text(
                      'CITY',
                      style:
                          _leadHeader,
                    ),
                  ),
                  Expanded(
                    child:
                        Text(
                      'BUDGET',
                      style:
                          _leadHeader,
                    ),
                  ),
                  Expanded(
                    child:
                        Text(
                      'SPACE',
                      style:
                          _leadHeader,
                    ),
                  ),
                  Expanded(
                    child:
                        Text(
                      'SOURCE',
                      style:
                          _leadHeader,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child:
                        Text(
                      'AI SCORE',
                      style:
                          _leadHeader,
                    ),
                  ),
                  Expanded(
                    child:
                        Text(
                      'TEMPERATURE',
                      style:
                          _leadHeader,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child:
                        Text(
                      'ACTION',
                      style:
                          _leadHeader,
                    ),
                  ),
                ],
              ),
            ),
            ...filteredLeads
                .map(
              (lead) =>
                  _leadRow(
                lead,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leadRow(
    Map<String, dynamic> lead,
  ) {
    final score =
        lead['score'] as int;

    final temp =
        temperature(score);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration:
          const BoxDecoration(
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
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  lead['name']
                      .toString(),
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),
                Text(
                  lead['mobile']
                      .toString(),
                  style:
                      const TextStyle(
                    fontSize: 9,
                    color:
                        Color(
                      0xFF64748B,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              lead['city']
                  .toString(),
              style:
                  const TextStyle(
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _currency(
                lead['budget']
                    as int,
              ),
              style:
                  const TextStyle(
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: Text(
              lead['commercialSpace']
                  .toString(),
              style:
                  const TextStyle(
                fontSize: 9,
              ),
            ),
          ),
          Expanded(
            child: Text(
              lead['source']
                  .toString(),
              style:
                  const TextStyle(
                fontSize: 9,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding:
                  const EdgeInsets.only(
                right: 12,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    '$score/100',
                    style:
                        const TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                    child:
                        LinearProgressIndicator(
                      value:
                          score / 100,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child:
                _temperatureBadge(
              temp,
            ),
          ),
          SizedBox(
            width: 80,
            child:
                TextButton.icon(
              onPressed: () {
                _viewLead(
                  lead,
                );
              },
              icon: const Icon(
                Icons
                    .visibility_outlined,
                size: 14,
              ),
              label:
                  const Text(
                'View',
                style:
                    TextStyle(
                  fontSize: 9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileList() {
    return Padding(
      padding:
          const EdgeInsets.all(
        14,
      ),
      child: Column(
        children:
            filteredLeads.map(
          (lead) {
            final temp =
                temperature(
              lead['score']
                  as int,
            );

            return Container(
              margin:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              padding:
                  const EdgeInsets.all(
                14,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF8FAFC,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  10,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            Text(
                          lead['name']
                              .toString(),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                      ),
                      _temperatureBadge(
                        temp,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    lead['mobile']
                        .toString(),
                  ),
                  const SizedBox(
                    height: 9,
                  ),
                  Text(
                    '${lead['city']} • ${_currency(lead['budget'] as int)}',
                    style:
                        const TextStyle(
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  LinearProgressIndicator(
                    value:
                        (lead['score']
                                as int) /
                            100,
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    'AI Score: ${lead['score']}/100',
                    style:
                        const TextStyle(
                      fontSize: 9,
                    ),
                  ),
                  Align(
                    alignment:
                        Alignment
                            .centerRight,
                    child:
                        TextButton(
                      onPressed:
                          () {
                        _viewLead(
                          lead,
                        );
                      },
                      child:
                          const Text(
                        'View Details',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  void _viewLead(
    Map<String, dynamic> lead,
  ) {
    final score =
        lead['score'] as int;

    final temp =
        temperature(score);

    showDialog(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                lead['name']
                    .toString(),
              ),
              const Text(
                'AI Lead Qualification Details',
                style:
                    TextStyle(
                  fontSize: 10,
                  fontWeight:
                      FontWeight
                          .w400,
                  color:
                      Color(
                    0xFF64748B,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child:
                SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 95,
                        height: 95,
                        alignment:
                            Alignment
                                .center,
                        decoration:
                            BoxDecoration(
                          color:
                              _temperatureColors(
                            temp,
                          ).$1,
                          shape:
                              BoxShape
                                  .circle,
                        ),
                        child:
                            Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Text(
                              '$score',
                              style:
                                  TextStyle(
                                fontSize:
                                    28,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                color:
                                    _temperatureColors(
                                  temp,
                                ).$2,
                              ),
                            ),
                            const Text(
                              '/ 100',
                              style:
                                  TextStyle(
                                fontSize:
                                    9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 18,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'AI Qualification',
                              style:
                                  TextStyle(
                                fontSize:
                                    10,
                                color:
                                    Color(
                                  0xFF64748B,
                                ),
                              ),
                            ),
                            Text(
                              '$temp Lead',
                              style:
                                  const TextStyle(
                                fontSize:
                                    21,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                            const Text(
                              'AI has classified this enquiry based on investment capacity, business experience and commercial space.',
                              style:
                                  TextStyle(
                                fontSize:
                                    10,
                                color:
                                    Color(
                                  0xFF64748B,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _detail(
                        'Full Name',
                        lead['name'],
                      ),
                      _detail(
                        'Mobile Number',
                        lead['mobile'],
                      ),
                      _detail(
                        'City',
                        lead['city'],
                      ),
                      _detail(
                        'District',
                        lead['district'],
                      ),
                      _detail(
                        'Investment Budget',
                        _currency(
                          lead['budget']
                              as int,
                        ),
                      ),
                      _detail(
                        'Existing Business',
                        lead[
                            'existingBusiness'],
                      ),
                      _detail(
                        'Commercial Space',
                        lead[
                            'commercialSpace'],
                      ),
                      _detail(
                        'Previous Experience',
                        lead[
                            'experience'],
                      ),
                      _detail(
                        'Preferred Location',
                        lead[
                            'preferredLocation'],
                      ),
                      _detail(
                        'Lead Source',
                        lead['source'],
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets
                            .all(
                      15,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFF8FAFC,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                    ),
                    child:
                        const Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'AI Score Calculation',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        _ScoreRow(
                          label:
                              'Investment Budget',
                          value:
                              '30 Points',
                        ),
                        _ScoreRow(
                          label:
                              'Commercial Space',
                          value:
                              '25 Points',
                        ),
                        _ScoreRow(
                          label:
                              'Existing Business',
                          value:
                              '20 Points',
                        ),
                        _ScoreRow(
                          label:
                              'Previous Experience',
                          value:
                              '15 Points',
                        ),
                        _ScoreRow(
                          label:
                              'Preferred Location',
                          value:
                              '10 Points',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text(
                'Close',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detail(
    String label,
    dynamic value,
  ) {
    return Container(
      width: 190,
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF8FAFC,
        ),
        borderRadius:
            BorderRadius
                .circular(
          9,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE2E8F0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                const TextStyle(
              fontSize: 8,
              color:
                  Color(
                0xFF64748B,
              ),
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            value.toString(),
            style:
                const TextStyle(
              fontSize: 10,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _temperatureBadge(
    String temp,
  ) {
    final colors =
        _temperatureColors(
      temp,
    );

    return Align(
      alignment:
          Alignment.centerLeft,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration:
            BoxDecoration(
          color: colors.$1,
          borderRadius:
              BorderRadius
                  .circular(
            15,
          ),
        ),
        child: Text(
          temp,
          style:
              TextStyle(
            color: colors.$2,
            fontSize: 9,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),
    );
  }

  (Color, Color)
      _temperatureColors(
    String type,
  ) {
    switch (type) {
      case 'Hot':
        return (
          const Color(
            0xFFFEF2F2,
          ),
          const Color(
            0xFFDC2626,
          ),
        );

      case 'Warm':
        return (
          const Color(
            0xFFFFF7ED,
          ),
          const Color(
            0xFFEA580C,
          ),
        );

      case 'Cold':
        return (
          const Color(
            0xFFEFF6FF,
          ),
          const Color(
            0xFF2563EB,
          ),
        );

      default:
        return (
          const Color(
            0xFFE0F2FE,
          ),
          const Color(
            0xFF0284C7,
          ),
        );
    }
  }

  String _currency(
    int value,
  ) {
    if (value >= 100000) {
      final lakh =
          value / 100000;

      return '₹${lakh.toStringAsFixed(lakh % 1 == 0 ? 0 : 1)} Lakh';
    }

    return '₹$value';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(
        14,
      ),
      border: Border.all(
        color:
            const Color(
          0xFFE5E7EB,
        ),
      ),
    );
  }
}

class _ScoreRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _ScoreRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize: 10,
              ),
            ),
          ),
          Text(
            value,
            style:
                const TextStyle(
              fontSize: 10,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _leadHeader =
    TextStyle(
  fontSize: 8,
  fontWeight:
      FontWeight.w700,
  color:
      Color(0xFF64748B),
);