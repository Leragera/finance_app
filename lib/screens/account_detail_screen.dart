import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class AccountDetailScreen extends StatefulWidget {
  final Map<String, dynamic> account;
  const AccountDetailScreen({super.key, required this.account});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> transfers = [];
  List<Map<String, dynamic>> allOperations = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadData();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _loadData() async {
    // Загружаем транзакции
    final allTransactions = await DBHelper.instance.getTransactions();
    final filteredTransactions = allTransactions.where((t) {
      return t['accountId'] == widget.account['id'];
    }).toList();

    // Загружаем переводы
    final allTransfers = await DBHelper.instance.getTransfers();
    final filteredTransfers = allTransfers.where((t) {
      return t['fromAccountId'] == widget.account['id'] ||
          t['toAccountId'] == widget.account['id'];
    }).toList();

    setState(() {
      transactions = filteredTransactions;
      transfers = filteredTransfers;
      // Объединяем всё в один список
      allOperations = _mergeOperations(filteredTransactions, filteredTransfers);
    });
  }

  // 🔥 МЕТОД РЕДАКТИРОВАНИЯ СЧЁТА
  Future<void> _editAccount() async {
    final nameController = TextEditingController(text: widget.account['name']);
    final balanceController = TextEditingController(
        text: widget.account['balance'].toString());
    String currency = widget.account['currency'] ?? '₽';
    Color selectedColor = Color(widget.account['color'] ?? Colors.blue.value);

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Редактировать счёт'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Баланс',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: currency,
                  isExpanded: true,
                  items: ['₽', '\$', '€']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    setDialogState(() => currency = val!);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Цвет счёта:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final isSelected = selectedColor.value == c.value;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => selectedColor = c);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final balance = double.tryParse(balanceController.text);

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введите название счёта')),
                  );
                  return;
                }

                if (balance == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введите корректный баланс')),
                  );
                  return;
                }

                // Обновляем счёт в базе данных
                await DBHelper.instance.updateAccount(
                  widget.account['id'],  // ← Первый аргумент: id
                  {                       // ← Второй аргумент: данные
                    'name': nameController.text,
                    'balance': balance,
                    'currency': currency,
                    'color': selectedColor.value,
                  },
                );

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {}); // Обновляем экран
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Счёт успешно обновлён'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 МЕТОД УДАЛЕНИЯ СЧЁТА
  Future<void> _deleteAccount() async {
    // Проверяем, есть ли транзакции
    if (transactions.isNotEmpty || transfers.isNotEmpty) {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Внимание'),
          content: const Text(
            'Этот счёт содержит транзакции и переводы. '
            'При удалении счёта все связанные операции будут удалены.\n\n'
            'Вы уверены, что хотите продолжить?',
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

      if (confirm != true) return;
    } else {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удаление счёта'),
          content: const Text('Вы уверены, что хотите удалить этот счёт?'),
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

      if (confirm != true) return;
    }

    try {
      // Удаляем счёт из базы данных
      await DBHelper.instance.deleteAccount(widget.account['id']);

      if (mounted) {
        Navigator.pop(context, true); // Возвращаемся с флагом обновления
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Счёт успешно удалён'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 Объединяем транзакции и переводы в один список
  List<Map<String, dynamic>> _mergeOperations(
    List<Map<String, dynamic>> transactions,
    List<Map<String, dynamic>> transfers,
  ) {
    final merged = <Map<String, dynamic>>[];

    // Добавляем транзакции
    for (var t in transactions) {
      merged.add({
        'type': 'transaction',
        'subtype': t['type'], // 'income' или 'expense'
        'title': t['title'] ?? t['category'] ?? 'Без названия',
        'category': t['category'],
        'amount': t['amount'],
        'date': t['date'],
        'accountId': t['accountId'],
      });
    }

    // Добавляем переводы
    for (var t in transfers) {
      final isOutgoing = t['fromAccountId'] == widget.account['id'];
      final isToGoal = t['toAccountId'] == 0; // 0 означает цель
      final isFromGoal = t['fromAccountId'] == 0;

      merged.add({
        'type': 'transfer',
        'subtype': isOutgoing ? 'outgoing' : 'incoming',
        'title': isToGoal
            ? 'В цель'
            : isFromGoal
                ? 'Из цели'
                : 'Перевод',
        'category': isToGoal
            ? 'Цель'
            : isFromGoal
                ? 'Цель'
                : 'Перевод',
        'amount': t['amount'],
        'date': t['date'],
        'note': t['note'] ?? '',
        'fromAccountId': t['fromAccountId'],
        'toAccountId': t['toAccountId'],
      });
    }

    // Сортируем по дате (новые сначала)
    merged.sort((a, b) {
      final dateA = DateTime.parse(a['date']);
      final dateB = DateTime.parse(b['date']);
      return dateB.compareTo(dateA);
    });

    return merged;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account['name']),
        actions: [
          // 🔥 КНОПКА РЕДАКТИРОВАНИЯ
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Редактировать счёт',
            onPressed: _editAccount,
          ),
          // 🔥 КНОПКА УДАЛЕНИЯ
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Удалить счёт',
            onPressed: _deleteAccount,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Все операции'),
            Tab(text: 'Транзакции'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 🔥 Все операции (транзакции + переводы)
          buildOperationsList(allOperations),
          // Только транзакции
          buildTransactionsList(),
        ],
      ),
    );
  }

  // 🔥 Виджет для всех операций (транзакции + переводы)
  Widget buildOperationsList(List<Map<String, dynamic>> operations) {
    if (operations.isEmpty) {
      return const Center(child: Text('Нет операций'));
    }

    return ListView.separated(
      itemCount: operations.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.shade300,
      ),
      itemBuilder: (context, index) {
        final op = operations[index];
        final date = DateTime.parse(op['date']);
        final formattedDate = '${date.day}.${date.month}.${date.year}';
        final isTransaction = op['type'] == 'transaction';
        final isTransfer = op['type'] == 'transfer';

        // Определяем цвет и иконку
        Color amountColor;
        IconData icon;
        String prefix = '';

        if (isTransaction) {
          if (op['subtype'] == 'income') {
            amountColor = Colors.green;
            icon = Icons.arrow_upward;
            prefix = '+';
          } else {
            amountColor = Colors.red;
            icon = Icons.arrow_downward;
            prefix = '-';
          }
        } else {
          // Перевод
          if (op['subtype'] == 'outgoing') {
            amountColor = Colors.orange;
            icon = Icons.swap_horiz;
            prefix = '-';
          } else {
            amountColor = Colors.blue;
            icon = Icons.swap_horiz;
            prefix = '+';
          }
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: amountColor.withOpacity(0.1),
            child: Icon(icon, color: amountColor, size: 20),
          ),
          title: Text(
            op['title'],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTransfer && op['note']?.isNotEmpty == true)
                Text(
                  op['note'],
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          trailing: Text(
            '$prefix${op['amount'].toStringAsFixed(0)} ₽',
            style: TextStyle(
              color: amountColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  // 🔥 Виджет только для транзакций (старый функционал)
  Widget buildTransactionsList() {
    final expenses = transactions.where((t) => t['type'] == 'expense').toList();
    final incomes = transactions.where((t) => t['type'] == 'income').toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Расходы'),
              Tab(text: 'Доходы'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                buildList(expenses, Colors.red),
                buildList(incomes, Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildList(List data, Color color) {
    if (data.isEmpty) {
      return const Center(child: Text('Нет операций'));
    }

    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final t = data[index];
        return Card(
          child: ListTile(
            title: Text(
              t['category'] ?? 'Без категории',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              t['date'].toString().substring(0, 16),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            trailing: Text(
              '${t['amount']} ₽',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}