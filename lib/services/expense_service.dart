import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';

class ExpenseService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<TransactionModel> _transactions = [];
  List<TransactionModel> _filteredTransactions = [];
  String _filterCategory = 'All';
  DateTimeRange? _filterDateRange;

  List<TransactionModel> get transactions => _filteredTransactions;
  List<TransactionModel> get allTransactions => _transactions;

  ExpenseService() {
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final query = await _firestore
          .collection('transactions')
          .doc(user.uid)
          .collection('user_transactions')
          .orderBy('timestamp', descending: true)
          .get();

      _transactions = query.docs
          .map((doc) => TransactionModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();

      _applyFilters();
      notifyListeners();
    } catch (e) {
      print('Error loading transactions: $e');
    }
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final docRef = _firestore
          .collection('transactions')
          .doc(user.uid)
          .collection('user_transactions')
          .doc();

      transaction.id = docRef.id;

      await docRef.set(transaction.toMap());

      _transactions.insert(0, transaction);
      _applyFilters();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('transactions')
          .doc(user.uid)
          .collection('user_transactions')
          .doc(transactionId)
          .delete();

      _transactions.removeWhere((t) => t.id == transactionId);
      _applyFilters();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('transactions')
          .doc(user.uid)
          .collection('user_transactions')
          .doc(transaction.id)
          .update(transaction.toMap());

      final index = _transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _transactions[index] = transaction;
      }

      _applyFilters();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void filterByCategory(String category) {
    _filterCategory = category;
    _applyFilters();
  }

  void filterByDateRange(DateTimeRange? range) {
    _filterDateRange = range;
    _applyFilters();
  }

  void _applyFilters() {
    List<TransactionModel> filtered = _transactions;

    if (_filterCategory != 'All') {
      filtered = filtered.where((t) => t.category == _filterCategory).toList();
    }

    if (_filterDateRange != null) {
      filtered = filtered.where((t) {
        return t.timestamp.isAfter(_filterDateRange!.start) &&
            t.timestamp.isBefore(_filterDateRange!.end);
      }).toList();
    }

    _filteredTransactions = filtered;
    notifyListeners();
  }

  // Analytics methods
  Map<String, double> getCategorySpending() {
    final Map<String, double> spending = {};

    for (final transaction in _transactions.where((t) => t.type == 'debit')) {
      spending[transaction.category] =
          (spending[transaction.category] ?? 0) + transaction.amount;
    }

    return spending;
  }

  double getTotalSpent(DateTimeRange? range) {
    List<TransactionModel> transactions = _transactions
        .where((t) => t.type == 'debit')
        .toList();

    if (range != null) {
      transactions = transactions.where((t) {
        return t.timestamp.isAfter(range.start) &&
            t.timestamp.isBefore(range.end);
      }).toList();
    }

    return transactions.fold(0, (sum, t) => sum + t.amount);
  }

  double getTotalReceived(DateTimeRange? range) {
    List<TransactionModel> transactions = _transactions
        .where((t) => t.type == 'credit')
        .toList();

    if (range != null) {
      transactions = transactions.where((t) {
        return t.timestamp.isAfter(range.start) &&
            t.timestamp.isBefore(range.end);
      }).toList();
    }

    return transactions.fold(0, (sum, t) => sum + t.amount);
  }

  List<TransactionModel> getTopExpenses(int count) {
    final debitTransactions = _transactions
        .where((t) => t.type == 'debit')
        .toList();

    debitTransactions.sort((a, b) => b.amount.compareTo(a.amount));

    return debitTransactions.take(count).toList();
  }

  List<TransactionModel> getSubscriptions() {
    return _transactions.where((t) => t.isSubscription).toList();
  }

  Map<String, List<TransactionModel>> groupByMerchant() {
    final Map<String, List<TransactionModel>> groups = {};

    for (final transaction in _transactions) {
      final merchant = transaction.merchant;
      if (!groups.containsKey(merchant)) {
        groups[merchant] = [];
      }
      groups[merchant]!.add(transaction);
    }

    return groups;
  }
}
