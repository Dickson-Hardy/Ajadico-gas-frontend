// Dependency-free arithmetic check; does not launch the Flutter engine.
import '../lib/models/shift_adjustment.dart';

void main() {
  ShiftAdjustment entry(
          ShiftAdjustmentKind kind, double amount, String status) =>
      ShiftAdjustment(
          id: 'fixture',
          shiftId: 'fixture-shift',
          stationCode: 'TEST',
          attendantId: 'fixture-user',
          attendantName: 'Test attendant',
          kind: kind,
          reason: 'Test entry',
          amount: amount,
          status: status,
          createdAt: DateTime(2026, 10, 14));
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  final entries = [
    entry(ShiftAdjustmentKind.expense, 5000, 'approved'),
    entry(ShiftAdjustmentKind.calibrationReturn, 24000, 'approved'),
    entry(ShiftAdjustmentKind.generatorFuel, 15000, 'approved'),
    entry(ShiftAdjustmentKind.companyVehicle, 6000, 'approved'),
    entry(ShiftAdjustmentKind.expense, 99999, 'pending'),
    entry(ShiftAdjustmentKind.expense, 99999, 'rejected')
  ];
  final totals = ShiftAdjustmentTotals(entries);
  check(totals.approvedExpenses == 5000, 'Approved expense total');
  check(totals.approvedFuelValue == 45000, 'Approved non-sale fuel total');
  check(totals.hasPending, 'Pending entries must block finalization');
  check(totals.variance(grossSales: 1200000, money: 1150000, credit: 0) == 0,
      'Balanced example');
  check(
      totals.variance(grossSales: 1200000, money: 1140000, credit: 0) == -10000,
      'Shortage example');
  check(
      totals.variance(grossSales: 1200000, money: 1160000, credit: 0) == 10000,
      'Excess example');
  check(
      totals.variance(grossSales: 1200000, money: 1050000, credit: 100000) == 0,
      'Credit counted once');
  final restored = ShiftAdjustment.fromJson(entries.first.toJson());
  check(
      restored.amount == 5000 &&
          restored.status == 'approved' &&
          restored.shiftId == 'fixture-shift',
      'Serialization');
  print('8 shift-adjustment arithmetic and serialization checks passed.');
}
