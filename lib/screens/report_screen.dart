import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/db_helper.dart';
import 'package:flutter/services.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> accounts = [];
  double totalIncome = 0;
  double totalExpense = 0;
  bool _isLoading = true;
  double _totalBalance = 0;

  DateTime _selectedMonth = DateTime.now();
  final List<String> months = [
    "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
    "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final allTransactions = await DBHelper.instance.getTransactions();
    transactions = allTransactions.where((t) {
      final date = DateTime.parse(t['date']);
      return date.month == _selectedMonth.month &&
          date.year == _selectedMonth.year;
    }).toList();

    accounts = await DBHelper.instance.getAccounts();

    totalIncome = transactions
        .where((t) => t['type'] == 'income')
        .fold(0.0, (sum, t) => sum + t['amount']);
    totalExpense = transactions
        .where((t) => t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + t['amount']);

    _totalBalance = accounts.fold(0.0, (sum, acc) => sum + (acc['balance'] ?? 0));

    setState(() => _isLoading = false);
  }

  Future<void> _exportPdf() async {
    try {
      final pdf = pw.Document();

      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final font = pw.Font.ttf(fontData);
      final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final boldFont = pw.Font.ttf(boldFontData);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Финансовый отчёт',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    font: boldFont,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Период: ${months[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                style: pw.TextStyle(fontSize: 12, font: boldFont),
              ),
              pw.Text(
                'Дата формирования: ${DateTime.now().toString().substring(0, 16)}',
                style: pw.TextStyle(fontSize: 10, font: font),
              ),
              pw.Divider(),
              pw.SizedBox(height: 16),

              pw.Header(
                level: 1,
                child: pw.Text('Общая сводка', style: pw.TextStyle(font: boldFont)),
              ),
              pw.TableHelper.fromTextArray(
                headers: ['Показатель', 'Сумма'],
                data: [
                  ['Доходы', '${totalIncome.toStringAsFixed(0)} ₽'],
                  ['Расходы', '${totalExpense.toStringAsFixed(0)} ₽'],
                  ['Баланс', '${(totalIncome - totalExpense).toStringAsFixed(0)} ₽'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont),
                cellStyle: pw.TextStyle(font: font),
                headerDecoration: pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.centerRight,
              ),
              pw.SizedBox(height: 16),

              pw.Header(
                level: 1,
                child: pw.Text('Транзакции за месяц', style: pw.TextStyle(font: boldFont)),
              ),
              if (transactions.isEmpty)
                pw.Text('Нет транзакций', style: pw.TextStyle(fontSize: 10, font: font))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Дата', 'Категория', 'Тип', 'Сумма'],
                  data: [
                    ...transactions.map((t) {
                      final date = DateTime.parse(t['date']);
                      return [
                        '${date.day}.${date.month}.${date.year}',
                        t['category'] ?? '—',
                        t['type'] == 'income' ? 'Доход' : 'Расход',
                        '${t['amount'].toStringAsFixed(0)} ₽',
                      ];
                    }),
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont),
                  cellStyle: pw.TextStyle(fontSize: 9, font: font),
                  headerDecoration: pw.BoxDecoration(color: PdfColors.grey800),
                  cellAlignment: pw.Alignment.centerRight,
                ),
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'Сформировано в приложении «Финансы»',
                  style: pw.TextStyle(fontSize: 8, font: font),
                ),
              ),
            ],
          ),
        ),
      );

      // 🔥 ИСПРАВЛЕНИЕ: Сохранение в папку Загрузки
      Directory directory;
      String fileName = 'finance_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (Platform.isAndroid) {
        // Запрашиваем разрешение
        if (await Permission.storage.status.isDenied) {
          await Permission.storage.request();
        }

        // 🔥 Используем папку Download
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else if (Platform.isIOS) {
        // Для iOS используем документы
        directory = await getApplicationDocumentsDirectory();
      } else {
        // Для других платформ
        directory = await getApplicationDocumentsDirectory();
      }

      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Сохраняем файл
      await file.writeAsBytes(await pdf.save());

      // Показываем диалог
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Отчёт сохранён'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Файл: $fileName'),
                const SizedBox(height: 8),
                Text(
                  Platform.isAndroid
                      ? 'Папка: Загрузки (Download)'
                      : 'Папка: Документы приложения',
                ),
                const SizedBox(height: 16),
                const Text('Что хотите сделать?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await Share.shareXFiles(
                    [XFile(filePath)],
                    text: 'Финансовый отчёт',
                    subject: 'Отчёт по финансам',
                  );
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.share),
                label: const Text('Поделиться'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Финансовый отчёт'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                      _selectedMonth = DateTime(_selectedMonth.year, month);
                    });
                    _loadData();
                  }
                },
                child: Text(
                  "${months[_selectedMonth.month - 1]} ${_selectedMonth.year}",
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 16),
                    _buildChartsSection(),
                    const SizedBox(height: 16),
                    _buildTransactionsList(),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                label: const Text(
                  'Скачать отчёт (PDF)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Общая сводка за ${months[_selectedMonth.month - 1]}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _summaryItem('Доходы', totalIncome, Colors.green, Icons.arrow_upward),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryItem('Расходы', totalExpense, Colors.red, Icons.arrow_downward),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _totalBalance >= 0
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _totalBalance >= 0
                        ? Icons.account_balance_wallet
                        : Icons.trending_down,
                    color: _totalBalance >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Баланс: ${_totalBalance.toStringAsFixed(0)} ₽',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _totalBalance >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(
            '${amount.toStringAsFixed(0)} ₽',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    final categoryExpenses = <String, double>{};
    for (var t in transactions.where((t) => t['type'] == 'expense')) {
      final category = t['category'] ?? 'Другое';
      categoryExpenses[category] = (categoryExpenses[category] ?? 0) + t['amount'];
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Расходы по категориям',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (categoryExpenses.isEmpty)
              const Center(child: Text('Нет данных'))
            else
              _buildChartWithLegend(categoryExpenses, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildChartWithLegend(Map<String, double> data, Color baseColor) {
    final entries = data.entries.toList();
    final total = data.values.fold(0.0, (a, b) => a + b);
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.amber,
    ];

    return SizedBox(
      height: 180,
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 30,
                sectionsSpace: 2,
                sections: entries.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final value = entry.value.value;
                  final percent = (value / total * 100);
                  return PieChartSectionData(
                    value: value,
                    color: colors[idx % colors.length],
                    title: percent > 10 ? '${percent.toStringAsFixed(0)}%' : '',
                    radius: 35,
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: data.length,
              itemBuilder: (context, index) {
                final entry = data.entries.elementAt(index);
                final percent = (entry.value / total * 100);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Транзакции за ${months[_selectedMonth.month - 1]}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              const Center(child: Text('Нет транзакций'))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length > 20 ? 20 : transactions.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final t = transactions[index];
                  final date = DateTime.parse(t['date']);
                  final isIncome = t['type'] == 'income';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isIncome ? Colors.green : Colors.red,
                    ),
                    title: Text(t['category'] ?? 'Без категории'),
                    subtitle: Text('${date.day}.${date.month}.${date.year}'),
                    trailing: Text(
                      '${t['amount']} ₽',
                      style: TextStyle(
                        color: isIncome ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            if (transactions.length > 20)
              Text(
                '... и ещё ${transactions.length - 20}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }
}