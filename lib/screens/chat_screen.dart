import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../services/ai_advisor_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final AIAdvisorService _advisor = AIAdvisorService();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _showPresets = true;

  final List<Map<String, String>> _presetQuestions = [
    {'question': 'Где я трачу больше всего', 'label': '📊 Анализ расходов'},
    {'question': 'Как сэкономить', 'label': '💡 Советы по экономии'},
    {'question': 'Сколько могу отложить', 'label': '💰 Накопления'},
    {'question': 'Хватит ли денег до зарплаты', 'label': '💵 До зарплаты'},
    {'question': 'Бюджет на месяц', 'label': '📋 Бюджет месяца'},
    {'question': 'Сколько осталось до конца месяца', 'label': '📅 До конца месяца'},
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final messages = await DBHelper.instance.getChatMessages();
      if (mounted) {
        setState(() {
          _messages.clear();
          if (messages.isEmpty) {
            const greeting = '👋 Привет! Я ваш финансовый советник.\nВыберите вопрос или напишите свой:';
            _messages.add({'role': 'assistant', 'content': greeting});

            // 🔥 ИСПРАВЛЕНИЕ: Сохраняем приветствие в БД, чтобы оно не пропадало
            _saveToDb('assistant', greeting);

            _showPresets = true;
          } else {
            for (var msg in messages) {
              _messages.add({
                'role': msg['role'],
                'content': msg['content'],
              });
            }
            _showPresets = false;
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Ошибка загрузки истории: $e');
    }
  }

  // Хелпер для сохранения
  Future<void> _saveToDb(String role, String content) async {
    try {
      await DBHelper.instance.saveChatMessage(role, content);
    } catch (e) {
      print('Ошибка сохранения в БД: $e');
    }
  }

  void _sendMessage(String question) async {
    if (question.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': question});
      _isLoading = true;
      _showPresets = false;
    });

    await _saveToDb('user', question);

    _controller.clear();
    _scrollToBottom();

    try {
      final advice = await _advisor.getAdvice(question);
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': advice});
          _isLoading = false;
        });
        await _saveToDb('assistant', advice);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Произошла ошибка: $e\nПопробуйте ещё раз.'
          });
          _isLoading = false;
        });
        await _saveToDb('assistant', 'Произошла ошибка: $e');
      }
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю чата?'),
        content: const Text('Все сообщения будут удалены'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Очистить')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DBHelper.instance.clearChatMessages();
        if (mounted) {
          setState(() {
            _messages.clear();
            const greeting = '👋 Привет! Я ваш финансовый советник.\nВыберите вопрос или напишите свой:';
            _messages.add({'role': 'assistant', 'content': greeting});
            // Сохраняем приветствие после очистки
            _saveToDb('assistant', greeting);
            _showPresets = true;
          });
        }
      } catch (e) {
        print('Ошибка очистки: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Финансовый советник',
        style: TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _clearChat, tooltip: 'Очистить'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChatHistory, tooltip: 'Обновить'),
        ],
      ),
      // SafeArea защищает от навигационной панели
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Colors.blue.shade700
                            : Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message['content']!,
                        style: TextStyle(
                          color: isUser ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_showPresets)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Быстрые вопросы:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetQuestions.map((preset) {
                        return ActionChip(
                          label: Text(preset['label']!, style: const TextStyle(fontSize: 12)),
                          onPressed: () => _sendMessage(preset['question']!),
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            if (_isLoading)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: LinearProgressIndicator()),
            Container(
              // 🔥 ИСПРАВЛЕНИЕ: Убрано viewInsets.bottom. Flutter сам всё сдвигает.
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Спросите совета...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                      onSubmitted: (_) => _sendMessage(_controller.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.blue),
                    onPressed: _isLoading ? null : () => _sendMessage(_controller.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}