import '../database/db_helper.dart';

class AIAdvisorService {
  final DBHelper _db = DBHelper.instance;
  static const bool useOpenAI = false;

  Future<String> getAdvice(String question) async {
    if (useOpenAI) {
      return await _getOpenAIAdvice(question);
    } else {
      return await _getRuleBasedAdvice(question);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🧠 УМНЫЙ Rule-based AI с анализом финансов
  // ─────────────────────────────────────────────────────────────
  Future<String> _getRuleBasedAdvice(String question) async {
    question = question.toLowerCase().trim();

    try {
      // 🔥 Паттерн 1: "Хочу купить [что-то] за [сумма]"
      final buyPattern = RegExp(r'хочу\s+(купить|приобрести|взять).*?(за|на)\s+([\d\s]+)');
      final buyMatch = buyPattern.firstMatch(question);
      if (buyMatch != null) {
        final amountStr = buyMatch.group(2)!.replaceAll(' ', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          return await _getSmartPurchaseAdvice(amount, question);
        }
      }

      // 🔥 Паттерн 2: "Хочу [что-то] за [сумма]" (без "купить")
      final wantPattern = RegExp(r'хочу.*?за\s+([\d\s]+)');
      final wantMatch = wantPattern.firstMatch(question);
      if (wantMatch != null) {
        final amountStr = wantMatch.group(1)!.replaceAll(' ', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          return await _getSmartPurchaseAdvice(amount, question);
        }
      }

      // 🔥 Паттерн 3: "Могу ли я купить [что-то] за [сумма]"
      final canBuyPattern = RegExp(r'могу\s+(ли|я)\s+(купить|позволить).*?за\s+([\d\s]+)');
      final canBuyMatch = canBuyPattern.firstMatch(question);
      if (canBuyMatch != null) {
        final amountStr = canBuyMatch.group(3)!.replaceAll(' ', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          return await _getSmartPurchaseAdvice(amount, question);
        }
      }

      // 🔥 Паттерн 4: "Отпуск" / "поездка" / "путешествие"
      if (question.contains('отпуск') ||
          question.contains('поездк') ||
          question.contains('путешеств')) {
        final amountPattern = RegExp(r'за\s+([\d\s]+)');
        final amountMatch = amountPattern.firstMatch(question);
        if (amountMatch != null) {
          final amountStr = amountMatch.group(1)!.replaceAll(' ', '');
          final amount = double.tryParse(amountStr);
          if (amount != null) {
            return await _getSmartPurchaseAdvice(amount, question);
          }
        }
      }

      // 🔥 Паттерн 5: "Где я трачу больше всего"
      if (question.contains('трачу') || question.contains('расход')) {
        return await _getSpendingAnalysis();
      }

      // 🔥 Паттерн 6: "Как сэкономить"
      if (question.contains('сэкономить') || question.contains('сократить')) {
        return await _getSavingTips();
      }

      // 🔥 Паттерн 7: "Сколько могу отложить"
      if (question.contains('отложить') || question.contains('свободн')) {
        return await _getFreeMoneyAdvice();
      }

      // 🔥 Паттерн 8: "Хватит ли денег до зарплаты"
      if (question.contains('хватит') && question.contains('зарплат')) {
        return await _getSalaryAdvice();
      }

      // 🔥 Паттерн 9: "Бюджет на месяц"
      if (question.contains('бюджет') && question.contains('месяц')) {
        return await _getMonthlyBudgetAdvice();
      }

      // 🔥 Паттерн 10: "Сколько осталось до конца месяца"
      if (question.contains('осталось') && question.contains('месяц')) {
        return await _getMonthEndAdvice();
      }

      return _getHelpMessage();
    } catch (e) {
      return "Произошла ошибка при обработке вопроса. Попробуйте перефразировать.\n\nОшибка: $e";
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 💡 УМНЫЙ совет по покупке (с учётом даты и бюджета)
  // ─────────────────────────────────────────────────────────────
  Future<String> _getSmartPurchaseAdvice(double targetAmount, String question) async {
    final transactions = await _db.getTransactions();
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);

    // 🔥 Получаем текущий баланс
    final accounts = await _db.getAccounts();
    final currentBalance = accounts.fold(0.0, (sum, acc) => sum + (acc['balance'] ?? 0));

    // 🔥 Получаем расходы за текущий месяц
    final monthTransactions = transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return t['type'] == 'expense' &&
             date.month == now.month &&
             date.year == now.year;
    }).toList();

    final monthSpent = monthTransactions.fold(0.0, (sum, t) => sum + t['amount']);

    // 🔥 Получаем средние расходы за 3 месяца
    final recentTransactions = transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.isAfter(threeMonthsAgo) && t['type'] == 'expense';
    }).toList();

    final avgMonthlyExpense = recentTransactions.isEmpty
        ? 0.0
        : recentTransactions.fold(0.0, (sum, t) => sum + t['amount']) / 3;

    // 🔥 Получаем доходы за 3 месяца
    final incomeTransactions = transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.isAfter(threeMonthsAgo) && t['type'] == 'income';
    }).toList();

    final avgMonthlyIncome = incomeTransactions.isEmpty
        ? 0.0
        : incomeTransactions.fold(0.0, (sum, t) => sum + t['amount']) / 3;

    // 🔥 Сколько дней осталось до конца месяца
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = endOfMonth.difference(now).inDays + 1;
    final daysPassed = now.day;
    final totalDays = endOfMonth.day;

    // 🔥 Прогноз расходов до конца месяца
    final dailyAverage = daysPassed > 0 ? monthSpent / daysPassed : 0;
    final projectedMonthEndExpense = monthSpent + (dailyAverage * daysRemaining);

    // 🔥 Сколько денег нужно на жизнь до конца месяца
    final neededForLiving = (avgMonthlyExpense / totalDays) * daysRemaining;

    // 🔥 Анализ ситуации
    final remainingAfterPurchase = currentBalance - targetAmount;
    final isAffordable = remainingAfterPurchase >= neededForLiving;
    final willBeBroke = remainingAfterPurchase < 1000;
    final isBeginningOfMonth = daysPassed <= 10;
    final isEndOfMonth = daysRemaining <= 5;

    // 🔥 Формируем умный ответ
    if (currentBalance < targetAmount) {
      final shortage = targetAmount - currentBalance;
      return "❌ К сожалению, у вас недостаточно средств.\n\n"
             "На счетах: ${currentBalance.toStringAsFixed(0)} ₽\n"
             "Нужно: ${targetAmount.toStringAsFixed(0)} ₽\n"
             "Не хватает: ${shortage.toStringAsFixed(0)} ₽\n\n"
             "💡 Рекомендация: накопите ещё ${shortage.toStringAsFixed(0)} ₽ перед покупкой.";
    }

    if (!isAffordable && !isBeginningOfMonth) {
      final warning = remainingAfterPurchase < 0
          ? "После покупки у вас будет долг ${(-remainingAfterPurchase).toStringAsFixed(0)} ₽"
          : "После покупки останется ${remainingAfterPurchase.toStringAsFixed(0)} ₽";

      return "⚠️ НЕ РЕКОМЕНДУЮ эту покупку сейчас!\n\n"
             "На счетах: ${currentBalance.toStringAsFixed(0)} ₽\n"
             "Покупка: ${targetAmount.toStringAsFixed(0)} ₽\n"
             "$warning\n"
             "До конца месяца: $daysRemaining дн.\n"
             "Нужно на жизнь: ${neededForLiving.toStringAsFixed(0)} ₽\n\n"
             "💡 Рекомендация:\n"
             "• Отложите покупку на начало следующего месяца\n"
             "• Или сократите сумму до ${(currentBalance - neededForLiving).toStringAsFixed(0)} ₽\n"
             "• Или найдите дополнительный доход";
    }

    if (willBeBroke && !isEndOfMonth) {
      return "⚠️ ОПАСНАЯ ПОКУПКА!\n\n"
             "После покупки останется: ${remainingAfterPurchase.toStringAsFixed(0)} ₽\n"
             "До конца месяца: $daysRemaining дн.\n"
             "Нужно на жизнь: ${neededForLiving.toStringAsFixed(0)} ₽\n\n"
             "Этого не хватит на проживание! Рекомендую:\n"
             "• Купить что-то дешевле\n"
             "• Дождаться зарплаты\n"
             "• Или отложить покупку";
    }

    if (isAffordable && isBeginningOfMonth) {
      return "✅ ПОКУПКА БЕЗОПАСНА!\n\n"
             "На счетах: ${currentBalance.toStringAsFixed(0)} ₽\n"
             "Покупка: ${targetAmount.toStringAsFixed(0)} ₽\n"
             "Останется: ${remainingAfterPurchase.toStringAsFixed(0)} ₽\n"
             "До конца месяца: $daysRemaining дн.\n"
             "Нужно на жизнь: ${neededForLiving.toStringAsFixed(0)} ₽\n\n"
             "У вас достаточно средств. Можете покупать!\n"
             "Но не забудьте отложить ${neededForLiving.toStringAsFixed(0)} ₽ на обязательные расходы.";
    }

    final monthlySavings = avgMonthlyIncome - avgMonthlyExpense;
    final monthsNeeded = monthlySavings > 0 ? (targetAmount - currentBalance) / monthlySavings : 999;

    return "Анализ покупки за ${targetAmount.toStringAsFixed(0)} ₽:\n\n"
           "На счетах: ${currentBalance.toStringAsFixed(0)} ₽\n"
           "После покупки: ${remainingAfterPurchase.toStringAsFixed(0)} ₽\n"
           "До конца месяца: $daysRemaining дн.\n"
           "Нужно на жизнь: ${neededForLiving.toStringAsFixed(0)} ₽\n\n"
           "${isAffordable ? 'Покупка безопасна' : '⚠️ Будьте осторожны'}\n\n"
           "💡 Рекомендация: ${isAffordable ? 'Можно покупать!' : 'Лучше отложить'}";
  }

  // ─────────────────────────────────────────────────────────────
  // 📊 Анализ расходов
  // ─────────────────────────────────────────────────────────────
  Future<String> _getSpendingAnalysis() async {
    final transactions = await _db.getTransactions();
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);

    final recentTransactions = transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.isAfter(threeMonthsAgo) && t['type'] == 'expense';
    }).toList();

    if (recentTransactions.isEmpty) {
      return "Пока недостаточно данных.\nДобавьте больше транзакций!";
    }

    final categoryExpenses = <String, double>{};
    for (var t in recentTransactions) {
      final cat = t['category'] ?? 'Другое';
      categoryExpenses[cat] = (categoryExpenses[cat] ?? 0) + t['amount'];
    }

    final sortedCategories = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = categoryExpenses.values.fold(0.0, (a, b) => a + b);

    final buffer = StringBuffer("Анализ расходов за 3 месяца:\n\n");
    buffer.write("Всего: ${total.toStringAsFixed(0)} ₽\n");
    buffer.write("В среднем: ${(total / 3).toStringAsFixed(0)} ₽/мес\n\n");
    buffer.write("Топ категорий:\n");

    for (var i = 0; i < sortedCategories.length && i < 5; i++) {
      final entry = sortedCategories[i];
      final percent = (entry.value / total * 100);
      buffer.write("${i + 1}. ${entry.key}: ${entry.value.toStringAsFixed(0)} ₽ (${percent.toStringAsFixed(0)}%)\n");
    }

    if (sortedCategories.isNotEmpty) {
      final top = sortedCategories.first;
      final topPercent = (top.value / total * 100);
      if (topPercent > 30) {
        buffer.write("\nКатегория '${top.key}' составляет ${topPercent.toStringAsFixed(0)}% расходов!\n");
        buffer.write("Рассмотрите возможность сокращения на 10-20%.");
      }
    }

    return buffer.toString();
  }

  // ─────────────────────────────────────────────────────────────
  // 💡 Советы по экономии
  // ─────────────────────────────────────────────────────────────
  Future<String> _getSavingTips() async {
    final transactions = await _db.getTransactions();
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);

    final recentTransactions = transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.isAfter(threeMonthsAgo) && t['type'] == 'expense';
    }).toList();

    final categoryExpenses = <String, double>{};
    for (var t in recentTransactions) {
      final cat = t['category'] ?? 'Другое';
      categoryExpenses[cat] = (categoryExpenses[cat] ?? 0) + t['amount'];
    }

    if (categoryExpenses.isEmpty) {
      return "Добавьте транзакции для персональных советов!";
    }

    final topCategory = categoryExpenses.entries.reduce((a, b) => a.value > b.value ? a : b);
    final potentialSavings = topCategory.value * 0.2;

    return "Советы по экономии:\n\n"
           "1. Ваша топ категория: '${topCategory.key}'\n"
           "   Тратите: ${topCategory.value.toStringAsFixed(0)} ₽/3 мес\n"
           "   Сократите на 20% = ${potentialSavings.toStringAsFixed(0)} ₽\n\n"
           "2. Отмените неиспользуемые подписки\n"
           "3. Планируйте покупки заранее\n"
           "4. Готовьте дома вместо доставки\n\n"
           "Экономия в месяц: до ${(potentialSavings / 3).toStringAsFixed(0)} ₽";
  }

  // ─────────────────────────────────────────────────────────────
  // 💵 Сколько можно отложить
  // ─────────────────────────────────────────────────────────────
  Future<String> _getFreeMoneyAdvice() async {
    final transactions = await _db.getTransactions();
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);

    final recentTransactions = transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.isAfter(threeMonthsAgo);
    }).toList();

    final avgIncome = recentTransactions
        .where((t) => t['type'] == 'income')
        .fold(0.0, (sum, t) => sum + t['amount']) / 3;

    final avgExpense = recentTransactions
        .where((t) => t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + t['amount']) / 3;

    final monthlySavings = avgIncome - avgExpense;
    final accounts = await _db.getAccounts();
    final currentBalance = accounts.fold(0.0, (sum, acc) => sum + (acc['balance'] ?? 0));

    if (monthlySavings <= 0) {
      return "⚠️ Сейчас расходы превышают доходы!\n\n"
             "Доходы: ${avgIncome.toStringAsFixed(0)} ₽/мес\n"
             "Расходы: ${avgExpense.toStringAsFixed(0)} ₽/мес\n\n"
             "💡 Рекомендации:\n"
             "1. Сократите траты на ${(avgExpense * 0.2).toStringAsFixed(0)} ₽ (20%)\n"
             "2. Найдите дополнительный доход\n"
             "3. Ведите учёт всех мелких трат";
    }

    return "Сколько можно отложить:\n\n"
           "Доходы: ${avgIncome.toStringAsFixed(0)} ₽/мес\n"
           "Расходы: ${avgExpense.toStringAsFixed(0)} ₽/мес\n"
           "Свободно: ${monthlySavings.toStringAsFixed(0)} ₽/мес\n\n"
           "💡 Рекомендация:\n"
           "• Откладывайте: ${(monthlySavings * 0.8).toStringAsFixed(0)} ₽/мес (80%)\n"
           "• На расходы: ${(monthlySavings * 0.2).toStringAsFixed(0)} ₽/мес (20%)\n\n"
           "На счетах уже: ${currentBalance.toStringAsFixed(0)} ₽\n"
           "За год накопите: ${(monthlySavings * 0.8 * 12).toStringAsFixed(0)} ₽";
  }

  // ─────────────────────────────────────────────────────────────
  // 💰 Хватит ли до зарплаты
  // ─────────────────────────────────────────────────────────────
  Future<String> _getSalaryAdvice() async {
    final accounts = await _db.getAccounts();
    final currentBalance = accounts.fold(0.0, (sum, acc) => sum + (acc['balance'] ?? 0));

    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = endOfMonth.difference(now).inDays + 1;

    final transactions = await _db.getTransactions();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);

    final recentTransactions = transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.isAfter(threeMonthsAgo) && t['type'] == 'expense';
    }).toList();

    final avgDailyExpense = recentTransactions.isEmpty
        ? 0.0
        : recentTransactions.fold(0.0, (sum, t) => sum + t['amount']) / 90;

    final neededForDays = avgDailyExpense * daysRemaining;
    final willHaveLeft = currentBalance - neededForDays;

    return "Хватит ли денег до зарплаты:\n\n"
           "На счетах: ${currentBalance.toStringAsFixed(0)} ₽\n"
           "Дней до конца месяца: $daysRemaining\n"
           "Средний дневной расход: ${avgDailyExpense.toStringAsFixed(0)} ₽\n"
           "Нужно на жизнь: ${neededForDays.toStringAsFixed(0)} ₽\n\n"
           "${willHaveLeft >= 0 ? '✅ Хватит!' : '⚠️ Не хватит!'}\n"
           "${willHaveLeft >= 0 ? 'Останется: ${willHaveLeft.toStringAsFixed(0)} ₽' : 'Дефицит: ${(-willHaveLeft).toStringAsFixed(0)} ₽'}";
  }

  // ─────────────────────────────────────────────────────────────
  // 📋 Бюджет на месяц
  // ─────────────────────────────────────────────────────────────
  Future<String> _getMonthlyBudgetAdvice() async {
    final now = DateTime.now();
    final transactions = await _db.getTransactions();

    final monthTransactions = transactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.month == now.month && date.year == now.year;
    }).toList();

    final income = monthTransactions
        .where((t) => t['type'] == 'income')
        .fold(0.0, (sum, t) => sum + t['amount']);

    final expense = monthTransactions
        .where((t) => t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + t['amount']);

    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = endOfMonth.difference(now).inDays + 1;
    final dailyBudget = (income - expense) / daysRemaining;

    return "Бюджет на этот месяц:\n\n"
           "Доходы: ${income.toStringAsFixed(0)} ₽\n"
           "Расходы: ${expense.toStringAsFixed(0)} ₽\n"
           "Остаток: ${(income - expense).toStringAsFixed(0)} ₽\n"
           "Дней осталось: $daysRemaining\n\n"
           "Дневной бюджет: ${dailyBudget.toStringAsFixed(0)} ₽/день";
  }

  // ─────────────────────────────────────────────────────────────
  // 📅 До конца месяца
  // ─────────────────────────────────────────────────────────────
  Future<String> _getMonthEndAdvice() async {
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = endOfMonth.difference(now).inDays + 1;
    final daysPassed = now.day;

    return "До конца месяца:\n\n"
           "Прошло дней: $daysPassed\n"
           "Осталось дней: $daysRemaining\n"
           "Всего дней: ${endOfMonth.day}\n\n"
           "${daysRemaining > 15 ? 'Месяц только начался' : daysRemaining > 5 ? 'Середина месяца' : 'Конец месяца'}";
  }

  // ─────────────────────────────────────────────────────────────
  // ❓ Сообщение помощи
  // ─────────────────────────────────────────────────────────────
  String _getHelpMessage() {
    return "Я могу помочь:\n\n"
           "Покупки:\n"
           "• 'Хочу купить телефон за 50000 ₽'\n"
           "• 'Могу ли я позволить отпуск за 100000?'\n\n"
           "Расходы:\n"
           "• 'Где я трачу больше всего'\n"
           "• 'Сколько осталось до конца месяца'\n\n"
           "Бюджет:\n"
           "• 'Хватит ли денег до зарплаты'\n"
           "• 'Бюджет на месяц'\n"
           "• 'Сколько могу отложить'\n\n"
           "Экономия:\n"
           "• 'Как сэкономить'\n\n"
           "Попробуйте спросить!";
  }

  // ─────────────────────────────────────────────────────────────
  // 📋 Список preset-вопросов для UI
  // ─────────────────────────────────────────────────────────────
  static List<Map<String, String>> getPresetQuestions() {
    return [
      {'question': 'Где я трачу больше всего', 'label': '📊 Анализ расходов'},
      {'question': 'Как сэкономить', 'label': '💡 Советы по экономии'},
      {'question': 'Сколько могу отложить', 'label': '💰 Накопления'},
      {'question': 'Хватит ли денег до зарплаты', 'label': '💵 До зарплаты'},
      {'question': 'Бюджет на месяц', 'label': '📋 Бюджет месяца'},
      {'question': 'Сколько осталось до конца месяца', 'label': '📅 До конца месяца'},
    ];
  }

  Future<String> _getOpenAIAdvice(String question) async {
    return "OpenAI отключен. Используйте rule-based режим.";
  }
}