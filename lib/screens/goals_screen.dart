import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'add_goal_screen.dart';
import 'transfer_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _goals = await DBHelper.instance.getGoals();
    _accounts = await DBHelper.instance.getAccounts();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Накопительные цели',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _goals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.savings, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Нет накопительных целей',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создайте первую цель для накоплений',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.all(8),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddGoalScreen()),
                        );
                        if (result == true) _loadData();
                      },
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: const Text('Создать цель'),
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
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _goals.length,
              itemBuilder: (context, index) {
                final goal = _goals[index];
                final progress = goal['targetAmount'] > 0
                    ? (goal['currentAmount'] / goal['targetAmount'] * 100).clamp(0, 100)
                    : 0.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Color(goal['color'] ?? 0xFF2196F3).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  goal['icon'] ?? '💰',
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal['name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (goal['deadline'] != null)
                                    Text(
                                      'До ${DateTime.parse(goal['deadline']).day}.${DateTime.parse(goal['deadline']).month}.${DateTime.parse(goal['deadline']).year}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'add', child: Text('Пополнить')),
                                const PopupMenuItem(value: 'withdraw', child: Text('Вывести')),
                                const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                              ],
                              onSelected: (value) async {
                                if (value == 'add') {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TransferScreen(
                                        goalId: goal['id'],
                                        goalName: goal['name'],
                                        currentAmount: goal['currentAmount'],
                                        targetAmount: goal['targetAmount'],
                                        accounts: _accounts,
                                      ),
                                    ),
                                  );
                                  if (result == true) _loadData();
                                } else if (value == 'withdraw') {
                                  // Логика вывода
                                  _showWithdrawDialog(goal);
                                } else if (value == 'delete') {
                                  _showDeleteDialog(goal);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Прогресс-бар
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(goal['color'] ?? 0xFF2196F3),
                            ),
                            minHeight: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${goal['currentAmount'].toStringAsFixed(0)} ₽',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(goal['color'] ?? 0xFF2196F3),
                              ),
                            ),
                            Text(
                              '${goal['targetAmount'].toStringAsFixed(0)} ₽',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${progress.toStringAsFixed(0)}% достигнуто',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddGoalScreen()),
          );
          if (result == true) _loadData();
        },
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Новая цель'),
        backgroundColor: Colors.grey[300],
        foregroundColor: Colors.black,
      ),
    );
  }

  void _showWithdrawDialog(Map<String, dynamic> goal) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Вывод из цели'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Цель: ${goal['name']}'),
            Text('Доступно: ${goal['currentAmount']} ₽'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Сумма',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'На счёт'),
              items: _accounts.map((acc) {
                return DropdownMenuItem(
                  value: acc['id'] as int,
                  child: Text('${acc['name']} (${acc['currency']})'),
                );
              }).toList(),
              onChanged: (val) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Вывести'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // TODO: Реализовать вывод
      _loadData();
    }
  }

  void _showDeleteDialog(Map<String, dynamic> goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить цель?'),
        content: Text('Вы уверены, что хотите удалить цель "${goal['name']}"?\n\nСредства будут возвращены на счета.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBHelper.instance.deleteGoal(goal['id']);
      _loadData();
    }
  }
}