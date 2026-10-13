import 'package:flutter/material.dart';
import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import 'add_account_screen.dart';
import '../database/db_helper.dart';
import 'package:fl_chart/fl_chart.dart';
import 'account_detail_screen.dart';
import 'edit_transaction_screen.dart';
import '../services/ml_service.dart';
import 'chat_screen.dart';
import 'report_screen.dart';
import 'limits_screen.dart';
import 'goals_screen.dart';
import 'transfer_screen.dart';
import 'transfer_between_accounts_screen.dart';
import 'scan_receipt_screen.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final List<String> months = [
    "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
    "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
  ];
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> transactions = [];
  late TabController _tabController;
  DateTime selectedMonth = DateTime.now();
  int? selectedAccountId;
  String _statPeriod = 'month';
  String _statType = 'both';
  bool _shouldRefreshForecast = true;
  Map<String, dynamic>? _cachedForecast;
  double totalIncome = 0;
  double totalExpense = 0;

  @override
  void initState() {
    super.initState();
    loadTransactions();
    loadAccounts();
    _tabController = TabController(length: 6, vsync: this);
     NotificationService().init();
  }

  Future<void> loadTransactions() async {
    final data = await DBHelper.instance.getTransactions();
    setState(() {
      transactions = data;
      _shouldRefreshForecast = true;
      _cachedForecast = null;
    });
  }

  Future<void> loadAccounts() async {
    accounts = await DBHelper.instance.getAccounts();
    setState(() {});
    _shouldRefreshForecast = true;
    _cachedForecast = null;
  }

  String getAccountName(int? id) {
    final acc = accounts.firstWhere(
      (a) => a['id'] == id,
      orElse: () => {},
    );
    return acc.isNotEmpty ? acc['name'] : 'Без счета';
  }

  double getTotalBalance() {
    double total = 0;
    for (var acc in accounts) {
      total += acc['balance'] ?? 0;
    }
    return total;
  }

  List<Map<String, dynamic>> _filterByPeriod(List<Map<String, dynamic>> data, String type) {
    final now = DateTime.now();
    DateTime startDate;
    switch (_statPeriod) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }
    return data.where((t) {
      if (type != 'both' && t['type'] != type) return false;
      final date = DateTime.parse(t['date']);
      return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
    }).toList();
  }

  Map<String, double> _groupDataForChart(List<Map<String, dynamic>> data) {
    final Map<String, double> result = {};

    // 🔥 Сортируем данные по дате перед группировкой
    final sortedData = List<Map<String, dynamic>>.from(data);
    sortedData.sort((a, b) {
      final dateA = DateTime.parse(a['date']);
      final dateB = DateTime.parse(b['date']);
      return dateA.compareTo(dateB); // От старых к новым
    });

    for (var item in sortedData) {
      final date = DateTime.parse(item['date']);
      String key;
      switch (_statPeriod) {
        case 'week':
          key = '${date.day}.${date.month}';
          break;
        case 'year':
          // 🔥 Формат для года: "Мес'год" чтобы было компактнее
          key = '${months[date.month - 1].substring(0, 3)}';
          break;
        default:
          key = '${date.day} ${months[date.month - 1].substring(0, 3)}';
      }
      result[key] = (result[key] ?? 0) + item['amount'];
    }
    return result;
  }


  @override
  Widget build(BuildContext context) {
    final expenses = transactions.where((t) {
      if (t['type'] != 'expense') return false;
      final date = DateTime.parse(t['date']);
      return date.month == selectedMonth.month && date.year == selectedMonth.year;
    }).toList();
    final incomes = transactions.where((t) {
      if (t['type'] != 'income') return false;
      final date = DateTime.parse(t['date']);
      return date.month == selectedMonth.month && date.year == selectedMonth.year;
    }).toList();
    totalIncome = incomes.fold(0.0, (sum, item) => sum + item['amount']);
    totalExpense = expenses.fold(0.0, (sum, item) => sum + item['amount']);
    final totalBalance = getTotalBalance();

    return SafeArea(
      child: Scaffold(
        // 🔥 ДОБАВЛЯЕМ DRAWER (ВЫДВИЖНУЮ ПАНЕЛЬ)
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[200],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Меню',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Перевод между счетами'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransferBetweenAccountsScreen()),
                  );
                  if (result == true) {
                    loadAccounts();
                    loadTransactions();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner),
                title: const Text('Скан чека'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ScanReceiptScreen()),
                  );
                  if (result == true) {
                    loadTransactions();
                    loadAccounts();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.savings),
                title: const Text('Накопительные цели'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  );
                  if (result == true) {
                    loadAccounts();
                    loadTransactions();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Лимиты по категориям'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LimitsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.assessment),
                title: const Text('Отчёт'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('Чат с советами'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Настройки'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        appBar: AppBar(
          title: const Text('Финансы'),
          // 🔥 КНОПКА МЕНЮ (ГАМБУРГЕР) АВТОМАТИЧЕСКИ ДОБАВЛЯЕТСЯ С DRAWER
        ),
        body: Column(
          children: [
            // 📅 Выбор месяца
            Container(
              width: double.infinity,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: GestureDetector(
                onTap: () async {
                  int? month = await showModalBottomSheet<int>(
                    context: context,
                    builder: (context) => ListView.builder(
                      itemCount: 12,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(months[index]),
                        onTap: () => Navigator.pop(context, index + 1),
                      ),
                    ),
                  );
                  if (month != null) {
                    setState(() {
                      selectedMonth = DateTime(selectedMonth.year, month);
                    });
                  }
                },
                child: Text(
                  "${months[selectedMonth.month - 1]} ${selectedMonth.year}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // 💰 Сводка
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _summaryItem("Доходы", totalIncome),
                  _summaryItem("Расходы", totalExpense),
                  _summaryItem("Баланс", totalBalance),
                ],
              ),
            ),
            // 📑 Вкладки
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey,
              indicatorColor: Colors.blue.shade200,
              tabs: const [
                Tab(text: "Счета", icon: Icon(Icons.account_balance_wallet, size: 18)),
                Tab(text: "Доходы", icon: Icon(Icons.arrow_upward, size: 18)),
                Tab(text: "Расходы", icon: Icon(Icons.arrow_downward, size: 18)),
                Tab(text: "Диаграммы", icon: Icon(Icons.pie_chart, size: 18)),
                Tab(text: "Статистика", icon: Icon(Icons.bar_chart, size: 18)),
                Tab(text: "Прогноз", icon: Icon(Icons.trending_up, size: 18)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAccountsTab(),
                  _buildTransactionsTab('income', Colors.green, "Добавить доход"),
                  _buildTransactionsTab('expense', Colors.red, "Добавить расход"),
                  _buildChartsTab(incomes, expenses),
                  _buildStatisticsTab(),
                  _buildForecastTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsTab() {
    return Column(
      children: [
        Expanded(child: buildAccountsGrid()),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildSmallButton(
            "Добавить счет",
            () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddAccountScreen()),
              );
              if (result == true) loadAccounts();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab(String type, Color color, String buttonText) {
    final data = transactions.where((t) {
      if (t['type'] != type) return false;
      final date = DateTime.parse(t['date']);
      return date.month == selectedMonth.month && date.year == selectedMonth.year;
    }).toList();

    return Column(
      children: [
        Expanded(child: buildList(data, color, type)),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildSmallButton(
            buttonText,
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      type == 'income' ? const AddIncomeScreen() : const AddExpenseScreen(),
                ),
              );
              loadTransactions();
              loadAccounts();
              setState(() {
                _shouldRefreshForecast = true;
                _cachedForecast = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChartsTab(List incomes, List expenses) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartCard("Доходы", incomes, Colors.grey),
          const SizedBox(height: 16),
          _buildChartCard("Расходы", expenses, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, List data, Color color) {
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text("Нет данных за $title"),
        ),
      );
    }

    final categoryTotals = <String, double>{};
    for (var item in data) {
      final category = item['category'] ?? 'Другое';
      categoryTotals[category] = (categoryTotals[category] ?? 0) + item['amount'];
    }

    final total = categoryTotals.values.fold(0.0, (a, b) => a + b);

    // 🔥 СТРОГИЕ ЦВЕТА ДЛЯ ДИАГРАММ
    final colors = [
      Colors.blueGrey,
      Colors.grey,
      Colors.brown,
      Colors.blueGrey[700]!,
      Colors.grey[700]!,
      Colors.brown[700]!,
    ];

    final entries = categoryTotals.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Всего: ${total.toStringAsFixed(0)} руб.",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 40,
                  sections: entries.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final catEntry = entry.value;
                    final percent = (catEntry.value / total * 100);
                    return PieChartSectionData(
                      value: catEntry.value,
                      color: colors[idx % colors.length],
                      // 🔥 ИСПРАВЛЕНО: показываем и процент, и сумму
                      title: percent > 8
                          ? "${percent.toStringAsFixed(0)}%\n${catEntry.value.toStringAsFixed(0)} ₽"
                          : "",
                      radius: 35,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: entries.asMap().entries.map((entry) {
                final idx = entry.key;
                final catEntry = entry.value;
                final percent = (catEntry.value / total * 100);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[idx % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 🔥 ИСПРАВЛЕНО: показываем и процент, и сумму в легенде
                    Text(
                      "${catEntry.key}\n${percent.toStringAsFixed(0)}% (${catEntry.value.toStringAsFixed(0)} ₽)",
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Map<String, double>> _groupDataForChartBoth(List<Map<String, dynamic>> data) {
    final result = <String, Map<String, double>>{};

    for (var item in data) {
      final date = DateTime.parse(item['date']);
      final type = item['type'] as String; // 'income' или 'expense'
      final amount = item['amount'] as double;

      String key;
      switch (_statPeriod) {
        case 'week':
          key = '${date.day}.${date.month}';
          break;
        case 'year':
          key = months[date.month - 1];
          break;
        default:
          key = '${date.day} ${months[date.month - 1].substring(0, 3)}';
      }

      result.putIfAbsent(key, () => {'income': 0, 'expense': 0});
      result[key]![type] = (result[key]![type] ?? 0) + amount;
    }
    return result;
  }

  Map<String, Map<String, double>> _mergeDataForBoth(
    Map<String, double> income,
    Map<String, double> expense,
  ) {
    final allKeys = {...income.keys, ...expense.keys};
    final result = <String, Map<String, double>>{};

    for (final key in allKeys) {
      result[key] = {
        'income': income[key] ?? 0,
        'expense': expense[key] ?? 0,
      };
    }

    return result;
  }

  // 🔥 Рассчитывает максимальное значение для Y оси
  double _calculateMaxY(
    Map<String, double> income,
    Map<String, double> expense,
  ) {
    final allValues = [...income.values, ...expense.values];
    if (allValues.isEmpty) return 10;
    final max = allValues.reduce((a, b) => a > b ? a : b);
    return max * 1.2;
  }

  // 🔥 ИСПРАВЛЕННЫЙ _buildStatisticsTab
  Widget _buildStatisticsTab() {
    final incomeData = _filterByPeriod(transactions, 'income');
    final expenseData = _filterByPeriod(transactions, 'expense');

    // Группируем данные по периодам отдельно для доходов и расходов
    final incomeGrouped = _groupDataForChart(incomeData);
    final expenseGrouped = _groupDataForChart(expenseData);

    // 🔥 СОЗДАЁМ entries для отображения
    final entries = _statType == 'both'
        ? _mergeDataForBoth(incomeGrouped, expenseGrouped).entries.toList()
        : (_statType == 'income' ? incomeGrouped : expenseGrouped).entries.toList();

    final totalInc = incomeData.fold(0.0, (s, i) => s + i['amount']);
    final totalExp = expenseData.fold(0.0, (s, i) => s + i['amount']);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[850]
              : Colors.grey[100],
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Период: ", style: TextStyle(fontWeight: FontWeight.w500)),
                  _buildFilterChip("Неделя", 'week'),
                  _buildFilterChip("Месяц", 'month'),
                  _buildFilterChip("Год", 'year'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Тип: ", style: TextStyle(fontWeight: FontWeight.w500)),
                  _buildFilterChip("Доходы", 'income', isType: true),
                  _buildFilterChip("Расходы", 'expense', isType: true),
                  _buildFilterChip("Оба", 'both', isType: true),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _summaryItem("Доходы", totalInc, Colors.green),
              _summaryItem("Расходы", totalExp, Colors.red),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text("Нет данных за выбранный период"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _statType == 'both'
                                ? _calculateMaxYForBoth(incomeGrouped, expenseGrouped)
                                : _calculateMaxYForSingle(_statType == 'income' ? incomeGrouped : expenseGrouped),
                            barGroups: _statType == 'both'
                                ? _buildBothBarGroups(_mergeDataForBoth(incomeGrouped, expenseGrouped))
                                : _buildSingleBarGroups(_statType == 'income' ? incomeGrouped : expenseGrouped),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) return const Text('');
                                    return Text(
                                      '${(value / 1000).toStringAsFixed(0)}к',
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    // 🔥 ИСПРАВЛЕНО: используем entries который определён выше
                                    if (value.toInt() >= 0 && value.toInt() < entries.length) {
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        space: 4,
                                        child: RotatedBox(
                                          quarterTurns: -1,
                                          child: Text(
                                            entries[value.toInt()].key,
                                            style: const TextStyle(fontSize: 9),
                                          ),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 40,
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(show: true),
                            borderData: FlBorderData(show: true),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Легенда ТОЛЬКО для режима "Оба"
                      if (_statType == 'both')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem("Расходы", Colors.grey[700]!),
                            const SizedBox(width: 20),
                            _buildLegendItem("Доходы", Colors.blueGrey[400]!),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }


  // 🔥 Для режима "Оба" (две шкалы)
  List<BarChartGroupData> _buildBothBarGroups(
    Map<String, Map<String, double>> data,
  ) {
    return data.entries.map((entry) {
      final dateKey = entry.key;
      final values = entry.value; // ✅ Доступ к внутреннему Map

      return BarChartGroupData(
        x: data.keys.toList().indexOf(dateKey),
        barRods: [
          // Расходы (серый)
          BarChartRodData(
            toY: values['expense'] ?? 0, // ✅ Теперь работает
            color: Colors.grey[700]!,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
          // Доходы (синий/зелёный)
          BarChartRodData(
            toY: values['income'] ?? 0, // ✅ Теперь работает
            color: Colors.blueGrey[400]!,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        barsSpace: 4,
      );
    }).toList();
  }

  // 🔥 Для режима "Доходы" или "Расходы" (одна шкала)
  List<BarChartGroupData> _buildSingleBarGroups(
    Map<String, double> data,
  ) {
    return data.entries.map((entry) {
      final value = entry.value; // ✅ Доступ к значению

      return BarChartGroupData(
        x: data.keys.toList().indexOf(entry.key),
        barRods: [
          BarChartRodData(
            toY: value, // ✅ Теперь double, не MapEntry
            color: _statType == 'expense'
                ? Colors.grey[700]!
                : Colors.blueGrey[400]!,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  // 🔥 Максимальное значение для режима "Оба"
  double _calculateMaxYForBoth(
    Map<String, double> income,
    Map<String, double> expense,
  ) {
    final allValues = [...income.values, ...expense.values];
    if (allValues.isEmpty) return 10;
    final max = allValues.reduce((a, b) => a > b ? a : b);
    return max * 1.2;
  }

  // 🔥 Максимальное значение для режима "Один тип"
  double _calculateMaxYForSingle(Map<String, double> data) {
    if (data.values.isEmpty) return 10;
    final max = data.values.reduce((a, b) => a > b ? a : b);
    return max * 1.2;
  }

  Widget _buildFilterChip(String label, String value, {bool isType = false}) {
    final isSelected = isType ? _statType == value : _statPeriod == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.black : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            if (isType) {
              _statType = value;
            } else {
              _statPeriod = value;
            }
          });
        },
        selectedColor: Colors.grey[300],
        checkmarkColor: Colors.black,
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 4, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _summaryItem(String title, double value, [Color? color]) {
    return Column(
      children: [
        Text(
          "${value.toStringAsFixed(0)} руб.",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSmallButton(String text, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          foregroundColor: Colors.black,
          minimumSize: const Size(160, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget buildList(List data, Color color, String type) {
    if (data.isEmpty) {
      return const Center(child: Text("Нет данных"));
    }

    List filteredTransactions = data.where((t) {
      final date = DateTime.parse(t['date']);
      final matchMonth = date.month == selectedMonth.month && date.year == selectedMonth.year;
      final matchAccount = selectedAccountId == null || t['accountId'] == selectedAccountId;
      return matchMonth && matchAccount;
    }).toList();

    return ListView.separated(
      itemCount: filteredTransactions.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade300),
      itemBuilder: (context, index) {
        final t = filteredTransactions[index];
        final date = DateTime.parse(t['date']);
        final formattedDate = "${date.day}.${date.month}.${date.year}";

        return ListTile(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditTransactionScreen(transaction: t)),
            );
            if (result == true) {
              loadTransactions();
              loadAccounts();
            }
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minLeadingWidth: 40,
          title: Text(
            t['category'] ?? 'Без категории',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                getAccountName(t['accountId']),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                formattedDate,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          trailing: Text(
            "${t['amount']} руб.",
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  Widget buildAccountsGrid() {
    if (accounts.isEmpty) {
      return const Center(
        child: Text(
          'Нет счетов\nНажмите "Добавить счет"',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final acc = accounts[index];
        // 🔥 Безопасное получение баланса с проверкой на null
        final balance = acc['balance'] ?? 0.0;
        final currency = acc['currency'] ?? '₽';
        final colorValue = acc['color'] ?? Colors.blue.value;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AccountDetailScreen(account: acc)),
            );
          },
          child: Card(
            // 🔥 Безопасная работа с цветом
            color: Color(colorValue).withOpacity(0.1),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acc['name'] ?? 'Без названия',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // 🔥 Форматированное отображение баланса
                  Text(
                    '${balance.toStringAsFixed(0)} $currency',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForecastTab() {
    if (_shouldRefreshForecast) {
      _shouldRefreshForecast = false;
      _cachedForecast = null;
    }

    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(_cachedForecast == null ? 'new' : 'cached'),
      future: _cachedForecast != null
          ? Future.value(_cachedForecast)
          : MLService().getForecast(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text("Ошибка загрузки прогноза"));
        }

        _cachedForecast ??= snapshot.data;
        final data = snapshot.data!;
        final forecast = data['forecast'] ?? 0;
        final confidence = (data['confidence'] ?? 0) * 100;
        final trend = data['trend'] ?? 'stable';

        // 🔥 Получаем расходы по месяцам
        final monthlyExpenses = _getMonthlyExpenses();
        final lastActualExpense = monthlyExpenses.isNotEmpty
              ? monthlyExpenses.last['amount'] as double
              : 0.0;

        // 🔥 СОРТИРУЕМ по дате (от старых к новым)
        monthlyExpenses.sort((a, b) {
          final dateA = DateTime.parse(a['date']);
          final dateB = DateTime.parse(b['date']);
          return dateA.compareTo(dateB); // ✅ Старые слева, новые справа
        });

        final currentExpenses = transactions
            .where((t) {
              if (t['type'] != 'expense') return false;
              final date = DateTime.parse(t['date']);
              return date.month == selectedMonth.month &&
                     date.year == selectedMonth.year;
            })
            .fold(0.0, (sum, t) => sum + t['amount']);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        "Прогноз расходов на следующий месяц",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      // 🔥 БЕЛОЕ ЧИСЛО РАСХОДОВ
                      Text(
                        "${forecast.toStringAsFixed(0)} руб.",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTrendIndicator(trend),
                          const SizedBox(width: 8),
                          Text(
                            trend == 'growth'
                                ? "Рост расходов"
                                : trend == 'decline'
                                    ? "Снижение расходов"
                                    : "Стабильно",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: confidence / 100,
                        backgroundColor: Colors.grey.shade200,
                        color: confidence > 70
                            ? Colors.green
                            : confidence > 40
                                ? Colors.orange
                                : Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Уверенность: ${confidence.toStringAsFixed(0)}%",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),

                      _buildExpenseChart(monthlyExpenses, forecast),
                      // 🔥 СЕРАЯ ПЛАШКА ВМЕСТО СИНЕЙ
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Что это значит?",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[300]
                                        : Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Машинное обучение (линейная регрессия)\n"
                              "Анализирует ваши расходы за последние месяцы и находит закономерности:\n"
                              "• Если расходы растут → прогноз будет выше\n"
                              "• Если снижаются → прогноз будет ниже\n"
                              "• Уверенность показывает точность модели (R²)\n"
                              "Текущие расходы: ${currentExpenses.toStringAsFixed(0)} руб.\n"
                              "Точность модели: ${(data['r2_score'] * 100).toStringAsFixed(0)}%",
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                            if ((data['r2_score'] ?? 0) < 0.3 || (data['confidence'] ?? 0) < 0.5)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[900]
                                        : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.grey.shade700,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_rounded,
                                        color: Colors.grey.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Мало данных для точного прогноза\n"
                                          "Добавьте транзакции за 3+ месяца для улучшения точности модели",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey[400]
                                                : Colors.grey[800],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Рекомендации",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendation(
                        trend == 'growth'
                            ? "Ваши расходы растут. Рассмотрите возможность сокращения трат в категориях: Еда, Развлечения"
                            : trend == 'decline'
                                ? "Отлично! Вы контролируете расходы. Продолжайте в том же духе!"
                                : "Ваши расходы стабильны. Поддерживайте текущий бюджет.",
                        trend == 'growth'
                            ? Icons.warning
                            : trend == 'decline'
                                ? Icons.check_circle
                                : Icons.info,
                      ),
                      if (forecast > totalIncome)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildRecommendation(
                            "Внимание! Прогнозируемые расходы превышают ваши доходы. Рекомендуется сократить траты на ${(forecast - totalIncome).toStringAsFixed(0)} руб.",
                            Icons.error,
                            isError: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendIndicator(String trend) {
    return Icon(
      trend == 'growth' ? Icons.trending_up :
      trend == 'decline' ? Icons.trending_down : Icons.trending_flat,
      color: trend == 'growth' ? Colors.red :
             trend == 'decline' ? Colors.green : Colors.orange,
      size: 24,
    );
  }

  Widget _buildRecommendation(String text, IconData icon, {bool isError = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isError ? Colors.red : Colors.blue,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isError ? Colors.red.shade700 : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Динамика расходов',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _cachedForecast != null
                  ? _buildLineChart()
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    // Получаем исторические данные
    final expenses = transactions.where((t) => t['type'] == 'expense').toList();

    // Группируем по месяцам
    final Map<String, double> monthlyExpenses = {};
    for (var t in expenses) {
      final date = DateTime.parse(t['date']);
      final key = '${months[date.month - 1].substring(0, 3)} ${date.year}';
      monthlyExpenses[key] = (monthlyExpenses[key] ?? 0) + t['amount'];
    }

    final entries = monthlyExpenses.entries.toList();

    if (entries.isEmpty) {
      return const Center(child: Text('Нет данных'));
    }

    // 🔥 Добавляем прогнозную точку
    final forecast = _cachedForecast!['forecast'] as double;
    final nextMonthIndex = entries.length.toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${(value / 1000).toStringAsFixed(0)}к',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < entries.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(
                      entries[value.toInt()].key,
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          // 🔥 Линия исторических данных
          LineChartBarData(
            spots: entries.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.value);
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2),
            ),
          ),
          // 🔥 Линия тренда (опционально)
          if (_cachedForecast != null)
            LineChartBarData(
              spots: [
                // Последняя историческая точка
                FlSpot(
                  (entries.length - 1).toDouble(),
                  entries.last.value,
                ),
                // Прогнозная точка
                FlSpot(nextMonthIndex, forecast),
              ],
              isCurved: false,
              color: Colors.orange,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: Colors.orange,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              dashArray: [5, 5], // Пунктирная линия для прогноза
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getMonthlyExpenses() {
    final expenses = transactions.where((t) => t['type'] == 'expense').toList();

    // Группируем по месяцам
    final Map<String, Map<String, dynamic>> monthlyTotals = {};

    for (var expense in expenses) {
      final date = DateTime.parse(expense['date']);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      if (!monthlyTotals.containsKey(key)) {
        monthlyTotals[key] = {
          'year': date.year,
          'month': date.month,
          'amount': 0.0,
        };
      }
      monthlyTotals[key]!['amount'] += expense['amount'];
    }

    // Преобразуем в список для графика
    return monthlyTotals.entries.map((entry) {
      final data = entry.value;
      final year = data['year'] as int;
      final month = data['month'] as int;

      return {
        'date': '${year}-${month.toString().padLeft(2, '0')}-01', // ✅ Полная дата
        'label': '${months[month - 1]} $year',
        'amount': data['amount'] as double,
      };
    }).toList();
  }

  // 🔥 НОВЫЙ МЕТОД для построения графика
  Widget _buildExpenseChart(List<Map<String, dynamic>> monthlyExpenses, double forecast) {
    if (monthlyExpenses.isEmpty) {
      return const Center(child: Text('Нет данных'));
    }

    // 🔥 Добавляем прогнозную точку
    final allData = List<Map<String, dynamic>>.from(monthlyExpenses);
    allData.add({
      'date': 'forecast',
      'label': 'Прогноз',
      'amount': forecast,
      'isForecast': true,
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Динамика расходов',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: _calculateGridInterval(monthlyExpenses),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatYAxis(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < allData.length) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 4,
                              child: Transform.rotate(
                                angle: -0.3,
                                child: Text(
                                  allData[value.toInt()]['label'],
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatYAxis(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: allData.asMap().entries.map((entry) {
                        final isForecast = entry.value['isForecast'] == true;
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value['amount'],
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isForecast = allData[index]['isForecast'] == true;
                          return FlDotCirclePainter(
                            radius: isForecast ? 8 : 5,
                            color: isForecast ? Colors.orange : Colors.blue,
                            strokeWidth: isForecast ? 3 : 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Вспомогательные методы
  double _calculateGridInterval(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 10000;
    final max = data.map((e) => e['amount'] as double).reduce((a, b) => a > b ? a : b);
    return max / 5; // 5 делений
  }

  String _formatYAxis(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}