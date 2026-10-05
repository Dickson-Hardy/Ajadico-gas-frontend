enum CustomerCreditStatus {
  current,
  overdue,
  settled,
}

class CreditCustomer {
  final String id;
  final String name;
  final double outstanding;
  final String lastRepayment;
  final String dueDate;
  final CustomerCreditStatus status;

  const CreditCustomer({
    required this.id,
    required this.name,
    required this.outstanding,
    required this.lastRepayment,
    required this.dueDate,
    required this.status,
  });

  static List<CreditCustomer> getDefaultCustomers() {
    return const [];
  }
}
