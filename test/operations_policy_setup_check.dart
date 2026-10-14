import '../lib/models/operations_policy.dart';

void main() {
  OperationsPolicy policy(
          double cashier, double manager, List<String> categories) =>
      OperationsPolicy(
          revision: 1,
          cashierApprovalLimit: cashier,
          managerApprovalLimit: manager,
          expenseCategories: categories);
  void rejected(void Function() action) {
    try {
      action();
    } on FormatException {
      return;
    }
    throw StateError('Invalid configuration was accepted');
  }

  final saved = policy(3500, 27500, ['Maintenance', 'Cleaning']);
  if (saved.cashierApprovalLimit != 3500 || saved.managerApprovalLimit != 27500)
    throw StateError('Operator-defined limits were changed');
  rejected(() => policy(-1, 20, ['Maintenance']));
  rejected(() => policy(20, 10, ['Maintenance']));
  rejected(() => policy(double.nan, 10, ['Maintenance']));
  rejected(() => policy(0, double.infinity, ['Maintenance']));
  rejected(() => policy(0, 10, []));
  rejected(() => policy(0, 10, ['Maintenance', 'Maintenance']));
  rejected(() => policy(0, 10, [' Maintenance']));
  rejected(() => policy(0, 10, ['x' * 101]));
  rejected(() => policy(0, 1000000000000, ['Maintenance']));
  if (policy(0, 0, ['Maintenance']).cashierApprovalLimit != 0)
    throw StateError('Explicit zero limit should be valid');
  print('11 operator-defined approval-policy validation checks passed.');
}
