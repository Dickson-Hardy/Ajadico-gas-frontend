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

  static List<CreditCustomer> getDemoCustomers() {
    return const [
      CreditCustomer(
        id: 'c1',
        name: 'Sample Haulage Ltd',
        outstanding: 1240000.0,
        lastRepayment: '24 Sep',
        dueDate: '15 Oct',
        status: CustomerCreditStatus.current,
      ),
      CreditCustomer(
        id: 'c2',
        name: 'Sample Farms',
        outstanding: 310000.0,
        lastRepayment: '2 Sep',
        dueDate: '30 Sep',
        status: CustomerCreditStatus.overdue,
      ),
      CreditCustomer(
        id: 'c3',
        name: 'Sample Clinic',
        outstanding: 0.0,
        lastRepayment: '29 Sep',
        dueDate: '—',
        status: CustomerCreditStatus.settled,
      ),
    ];
  }
}
