class OperationsPolicy {
  final int revision;
  final double cashierApprovalLimit;
  final double managerApprovalLimit;
  final List<String> expenseCategories;

  OperationsPolicy({
    required this.revision,
    required this.cashierApprovalLimit,
    required this.managerApprovalLimit,
    required List<String> expenseCategories,
  }) : expenseCategories = List.unmodifiable(expenseCategories) {
    if (revision < 1 ||
        !cashierApprovalLimit.isFinite ||
        !managerApprovalLimit.isFinite ||
        cashierApprovalLimit < 0 ||
        managerApprovalLimit < cashierApprovalLimit ||
        managerApprovalLimit >= 1000000000000 ||
        expenseCategories.isEmpty ||
        expenseCategories.length > 50 ||
        expenseCategories.any((value) =>
            value.trim().isEmpty ||
            value != value.trim() ||
            value.length > 100) ||
        expenseCategories.toSet().length != expenseCategories.length) {
      throw const FormatException('Invalid operational policy');
    }
  }

  factory OperationsPolicy.fromJson(Map<String, dynamic> json) =>
      OperationsPolicy(
        revision: (json['revision'] as num).toInt(),
        cashierApprovalLimit:
            (json['cashier_approval_limit'] as num).toDouble(),
        managerApprovalLimit:
            (json['manager_approval_limit'] as num).toDouble(),
        expenseCategories: (json['expense_categories'] as List).cast<String>(),
      );
}
