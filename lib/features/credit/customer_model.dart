class Customer {
  final String id;
  final String name;
  final String mobile;
  final double currentBalance;

  Customer({
    required this.id, 
    required this.name, 
    required this.mobile, 
    this.currentBalance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'currentBalance': currentBalance,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown',
      mobile: map['mobile'] ?? '',
      currentBalance: (map['currentBalance'] ?? 0.0).toDouble(),
    );
  }
}
