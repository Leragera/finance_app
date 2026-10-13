class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final String type; // income / expense
  final String category;
  final int accountId;
  final DateTime date;

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.accountId,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'accountId': accountId,
      'date': date.toIso8601String(),
    };
  }
}