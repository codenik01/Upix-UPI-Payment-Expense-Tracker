class TransactionModel {
  String? id;
  double amount;
  String type; // 'debit' or 'credit'
  String category;
  String merchant;
  DateTime timestamp;
  String? upiId;
  String? paymentMethod;
  String? bankName;
  String? note;
  bool isSubscription;
  bool isEMI;
  String? subscriptionId;
  String? smsBody;

  TransactionModel({
    this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.timestamp,
    this.upiId,
    this.paymentMethod = 'UPI',
    this.bankName,
    this.note,
    this.isSubscription = false,
    this.isEMI = false,
    this.subscriptionId,
    this.smsBody,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      amount: map['amount']?.toDouble() ?? 0.0,
      type: map['type'] ?? 'debit',
      category: map['category'] ?? 'Misc',
      merchant: map['merchant'] ?? 'Unknown',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      upiId: map['upiId'],
      paymentMethod: map['paymentMethod'] ?? 'UPI',
      bankName: map['bankName'],
      note: map['note'],
      isSubscription: map['isSubscription'] ?? false,
      isEMI: map['isEMI'] ?? false,
      subscriptionId: map['subscriptionId'],
      smsBody: map['smsBody'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'category': category,
      'merchant': merchant,
      'timestamp': timestamp.toIso8601String(),
      'upiId': upiId,
      'paymentMethod': paymentMethod,
      'bankName': bankName,
      'note': note,
      'isSubscription': isSubscription,
      'isEMI': isEMI,
      'subscriptionId': subscriptionId,
      'smsBody': smsBody,
    };
  }
}
