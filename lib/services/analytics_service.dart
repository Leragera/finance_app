import '../database/db_helper.dart';
import 'linear_regression.dart';

/// Сервис аналитики и прогнозирования расходов
/// Использует линейную регрессию для прогнозирования
class AnalyticsService {
  final DBHelper _db = DBHelper.instance;
  final LinearRegression _model = LinearRegression();

  /// Статистика за период
  Future<Map<String, dynamic>> getPeriodStats({
    required DateTime start,
    required DateTime end,
  }) async {
    final transactions = await _db.getTransactions();

    // Фильтруем транзакции по периоду
    final filtered = transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.isAfter(start.subtract(const Duration(days: 1))) &&
          date.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    // Считаем доходы и расходы
    final income = filtered
        .where((t) => t['type'] == 'income')
        .fold(0.0, (sum, t) => sum + (t['amount'] ?? 0));
    final expense = filtered
        .where((t) => t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + (t['amount'] ?? 0));

    // Расходы по категориям
    final categoryExpenses = <String, double>{};
    for (var t in filtered.where((t) => t['type'] == 'expense')) {
      final cat = t['category'] ?? 'Другое';
      categoryExpenses[cat] = (categoryExpenses[cat] ?? 0) + (t['amount'] ?? 0);
    }

    // Средний дневной расход
    final days = end.difference(start).inDays + 1;
    final avgDailyExpense = days > 0 ? expense / days : 0;

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
      'categoryExpenses': categoryExpenses,
      'avgDailyExpense': avgDailyExpense,
      'transactionCount': filtered.length,
      'period': {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
    };
  }

  /// Тренды по месяцам
  Future<List<Map<String, dynamic>>> getMonthlyTrends({
    int monthsCount = 6,
  }) async {
    final transactions = await _db.getTransactions();
    final now = DateTime.now();
    final trends = <Map<String, dynamic>>[];

    for (int i = monthsCount - 1; i >= 0; i--) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);

      final monthTransactions = transactions.where((t) {
        final date = DateTime.parse(t['date']);
        return date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            date.isBefore(monthEnd.add(const Duration(days: 1)));
      }).toList();

      final income = monthTransactions
          .where((t) => t['type'] == 'income')
          .fold(0.0, (sum, t) => sum + (t['amount'] ?? 0));
      final expense = monthTransactions
          .where((t) => t['type'] == 'expense')
          .fold(0.0, (sum, t) => sum + (t['amount'] ?? 0));

      trends.add({
        'month': '${monthStart.month}.${monthStart.year}',
        'month_num': monthsCount - 1 - i,
        'income': income,
        'expense': expense,
        'balance': income - expense,
      });
    }

    return trends;
  }

  /// 🔥 СГЛАЖИВАНИЕ ДАННЫХ (скользящее среднее)
  List<double> _smoothData(List<double> data) {
    if (data.length < 3) return data;

    final smoothed = <double>[];
    for (int i = 0; i < data.length; i++) {
      if (i == 0 || i == data.length - 1) {
        // Первая и последняя точки остаются без изменений
        smoothed.add(data[i]);
      } else {
        // Скользящее среднее из 3 точек
        final avg = (data[i - 1] + data[i] + data[i + 1]) / 3;
        smoothed.add(avg);
      }
    }
    return smoothed;
  }

  /// Прогноз расходов на следующий месяц
  Future<Map<String, dynamic>> forecastNextMonth() async {
    try {
      // Получаем тренды за последние 6 месяцев
      final trends = await getMonthlyTrends(monthsCount: 6);

      // Фильтруем только месяцы с расходами
      final expenses = trends
          .where((t) => (t['expense'] ?? 0) > 0)
          .toList();

      // Если мало данных — возвращаем среднее
      if (expenses.length < 2) {
        final avgExpense = expenses.isEmpty
            ? 0.0
            : expenses.fold(0.0, (sum, t) => sum + (t['expense'] ?? 0)) / expenses.length;

        return {
          'forecast': avgExpense,
          'confidence': 0.3, // Низкая уверенность из-за малого количества данных
          'trend': 'stable',
          'r2_score': 0.0,
          'data_points': expenses.length,
          'message': expenses.length < 2
              ? 'Недостаточно данных для прогноза (нужно минимум 2 месяца)'
              : 'Прогноз на основе среднего значения',
        };
      }

      // 🔥 Готовим данные для линейной регрессии
      final x = <double>[]; // Номера месяцев (0, 1, 2, 3...)
      final y = <double>[]; // Суммы расходов

      for (int i = 0; i < expenses.length; i++) {
        x.add(i.toDouble());
        y.add(expenses[i]['expense'] ?? 0);
      }

      // 🔥 ПРИМЕНЯЕМ СГЛАЖИВАНИЕ к данным
      final ySmoothed = _smoothData(y);

      // 🔥 Обучаем модель на сглаженных данных
      _model.train(x, ySmoothed);

      // 🔥 Делаем прогноз на следующий месяц
      final nextMonthIndex = expenses.length.toDouble();
      final forecast = _model.predictClamped(nextMonthIndex);

      // 🔥 Рассчитываем уверенность прогноза
      // R² показывает качество модели (0-1)
      // dataPoints показывает количество данных (чем больше, тем лучше)
      final r2Clamped = _model.r2Score.clamp(0.0, 1.0);
      final dataConfidence = r2Clamped;
      final dataQualityFactor = (expenses.length / 6).clamp(0.0, 1.0);
      final confidence = (dataConfidence * 0.5 + dataQualityFactor * 0.5).clamp(0.0, 1.0);

      // 🔥 Определяем тренд
      String trend;
      if (_model.slope > 500) {
        trend = 'growth';
      } else if (_model.slope < -500) {
        trend = 'decline';
      } else {
        trend = 'stable';
      }

      // 🔥 Формируем результат
      return {
        'forecast': forecast,
        'confidence': confidence,
        'trend': trend,
        'r2_score': r2Clamped,
        'slope': _model.slope,
        'intercept': _model.intercept,
        'data_points': expenses.length,
        'smoothed': true, // 🔥 Помечаем, что использовалось сглаживание
        'message': 'Прогноз на основе линейной регрессии со сглаживанием',
      };
    } catch (e) {
      print('Ошибка прогнозирования: $e');
      return {
        'forecast': 0,
        'confidence': 0,
        'trend': 'stable',
        'r2_score': 0,
        'message': 'Ошибка прогноза: $e',
      };
    }
  }

  /// Получить аналитику за период
  Future<Map<String, dynamic>> getAnalytics(int months) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months, 1);
    return await getPeriodStats(start: start, end: now);
  }

  /// Сброс модели
  void resetModel() {
    _model.reset();
  }
}