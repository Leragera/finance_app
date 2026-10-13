import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class TransferBetweenAccountsScreen extends StatefulWidget {
  const TransferBetweenAccountsScreen({super.key});

  @override
  State<TransferBetweenAccountsScreen> createState() => _TransferBetweenAccountsScreenState();
}

class _TransferBetweenAccountsScreenState extends State<TransferBetweenAccountsScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  List<Map<String, dynamic>> _accounts = [];
  int? _fromAccountId;
  int? _toAccountId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await DBHelper.instance.getAccounts();
    setState(() {
      _accounts = accounts;
      if (_accounts.length >= 2) {
        _fromAccountId = _accounts[0]['id'];
        _toAccountId = _accounts[1]['id'];
      } else if (_accounts.isNotEmpty) {
        _fromAccountId = _accounts[0]['id'];
      }
      _isLoading = false;
    });
  }

  Future<void> _performTransfer() async {
    final amount = double.tryParse(_amountController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }

    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите счета')),
      );
      return;
    }

    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите разные счета')),
      );
      return;
    }

    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Выполняем перевод
      await DBHelper.instance.transferBetweenAccounts(
        fromAccountId: _fromAccountId!,
        toAccountId: _toAccountId!,
        amount: amount,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text,
      );

      // Закрываем индикатор
      if (mounted) Navigator.pop(context);

      // Показываем успех
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Перевод ${amount.toStringAsFixed(0)} ₽ выполнен'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Закрываем индикатор
      if (mounted) Navigator.pop(context);

      // Показываем ошибку
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Перевод между счетами'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Карточка "Со счёта"
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Со счёта',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      if (_accounts.isEmpty)
                        const Text('Нет доступных счетов', style: TextStyle(color: Colors.red))
                      else
                        DropdownButtonFormField<int>(
                          value: _fromAccountId,
                          isDense: false,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[100],
                          ),
                          dropdownColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.white,
                          iconSize: 24,
                          items: _accounts.map((acc) {
                            return DropdownMenuItem(
                              value: acc['id'] as int,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      acc['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        height: 1.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${acc['balance'].toStringAsFixed(0)} ${acc['currency']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        height: 1.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _fromAccountId = val),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Иконка стрелки
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_downward,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Карточка "На счёт"
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'На счёт',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      if (_accounts.isEmpty)
                        const Text('Нет доступных счетов', style: TextStyle(color: Colors.red))
                      else
                        DropdownButtonFormField<int>(
                          value: _toAccountId,
                          isDense: false,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[100],
                          ),
                          dropdownColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.white,
                          iconSize: 24,
                          items: _accounts.map((acc) {
                            return DropdownMenuItem(
                              value: acc['id'] as int,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      acc['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        height: 1.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${acc['balance'].toStringAsFixed(0)} ${acc['currency']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        height: 1.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _toAccountId = val);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Поле суммы
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Сумма (₽)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  prefixIcon: const Icon(Icons.attach_money),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              // Поле комментария
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Комментарий (необязательно)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  prefixIcon: const Icon(Icons.note),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[100],
                ),
              ),
              const SizedBox(height: 32),
              // Кнопка перевода
              Container(
                margin: const EdgeInsets.all(8),
                child: ElevatedButton(
                  onPressed: _accounts.length < 2 ? null : _performTransfer,
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
                  child: _accounts.length < 2
                      ? const Text('Нужно минимум 2 счёта')
                      : const Text(
                          'Перевести',
                          style: TextStyle(fontSize: 14),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}