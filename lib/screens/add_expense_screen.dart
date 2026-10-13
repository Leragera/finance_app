import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../widgets/calculator_input.dart';
import 'add_category_screen.dart';
import '../services/limit_checker_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  List<Map<String, dynamic>> accounts = [];
  int? selectedAccountId;
  List<Map<String, dynamic>> categories = [];
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    loadAccounts();
    loadCategories();
  }

  void _showCalculator() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: CalculatorInput(
            controller: _amountController,
            onClose: () {
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  // ✅ ПРОВЕРКА ЛИМИТА ПЕРЕД СОХРАНЕНИЕМ
  Future<bool> _checkLimit(double amount, String category) async {
    final result = await LimitCheckerService().checkCategoryLimit(category, amount);

    if (!result['hasLimit']) {
      return true; // Лимит не установлен, всё ок
    }

    if (result['exceeded']) {
      // 🔴 Показываем предупреждение
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
          title: const Text('⚠️ Лимит превышен!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result['message'], style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (result['percentUsed'] / 100).clamp(0, 1),
                backgroundColor: Colors.grey.shade200,
                color: result['percentUsed'] > 100 ? Colors.red : Colors.orange,
              ),
              const SizedBox(height: 8),
              Text(
                'Потрачено: ${result['currentSpending'].toStringAsFixed(0)} ₽ из ${result['limit'].toStringAsFixed(0)} ₽',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Всё равно сохранить'),
            ),
          ],
        ),
      );
      return confirm ?? false;
    }

    // 🟡 Предупреждение, если близко к лимиту (>80%)
    if (result['percentUsed'] > 80) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.info, color: Colors.blue, size: 48),
          title: const Text('ℹ️ Внимание'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result['message']),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (result['percentUsed'] / 100).clamp(0, 1),
                backgroundColor: Colors.grey.shade200,
                color: Colors.orange,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
    }

    return true;
  }

  // ✅ ИСПРАВЛЕНО: Future<void> вместо void
  Future<void> _saveExpense() async {
    final title = _titleController.text;
    final amount = double.tryParse(_amountController.text);

    // ✅ Проверка валидности с сообщением пользователю
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название расхода')),
      );
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }
    if (selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите счёт')),
      );
      return;
    }
    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите категорию')),
      );
      return;
    }

    // 🔥 ПРОВЕРЯЕМ ЛИМИТ
    final limitOk = await _checkLimit(amount, selectedCategory!);
    if (!limitOk) {
      return; // Пользователь отменил
    }

    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 🔥 Сохраняем транзакцию
      await DBHelper.instance.insertTransaction({
        'title': title,
        'amount': amount,
        'type': 'expense',
        'category': selectedCategory,
        'accountId': selectedAccountId,
        'date': DateTime.now().toString(),
      });

      // 🔥 Обновляем баланс счёта
      await DBHelper.instance.updateAccountBalance(
        selectedAccountId!,
        amount,
        'expense',
      );

      // Закрываем индикатор загрузки
      if (mounted) Navigator.pop(context);

      // Показываем успех
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Расход ${amount.toStringAsFixed(0)} ₽ сохранён'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Закрываем индикатор загрузки
      if (mounted) Navigator.pop(context);
      // Показываем ошибку
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void loadAccounts() async {
    final data = await DBHelper.instance.getAccounts();
    setState(() {
      accounts = data;
      if (accounts.isNotEmpty && selectedAccountId == null) {
        selectedAccountId = accounts[0]['id'];
      }
    });
  }

  void loadCategories() async {
    final data = await DBHelper.instance.getCategories('expense');
    setState(() {
      // Убираем дубликаты по имени
      final uniqueCategories = <Map<String, dynamic>>[];
      final seenNames = <String>{};
      for (var category in data) {
        final name = category['name'];
        if (!seenNames.contains(name)) {
          seenNames.add(name);
          uniqueCategories.add(category);
        }
      }
      categories = uniqueCategories;
      if (categories.isNotEmpty) {
        if (selectedCategory == null ||
            !categories.any((c) => c['name'] == selectedCategory)) {
          selectedCategory = categories.first['name'];
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Добавить расход"),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Название",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              focusNode: _amountFocus,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Сумма",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calculate),
                  onPressed: _showCalculator,
                ),
              ),
            ),
            const SizedBox(height: 16),
            categories.isEmpty
                ? const Text("Нет категорий")
                : DropdownButton<String>(
                    value: categories.any((c) => c['name'] == selectedCategory)
                        ? selectedCategory
                        : categories.first['name'],
                    isExpanded: true,
                    items: categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['name'],
                        child: Text(c['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => selectedCategory = val);
                    },
                  ),
            TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddCategoryScreen(type: 'expense'),
                  ),
                );
                if (result == true) {
                  loadCategories();
                }
              },
              child: const Text("Добавить категорию"),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: selectedAccountId,
              decoration: const InputDecoration(
                labelText: "Счет",
                border: OutlineInputBorder(),
              ),
              items: accounts.map<DropdownMenuItem<int>>((acc) {
                return DropdownMenuItem<int>(
                  value: acc['id'] as int,
                  child: Text("${acc['name']} (${acc['currency']})"),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedAccountId = val;
                });
              },
            ),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                  minimumSize: const Size(160, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Сохранить",
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountFocus.dispose();
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}