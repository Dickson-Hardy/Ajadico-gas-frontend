import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/evidence_preview_dialog.dart';
import '../../core/widgets/operations_workspace.dart';
import '../../models/bank_deposit.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

class BankDepositVerificationScreen extends StatefulWidget {
  final VoidCallback onBack;

  const BankDepositVerificationScreen({super.key, required this.onBack});

  @override
  State<BankDepositVerificationScreen> createState() =>
      _BankDepositVerificationScreenState();
}

class _BankDepositVerificationScreenState
    extends State<BankDepositVerificationScreen> {
  final state = StationAppState.instance;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} at $hour:$minute';
  }

  Future<void> _confirmDeposit(BankDepositRecord dep) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm bank credit alert?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${CurrencyFormatter.formatNaira(dep.amount)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Depositor: ${dep.cashierName}',
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
            ),
            Text(
              '${dep.stationName} · ${dep.bankName}',
              style: const TextStyle(fontSize: 13, color: AppColors.slate),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dual-custody action: this locks the deposit into the company ledger as matched against the bank credit alert.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bank,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            child:
                const Text('Confirm Deposit', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runDepositAction(dep);
  }

  Future<void> _runDepositAction(BankDepositRecord dep) async {
    setState(() => _processingIds.add(dep.id));
    try {
      final ok = await state.confirmBankDeposit(dep.id);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.ok,
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Deposit ${dep.id} of ${CurrencyFormatter.formatNaira(dep.amount)} confirmed against bank credit alert by Director.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.bad,
              behavior: SnackBarBehavior.floating,
              content: Text('Failed to confirm deposit. Please retry.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bad,
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to confirm deposit: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(dep.id));
    }
  }

  void _showTellerSlip(BankDepositRecord deposit) {
    EvidencePreviewDialog.show(context,
        title: 'Teller slip', reference: deposit.slipUrl);
  }

  Widget _buildRestrictedAccess() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        title: const Text('Deposit approvals',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: AppColors.muted),
              const SizedBox(height: 16),
              const Text(
                'Restricted — director access required',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dual-custody bank credit verification is limited to the Director role.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _flagDiscrepancyDialog(BankDepositRecord dep) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.bad),
              const SizedBox(width: 8),
              const Text('Flag Deposit Discrepancy'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are flagging ${CurrencyFormatter.formatNaira(dep.amount)} remitted by ${dep.cashierName} for ${dep.stationName}.',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              const Text('Discrepancy Reason / Audit Note *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. Credit alert not received on corporate statement; or amount credited is short by ₦50,000.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.bad),
              onPressed: () async {
                final notes = textController.text.trim();
                if (notes.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter discrepancy reason.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _processingIds.add(dep.id));
                try {
                  final ok =
                      await state.flagBankDepositDiscrepancy(dep.id, notes);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.bad,
                        behavior: SnackBarBehavior.floating,
                        content: Text(ok
                            ? 'Deposit flagged for review.'
                            : 'Could not flag the deposit. Reconnect and retry.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.bad,
                        behavior: SnackBarBehavior.floating,
                        content: Text('Failed to flag deposit: $e'),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _processingIds.remove(dep.id));
                }
              },
              child: const Text('Flag Discrepancy'),
            ),
          ],
        );
      },
    );
  }

  String _statusFilter = 'Awaiting';
  String _search = '';

  bool _matchesStatus(BankDepositRecord deposit) => switch (_statusFilter) {
        'Awaiting' => !deposit.isConfirmed && deposit.status != 'discrepancy',
        'Confirmed' => deposit.isConfirmed,
        'Flagged' => deposit.status == 'discrepancy',
        _ => true,
      };

  Widget _depositActions(BankDepositRecord deposit) {
    final processing = _processingIds.contains(deposit.id);
    return Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
              tooltip: 'View teller slip',
              onPressed: () => _showTellerSlip(deposit),
              icon: const Icon(Icons.attach_file, size: 18)),
          if (!deposit.isConfirmed) ...[
            OutlinedButton(
                onPressed:
                    processing ? null : () => _flagDiscrepancyDialog(deposit),
                child: const Text('Flag')),
            ElevatedButton(
                onPressed: processing ? null : () => _confirmDeposit(deposit),
                child: Text(processing ? 'Saving…' : 'Confirm')),
          ] else
            Tooltip(
                message: 'Confirmed by ${deposit.confirmedBy ?? 'Director'}',
                child: const Icon(Icons.check_circle_outline,
                    size: 19, color: AppColors.ok)),
        ]);
  }

  @override
  Widget build(BuildContext context) {
    if (state.currentUser.role != UserRole.director)
      return _buildRestrictedAccess();
    final colors = Theme.of(context).colorScheme;
    final deposits = state.deposits;
    final pending = deposits
        .where((d) => !d.isConfirmed && d.status != 'discrepancy')
        .toList();
    final confirmed = deposits.where((d) => d.isConfirmed).toList();
    final flagged = deposits.where((d) => d.status == 'discrepancy').toList();
    final filtered = deposits
        .where((d) =>
            _matchesStatus(d) &&
            '${d.bankName} ${d.tellerNumber ?? ''} ${d.cashierName} ${d.stationName}'
                .toLowerCase()
                .contains(_search.toLowerCase()))
        .toList();
    final metrics = [
      WorkspaceMetric(
          label: 'Awaiting confirmation',
          value: CurrencyFormatter.formatNaira(
              pending.fold(0.0, (sum, d) => sum + d.amount)),
          detail: '${pending.length} deposits'),
      WorkspaceMetric(
          label: 'Confirmed deposits',
          value: CurrencyFormatter.formatNaira(
              confirmed.fold(0.0, (sum, d) => sum + d.amount)),
          detail: '${confirmed.length} deposits'),
      WorkspaceMetric(
          label: 'Flagged for review',
          value: CurrencyFormatter.formatNaira(
              flagged.fold(0.0, (sum, d) => sum + d.amount)),
          detail: '${flagged.length} deposits',
          color: flagged.isEmpty ? null : AppColors.bad),
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Deposit approvals'),
        actions: [
          IconButton(
              tooltip: 'Refresh records',
              onPressed: state.isSyncingWithRemote
                  ? null
                  : () => state.syncWithSupabase(),
              icon: const Icon(Icons.refresh)),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bank deposit register',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                        'Match cash handovers to bank credits, then confirm or flag the record.',
                        style: TextStyle(
                            fontSize: 13, color: colors.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760
                          ? 3
                          : constraints.maxWidth >= 500
                              ? 2
                              : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: metrics
                              .map((m) => SizedBox(width: width, child: m))
                              .toList());
                    }),
                    const SizedBox(height: 24),
                    Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final filter in [
                            'Awaiting',
                            'Confirmed',
                            'Flagged',
                            'All'
                          ])
                            ChoiceChip(
                                label: Text(filter),
                                selected: _statusFilter == filter,
                                onSelected: (_) =>
                                    setState(() => _statusFilter = filter)),
                          SizedBox(
                              width: 260,
                              child: TextField(
                                decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search, size: 18),
                                    hintText: 'Search bank, teller or bearer'),
                                onChanged: (value) =>
                                    setState(() => _search = value.trim()),
                              )),
                        ]),
                    const SizedBox(height: 20),
                    WorkspaceSection(
                      title: 'Deposit records',
                      subtitle:
                          '${filtered.length} matching records · ${state.currentStationName}',
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(36),
                              child: Column(children: [
                                Icon(Icons.account_balance_outlined,
                                    size: 30, color: colors.onSurfaceVariant),
                                const SizedBox(height: 12),
                                const Text('No matching deposits',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text(
                                    deposits.isEmpty
                                        ? 'Cash handovers recorded at the station appear here for review.'
                                        : 'Choose another status or adjust your search.',
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ]))
                          : LayoutBuilder(builder: (context, constraints) {
                              if (constraints.maxWidth < 720) {
                                return Column(children: [
                                  for (var i = 0; i < filtered.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                          height: 1,
                                          color: colors.outlineVariant),
                                    Padding(
                                        padding: const EdgeInsets.all(18),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  CurrencyFormatter.formatNaira(
                                                      filtered[i].amount),
                                                  style: const TextStyle(
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              const SizedBox(height: 6),
                                              Text(
                                                  '${filtered[i].bankName} · ${filtered[i].tellerNumber ?? 'No teller reference'}'),
                                              const SizedBox(height: 4),
                                              Text(
                                                  '${filtered[i].cashierName} · ${_formatDateTime(filtered[i].handedOverAt)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall),
                                              if (filtered[i]
                                                      .directorNotes
                                                      ?.isNotEmpty ==
                                                  true) ...[
                                                const SizedBox(height: 6),
                                                Text(filtered[i].directorNotes!,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall),
                                              ],
                                              const SizedBox(height: 12),
                                              _depositActions(filtered[i]),
                                            ])),
                                  ],
                                ]);
                              }
                              return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    dataRowMinHeight: 68,
                                    dataRowMaxHeight: 92,
                                    columns: const [
                                      DataColumn(
                                          label: Text('BANK / REFERENCE')),
                                      DataColumn(label: Text('BEARER')),
                                      DataColumn(label: Text('HANDOVER')),
                                      DataColumn(
                                          label: Text('AMOUNT'), numeric: true),
                                      DataColumn(label: Text('STATUS')),
                                      DataColumn(label: Text('REVIEW')),
                                    ],
                                    rows: filtered
                                        .map((d) => DataRow(cells: [
                                              DataCell(Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(d.bankName,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                    Text(
                                                        d.tellerNumber ??
                                                            'No teller reference',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall),
                                                  ])),
                                              DataCell(Text(d.cashierName)),
                                              DataCell(Text(_formatDateTime(
                                                  d.handedOverAt))),
                                              DataCell(Text(
                                                  CurrencyFormatter.formatNaira(
                                                      d.amount),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                              DataCell(StatusChip(
                                                  label: d.isConfirmed
                                                      ? 'Confirmed'
                                                      : d.status ==
                                                              'discrepancy'
                                                          ? 'Flagged'
                                                          : 'Awaiting',
                                                  type: d.isConfirmed
                                                      ? ChipType.ok
                                                      : d.status ==
                                                              'discrepancy'
                                                          ? ChipType.bad
                                                          : ChipType.warn)),
                                              DataCell(_depositActions(d)),
                                            ]))
                                        .toList(),
                                  ));
                            }),
                    ),
                    const SizedBox(height: 24),
                  ]),
            )),
      ),
    );
  }
}
