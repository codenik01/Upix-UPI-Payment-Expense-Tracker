class UserModel {
  String uid;
  String name;
  String email;
  DateTime createdAt;
  List<String> categories;
  bool isPremium;
  Map<String, dynamic> settings;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    this.categories = const [
      'Food',
      'Shopping',
      'Transport',
      'Recharge',
      'Subscription',
      'Rent',
      'EMI',
      'Investment',
      'Cash Withdrawal',
      'Misc',
    ],
    this.isPremium = false,
    this.settings = const {
      'smsTracking': true,
      'autoCategorization': true,
      'offlineMode': true,
      'currency': 'INR',
      'language': 'English',
      'bharatMode': false,
    },
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      name: map['name'],
      email: map['email'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      categories: List<String>.from(map['categories'] ?? []),
      isPremium: map['isPremium'] ?? false,
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'categories': categories,
      'isPremium': isPremium,
      'settings': settings,
    };
  }
}
