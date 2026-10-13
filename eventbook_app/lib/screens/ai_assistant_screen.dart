import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/event_card.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(AppState appState, String text) {
    appState.sendChatMessage(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final messages = appState.chatMessages;
    if (messages.length != _lastCount) {
      _lastCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    }
    const prompts = ['Garba events near me', 'Music under ₹2000', 'Tech summits in Mumbai', 'Free events this weekend', 'Food events'];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('EventAI Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: prompts
                  .map((text) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(label: Text(text, style: const TextStyle(fontSize: 12)), onPressed: () => _send(appState, text)),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) => _Bubble(message: messages[index]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.barColor(context),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) => _send(appState, value),
                      decoration: InputDecoration(
                        hintText: 'Ask about events, cities, budgets…',
                        filled: true,
                        fillColor: AppTheme.subtle(context),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => _send(appState, _textController.text),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82 > 560 ? 560 : MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(14),
        decoration: isUser
            ? BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(16))
            : AppTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(color: isUser ? Colors.white : null, fontSize: 14, height: 1.4)),
            ...message.recommendedEvents.map((event) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openEvent(context, event),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.subtle(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(width: 48, height: 48, child: EventImage(event.imageUrl, iconSize: 18)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${event.dateLabel} · ${event.location} · ${formatPrice(event.priceStarting)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
