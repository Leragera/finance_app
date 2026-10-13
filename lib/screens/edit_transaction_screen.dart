import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class EditTransactionScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;
  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late String _selectedCategory;
  late int? _selectedAccountId;
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> categories = []; // ✅ Загружаем из БД

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.transaction['title']);
    _amountController = TextEditingController(
      text: widget.transaction['amount'].toString()
    );
    _selectedAccountId = widget.transaction['accountId'];
    loadAccounts();
    loadCategories(); // ✅ Загружаем категории из БД
  }

  void loadAccounts() async {
    final data = await DBHelper.instance.getAccounts();
    setState(() {
      accounts = data;
    });
  }

  void loadCategories() async {
    final String type = widget.transaction['type'];
    final data = await DBHelper.instance.getCategories(type);
    setState(() {
      // ✅ Убираем дубликаты
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

      // ✅ Инициализируем выбранную категорию
      final savedCategory = widget.transaction['category'];
      if (savedCategory != null &&
          categories.any((c) => c['name'] == savedCategory)) {
        _selectedCategory = savedCategory;
      } else if (categories.isNotEmpty) {
        _selectedCategory = categories.first['name'];
      } else {
        _selectedCategory = 'Другое';
      }
    });
  }

  void _saveTransaction() async {
    final title = _titleController.text;
    final amount = double.tryParse(_amountController.text);
    if (title.isEmpty || amount == null || _selectedAccountId == null) return;

    await DBHelper.instance.updateTransaction(
      widget.transaction['id'],
      {
        'title': title,
        'amount': amount,
        'category': _selectedCategory,
        'accountId': _selectedAccountId,
        'type': widget.transaction['type'],
      },
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _deleteTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить ${widget.transaction['type'] == 'income' ? 'доход' : 'расход'}?'),
        content: const Text('Вы уверены?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBHelper.instance.deleteTransaction(
        widget.transaction['id'],
        widget.transaction['accountId'],
        widget.transaction['amount'],
        widget.transaction['type'],
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Редактировать ${widget.transaction['type'] == 'income' ? 'доход' : 'расход'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteTransaction,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: widget.transaction['type'] == 'income' ? 'Источник' : 'Название',
              ),
            ),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Сумма"),
            ),
            const SizedBox(height: 12),
            // ✅ Dropdown с категориями из БД
            categories.isEmpty
                ? const Text("Нет категорий")
                : DropdownButton<String>(
                    value: categories.any((c) => c['name'] == _selectedCategory)
                        ? _selectedCategory
                        : categories.first['name'],
                    isExpanded: true,
                    // ✅ Явно указываем тип
                    items: categories.map<DropdownMenuItem<String>>((c) {
                      return DropdownMenuItem<String>(
                        value: c['name'],
                        child: Text(c['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedCategory = val!);
                    },
                  ),
            const SizedBox(height: 12),
            DropdownButton<int>(
              value: _selectedAccountId,
              isExpanded: true,
              hint: const Text("Выберите счет"),
              items: accounts.map<DropdownMenuItem<int>>((acc) {
                return DropdownMenuItem<int>(
                  value: acc['id'] as int,
                  child: Text("${acc['name']} (${acc['currency']})"),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedAccountId = val;
                });
              },
            ),
            const SizedBox(height: 20),
            Container(
                margin: const EdgeInsets.all(8),
                child: ElevatedButton(
                onPressed: _saveTransaction,
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
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}