final List<String> testSmsMessages = [
  "Rs 150 debited via UPI to ZOMATO@okaxis",
  "INR 290.00 paid to SWIGGY from your HDFC Bank account",
  "Your a/c XX1234 credited with Rs 3,000 from GOOGLE PAY",
  "Rs 500 spent at AMAZON via UPI",
  "INR 299 debited for NETFLIX subscription",
  "Rs 250 paid to OLA from your SBI account",
  "Your ICICI Bank a/c debited Rs 199 for SPOTIFY",
  "Rs 1000 received from MANISH KUMAR via UPI",
  "INR 2999 paid for JIO recharge",
  "Rs 15000 rent paid to LANDLORD",
  "EMI of Rs 4500 debited for PERSONAL LOAN",
  "Rs 2499 paid to MYNTRA for shopping",
  "INR 89 debited at STARBUCKS CAFE",
  "Rs 350 Uber ride charged to your account",
  "IRCTC ticket booking of Rs 1200 debited",
];

// Optional: You can also add this function if you want to generate demo transactions
List<Map<String, dynamic>> getTestTransactions() {
  final List<Map<String, dynamic>> transactions = [];
  final now = DateTime.now();

  for (int i = 0; i < 15; i++) {
    final daysAgo = i;
    final date = now.subtract(Duration(days: daysAgo));

    transactions.add({
      'amount': [
        150,
        290,
        500,
        299,
        250,
        199,
        1000,
        2999,
        15000,
        4500,
        2499,
        89,
        350,
        1200,
      ][i % 14],
      'type': i % 5 == 0 ? 'credit' : 'debit',
      'category': [
        'Food',
        'Food',
        'Shopping',
        'Subscription',
        'Transport',
        'Subscription',
        'Recharge',
        'Rent',
        'EMI',
        'Shopping',
        'Food',
        'Transport',
        'Transport',
        'Misc',
      ][i % 14],
      'merchant': [
        'ZOMATO',
        'SWIGGY',
        'AMAZON',
        'NETFLIX',
        'OLA',
        'SPOTIFY',
        'JIO',
        'LANDLORD',
        'BANK',
        'MYNTRA',
        'STARBUCKS',
        'UBER',
        'IRCTC',
        'UNKNOWN',
      ][i % 14],
      'timestamp': date,
      'paymentMethod': 'UPI',
    });
  }

  return transactions;
}
