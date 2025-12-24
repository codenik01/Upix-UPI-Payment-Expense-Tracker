import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:upix/services/native_sms_handler.dart';
import '../../services/expense_service.dart';
// Changed import
import '../../services/auth_service.dart';
import 'transaction_list_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import '../../data/test_sms_data.dart';
import '../../models/transaction_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTimeRange? _selectedRange;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Wait for the next frame to ensure build is complete
    await Future.delayed(Duration.zero);

    final smsService = Provider.of<NativeSmsService>(
      context,
      listen: false,
    ); // Changed type
    await smsService.initialize();

    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _processTestSms() async {
    final smsService = Provider.of<NativeSmsService>(
      context,
      listen: false,
    ); // Changed type
    final expenseService = Provider.of<ExpenseService>(context, listen: false);

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 12),
            Text('Processing SMS messages...'),
          ],
        ),
        duration: Duration(seconds: 5),
      ),
    );

    int processedCount = 0;

    for (final sms in testSmsMessages) {
      final transaction = smsService.parseSmsSync(sms); // Changed method
      if (transaction != null) {
        expenseService.addTransaction(transaction);
        processedCount++;
      }

      // Small delay between processing to make it visible
      await Future.delayed(const Duration(milliseconds: 100));
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Processed $processedCount test SMS messages'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addManualTransaction() {
    showDialog(
      context: context,
      builder: (context) {
        final amountController = TextEditingController();
        final merchantController = TextEditingController();
        String selectedCategory = 'Food';
        String selectedType = 'debit';

        final List<String> categories = [
          'Food',
          'Shopping',
          'Transport',
          'Recharge',
          'Subscription',
          'Rent',
          'EMI',
          'Misc',
        ];

        return AlertDialog(
          title: const Text('Add Manual Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: merchantController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant/Description',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value!;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(
                      value: 'debit',
                      child: Text('Debit (Spent)'),
                    ),
                    DropdownMenuItem(
                      value: 'credit',
                      child: Text('Credit (Received)'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Transaction Type',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                final merchant = merchantController.text.trim();

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (merchant.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter merchant name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final expenseService = Provider.of<ExpenseService>(
                  context,
                  listen: false,
                );
                final transaction = TransactionModel(
                  amount: amount,
                  type: selectedType,
                  category: selectedCategory,
                  merchant: merchant,
                  timestamp: DateTime.now(),
                  paymentMethod: 'Manual',
                  note: 'Manually added transaction',
                );

                expenseService.addTransaction(transaction);

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Added transaction: ₹$amount to $merchant'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseService = Provider.of<ExpenseService>(context);
    final authService = Provider.of<AuthService>(context);
    final smsService = Provider.of<NativeSmsService>(context); // Changed type

    // Check if user is authenticated
    if (authService.currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Loading user data...'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  authService.signOut();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    final totalSpent = expenseService.getTotalSpent(_selectedRange);
    final totalReceived = expenseService.getTotalReceived(_selectedRange);
    final categorySpending = expenseService.getCategorySpending();
    final topExpenses = expenseService.getTopExpenses(3);

    final List<Widget> _screens = [
      _buildDashboard(
        expenseService,
        smsService,
        totalSpent,
        totalReceived,
        categorySpending,
        topExpenses,
      ),
      const TransactionListScreen(),
      const InsightsScreen(),
      SettingsScreen(user: authService.currentUser!),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Expense Tracker'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: _isInitialized
          ? _screens[_selectedIndex]
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(
    ExpenseService expenseService,
    NativeSmsService smsService, // Changed type
    double totalSpent,
    double totalReceived,
    Map<String, double> categorySpending,
    List<TransactionModel> topExpenses,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Spending',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${totalSpent.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            Text(
                              'Spent | ₹${totalReceived.toStringAsFixed(2)} Received',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TransactionListScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Spending by Category
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Spending by Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: categorySpending.isEmpty
                          ? const Center(child: Text('No data available'))
                          : SfCircularChart(
                              series: <CircularSeries>[
                                DoughnutSeries<
                                  MapEntry<String, double>,
                                  String
                                >(
                                  dataSource: categorySpending.entries.toList(),
                                  xValueMapper: (entry, _) => entry.key,
                                  yValueMapper: (entry, _) => entry.value,
                                  dataLabelSettings: const DataLabelSettings(
                                    isVisible: true,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Expenses
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Expenses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (topExpenses.isEmpty)
                      const Center(child: Text('No expenses yet'))
                    else
                      ...topExpenses.map(
                        (expense) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getCategoryColor(
                              expense.category,
                            ),
                            child: Icon(
                              _getCategoryIcon(expense.category),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(expense.merchant),
                          subtitle: Text(expense.category),
                          trailing: Text(
                            '₹${expense.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: expense.type == 'debit'
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SMS Controls Card (Updated)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SMS Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              smsService.isListening ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: smsService.isListening
                                    ? const Color(0xFF10B981)
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${smsService.processedTransactions.length} SMS processed',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        Switch(
                          value: smsService.isListening,
                          onChanged: (value) async {
                            if (value) {
                              await smsService.startListening();
                            } else {
                              await smsService.stopListening();
                            }
                          },
                          activeColor: const Color(0xFF4F46E5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await smsService.loadExistingSms(limit: 50);
                            },
                            icon: const Icon(Icons.history),
                            label: const Text('Load Past SMS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              smsService.testSmsParsing();
                            },
                            icon: const Icon(Icons.bug_report),
                            label: const Text('Test'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Demo Tools Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Demo Tools',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Test SMS detection and add demo data:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _processTestSms,
                      icon: const Icon(Icons.sms),
                      label: const Text('Process Test SMS Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _addManualTransaction,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Manual Transaction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Clear all transactions
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Clear All Data'),
                            content: const Text(
                              'Are you sure you want to clear all transactions? This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  final expenseService =
                                      Provider.of<ExpenseService>(
                                        context,
                                        listen: false,
                                      );
                                  final smsService =
                                      Provider.of<NativeSmsService>(
                                        context,
                                        listen: false,
                                      );

                                  // Clear SMS service data
                                  smsService.clearProcessedTransactions();
                                  smsService.clearLogs();

                                  // Note: For Firestore data, you need to implement delete in ExpenseService
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Cleared local SMS data. Firestore data remains.',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Clear SMS Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // View SMS Logs Button
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('SMS Logs'),
                            content: SizedBox(
                              width: double.maxFinite,
                              height: 400,
                              child: ListView.builder(
                                itemCount: smsService.smsLogs.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    title: Text(smsService.smsLogs[index]),
                                    dense: true,
                                  );
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('View SMS Logs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Food': Colors.orange,
      'Shopping': Colors.purple,
      'Transport': Colors.blue,
      'Recharge': Colors.green,
      'Subscription': Colors.pink,
      'Rent': Colors.brown,
      'EMI': Colors.red,
      'Misc': Colors.grey,
    };
    return colors[category] ?? Colors.grey;
  }

  IconData _getCategoryIcon(String category) {
    final icons = {
      'Food': Icons.restaurant,
      'Shopping': Icons.shopping_bag,
      'Transport': Icons.directions_car,
      'Recharge': Icons.phone_android,
      'Subscription': Icons.subscriptions,
      'Rent': Icons.home,
      'EMI': Icons.money,
      'Misc': Icons.more_horiz,
    };
    return icons[category] ?? Icons.category;
  }
}
