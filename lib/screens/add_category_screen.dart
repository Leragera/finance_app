import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class AddCategoryScreen extends StatefulWidget {
  final String type; // 'income' или 'expense'
  const AddCategoryScreen({super.key, required this.type});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void saveCategory() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    // ✅ ПРОВЕРКА: существует ли уже такая категория
    final existingCategories = await DBHelper.instance.getCategories(widget.type);
    final exists = existingCategories.any((c) => c['name'].toLowerCase() == name.toLowerCase());

    if (exists) {
      // 🔥 Показываем ошибку, если категория уже есть
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Категория "$name" уже существует!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // ✅ Добавляем только если не существует
    await DBHelper.instance.insertCategory({
      'name': name,
      'type': widget.type,
    });

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Новая категория"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Название категории",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveCategory,
              child: const Text("Сохранить"),
            ),
          ],
        ),
      ),
    );
  }
}