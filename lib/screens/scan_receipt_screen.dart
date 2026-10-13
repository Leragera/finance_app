import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../database/db_helper.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String _recognizedText = '';
  double? _totalAmount;
  String? _merchant;
  DateTime? _date;
  bool _isProcessing = false;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _image = File(image.path);
        _isProcessing = true;
      });
      await _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_image == null) return;

    final inputImage = InputImage.fromFile(_image!);
    final textRecognizer = TextRecognizer();
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    setState(() {
      _recognizedText = recognizedText.text;
      _extractData(_recognizedText);
      _isProcessing = false;
    });
  }

  void _extractData(String text) {
    final lines = text.split('\n');

    // 🔥 БОЛЕЕ ГИБКИЙ ПОИСК СУММЫ
    // Ищем различные паттерны: ИТОГО, TOTAL, СУММА, ВСЕГО + цифры
    final amountPatterns = [
      // Паттерн 1: ИТОГО/TOTAL/СУММА + цифры + валюта
      RegExp(r'(?:ИТОГО|TOTAL|СУММА|ВСЕГО|ИТОГ|Итого|Сумма|Всего)[:\s]*([0-9\s,\.]+)\s*(?:₽|руб|RUB)?', caseSensitive: false),

      // Паттерн 2: Цифры + валюта (старый, но рабочий)
      RegExp(r'([0-9]+[\s,\.]?[0-9]*)\s*(?:₽|руб|RUB)', caseSensitive: false),

      // Паттерн 3: Просто крупные суммы (2+ цифры перед точкой/пробелом)
      RegExp(r'(?:^|\s)(\d{3,}[\s,\.]?\d*)\s*(?:$|\n)', caseSensitive: false),
    ];

    // 🔥 ПОИСК СУММЫ
    for (var pattern in amountPatterns) {
      for (var line in lines) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final amountStr = match.group(1)?.replaceAll(RegExp(r'[\s,]'), '').replaceAll(',', '.') ?? '';
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0 && amount < 1000000) {
            _totalAmount = amount;
            print('Найдена сумма: $amount');
            break;
          }
        }
      }
      if (_totalAmount != null) break;
    }

    // 🔥 ПОИСК ДАТЫ (более гибкий)
    final datePatterns = [
      RegExp(r'(\d{2}[.-]\d{2}[.-]\d{4})'),  // 14.04.2026
      RegExp(r'(\d{4}[.-]\d{2}[.-]\d{2})'),  // 2026.04.14
      RegExp(r'(\d{2}/\d{2}/\d{4})'),        // 14/04/2026
    ];

    for (var pattern in datePatterns) {
      for (var line in lines) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final dateStr = match.group(1)!.replaceAll('.', '-').replaceAll('/', '-');
          try {
            _date = DateTime.parse(dateStr.split('-').reversed.join('-'));
            print('Найдена дата: $_date');
            break;
          } catch (e) {
            // ignore
          }
        }
      }
      if (_date != null) break;
    }

    // 🔥 ПОИСК МАГАЗИНА (первая строка с буквами, 3-50 символов)
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          trimmed.length > 3 &&
          trimmed.length < 50 &&
          RegExp(r'[а-яА-Яa-zA-Z]').hasMatch(trimmed)) {
        _merchant = trimmed;
        print('Найден магазин: $_merchant');
        break;
      }
    }

    setState(() {});
  }

  Future<void> _saveTransaction() async {
    if (_totalAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось распознать сумму')),
      );
      return;
    }

    final accounts = await DBHelper.instance.getAccounts();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных счетов')),
      );
      return;
    }

    // Автоматически определяем категорию
    String category = 'Прочее';
    if (_merchant != null) {
      final merchantLower = _merchant!.toLowerCase();
      if (merchantLower.contains('пят') || merchantLower.contains('маг') ||
          merchantLower.contains('пере') || merchantLower.contains('лент')) {
        category = 'Продукты';
      } else if (merchantLower.contains('каф') || merchantLower.contains('рест')) {
        category = 'Кафе';
      }
    }

    await DBHelper.instance.insertTransaction({
      'title': _merchant ?? 'Покупка по чеку',
      'amount': _totalAmount,
      'type': 'expense',
      'category': category,
      'accountId': accounts[0]['id'],
      'date': (_date ?? DateTime.now()).toIso8601String(),
    });

    await DBHelper.instance.updateAccountBalance(
      accounts[0]['id'],
      _totalAmount!,
      'expense',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Чек сохранён: ${_totalAmount} ₽')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать чек'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_image!, height: 200),
                )
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Icon(Icons.camera_alt, size: 64)),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickImage,
                icon: _isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt, color: Colors.black),
                label: Text(_isProcessing ? 'Обработка...' : 'Сделать фото'),
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
              if (_recognizedText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Распознанные данные:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (_merchant != null) Text('Магазин: $_merchant'),
                        if (_totalAmount != null) Text('Сумма: ${_totalAmount} ₽'),
                        if (_date != null) Text('Дата: ${_date!.day}.${_date!.month}.${_date!.year}'),
                        const SizedBox(height: 12),
                        const Text(
                          'Полный текст:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _recognizedText,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                      'Сохранить транзакцию',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}