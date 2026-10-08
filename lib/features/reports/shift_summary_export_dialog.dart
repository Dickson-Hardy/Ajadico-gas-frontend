import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ajadico_logo.dart';
import '../../state/station_app_state.dart';

/// Shift Summary Export & Print Modal Dialog (BRD v3 §5.3, §5.5, §6.1)
///
/// Provides a comprehensive, production-grade shift audit report for:
/// - Station Cashiers (closing cash count & bank deposit sign-off)
/// - Branch Managers (shift verification, meter sales, and tank dip reconciliation)
/// - Central Auditors (Excel/CSV copy-paste and print-ready summary)
class ShiftSummaryExportDialog extends StatelessWidget {
  const ShiftSummaryExportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ShiftSummaryExportDialog(),
    );
  }

  String _generateCsv(StationAppState state) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    buffer.writeln('AJADICO ENERGY LIMITED - FORECOURT SHIFT SUMMARY AUDIT');
    buffer.writeln('Station Name,"${state.currentStationName}"');
    buffer.writeln('Station Code,"${state.currentStationCode}"');
    buffer.writeln('Audit Date,"$dateStr"');
    buffer.writeln('Audited By,"${state.currentUser.displayName} (${state.currentUser.role.name.toUpperCase()})"');
    buffer.writeln('');

    // 1. Pump Meter Reconciliation
    buffer.writeln('SECTION 1: PUMP METER SALES RECONCILIATION');
    buffer.writeln('Nozzle,Product,Opening Reading,Closing Reading,Litres Sold,Price (NGN),Expected Sales Value (NGN)');
    double totalLitres = 0.0;
    double totalExpectedValue = 0.0;
    for (var n in state.nozzles) {
      buffer.writeln('${n.nozzleNumber},"${n.productName}",${n.openingReading},${n.closingReading ?? ''},${n.litresSold},${n.pricePerLitre},${n.salesValue}');
      totalLitres += n.litresSold;
      totalExpectedValue += n.salesValue;
    }
    buffer.writeln('TOTAL,,,,$totalLitres,,$totalExpectedValue');
    buffer.writeln('');

    // 2. Attendant Remittances
    buffer.writeln('SECTION 2: FORECOURT ATTENDANT REMITTANCES');
    buffer.writeln('Attendant Name,Status,Expected Sales,Cash Declared,POS Card,POS Transfer,Bank Transfer,Credit Sales,Total Declared,Variance');
    for (var sub in state.submissions) {
      final totalDecl = sub.cashDeclared + sub.posCardDeclared + sub.posTransferDeclared + sub.bankTransferDeclared + sub.creditSalesDeclared;
      buffer.writeln('"${sub.attendantName}","${sub.status}",${sub.expectedSalesValue},${sub.cashDeclared},${sub.posCardDeclared},${sub.posTransferDeclared},${sub.bankTransferDeclared},${sub.creditSalesDeclared},$totalDecl,${sub.variance}');
    }
    buffer.writeln('');

    // 3. Physical Safe Cash Flow
    buffer.writeln('SECTION 3: PHYSICAL CASH SAFE RECONCILIATION');
    buffer.writeln('Item,Amount (NGN)');
    buffer.writeln('Opening Cash Safe,${state.openingCash}');
    buffer.writeln('Acknowledged Interim Cash Drops,${state.totalAcknowledgedInterimDrops}');
    buffer.writeln('Verified Cash Receipts,${state.totalVerifiedCashReceipts}');
    buffer.writeln('Approved Cash Expenses,-${state.totalPhysicalCashExpenses}');
    buffer.writeln('Handed Over for Bank Deposit,-${state.totalHandedOverDeposits}');
    buffer.writeln('Expected Closing Safe Cash,${state.expectedClosingCash}');
    buffer.writeln('Actual Physical Counted Cash,${state.totalCountedCash}');
    buffer.writeln('Cash Drawer Variance,${state.cashDrawerVariance}');
    buffer.writeln('');

    // 4. Denomination Breakdown
    buffer.writeln('SECTION 4: PHYSICAL DENOMINATIONS');
    buffer.writeln('Denomination (NGN),Note Count,Subtotal (NGN)');
    final denoms = [1000, 500, 200, 100, 50, 20, 10];
    for (var d in denoms) {
      final count = state.cashCounts[d] ?? 0;
      buffer.writeln('$d,$count,${d * count}');
    }
    buffer.writeln('');

    // 5. Underground Tanks
    buffer.writeln('SECTION 5: UNDERGROUND FUEL TANKS');
    buffer.writeln('Tank Code,Product,Capacity (L),Physical Dip (L),Book Stock (L),Variance (L),Ullage (L)');
    for (var t in state.tanks) {
      buffer.writeln('"${t.code}","${t.product}",${t.capacity},${t.physicalDip},${t.bookStock},${t.variance},${t.capacity - t.physicalDip}');
    }

    return buffer.toString();
  }

  String _generateTextSummary(StationAppState state) {
    final buffer = StringBuffer();
    final now = DateTime.now();

    buffer.writeln('====================================================');
    buffer.writeln('        AJADICO ENERGY - SHIFT AUDIT REPORT        ');
    buffer.writeln('====================================================');
    buffer.writeln('Station: ${state.currentStationName} (${state.currentStationCode})');
    buffer.writeln('Date:    ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
    buffer.writeln('Auditor: ${state.currentUser.displayName} [${state.currentUser.role.name.toUpperCase()}]');
    buffer.writeln('----------------------------------------------------');

    buffer.writeln('\n[1. FUEL SALES & PUMP DISPENSING]');
    double totalLitres = 0.0;
    double totalExpected = 0.0;
    for (var n in state.nozzles) {
      buffer.writeln(' Nozzle ${n.nozzleNumber} (${n.productName}): ${n.litresSold.toStringAsFixed(1)}L @ ${CurrencyFormatter.formatNaira(n.pricePerLitre)} = ${CurrencyFormatter.formatNaira(n.salesValue)}');
      totalLitres += n.litresSold;
      totalExpected += n.salesValue;
    }
    buffer.writeln(' TOTAL METER SALES: ${totalLitres.toStringAsFixed(1)} Litres | ${CurrencyFormatter.formatNaira(totalExpected)}');

    buffer.writeln('\n[2. ATTENDANT REMITTANCES]');
    if (state.submissions.isEmpty) {
      buffer.writeln(' No end-of-shift attendant submissions in queue.');
    } else {
      for (var sub in state.submissions) {
        buffer.writeln(' Attendant: ${sub.attendantName} [${sub.status}]');
        buffer.writeln('   Expected: ${CurrencyFormatter.formatNaira(sub.expectedSalesValue)}');
        buffer.writeln('   Cash Declared: ${CurrencyFormatter.formatNaira(sub.cashDeclared)} | POS: ${CurrencyFormatter.formatNaira(sub.posCardDeclared + sub.posTransferDeclared)}');
        buffer.writeln('   Variance: ${CurrencyFormatter.formatVariance(sub.variance)}');
      }
    }

    buffer.writeln('\n[3. CASH SAFE RECONCILIATION]');
    buffer.writeln(' Opening Safe:        ${CurrencyFormatter.formatNaira(state.openingCash)}');
    buffer.writeln(' + Interim Drops:     ${CurrencyFormatter.formatNaira(state.totalAcknowledgedInterimDrops)}');
    buffer.writeln(' + Cash Receipts:     ${CurrencyFormatter.formatNaira(state.totalVerifiedCashReceipts)}');
    buffer.writeln(' - Cash Expenses:     ${CurrencyFormatter.formatNaira(state.totalPhysicalCashExpenses)}');
    buffer.writeln(' - Bank Handover:     ${CurrencyFormatter.formatNaira(state.totalHandedOverDeposits)}');
    buffer.writeln(' Expected Closing:    ${CurrencyFormatter.formatNaira(state.expectedClosingCash)}');
    buffer.writeln(' Physical Counted:    ${CurrencyFormatter.formatNaira(state.totalCountedCash)}');
    buffer.writeln(' Drawer Variance:     ${CurrencyFormatter.formatVariance(state.cashDrawerVariance)}');

    buffer.writeln('\n[4. UNDERGROUND STORAGE TANKS]');
    for (var t in state.tanks) {
      buffer.writeln(' Tank ${t.code} (${t.product}): Dip ${t.physicalDip.toStringAsFixed(0)}L | Book ${t.bookStock.toStringAsFixed(0)}L | Var ${t.variance.toStringAsFixed(0)}L');
    }

    buffer.writeln('\n====================================================');
    buffer.writeln('SIGN-OFF SIGNATURES:');
    buffer.writeln('Cashier:   ____________________');
    buffer.writeln('Manager:   ____________________');
    buffer.writeln('Director:  ____________________');
    buffer.writeln('====================================================');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = StationAppState.instance;
    final now = DateTime.now();
    final denoms = [1000, 500, 200, 100, 50, 20, 10];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 850),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print_outlined, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shift Summary & Audit Report',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${state.currentStationName} · ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close shift summary',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AjadicoLogo.horizontal(size: 28, showSubtitle: true),
                                const SizedBox(height: 6),
                                Text(
                                  'Station Code: ${state.currentStationCode} · Forecourt Multi-Tank Branch',
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Auditor: ${state.currentUser.displayName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text('Role: ${state.currentUser.role.name.toUpperCase()} · Certified', style: const TextStyle(fontSize: 12, color: AppColors.ok)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: Pump Meter Reconciliation
                    _buildSectionHeader('1. Pump Meter Sales & Litres Reconciliation', Icons.speed),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 640),
                        child: Table(
                          border: TableBorder.all(color: AppColors.line, width: 0.8),
                          columnWidths: const {
                            0: FlexColumnWidth(1.2),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(1.5),
                            3: FlexColumnWidth(1.5),
                            4: FlexColumnWidth(1.5),
                            5: FlexColumnWidth(2.0),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: AppColors.lightBackground),
                              children: [
                                _buildTableHeader('Nozzle'),
                                _buildTableHeader('Product'),
                                _buildTableHeader('Opening (L)'),
                                _buildTableHeader('Closing (L)'),
                                _buildTableHeader('Sold (L)'),
                                _buildTableHeader('Expected Sales (₦)'),
                              ],
                            ),
                            ...state.nozzles.map((n) => TableRow(
                                  children: [
                                    _buildTableCell('Pump #${n.nozzleNumber}'),
                                    _buildTableCell(n.productName, isBold: true),
                                    _buildTableCell(n.openingReading.toStringAsFixed(1)),
                                    _buildTableCell(n.closingReading?.toStringAsFixed(1) ?? '—'),
                                    _buildTableCell(n.litresSold.toStringAsFixed(1), isBold: true),
                                    _buildTableCell(CurrencyFormatter.formatNaira(n.salesValue), isBold: true),
                                  ],
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Attendant Remittances
                    _buildSectionHeader('2. Forecourt Attendant Remittances', Icons.people_outline),
                    const SizedBox(height: 8),
                    if (state.submissions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: const Text('No attendant shift remittance closures submitted yet today.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 700),
                          child: Table(
                            border: TableBorder.all(color: AppColors.line, width: 0.8),
                            columnWidths: const {
                              0: FlexColumnWidth(1.8),
                              1: FlexColumnWidth(1.3),
                              2: FlexColumnWidth(1.3),
                              3: FlexColumnWidth(1.5),
                              4: FlexColumnWidth(1.2),
                              5: FlexColumnWidth(1.3),
                              6: FlexColumnWidth(1.6),
                            },
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(color: AppColors.lightBackground),
                                children: [
                                  _buildTableHeader('Attendant'),
                                  _buildTableHeader('Expected (₦)'),
                                  _buildTableHeader('Cash (₦)'),
                                  _buildTableHeader('POS / Bank (₦)'),
                                  _buildTableHeader('Credit (₦)'),
                                  _buildTableHeader('Variance (₦)'),
                                  _buildTableHeader('Status'),
                                ],
                              ),
                              ...state.submissions.map((sub) => TableRow(
                                    children: [
                                      _buildTableCell(sub.attendantName, isBold: true),
                                      _buildTableCell(CurrencyFormatter.formatNaira(sub.expectedSalesValue)),
                                      _buildTableCell(CurrencyFormatter.formatNaira(sub.cashDeclared)),
                                      _buildTableCell(CurrencyFormatter.formatNaira(sub.posCardDeclared + sub.posTransferDeclared + sub.bankTransferDeclared)),
                                      _buildTableCell(CurrencyFormatter.formatNaira(sub.creditSalesDeclared)),
                                      _buildTableCell(
                                        CurrencyFormatter.formatVariance(sub.variance),
                                        textColor: sub.variance < 0 ? AppColors.bad : (sub.variance > 0 ? AppColors.ok : AppColors.ink),
                                        isBold: true,
                                      ),
                                      _buildTableCell(sub.status),
                                    ],
                                  )),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Section 3: Cash Safe Reconciliation & Denominations
                    _buildSectionHeader('3. Cashier Safe & Physical Denomination Count', Icons.point_of_sale),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Safe Equation
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              children: [
                                _buildSummaryRow('Opening Safe Balance:', CurrencyFormatter.formatNaira(state.openingCash)),
                                _buildSummaryRow('+ Acknowledged Interim Drops:', CurrencyFormatter.formatNaira(state.totalAcknowledgedInterimDrops), isGreen: true),
                                _buildSummaryRow('+ Verified Cash Receipts:', CurrencyFormatter.formatNaira(state.totalVerifiedCashReceipts), isGreen: true),
                                _buildSummaryRow('- Approved Cash Expenses:', CurrencyFormatter.formatNaira(state.totalPhysicalCashExpenses), isRed: true),
                                _buildSummaryRow('- Bank Deposit Handover:', CurrencyFormatter.formatNaira(state.totalHandedOverDeposits), isBlue: true),
                                const Divider(color: AppColors.line),
                                _buildSummaryRow('Target Expected Closing Safe:', CurrencyFormatter.formatNaira(state.expectedClosingCash), isBold: true),
                                _buildSummaryRow('Actual Physical Count:', CurrencyFormatter.formatNaira(state.totalCountedCash), isBold: true),
                                _buildSummaryRow(
                                  'Drawer Variance:',
                                  CurrencyFormatter.formatVariance(state.cashDrawerVariance),
                                  isBold: true,
                                  textColor: state.cashDrawerVariance < 0 ? AppColors.bad : (state.cashDrawerVariance > 0 ? AppColors.ok : AppColors.ink),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Denomination Table
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 260),
                              child: Table(
                                border: TableBorder.all(color: AppColors.line, width: 0.8),
                                columnWidths: const {
                                  0: FlexColumnWidth(1.2),
                                  1: FlexColumnWidth(1.0),
                                  2: FlexColumnWidth(1.6),
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(color: AppColors.lightBackground),
                                    children: [
                                      _buildTableHeader('Note'),
                                      _buildTableHeader('Count'),
                                      _buildTableHeader('Total (₦)'),
                                    ],
                                  ),
                                  ...denoms.map((d) {
                                    final count = state.cashCounts[d] ?? 0;
                                    return TableRow(
                                      children: [
                                        _buildTableCell('₦$d'),
                                        _buildTableCell('$count'),
                                        _buildTableCell(CurrencyFormatter.formatNaira(d * count.toDouble())),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 4: Underground Storage Tanks
                    _buildSectionHeader('4. Underground Tanks (UST) Physical Dips & Ullage', Icons.propane_tank_outlined),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 720),
                        child: Table(
                          border: TableBorder.all(color: AppColors.line, width: 0.8),
                          columnWidths: const {
                            0: FlexColumnWidth(1.0),
                            1: FlexColumnWidth(1.0),
                            2: FlexColumnWidth(1.3),
                            3: FlexColumnWidth(1.4),
                            4: FlexColumnWidth(1.4),
                            5: FlexColumnWidth(1.3),
                            6: FlexColumnWidth(1.3),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: AppColors.lightBackground),
                              children: [
                                _buildTableHeader('Tank Code'),
                                _buildTableHeader('Fuel'),
                                _buildTableHeader('Capacity (L)'),
                                _buildTableHeader('Physical Dip (L)'),
                                _buildTableHeader('Calculated (L)'),
                                _buildTableHeader('Variance (L)'),
                                _buildTableHeader('Ullage (L)'),
                              ],
                            ),
                            ...state.tanks.map((t) => TableRow(
                                  children: [
                                    _buildTableCell(t.code, isBold: true),
                                    _buildTableCell(t.product),
                                    _buildTableCell(CurrencyFormatter.formatLitres(t.capacity)),
                                    _buildTableCell(CurrencyFormatter.formatLitres(t.physicalDip), isBold: true),
                                    _buildTableCell(CurrencyFormatter.formatLitres(t.bookStock)),
                                    _buildTableCell(
                                      '${t.variance >= 0 ? '+' : '−'}${CurrencyFormatter.formatLitres(t.variance.abs())}',
                                      textColor: t.hasDeficit ? AppColors.bad : AppColors.ink,
                                      isBold: true,
                                    ),
                                    _buildTableCell(CurrencyFormatter.formatLitres(t.capacity - t.physicalDip)),
                                  ],
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Signatures Block
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          Widget signField(String role) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(role, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                  const SizedBox(height: 24),
                                  const Text('Sign: __________________________', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              );
                          const roles = [
                            'Cashier Booth Representative:',
                            'Branch Station Manager:',
                            'Central Director / Internal Audit:',
                          ];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CERTIFICATION & AUDIT SIGN-OFF:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink)),
                              const SizedBox(height: 16),
                              if (constraints.maxWidth < 700)
                                ...roles.map(
                                  (role) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: signField(role),
                                  ),
                                )
                              else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: roles
                                      .map(
                                        (role) => Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 12),
                                            child: signField(role),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.border)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_all, size: 18),
                    label: const Text('Copy Formatted Text'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () {
                      final txt = _generateTextSummary(state);
                      Clipboard.setData(ClipboardData(text: txt));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Shift summary text copied to clipboard! Paste it wherever it is needed.'),
                          backgroundColor: AppColors.ink,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.table_chart, size: 18),
                    label: const Text('Copy Excel / CSV Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ok,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () {
                      final csv = _generateCsv(state);
                      Clipboard.setData(ClipboardData(text: csv));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Shift Summary CSV copied to clipboard! Paste directly into Microsoft Excel or Google Sheets.'),
                          backgroundColor: AppColors.ok,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink)),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: textColor ?? AppColors.ink,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isGreen = false, bool isRed = false, bool isBlue = false, Color? textColor}) {
    Color valColor = textColor ?? AppColors.ink;
    if (isGreen) valColor = AppColors.ok;
    if (isRed) valColor = AppColors.bad;
    if (isBlue) valColor = AppColors.bank;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valColor)),
        ],
      ),
    );
  }
}
