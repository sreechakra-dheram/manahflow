class MonthlyPayment {
  final String month;
  final double amountLakhs;

  const MonthlyPayment({required this.month, required this.amountLakhs});
}

class VendorOutstanding {
  final String vendorName;
  final double amount;
  final String agingBucket;

  const VendorOutstanding({
    required this.vendorName,
    required this.amount,
    required this.agingBucket,
  });
}

class ProjectExpense {
  final String projectName;
  final double amountLakhs;

  const ProjectExpense({required this.projectName, required this.amountLakhs});
}

const List<MonthlyPayment> kMonthlyPayments = [
  MonthlyPayment(month: 'Apr', amountLakhs: 12.5),
  MonthlyPayment(month: 'May', amountLakhs: 18.3),
  MonthlyPayment(month: 'Jun', amountLakhs: 14.7),
  MonthlyPayment(month: 'Jul', amountLakhs: 22.1),
  MonthlyPayment(month: 'Aug', amountLakhs: 19.8),
  MonthlyPayment(month: 'Sep', amountLakhs: 25.4),
  MonthlyPayment(month: 'Oct', amountLakhs: 28.6),
  MonthlyPayment(month: 'Nov', amountLakhs: 31.2),
  MonthlyPayment(month: 'Dec', amountLakhs: 24.5),
  MonthlyPayment(month: 'Jan', amountLakhs: 35.8),
  MonthlyPayment(month: 'Feb', amountLakhs: 29.3),
  MonthlyPayment(month: 'Mar', amountLakhs: 38.9),
];

const List<VendorOutstanding> kVendorOutstanding = [
  VendorOutstanding(vendorName: 'Sharma Constructions', amount: 485000, agingBucket: '0–30 days'),
  VendorOutstanding(vendorName: 'RK Electricals', amount: 191300, agingBucket: '30–60 days'),
  VendorOutstanding(vendorName: 'Metro Steel Suppliers', amount: 441200, agingBucket: '60–90 days'),
  VendorOutstanding(vendorName: 'Apex Plumbing Works', amount: 314300, agingBucket: '90+ days'),
];

const List<ProjectExpense> kProjectExpenses = [
  ProjectExpense(projectName: 'Whitefield Residential', amountLakhs: 42.5),
  ProjectExpense(projectName: 'MG Road Commercial', amountLakhs: 38.7),
  ProjectExpense(projectName: 'Hebbal Infrastructure', amountLakhs: 29.1),
];
