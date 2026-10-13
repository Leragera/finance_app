import '../database/db_helper.dart';

class LimitCheckerService {
  final DBHelper _db = DBHelper.instance;

  /// Проверить, не превышен ли лимит категории
  Future<Map<String, dynamic>> checkCategoryLimit(
    String category,
    double newExpense,
  ) async {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;

    // Получаем лимит
    final limit = await _db.getCategoryLimit(category, month, year);
    if (limit == null) {
      return {
        'exceeded': false,
        'message': 'Лимит не установлен',
        'hasLimit': false,
      };
    }

    // Считаем текущие траты по категории за месяц
    final transactions = await _db.getTransactions();
    final currentSpending = transactions
        .where((t) =>
            t['type'] == 'expense' &&
            t['category'] == category &&
            DateTime.parse(t['date']).month == month &&
            DateTime.parse(t['date']).year == year)
        .fold(0.0, (sum, t) => sum + t['amount']);

    final newTotal = currentSpending + newExpense;
    final exceeded = newTotal > limit;
    final remaining = limit - newTotal;

    return {
      'exceeded': exceeded,
      'limit': limit,
      'currentSpending': currentSpending,
      'newTotal': newTotal,
      'remaining': remaining,
      'percentUsed': (newTotal / limit * 100).clamp(0, 100),
      'hasLimit': true,
      'message': exceeded
          ? 'Лимит превышен на ${(-remaining).toStringAsFixed(0)} ₽!'
          : 'В пределах лимита. Осталось: ${remaining.toStringAsFixed(0)} ₽',
    };
  }

  /// Получить текущие траты по всем категориям с лимитами
  Future<List<Map<String, dynamic>>> getLimitsWithSpending() async {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;

    final limits = await _db.getCurrentMonthLimits();
    final transactions = await _db.getTransactions();

    final result = <Map<String, dynamic>>[];

    for (var limit in limits) {
      final category = limit['category'] as String;
      final limitAmount = limit['limitAmount'] as double;

      final currentSpending = transactions
          .where((t) =>
              t['type'] == 'expense' &&
              t['category'] == category &&
              DateTime.parse(t['date']).month == month &&
              DateTime.parse(t['date']).year == year)
          .fold(0.0, (sum, t) => sum + t['amount']);

      final remaining = limitAmount - currentSpending;
      final percentUsed = (currentSpending / limitAmount * 100).clamp(0, 100);
      final exceeded = currentSpending > limitAmount;

      result.add({
        'category': category,
        'limit': limitAmount,
        'spent': currentSpending,
        'remaining': remaining,
        'percentUsed': percentUsed,
        'exceeded': exceeded,
      });
    }

    return result;
  }
}