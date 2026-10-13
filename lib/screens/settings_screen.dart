import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../database/seed_data_service.dart'; // 🔥 Импортируем сервис тестовых данных

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  int _reminderHour = 21;
  int _reminderMinute = 0;
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _notificationsEnabled = await _notificationService.areNotificationsEnabled();
    final time = await _notificationService.getReminderTime();
    setState(() {
      _reminderHour = time['hour']!;
      _reminderMinute = time['minute']!;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _notificationService.setNotificationsEnabled(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Уведомления включены' : 'Уведомления выключены'),
        ),
      );
    }
  }

  Future<void> _showTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked != null) {
      setState(() {
        _reminderHour = picked.hour;
        _reminderMinute = picked.minute;
      });
      await _notificationService.setReminderTime(_reminderHour, _reminderMinute);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Напоминание установлено на ${picked.format(context)}'),
          ),
        );
      }
    }
  }

  Future<void> _testNotification() async {
    await _notificationService.showNotification(
      title: 'Тестовое уведомление',
      body: 'Если вы видите это — уведомления работают!',
    );
  }

  // 🔥 НОВАЯ ФУНКЦИЯ ДЛЯ ДОБАВЛЕНИЯ ТЕСТОВЫХ ДАННЫХ
  Future<void> _addTestData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Добавить тестовые данные?'),
        content: const Text(
          'Это действие добавит тестовые транзакции за последние 6 месяцев '
          'и установит лимиты по категориям.\n\n'
          '⚠️ Существующие данные НЕ будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Добавление тестовых данных...'),
            ],
          ),
        ),
      );

      try {
        await SeedDataService().seedAll();

        if (mounted) Navigator.pop(context); // Закрываем индикатор

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Тестовые данные добавлены!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context); // Закрываем индикатор

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Ошибка: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔔 Уведомления
          Card(
            child: SwitchListTile(
              title: const Text('Уведомления'),
              subtitle: const Text('Напоминать о записи расходов'),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              secondary: const Icon(Icons.notifications),
            ),
          ),
          const SizedBox(height: 16),

          // ⏰ Время напоминания
          if (_notificationsEnabled)
            Card(
              child: ListTile(
                title: const Text('Время напоминания'),
                subtitle: Text(
                  '${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: _showTimePicker,
              ),
            ),
          const SizedBox(height: 16),

          // 🧪 Тест уведомления
          Card(
            child: ListTile(
              title: const Text('Проверить уведомления'),
              subtitle: const Text('Отправить тестовое уведомление'),
              trailing: const Icon(Icons.send),
              onTap: _testNotification,
            ),
          ),
          const SizedBox(height: 16),

          // 🔥 НОВАЯ КНОПКА: Добавить тестовые данные
          Card(
            child: ListTile(
              title: const Text('Добавить тестовые данные'),
              subtitle: const Text('Добавить транзакции за 6 месяцев для тестирования'),
              trailing: const Icon(Icons.cloud_download),
              onTap: _addTestData,
            ),
          ),
          const SizedBox(height: 16),

          // ℹ️ Информация
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'О приложении',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Версия: 1.0.0\n'
                    'Финансовый помощник с ML-прогнозами',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}