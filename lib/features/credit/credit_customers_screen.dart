import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/credit_customer.dart';
import '../../state/station_app_state.dart';

class CreditCustomersScreen extends StatefulWidget {
  final VoidCallback onBack;

  const CreditCustomersScreen({super.key, required this.onBack});

  @override
  State<CreditCustomersScreen> createState() => _CreditCustomersScreenState();
}

class _CreditCustomersScreenState extends State<CreditCustomersScreen> {
  final state = StationAppState.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  List<CreditCustomer> get _filteredCustomers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return state.creditCustomers;
    return state.creditCustomers.where((c) => c.name.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final customers = _filteredCustomers;
    final totalOutstanding = state.creditCustomers.fold(0.0, (s, c) => s + c.outstanding);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Credit Customers Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Director · All Branches Corporate Accounts (§4.8–§4.10)', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credit customers ledger',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Authorized commercial accounts who may dispense fuel on credit at any pump.',
                          style: TextStyle(fontSize: 15, color: AppColors.muted),
                        ),
                      ],
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Outstanding Receivables', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            Text(
                              CurrencyFormatter.formatNaira(totalOutstanding),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search & Add Button Bar
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search by customer name...',
                              prefixIcon: Icon(Icons.search, color: AppColors.muted),
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('New credit customer addition requires Director authorization (§4.10).'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add customer'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(160, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Customer Data Table
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                        columns: const [
                          DataColumn(label: Text('Customer Account')),
                          DataColumn(label: Text('Outstanding Debt', textAlign: TextAlign.right), numeric: true),
                          DataColumn(label: Text('Last Repayment')),
                          DataColumn(label: Text('Payment Terms')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: customers.map((cust) {
                          return DataRow(
                            cells: [
                              DataCell(Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(CurrencyFormatter.formatNaira(cust.outstanding), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(cust.lastRepayment)),
                              DataCell(Text(cust.dueDate)),
                              DataCell(
                                StatusChip(
                                  label: cust.status == CustomerCreditStatus.current
                                      ? 'Current'
                                      : cust.status == CustomerCreditStatus.overdue
                                          ? 'Overdue'
                                          : 'Settled',
                                  type: cust.status == CustomerCreditStatus.current
                                      ? ChipType.ok
                                      : cust.status == CustomerCreditStatus.overdue
                                          ? ChipType.bad
                                          : ChipType.ok,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                const Text(
                  'Note: Only Directors can authorize new credit customers. Names above are active demo accounts.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
