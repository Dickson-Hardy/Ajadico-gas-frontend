import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/operations_workspace.dart';
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
    return state.creditCustomers
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
  }

  void _showCreateResultSnackBar(String result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: switch (result) {
          'created' => AppColors.ok,
          'queued' => AppColors.warn,
          _ => AppColors.bad,
        },
        behavior: SnackBarBehavior.floating,
        content: switch (result) {
          'created' => const Text('Customer added'),
          'queued' => const Text('Saved — will sync when online'),
          _ => const Text('Could not add customer'),
        },
      ),
    );
  }

  Future<void> _showAddCustomerDialog() async {
    final companyController = TextEditingController();
    final contactController = TextEditingController();
    final termsController = TextEditingController();
    String error = '';
    bool isSubmitting = false;

    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Credit Customer'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Company Name *',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: companyController,
                      decoration: const InputDecoration(
                          hintText: 'Registered company name'),
                      onChanged: (_) => setDialogState(() => error = ''),
                    ),
                    const SizedBox(height: 14),
                    const Text('Contact Person *',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: contactController,
                      decoration: const InputDecoration(
                          hintText: 'Contact person full name'),
                      onChanged: (_) => setDialogState(() => error = ''),
                    ),
                    const SizedBox(height: 14),
                    const Text('Payment Terms (days) *',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: termsController,
                      keyboardType: const TextInputType.numberWithOptions(),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: '30'),
                      onChanged: (_) => setDialogState(() => error = ''),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        error,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.bad),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final company = companyController.text.trim();
                        final contact = contactController.text.trim();
                        final terms = int.tryParse(termsController.text.trim());
                        if (company.isEmpty || contact.isEmpty) {
                          setDialogState(() => error =
                              'Company name and contact person are required.');
                          return;
                        }
                        if (terms == null || terms <= 0) {
                          setDialogState(() => error =
                              'Enter payment terms in days greater than 0.');
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          error = '';
                        });
                        final result = await state.createCreditCustomer(
                          companyName: company,
                          contactPerson: contact,
                          paymentTermsDays: terms,
                        );
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showCreateResultSnackBar(result);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Add Customer'),
              ),
            ],
          );
        },
      ),
    );

    await Navigator.of(context).push(route);
    await route.completed;
    companyController.dispose();
    contactController.dispose();
    termsController.dispose();
  }

  Future<void> _showRepaymentDialog(CreditCustomer customer) async {
    final amountController = TextEditingController();
    String error = '';

    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Record Repayment'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current outstanding: ${CurrencyFormatter.formatNaira(customer.outstanding)}',
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    const Text('Amount *',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                      ],
                      decoration: const InputDecoration(
                          prefixText: '₦ ', hintText: 'e.g. 50,000'),
                      onChanged: (_) => setDialogState(() => error = ''),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        error,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.bad),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(
                          amountController.text.trim().replaceAll(',', '')) ??
                      0.0;
                  if (amount <= 0) {
                    setDialogState(
                        () => error = 'Enter an amount greater than ₦0.');
                    return;
                  }
                  state.recordCreditRepayment(
                      customerId: customer.id, amount: amount);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.ok,
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                          'Repayment of ${CurrencyFormatter.formatNaira(amount)} recorded'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Record Repayment'),
              ),
            ],
          );
        },
      ),
    );

    await Navigator.of(context).push(route);
    await route.completed;
    amountController.dispose();
  }

  Widget _mobileCustomerCard(CreditCustomer customer) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            StatusChip(
              label: switch (customer.status) {
                CustomerCreditStatus.current => 'Current',
                CustomerCreditStatus.overdue => 'Overdue',
                CustomerCreditStatus.settled => 'Settled',
              },
              type: customer.status == CustomerCreditStatus.overdue
                  ? ChipType.bad
                  : ChipType.ok,
            ),
            const SizedBox(height: 16),
            Text('Outstanding balance',
                style: TextStyle(color: colors.onSurfaceVariant)),
            Text(CurrencyFormatter.formatNaira(customer.outstanding),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text('Last repayment: ${customer.lastRepayment}'),
            const SizedBox(height: 4),
            Text('Payment terms: ${customer.dueDate}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRepaymentDialog(customer),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Repayment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = _filteredCustomers;
    final totalOutstanding =
        state.creditCustomers.fold(0.0, (s, c) => s + c.outstanding);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Credit Customers Ledger',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Customer credit and repayments',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 760;
                  return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                            width: narrow
                                ? constraints.maxWidth
                                : constraints.maxWidth - 420,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Customer accounts',
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(
                                    'Review credit balances and record customer repayments.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                              ],
                            )),
                        SizedBox(
                            width: narrow ? constraints.maxWidth : 240,
                            child: WorkspaceMetric(
                              label: 'Outstanding credit',
                              value: CurrencyFormatter.formatNaira(
                                  totalOutstanding),
                            )),
                        ElevatedButton.icon(
                            onPressed: state.currentUser.isActive &&
                                    state.currentUser.role == UserRole.director
                                ? _showAddCustomerDialog
                                : null,
                            icon: const Icon(Icons.add, size: 17),
                            label: const Text('Add customer')),
                      ]);
                }),
                const SizedBox(height: 16),

                // Search Bar
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by customer name...',
                        prefixIcon: Icon(Icons.search,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Customer Data Table or Empty State
                if (customers.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 40, horizontal: 20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.people_outline,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'No Credit Customers Registered',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Authorized commercial fleet accounts will appear here once registered by the Director.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (MediaQuery.sizeOf(context).width < 700)
                  ...customers.map(_mobileCustomerCard)
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingTextStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface),
                          columns: const [
                            DataColumn(label: const Text('Customer Account')),
                            DataColumn(
                                label: const Align(
                                    alignment: Alignment.centerRight,
                                    child: const Text('Outstanding Debt')),
                                numeric: true),
                            DataColumn(label: const Text('Last Repayment')),
                            DataColumn(label: const Text('Payment Terms')),
                            DataColumn(label: const Text('Status')),
                            DataColumn(label: const Text('Actions')),
                          ],
                          rows: customers.map((cust) {
                            return DataRow(
                              cells: [
                                DataCell(Text(cust.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                                DataCell(
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      CurrencyFormatter.formatNaira(
                                          cust.outstanding),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                DataCell(Text(cust.lastRepayment)),
                                DataCell(Text(cust.dueDate)),
                                DataCell(
                                  StatusChip(
                                    label: cust.status ==
                                            CustomerCreditStatus.current
                                        ? 'Current'
                                        : cust.status ==
                                                CustomerCreditStatus.overdue
                                            ? 'Overdue'
                                            : 'Settled',
                                    type: cust.status ==
                                            CustomerCreditStatus.current
                                        ? ChipType.ok
                                        : cust.status ==
                                                CustomerCreditStatus.overdue
                                            ? ChipType.bad
                                            : ChipType.ok,
                                  ),
                                ),
                                DataCell(
                                  TextButton.icon(
                                    label: const Text('Repayment'),
                                    icon: const Icon(Icons.payments, size: 18),
                                    style: TextButton.styleFrom(
                                        minimumSize: const Size(48, 48)),
                                    onPressed: () => _showRepaymentDialog(cust),
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
                Text(
                  'Note: Only Directors can authorize new credit customers and set credit limits.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
