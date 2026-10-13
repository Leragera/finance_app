import '../database/db_helper.dart';
import 'dart:math';

class SeedDataService {
  final DBHelper _db = DBHelper.instance;
  final Random _random = Random(42); // 🔥 Фиксированный seed для воспроизводимости

  Future<void> addSampleTransactions() async {
    final expenseCategories = [
      'Продукты',
      'Еда',
      'Транспорт',
      'Кафе',
      'Такси',
      'Подписки',
      'Здоровье',
      'Одежда',
      'Развлечения',
    ];

    // 🔥 БАЗОВЫЕ СУММЫ ПО КАТЕГОРИЯМ (стабильные)
    final baseAmounts = {
      'Продукты': 12000.0,    // ~12к в месяц
      'Еда': 3000.0,          // ~3к в месяц
      'Транспорт': 2000.0,    // ~2к в месяц
      'Кафе': 2500.0,         // ~2.5к в месяц
      'Такси': 1500.0,        // ~1.5к в месяц
      'Подписки': 1000.0,     // ~1к в месяц (фиксировано)
      'Здоровье': 1500.0,     // ~1.5к в месяц
      'Одежда': 3000.0,       // ~3к в месяц
      'Развлечения': 4000.0,  // ~4к в месяц
    };

    final merchants = {
      'Продукты': ['Пятёрочка', 'Магнит', 'Перекрёсток'],
      'Еда': ['Пятёрочка', 'Магнит', 'Лента'],
      'Транспорт': ['Метро', 'Автобус'],
      'Кафе': ['Starbucks', 'Кофемания', 'KFC'],
      'Такси': ['Яндекс.Такси', 'Uber'],
      'Подписки': ['Netflix', 'Spotify', 'Яндекс.Плюс'],
      'Здоровье': ['Аптека', 'Клиника'],
      'Одежда': ['Zara', 'H&M'],
      'Развлечения': ['Кино', 'Театр'],
    };

    final accounts = await _db.getAccounts();
    if (accounts.isEmpty) {
      print('❌ Нет счетов для добавления транзакций');
      return;
    }

    final accountId = accounts.first['id'];
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - 6, 1);

    int transactionId = 1;
    int monthCounter = 0;

    for (var date = startDate; date.isBefore(now); date = date.add(const Duration(days: 1))) {
      final currentMonth = date.month;

      // 🔥 Считаем номер месяца для небольшого тренда
      if (date.day == 1) {
        monthCounter++;
      }

      // 🔥 ПРОДУКТЫ - 2-3 покупки в неделю (стабильно)
      if (date.weekday == 2 || date.weekday == 5) { // Вторник и пятница
        final baseAmount = baseAmounts['Продукты']! / 8; // ~1500 за покупку
        final variation = (_random.nextDouble() - 0.5) * 300; // ±150
        final amount = (baseAmount + variation).clamp(1200.0, 1800.0);

        await _db.insertTransaction({
          'title': merchants['Продукты']![_random.nextInt(3)],
          'amount': amount.roundToDouble(),
          'type': 'expense',
          'category': 'Продукты',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 17)).toString(),
        });
        transactionId++;
      }

      // 🔥 ЕДА - раз в неделю
      if (date.weekday == 3) { // Среда
        final baseAmount = baseAmounts['Еда']! / 4;
        final variation = (_random.nextDouble() - 0.5) * 200;
        final amount = (baseAmount + variation).clamp(600.0, 900.0);

        await _db.insertTransaction({
          'title': merchants['Еда']![_random.nextInt(3)],
          'amount': amount.roundToDouble(),
          'type': 'expense',
          'category': 'Еда',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 14)).toString(),
        });
        transactionId++;
      }

      // 🔥 ТРАНСПОРТ - каждый будний день (небольшие суммы)
      if (date.weekday <= 5) {
        final amount = 100 + _random.nextInt(50); // 100-150 ₽

        await _db.insertTransaction({
          'title': 'Метро',
          'amount': amount.toDouble(),
          'type': 'expense',
          'category': 'Транспорт',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 9)).toString(),
        });
        transactionId++;
      }

      // 🔥 КАФЕ - раз в неделю (выходные)
      if (date.weekday == 6 || date.weekday == 7) {
        if (_random.nextInt(2) == 0) {
          final baseAmount = baseAmounts['Кафе']! / 4;
          final variation = (_random.nextDouble() - 0.5) * 150;
          final amount = (baseAmount + variation).clamp(500.0, 800.0);

          await _db.insertTransaction({
            'title': merchants['Кафе']![_random.nextInt(3)],
            'amount': amount.roundToDouble(),
            'type': 'expense',
            'category': 'Кафе',
            'accountId': accountId,
            'date': date.add(const Duration(hours: 12)).toString(),
          });
          transactionId++;
        }
      }

      // 🔥 ТАКСИ - 1-2 раза в неделю
      if (date.weekday == 4 || date.weekday == 7) {
        final amount = 300 + _random.nextInt(200); // 300-500 ₽

        await _db.insertTransaction({
          'title': 'Яндекс.Такси',
          'amount': amount.toDouble(),
          'type': 'expense',
          'category': 'Такси',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 20)).toString(),
        });
        transactionId++;
      }

      // 🔥 ПОДПИСКИ - 1 числа каждого месяца (фиксировано)
      if (date.day == 1) {
        await _db.insertTransaction({
          'title': 'Netflix',
          'amount': 300.0,
          'type': 'expense',
          'category': 'Подписки',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 10)).toString(),
        });
        await _db.insertTransaction({
          'title': 'Яндекс.Плюс',
          'amount': 299.0,
          'type': 'expense',
          'category': 'Подписки',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 10)).toString(),
        });
        await _db.insertTransaction({
          'title': 'Spotify',
          'amount': 199.0,
          'type': 'expense',
          'category': 'Подписки',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 10)).toString(),
        });
        transactionId += 3;
      }

      // 🔥 ЗДОРОВЬЕ - раз в месяц
      if (date.day == 15) {
        final amount = 1200 + _random.nextInt(600); // 1200-1800 ₽

        await _db.insertTransaction({
          'title': 'Аптека',
          'amount': amount.toDouble(),
          'type': 'expense',
          'category': 'Здоровье',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 11)).toString(),
        });
        transactionId++;
      }

      // 🔥 ОДЕЖДА - раз в 2 месяца (стабильно)
      if (monthCounter % 2 == 0 && date.day == 10) {
        final amount = 2500 + _random.nextInt(1000); // 2500-3500 ₽

        await _db.insertTransaction({
          'title': merchants['Одежда']![_random.nextInt(2)],
          'amount': amount.toDouble(),
          'type': 'expense',
          'category': 'Одежда',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 15)).toString(),
        });
        transactionId++;
      }

      // 🔥 РАЗВЛЕЧЕНИЯ - 1-2 раза в месяц
      if (date.day == 20 || date.day == 25) {
        final amount = 1800 + _random.nextInt(1200); // 1800-3000 ₽

        await _db.insertTransaction({
          'title': merchants['Развлечения']![_random.nextInt(2)],
          'amount': amount.toDouble(),
          'type': 'expense',
          'category': 'Развлечения',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 19)).toString(),
        });
        transactionId++;
      }

      // 💵 ЗАРПЛАТА - 5 и 20 числа (стабильно)
      if (date.day == 5 || date.day == 20) {
        // 🔥 Небольшой рост зарплаты каждый месяц (+2% в месяц)
        final baseSalary = 45000.0;
        final growthFactor = 1.0 + (monthCounter * 0.02); // 2% рост в месяц
        final salary = (baseSalary * growthFactor).roundToDouble();

        await _db.insertTransaction({
          'title': 'Зарплата',
          'amount': salary,
          'type': 'income',
          'category': 'Зарплата',
          'accountId': accountId,
          'date': date.add(const Duration(hours: 10)).toString(),
        });
        transactionId++;
      }
    }

    print('✅ Добавлено тестовых транзакций: $transactionId');
    print('📊 СТАБИЛЬНЫЕ ДАННЫЕ:');
    print('   - Общие расходы в месяц: ~30,000-32,000 ₽');
    print('   - Доходы в месяц: ~90,000-95,000 ₽');
    print('   - Тренд: небольшой рост расходов и доходов');
    print('   - Вариация: ±10-15% (реалистично)');
  }

  Future<void> addSampleLimits() async {
    final limits = {
      'Продукты': 15000.0,
      'Еда': 4000.0,
      'Транспорт': 3000.0,
      'Кафе': 3500.0,
      'Такси': 2000.0,
      'Подписки': 1000.0,
      'Здоровье': 2000.0,
      'Одежда': 4000.0,
      'Развлечения': 5000.0,
    };

    final now = DateTime.now();
    for (var entry in limits.entries) {
      await _db.saveCategoryLimit(
        entry.key,
        entry.value,
        now.month,
        now.year,
      );
    }

    print('✅ Добавлено лимитов: ${limits.length}');
  }

  Future<void> _recalculateAllBalances() async {
    final accounts = await _db.getAccounts();

    for (var account in accounts) {
      final transactions = await _db.getTransactions();
      final accountTransactions = transactions.where((t) =>
        t['accountId'] == account['id']
      ).toList();

      double balance = 0;
      for (var t in accountTransactions) {
        if (t['type'] == 'income') {
          balance += t['amount'];
        } else {
          balance -= t['amount'];
        }
      }

      await _db.updateAccount(account['id'], {'balance': balance});
    }

    print('✅ Балансы пересчитаны');
  }

  Future<void> seedAll() async {
    print('🌱 Начинаем добавление СТАБИЛЬНЫХ тестовых данных...');
    await addSampleTransactions();
    await addSampleLimits();
    await _recalculateAllBalances();
    print('✅ Стабильные данные добавлены успешно!');
    print('📈 ML-модель должна показать:');
    print('   - Высокую точность (R² > 0.85)');
    print('   - Уверенность > 70%');
    print('   - Стабильный тренд с небольшим ростом');
  }
}