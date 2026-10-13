import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../widgets/calculator_input.dart';
import 'add_category_screen.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
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

  // ✅ ИСПРАВЛЕНО: Future<void> вместо void + предупреждения
  Future<void> _saveIncome() async {
    final title = _titleController.text;
    final amount = double.tryParse(_amountController.text);

    // ✅ Проверка валидности с сообщением пользователю
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Введите источник дохода')),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Введите корректную сумму')),
      );
      return;
    }

    if (selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Выберите счёт')),
      );
      return;
    }

    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Выберите категорию')),
      );
      return;
    }

    // 🔥 ПРЕДУПРЕЖДЕНИЕ ДЛЯ КРУПНЫХ СУММ (защита от ошибок)
    if (amount >= 100000) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Крупная сумма'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Вы добавляете доход: ${amount.toStringAsFixed(0)} ₽'),
              const SizedBox(height: 8),
              const Text(
                'Это крупная сумма. Проверьте, правильно ли вы ввели данные.',
                style: TextStyle(color: Colors.orange),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Всё верно'),
            ),
          ],
        ),
      );

      // Если пользователь отменил — выходим
      if (confirm != true) return;
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
        'type': 'income',
        'category': selectedCategory,
        'accountId': selectedAccountId,
        'date': DateTime.now().toString(),
      });

      // 🔥 Обновляем баланс счёта
      await DBHelper.instance.updateAccountBalance(
        selectedAccountId!,
        amount,
        'income',
      );

      // Закрываем индикатор загрузки
      if (mounted) Navigator.pop(context);

      // Показываем успех
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Доход ${amount.toStringAsFixed(0)} ₽ сохранён'),
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
    final data = await DBHelper.instance.getCategories('income');
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
        title: const Text("Добавить доход"),
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
                labelText: "Источник",
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
                    builder: (_) => AddCategoryScreen(type: 'income'),
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
                onPressed: _saveIncome,
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