import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/credit_customer.dart';

class CreditCustomersScreen extends StatefulWidget {
  final VoidCallback onBack;

  const CreditCustomersScreen({super.key, required this.onBack});

  @override
  State<CreditCustomersScreen> createState() => _CreditCustomersScreenState();
}

class _CreditCustomersScreenState extends State<CreditCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<CreditCustomer> _customers;

  @override
  void initState() {
    super.initState();
    _customers = CreditCustomer.getDemoCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CreditCustomer> get _filteredCustomers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _customers;
    return _customers.where((c) => c.name.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Credit Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Senior · All branches', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Credit customers',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Registered customers who can buy on credit at any pump.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // Search & Add customer bar
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
                                content: Text('New credit customer addition requires Senior / Director authorization (§4.10).'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add customer'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(140, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Customer Ledger Table Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                        columns: const [
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Outstanding', textAlign: TextAlign.right), numeric: true),
                          DataColumn(label: Text('Last repayment')),
                          DataColumn(label: Text('Due')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: _filteredCustomers.map((cust) {
                          return DataRow(
                            cells: [
                              DataCell(Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(CurrencyFormatter.formatNaira(cust.outstanding))),
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
                  'Only Senior and directors can add customers. Names above are placeholders.',
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
