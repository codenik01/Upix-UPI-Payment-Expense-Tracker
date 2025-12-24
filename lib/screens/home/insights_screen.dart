import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../services/expense_service.dart';
import '../../models/transaction_model.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  _InsightsScreenState createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _timeRange = 'This Month';
  final List<String> _timeRanges = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
    'All Time',
  ];

  @override
  Widget build(BuildContext context) {
    final expenseService = Provider.of<ExpenseService>(context);
    final transactions = expenseService.allTransactions;
    final categorySpending = expenseService.getCategorySpending();

    final dailyData = _getDailyData(transactions);
    final monthlyData = _getMonthlyData(transactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          DropdownButton<String>(
            value: _timeRange,
            onChanged: (value) {
              setState(() => _timeRange = value!);
            },
            items: _timeRanges.map((range) {
              return DropdownMenuItem(value: range, child: Text(range));
            }).toList(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monthly Trend Chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Spending Trend',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: SfCartesianChart(
                        primaryXAxis: CategoryAxis(),
                        series: <CartesianSeries>[
                          LineSeries<Map<String, dynamic>, String>(
                            dataSource: monthlyData,
                            xValueMapper: (Map<String, dynamic> data, _) =>
                                data['month'] as String,
                            yValueMapper: (Map<String, dynamic> data, _) =>
                                data['amount'] as double,
                            name: 'Spending',
                            color: const Color(0xFF4F46E5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Distribution
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category Distribution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...categorySpending.entries.map((entry) {
                      final total = categorySpending.values.fold(
                        0.0,
                        (a, b) => a + b,
                      );
                      final percentage = total > 0
                          ? (entry.value / total) * 100
                          : 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(entry.key)),
                            Expanded(
                              flex: 5,
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: Colors.grey[200],
                                color: _getCategoryColor(entry.key),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${percentage.toStringAsFixed(1)}%',
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // AI Suggestions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Suggestions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSuggestionCard(
                      'Food expenses are 40% higher than last month. Consider cooking at home.',
                      Icons.restaurant,
                      Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    _buildSuggestionCard(
                      'You have 3 active subscriptions costing ₹799/month.',
                      Icons.subscriptions,
                      Colors.pink,
                    ),
                    const SizedBox(height: 8),
                    _buildSuggestionCard(
                      'Phone recharge due in 3 days.',
                      Icons.phone_android,
                      Colors.green,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getDailyData(
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();
    final data = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final daySpent = transactions
          .where(
            (t) =>
                t.type == 'debit' &&
                t.timestamp.year == date.year &&
                t.timestamp.month == date.month &&
                t.timestamp.day == date.day,
          )
          .fold(0.0, (sum, t) => sum + t.amount);

      data.add({'day': _getDayName(date.weekday), 'amount': daySpent});
    }

    return data;
  }

  List<Map<String, dynamic>> _getMonthlyData(
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();
    final data = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthSpent = transactions
          .where(
            (t) =>
                t.type == 'debit' &&
                t.timestamp.year == date.year &&
                t.timestamp.month == date.month,
          )
          .fold(0.0, (sum, t) => sum + t.amount);

      data.add({
        'month': '${_getMonthName(date.month)} ${date.year}',
        'amount': monthSpent,
      });
    }

    return data;
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
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

  Widget _buildSuggestionCard(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
