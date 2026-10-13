import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class TransferScreen extends StatefulWidget {
  final int? goalId;
  final String? goalName;
  final double? currentAmount;
  final double? targetAmount;
  final List<Map<String, dynamic>> accounts;

  const TransferScreen({
    super.key,
    this.goalId,
    this.goalName,
    this.currentAmount,
    this.targetAmount,
    required this.accounts,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _amountController = TextEditingController();
  int? _fromAccountId;
  String? _note;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _fromAccountId = widget.accounts[0]['id'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGoalTransfer = widget.goalId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isGoalTransfer ? 'Пополнение цели' : 'Перевод между счетами'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isGoalTransfer) ...[
              Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[850]
                    : Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        widget.goalName!,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Текущая сумма: ${widget.currentAmount} ₽ из ${widget.targetAmount} ₽',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Сумма (₽)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),
            if (!isGoalTransfer) ...[
              DropdownButtonFormField<int>(
                value: _fromAccountId,
                decoration: const InputDecoration(labelText: 'Со счёта', border: OutlineInputBorder()),
                items: widget.accounts.map((acc) {
                  return DropdownMenuItem(
                    value: acc['id'] as int,
                    child: Text('${acc['name']} (${acc['balance']} ${acc['currency']})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _fromAccountId = val),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              decoration: InputDecoration(
                labelText: 'Комментарий (необязательно)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                prefixIcon: const Icon(Icons.note),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
              ),
              onChanged: (val) => _note = val,
            ),
            const SizedBox(height: 32),
            Container(
              margin: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: _performTransfer,
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
                  'Перевести',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performTransfer() async {
    final amount = double.tryParse(_amountController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите сумму')));
      return;
    }

    if (_fromAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите счёт')));
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Перевод выполнен')));
      Navigator.pop(context, true);
    }

    try {
      if (widget.goalId != null) {
        await DBHelper.instance.transferToGoal(
          fromAccountId: _fromAccountId!,
          goalId: widget.goalId!,
          amount: amount,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Перевод выполнен')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}