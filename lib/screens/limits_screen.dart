import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class LimitsScreen extends StatefulWidget {
  const LimitsScreen({super.key});

  @override
  State<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends State<LimitsScreen> {
  List<Map<String, dynamic>> _limits = [];
  Map<String, double> _spentByCategory = {};

  // 🔥 Базовые категории (остаются всегда)
  final List<String> _baseCategories = [
    'Еда',
    'Транспорт',
    'Развлечения',
    'Одежда',
    'Здоровье',
    'Продукты',
    'Кафе',
    'Такси',
    'Подписки',
    'Другое'
  ];

  // 🔥 Пользовательские категории (динамические)
  List<String> _customCategories = [];

  // 🔥 Все категории вместе
  List<String> get _allCategories => [..._baseCategories, ..._customCategories];

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final limits = await DBHelper.instance.getCurrentMonthLimits();
    final transactions = await DBHelper.instance.getTransactions();
    final categories = await DBHelper.instance.getCategories('expense');

    // 🔥 Получаем пользовательские категории из БД
    final customCats = categories
        .where((c) => !_baseCategories.contains(c['name']))
        .map((c) => c['name'] as String)
        .toList();

    // 🔥 Считаем траты по каждой категории за текущий месяц
    final now = DateTime.now();
    final spentByCategory = <String, double>{};

    for (var t in transactions.where((t) => t['type'] == 'expense')) {
      final date = DateTime.parse(t['date']);
      if (date.month == now.month && date.year == now.year) {
        final category = t['category'] ?? 'Другое';
        spentByCategory[category] = (spentByCategory[category] ?? 0) + t['amount'];
      }
    }

    setState(() {
      _limits = limits;
      _spentByCategory = spentByCategory;
      _customCategories = customCats;
    });
  }

  // 🔥 МЕТОД ДЛЯ ДОБАВЛЕНИЯ НОВОЙ КАТЕГОРИИ
  Future<void> _addCustomCategory() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Название категории',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                // 🔥 Добавляем категорию в БД
                await DBHelper.instance.insertCategory({
                  'name': name,
                  'type': 'expense',
                  'icon': 'category',
                });

                // 🔥 Сразу открываем диалог установки лимита
                if (mounted) Navigator.pop(context);
                _setLimit(name);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите название категории')),
                );
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  // 🔥 МЕТОД ДЛЯ УСТАНОВКИ ЛИМИТА
  Future<void> _setLimit(String category) async {
    final currentLimit = await DBHelper.instance.getCategoryLimit(
      category,
      DateTime.now().month,
      DateTime.now().year,
    );
    final controller = TextEditingController(
      text: currentLimit?.toStringAsFixed(0) ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Лимит для "$category"'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Сумма в ₽',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                final now = DateTime.now();
                await DBHelper.instance.saveCategoryLimit(
                  category,
                  amount,
                  now.month,
                  now.year,
                );
                await _loadLimits();
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Лимит: ${amount.toStringAsFixed(0)} ₽')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите сумму')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthName = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ][now.month - 1];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Лимиты по категориям'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLimits,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.blue[50],
            child: Column(
              children: [
                Text(
                  '$monthName ${now.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Нажмите на категорию для установки лимита',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _allCategories.length + 1, // 🔥 +1 для кнопки добавления
              itemBuilder: (context, index) {
                // 🔥 Последний элемент - кнопка добавления категории
                if (index == _allCategories.length) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Icon(
                        Icons.add,
                        color: Colors.blue[700],
                      ),
                    ),
                    title: const Text(
                      'Добавить категорию',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'Создать новую категорию с лимитом',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _addCustomCategory,
                  );
                }

                // 🔥 Отображение категории
                final category = _allCategories[index];
                final isCustom = _customCategories.contains(category);
                final limit = _limits.firstWhere(
                  (l) => l['category'] == category,
                  orElse: () => <String, dynamic>{},
                );
                final hasLimit = limit.isNotEmpty;
                final limitAmount = hasLimit ? (limit['limitAmount'] as double) : 0.0;
                final spentAmount = _spentByCategory[category] ?? 0.0;
                final percentUsed = limitAmount > 0
                    ? (spentAmount / limitAmount * 100).clamp(0, 100)
                    : 0.0;
                final isExceeded = spentAmount > limitAmount;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: hasLimit
                        ? (isExceeded ? Colors.red[100] : Colors.green[100])
                        : Colors.grey[200],
                    child: Icon(
                      hasLimit
                          ? (isExceeded ? Icons.warning : Icons.check_circle)
                          : Icons.add_circle_outline,
                      color: hasLimit
                          ? (isExceeded ? Colors.red : Colors.green)
                          : Colors.grey,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        category,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (isCustom) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        hasLimit
                            ? 'Потрачено: ${spentAmount.toStringAsFixed(0)} ₽ из ${limitAmount.toStringAsFixed(0)} ₽'
                            : 'Лимит не установлен',
                        style: TextStyle(
                          color: hasLimit
                              ? (isExceeded ? Colors.red[700] : Colors.green[700])
                              : Colors.grey[600],
                        ),
                      ),
                      if (hasLimit) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (percentUsed / 100).clamp(0, 1),
                            backgroundColor: Colors.grey.shade200,
                            color: isExceeded
                                ? Colors.red
                                : percentUsed > 80
                                    ? Colors.orange
                                    : Colors.green,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${percentUsed.toStringAsFixed(0)}% использовано',
                          style: TextStyle(
                            fontSize: 11,
                            color: isExceeded ? Colors.red[700] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chevron_right),
                      if (isCustom) ...[
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          color: Colors.red,
                          onPressed: () => _deleteCustomCategory(category),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => _setLimit(category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 МЕТОД ДЛЯ УДАЛЕНИЯ ПОЛЬЗОВАТЕЛЬСКОЙ КАТЕГОРИИ
  Future<void> _deleteCustomCategory(String category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(
          'Вы уверены, что хотите удалить категорию "$category"? '
          'Все связанные транзакции будут перенесены в категорию "Другое".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 🔥 Получаем все категории
      final allCategories = await DBHelper.instance.getCategories('expense');
      final categoryToDelete = allCategories.firstWhere(
        (c) => c['name'] == category,
        orElse: () => <String, dynamic>{},
      );

      if (categoryToDelete.isNotEmpty) {
        final categoryId = categoryToDelete['id'] as int;

        // 🔥 Удаляем категорию с переносом транзакций в "Другое"
        await DBHelper.instance.deleteCategoryWithReassign(categoryId, 'Другое');

        // 🔥 Удаляем лимиты
        final now = DateTime.now();
        await DBHelper.instance.deleteCategoryLimit(
          category,
          now.month,
          now.year,
        );

        await _loadLimits();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Категория удалена')),
          );
        }
      }
    }
  }
}