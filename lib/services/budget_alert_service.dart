import '../database/db_helper.dart';

class BudgetAlertService {
  final DBHelper _db = DBHelper.instance;

  /// Проверка расхода после добавления
  Future<Map<String, dynamic>> checkBudgetAlert({
    required double amount,
    required String category,
    required DateTime date,
  }) async {
    final now = DateTime.now();

    // 🔥 1. Получаем данные за текущий месяц
    final transactions = await _db.getTransactions();
    final monthTransactions = transactions.where((t) {
      final tDate = DateTime.parse(t['date']);
      return tDate.month == now.month && tDate.year == now.year;
    }).toList();

    // 🔥 2. Считаем расходы
    final totalExpenses = monthTransactions
        .where((t) => t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + t['amount']);

    final categoryExpenses = monthTransactions
        .where((t) => t['type'] == 'expense' && t['category'] == category)
        .fold(0.0, (sum, t) => sum + t['amount']);

    // 🔥 3. Средний дневной бюджет (за последние 3 месяца)
    final avgDailyBudget = await _calculateAverageDailyBudget();

    // 🔥 4. Оставшиеся дни месяца
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = endOfMonth.difference(now).inDays + 1;

    // 🔥 5. Оставшийся бюджет
    final monthlyBudget = avgDailyBudget * 30; // или пользовательский
    final remainingBudget = monthlyBudget - totalExpenses - amount;

    // 🔥 6. Необходимый дневной бюджет
    final requiredDailyBudget = remainingBudget / daysRemaining;

    // 🔥 7. Проверяем, насколько расход превышает норму
    final isUnusual = amount > avgDailyBudget * 2;
    final exceedsBy = amount - avgDailyBudget;
    final exceedsPercent = (exceedsBy / avgDailyBudget * 100).clamp(0, 1000);

    // 🔥 8. Генерируем рекомендации
    final recommendations = _generateRecommendations(
      amount: amount,
      category: category,
      categoryExpenses: categoryExpenses,
      remainingBudget: remainingBudget,
      requiredDailyBudget: requiredDailyBudget,
      avgDailyBudget: avgDailyBudget,
      daysRemaining: daysRemaining,
      isUnusual: isUnusual,
    );

    return {
      'alert': isUnusual || requiredDailyBudget < 0,
      'severity': _getSeverity(exceedsPercent, requiredDailyBudget),
      'isUnusual': isUnusual,
      'exceedsBy': exceedsBy,
      'exceedsPercent': exceedsPercent,
      'remainingBudget': remainingBudget,
      'requiredDailyBudget': requiredDailyBudget,
      'daysRemaining': daysRemaining,
      'categorySpent': categoryExpenses,
      'recommendations': recommendations,
    };
  }

  /// Расчёт среднего дневного бюджета (за 3 месяца)
  Future<double> _calculateAverageDailyBudget() async {
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);

    final transactions = await _db.getTransactions();
    final filtered = transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return t['type'] == 'expense' &&
             date.isAfter(threeMonthsAgo);
    }).toList();

    if (filtered.isEmpty) return 1000; // Дефолт

    final totalDays = now.difference(threeMonthsAgo).inDays;
    final totalExpenses = filtered.fold(0.0, (sum, t) => sum + t['amount']);

    return totalExpenses / totalDays;
  }

  /// Генерация рекомендаций
  List<String> _generateRecommendations({
    required double amount,
    required String category,
    required double categoryExpenses,
    required double remainingBudget,
    required double requiredDailyBudget,
    required double avgDailyBudget,
    required int daysRemaining,
    required bool isUnusual,
  }) {
    final recommendations = <String>[];

    if (isUnusual) {
      recommendations.add(
        '⚠️ Расход в ${amount.toStringAsFixed(0)} ₽ превышает ваш средний дневной бюджет '
        'в ${(amount / avgDailyBudget).toStringAsFixed(1)} раза!'
      );
    }

    if (requiredDailyBudget < 0) {
      recommendations.add(
        'Бюджет превышен! Вам нужно либо сократить расходы, либо увеличить доход.'
      );
    } else if (requiredDailyBudget < avgDailyBudget * 0.5) {
      recommendations.add(
        '⚠️ Чтобы уложиться в бюджет, вам нужно тратить не более '
        '${requiredDailyBudget.toStringAsFixed(0)} ₽ в день '
        '(обычно вы тратите ${avgDailyBudget.toStringAsFixed(0)} ₽).'
      );
    }

    // Рекомендации по категории
    if (categoryExpenses > avgDailyBudget * 10) {
      recommendations.add(
        'Категория "$category" составляет ${(categoryExpenses / (avgDailyBudget * 30) * 100).toStringAsFixed(0)}% '
        'ваших расходов. Рассмотрите возможность сокращения.'
      );
    }

    // Советы на оставшиеся дни
    if (daysRemaining > 0) {
      recommendations.add(
        'Осталось $daysRemaining дней в месяце. '
        'Ваш дневной бюджет: ${requiredDailyBudget.toStringAsFixed(0)} ₽.'
      );
    }

    return recommendations;
  }

  /// Определение серьёзности предупреждения
  String _getSeverity(double exceedsPercent, double requiredDailyBudget) {
    if (requiredDailyBudget < 0) return 'critical';
    if (exceedsPercent > 200) return 'high';
    if (exceedsPercent > 100) return 'medium';
    return 'low';
  }
}