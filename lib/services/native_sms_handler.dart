import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction_model.dart';

class NativeSmsService with ChangeNotifier {
  // Platform channels
  static const MethodChannel _methodChannel = MethodChannel(
    'com.upi.expense.tracker/sms',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.upi.expense.tracker/sms_stream',
  );

  // State management
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  List<String> _smsLogs = [];
  List<TransactionModel> _processedTransactions = [];
  StreamSubscription<String>? _smsStreamSubscription;

  // Getters
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  bool get isInitialized => _isInitialized;
  List<String> get smsLogs => _smsLogs;
  List<TransactionModel> get processedTransactions => _processedTransactions;

  // UPI Transaction Patterns
  final Map<String, RegExp> _upiPatterns = {
    'debit': RegExp(
      r'(?:(?:Rs\.?|INR|₹)\s*)(\d+(?:\.\d{1,2})?)\s*(?:debited|paid|spent|cash withdrawal|sent|charged|deducted).*?(?:to|for|from|at|via|by)\s*(.*?)(?:\s*(?:UPI|on|@|\.|,|$))',
      caseSensitive: false,
    ),
    'credit': RegExp(
      r'(?:(?:Rs\.?|INR|₹)\s*)(\d+(?:\.\d{1,2})?)\s*(?:credited|received|added|deposited).*?(?:from|by|to)\s*(.*?)(?:\s*(?:UPI|on|@|\.|,|$))',
      caseSensitive: false,
    ),
    // Add this new pattern for "debited by" format
    'debit_by': RegExp(
      r'(?:A\/c|Account|Acct).*?(?:Rs\.?|INR|₹)\s*(\d+(?:\.\d{1,2})?)\s*(?:debited|deducted)\s*by',
      caseSensitive: false,
    ),
  };

  // Bank-specific patterns
  final Map<String, RegExp> _bankPatterns = {
    'HDFC': RegExp(r'HDFC\s*Bank', caseSensitive: false),
    'ICICI': RegExp(r'ICICI\s*Bank', caseSensitive: false),
    'SBI': RegExp(r'SBI', caseSensitive: false),
    'Axis': RegExp(r'Axis\s*Bank', caseSensitive: false),
    'Kotak': RegExp(r'Kotak\s*Bank', caseSensitive: false),
    'Yes': RegExp(r'Yes\s*Bank', caseSensitive: false),
    'PNB': RegExp(r'PNB', caseSensitive: false),
    'BOI': RegExp(r'BOI', caseSensitive: false),
    'Canara': RegExp(r'Canara\s*Bank', caseSensitive: false),
  };

  // Merchant categorization patterns
  final Map<String, List<RegExp>> _merchantPatterns = {
    'Food': [
      RegExp(r'zomato', caseSensitive: false),
      RegExp(r'swiggy', caseSensitive: false),
      RegExp(r'mcdonalds', caseSensitive: false),
      RegExp(r'kfc', caseSensitive: false),
      RegExp(r'dominos', caseSensitive: false),
      RegExp(r'pizza', caseSensitive: false),
      RegExp(r'burger', caseSensitive: false),
      RegExp(r'cafe', caseSensitive: false),
      RegExp(r'restaurant', caseSensitive: false),
      RegExp(r'starbucks', caseSensitive: false),
      RegExp(r'food', caseSensitive: false),
    ],
    'Shopping': [
      RegExp(r'amazon', caseSensitive: false),
      RegExp(r'flipkart', caseSensitive: false),
      RegExp(r'myntra', caseSensitive: false),
      RegExp(r'ajio', caseSensitive: false),
      RegExp(r'bigbasket', caseSensitive: false),
      RegExp(r'grofers', caseSensitive: false),
      RegExp(r'zepto', caseSensitive: false),
      RegExp(r'shopping', caseSensitive: false),
    ],
    'Transport': [
      RegExp(r'ola', caseSensitive: false),
      RegExp(r'uber', caseSensitive: false),
      RegExp(r'rapido', caseSensitive: false),
      RegExp(r'metro', caseSensitive: false),
      RegExp(r'irctc', caseSensitive: false),
      RegExp(r'redbus', caseSensitive: false),
      RegExp(r'bus', caseSensitive: false),
      RegExp(r'train', caseSensitive: false),
      RegExp(r'flight', caseSensitive: false),
      RegExp(r'taxi', caseSensitive: false),
    ],
    'Recharge': [
      RegExp(r'recharge', caseSensitive: false),
      RegExp(r'jio', caseSensitive: false),
      RegExp(r'airtel', caseSensitive: false),
      RegExp(r'vi|vodafone', caseSensitive: false),
      RegExp(r'dth', caseSensitive: false),
      RegExp(r'electricity', caseSensitive: false),
      RegExp(r'water', caseSensitive: false),
      RegExp(r'gas', caseSensitive: false),
      RegExp(r'bill', caseSensitive: false),
    ],
    'Subscription': [
      RegExp(r'netflix', caseSensitive: false),
      RegExp(r'spotify', caseSensitive: false),
      RegExp(r'hotstar', caseSensitive: false),
      RegExp(r'prime\s*?video', caseSensitive: false),
      RegExp(r'youtube\s*?premium', caseSensitive: false),
      RegExp(r'disney\+', caseSensitive: false),
      RegExp(r'apple\s*?music', caseSensitive: false),
      RegExp(r'subscription', caseSensitive: false),
    ],
    'Rent': [
      RegExp(r'rent', caseSensitive: false),
      RegExp(r'house\s*?rent', caseSensitive: false),
    ],
    'EMI': [
      RegExp(r'emi', caseSensitive: false),
      RegExp(r'loan', caseSensitive: false),
    ],
    'Investment': [
      RegExp(r'mutual\s*?fund', caseSensitive: false),
      RegExp(r'stock', caseSensitive: false),
      RegExp(r'investment', caseSensitive: false),
      RegExp(r'sip', caseSensitive: false),
    ],
    'Cash Withdrawal': [
      RegExp(r'cash\s*?withdrawal', caseSensitive: false),
      RegExp(r'atm\s*?withdrawal', caseSensitive: false),
    ],
  };

  /// Initialize the SMS service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      _addLog('Native SMS Service Initialized');
      notifyListeners();
    } catch (e) {
      _addLog('Error initializing SMS service: $e');
    }
  }

  /// Check and request SMS permissions
  Future<bool> checkAndRequestPermissions() async {
    try {
      PermissionStatus status = await Permission.sms.status;

      if (status.isDenied || status.isRestricted) {
        _addLog('Requesting SMS permission...');
        status = await Permission.sms.request();
      }

      if (status.isGranted) {
        _addLog('SMS permission granted');
        return true;
      } else {
        _addLog('SMS permission denied');
        return false;
      }
    } catch (e) {
      _addLog('Error checking permissions: $e');
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Start listening to incoming SMS
  Future<void> startListening() async {
    try {
      if (_isListening) return;

      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        _addLog('Cannot start listening - permission denied');
        return;
      }

      _isListening = true;
      _addLog('=== STARTING NATIVE SMS LISTENING ===');

      // Start listening via event channel
      _smsStreamSubscription = _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) {
            _addLog('Received from EventChannel: $event');
            return event.toString();
          })
          .listen(
            _processIncomingSms,
            onError: (error) {
              _addLog('EventChannel error: $error');
            },
          );

      _addLog('EventChannel subscription created');
      notifyListeners();
    } catch (e) {
      _isListening = false;
      _addLog('Error starting SMS tracking: $e');
      notifyListeners();
    }
  }

  /// Stop listening to incoming SMS
  Future<void> stopListening() async {
    try {
      if (!_isListening) return;

      _isListening = false;
      await _smsStreamSubscription?.cancel();
      _smsStreamSubscription = null;

      _addLog('SMS tracking stopped');
      notifyListeners();
    } catch (e) {
      _addLog('Error stopping SMS tracking: $e');
      notifyListeners();
    }
  }

  /// Read existing SMS from device
  Future<void> loadExistingSms({int limit = 100}) async {
    try {
      _isProcessing = true;
      _addLog('Reading existing SMS...');
      notifyListeners();

      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return;

      // Call native method to read SMS
      final List<dynamic> smsList = await _methodChannel.invokeMethod(
        'readExistingSms',
        {'limit': limit},
      );

      // Parse each SMS
      int processedCount = 0;
      for (final smsData in smsList) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(smsData);
        final String smsBody = data['body']?.toString() ?? '';
        final String address = data['address']?.toString() ?? '';
        final int timestamp = data['timestamp'] is int ? data['timestamp'] : 0;

        final transaction = _parseSms(smsBody);
        if (transaction != null) {
          // Update timestamp from SMS if available
          if (timestamp > 0) {
            transaction.timestamp = DateTime.fromMillisecondsSinceEpoch(
              timestamp,
            );
          }

          _processedTransactions.insert(0, transaction);
          processedCount++;

          _addLog('Loaded transaction: ₹${transaction.amount} from $address');
        }
      }

      _addLog('Loaded $processedCount transactions from SMS history');
    } on PlatformException catch (e) {
      _addLog('Failed to read SMS: ${e.message}');
    } catch (e) {
      _addLog('Error loading existing SMS: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Process incoming SMS from stream
  void _processIncomingSms(String smsBody) {
    try {
      _isProcessing = true;
      notifyListeners();

      // Debug logging
      _debugSmsParsing(smsBody);

      final transaction = _parseSms(smsBody);
      if (transaction != null) {
        _processedTransactions.insert(0, transaction);
        _addLog(
          '✅ New Transaction: ₹${transaction.amount} to ${transaction.merchant}',
        );
      } else {
        _addLog('❌ Could not parse SMS as transaction');
      }
    } catch (e) {
      _addLog('Error processing incoming SMS: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Manually process an SMS message (for testing)
  Future<TransactionModel?> processSmsMessage(String smsBody) async {
    try {
      _isProcessing = true;
      notifyListeners();

      final transaction = _parseSms(smsBody);
      if (transaction != null) {
        _processedTransactions.insert(0, transaction);
        _addLog(
          'Processed transaction: ₹${transaction.amount} to ${transaction.merchant}',
        );
      } else {
        _addLog('Ignored non-transaction SMS');
      }

      return transaction;
    } catch (e) {
      _addLog('Error processing SMS: $e');
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Synchronous parsing (for testing)
  TransactionModel? parseSmsSync(String smsBody) {
    return _parseSms(smsBody);
  }

  /// Core SMS parsing logic
  TransactionModel? _parseSms(String smsBody) {
    try {
      final normalizedBody = smsBody.replaceAll('\n', ' ').trim();

      if (!_isTransactionSms(normalizedBody)) return null;

      String type = 'debit';
      double? amount;
      String? merchant;
      String? bankName;

      // Try all UPI patterns
      for (final entry in _upiPatterns.entries) {
        final match = entry.value.firstMatch(normalizedBody);
        if (match != null && match.groupCount >= 1) {
          type = entry.key.contains('debit') ? 'debit' : 'credit';
          final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
          amount = double.tryParse(amountStr);

          // For "debited by" pattern, there might not be a merchant
          if (match.groupCount >= 2) {
            merchant = match.group(2)?.trim();
          }

          // Check if it's a bank transaction (not UPI)
          if (normalizedBody.contains('CBoI') ||
              normalizedBody.contains('Canara') ||
              normalizedBody.contains('Ac') ||
              normalizedBody.contains('Account')) {
            merchant = 'Bank Transfer';
          }

          break;
        }
      }

      // Fallback: try to extract amount using general pattern
      if (amount == null || amount == 0) {
        final amountPatterns = [
          RegExp(
            r'(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
            caseSensitive: false,
          ),
          RegExp(r'debited by\s*(?:Rs\.?|INR|₹)\s*(\d+)', caseSensitive: false),
          RegExp(
            r'(\d+(?:\.\d{1,2})?)\s*(?:Rs\.?|INR|₹)',
            caseSensitive: false,
          ),
        ];

        for (final pattern in amountPatterns) {
          final match = pattern.firstMatch(normalizedBody);
          if (match != null) {
            final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
            amount = double.tryParse(amountStr);
            if (amount != null && amount > 0) break;
          }
        }

        if (amount == null || amount == 0) return null;
      }

      // Extract bank name
      for (final entry in _bankPatterns.entries) {
        if (entry.value.hasMatch(normalizedBody)) {
          bankName = entry.key;
          break;
        }
      }

      // If no bank detected but mentions CBoI
      if (bankName == null && normalizedBody.contains('CBoI')) {
        bankName = 'Canara';
      }

      // Categorize based on SMS content
      String category = 'Misc';
      merchant = merchant ?? _extractMerchantFromSms(normalizedBody);

      // If merchant is still null, try to determine from context
      if (merchant == null || merchant == 'Unknown') {
        if (normalizedBody.contains('UPI') || normalizedBody.contains('@')) {
          merchant = 'UPI Transfer';
          category = 'Transfer';
        } else if (normalizedBody.contains('debit') ||
            normalizedBody.contains('deducted')) {
          merchant = 'Bank Debit';
          category = 'Cash Withdrawal';
        } else if (normalizedBody.contains('credited') ||
            normalizedBody.contains('received')) {
          merchant = 'Bank Credit';
          category = 'Misc';
        }
      }

      // Check for UPI ID
      String? upiId;
      final upiMatch = RegExp(
        r'@(okaxis|okhdfcbank|oksbi|okicici|ybl|axl|ibl|paytm)',
      ).firstMatch(normalizedBody);
      if (upiMatch != null) {
        final upiPattern = RegExp(r'(\S+@\S+)').firstMatch(normalizedBody);
        upiId = upiPattern?.group(1);
      }

      // Extract timestamp
      DateTime timestamp = DateTime.now();

      return TransactionModel(
        amount: amount ?? 0,
        type: type,
        category: category,
        merchant: merchant ?? 'Bank Transaction',
        timestamp: timestamp,
        upiId: upiId,
        bankName: bankName,
        smsBody: normalizedBody,
        isSubscription: false,
        isEMI: false,
        paymentMethod: bankName != null ? 'Bank Transfer' : 'UPI',
      );
    } catch (e) {
      _addLog('Error parsing SMS: $e');
      return null;
    }
  }

  /// Check if SMS is a transaction message
  bool _isTransactionSms(String smsBody) {
    final keywords = [
      'debited',
      'credited',
      'paid',
      'received',
      'spent',
      'withdrawal',
      'transfer',
      'upi',
      'transaction',
      'rs ',
      'rs.',
      'inr ',
      '₹',
      'amount',
      'sent to',
      'received from',
      'debit',
      'credit',
      'a/c',
      'account',
      'acct',
      'balance',
      'bal:',
      'txn',
      'transaction',
    ];

    return keywords.any(
      (keyword) => smsBody.toLowerCase().contains(keyword.toLowerCase()),
    );
  }

  void _debugSmsParsing(String smsBody) {
    _addLog('=== SMS DEBUG START ===');
    _addLog('Raw SMS: $smsBody');

    final normalizedBody = smsBody.replaceAll('\n', ' ').trim();
    _addLog('Normalized: $normalizedBody');

    // Test all patterns
    for (final entry in _upiPatterns.entries) {
      final match = entry.value.firstMatch(normalizedBody);
      if (match != null) {
        _addLog('Pattern "${entry.key}" matched!');
        _addLog('Groups: ${match.groupCount}');
        for (int i = 0; i <= match.groupCount; i++) {
          _addLog('Group $i: ${match.group(i)}');
        }
      }
    }

    // Check if it's a transaction SMS
    _addLog('Is transaction SMS: ${_isTransactionSms(normalizedBody)}');

    _addLog('=== SMS DEBUG END ===');
  }

  /// Extract merchant name from SMS
  String? _extractMerchantFromSms(String smsBody) {
    final patterns = [
      RegExp(r'to\s+(.*?)\s+(?:on|via|using|@|\.|,)', caseSensitive: false),
      RegExp(r'at\s+(.*?)\s+(?:on|via|using|\.|,)', caseSensitive: false),
      RegExp(r'for\s+(.*?)\s+(?:on|via|using|\.|,)', caseSensitive: false),
      RegExp(r'from\s+(.*?)\s+(?:on|via|using|\.|,)', caseSensitive: false),
      RegExp(r'paid to\s+(.*?)\s+(?:via|using)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(smsBody);
      if (match != null && match.group(1) != null) {
        String merchant = match.group(1)!.trim();
        // Clean up merchant name
        merchant = merchant.replaceAll(RegExp(r'\s+@\S+$'), '');
        merchant = merchant.replaceAll(RegExp(r'\s+via\s+.*$'), '');
        merchant = merchant.replaceAll(RegExp(r'\s+using\s+.*$'), '');
        merchant = merchant.replaceAll(RegExp(r'\s+on\s+.*$'), '');
        return merchant;
      }
    }

    return null;
  }

  /// Test the SMS parsing with sample data
  Future<void> testSmsParsing() async {
    _addLog('Starting SMS parsing test...');

    final testMessages = [
      "Rs 150 debited via UPI to ZOMATO@okaxis. Avl bal: ₹5,250",
      "INR 2999 paid to AMAZON via UPI. Ref: 1234567890",
      "Your a/c XX1234 credited with Rs 45,000 from GOOGLE PAY",
      "Rs 299 debited for NETFLIX subscription. Auto-debit on 15th every month",
      "EMI of Rs 4500 debited for PERSONAL LOAN from HDFC Bank",
      "Rs 350 spent at UBER via UPI. Trip ID: UBER123456",
      "INR 199 paid to SPOTIFY. Subscription renewed",
      "Rs 15000 paid to LANDLORD for rent via UPI",
      "INR 2999 debited for JIO recharge. Thank you!",
    ];

    int successCount = 0;
    for (final message in testMessages) {
      final transaction = parseSmsSync(message);
      if (transaction != null) {
        successCount++;
        _addLog(
          '✓ Parsed: ₹${transaction.amount} - ${transaction.merchant} (${transaction.category})',
        );
      } else {
        _addLog('✗ Failed to parse: ${message.substring(0, 30)}...');
      }
    }

    _addLog(
      'Test completed: $successCount/${testMessages.length} messages parsed successfully',
    );
    notifyListeners();
  }

  /// Clear all processed transactions
  void clearProcessedTransactions() {
    _processedTransactions.clear();
    _addLog('Cleared all transactions');
    notifyListeners();
  }

  /// Clear all SMS logs
  void clearLogs() {
    _smsLogs.clear();
    notifyListeners();
  }

  /// Add log message
  void _addLog(String message) {
    _smsLogs.insert(
      0,
      '${DateTime.now().toString().substring(11, 19)}: $message',
    );
    if (_smsLogs.length > 100) _smsLogs.removeLast();
  }

  @override
  void dispose() {
    _smsStreamSubscription?.cancel();
    super.dispose();
  }
}
