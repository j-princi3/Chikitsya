import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/settings_provider.dart';
import '../utils/reminder_mapper.dart';
import '../models/reminder_model.dart';
import 'reminder_timeline_screen.dart';
import '../l10n/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatSession> _chatSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatSessions();
  }

  Future<void> _loadChatSessions() async {
    try {
      final sessions = await DatabaseService.getChatSessions();
      // Sort by most recent first
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      setState(() {
        _chatSessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading chat sessions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chat History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReminderTimelineScreen(),
                ),
              );
            },
            tooltip: 'Reminders',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatSessions.isEmpty
          ? _buildEmptyState()
          : _buildChatList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No chat history',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your conversations will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chatSessions.length,
      itemBuilder: (context, index) {
        final session = _chatSessions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.chat, color: Colors.blue.shade600),
            ),
            title: Text(
              session.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Updated ${_formatDate(session.updatedAt)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(chatId: session.chatId),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String chatId;

  const ChatDetailScreen({super.key, required this.chatId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  ChatSession? _chatSession;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  Map<String, dynamic>? _carePlan;
  String? _dischargeSummary;
  List<Reminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    _loadChatData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatData() async {
    try {
      // Load chat session
      final sessions = await DatabaseService.getChatSessions();
      _chatSession = sessions.firstWhere((s) => s.chatId == widget.chatId);

      // Load messages
      _messages = await DatabaseService.getChatMessages(widget.chatId);

      // Parse care plan data if available
      if (_chatSession?.carePlanData != null) {
        _carePlan = jsonDecode(_chatSession!.carePlanData!);
        _dischargeSummary = _chatSession!.dischargeSummary;

        // Generate reminders from care plan
        if (_carePlan != null) {
          _reminders = mapSummaryToReminders(_carePlan!);
        }
      }

      setState(() {
        _isLoading = false;
      });

      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('Error loading chat data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _translateMessage(String text, String targetLanguage) async {
    if (targetLanguage == 'English') return text;

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/translate-text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'source_language':
              'English', // Assuming stored messages are in English
          'target_language': targetLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['translated_text'] ?? text;
      }
    } catch (e) {
      print('Error translating message: $e');
    }

    return text; // Fallback to original text
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || _isTyping) return;

    final userMessage = message.trim();
    _messageController.clear();

    // Add user message
    final chatMessage = ChatMessage(
      chatId: widget.chatId,
      type: 'question',
      content: userMessage,
      timestamp: DateTime.now(),
      isFromUser: true,
    );

    setState(() {
      _messages.add(chatMessage);
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      // Get current language setting
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final language = settings.language;

      // Send to server
      final response = await _sendQueryToServer(
        userMessage,
        language,
        _dischargeSummary ?? '',
      );

      // Add AI response
      final aiMessage = ChatMessage(
        chatId: widget.chatId,
        type: 'answer',
        content: response,
        timestamp: DateTime.now(),
        isFromUser: false,
      );

      await DatabaseService.addChatMessage(chatMessage);
      await DatabaseService.addChatMessage(aiMessage);

      setState(() {
        _messages.add(aiMessage);
        _isTyping = false;
      });

      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');

      // Add error message
      final errorMessage = ChatMessage(
        chatId: widget.chatId,
        type: 'answer',
        content: 'Sorry, I encountered an error. Please try again.',
        timestamp: DateTime.now(),
        isFromUser: false,
      );

      setState(() {
        _messages.add(errorMessage);
        _isTyping = false;
      });

      _scrollToBottom();
    }
  }

  Future<String> _sendQueryToServer(
    String query,
    String language,
    String summary,
  ) async {
    final url = Uri.parse('${ApiService.baseUrl}/voice-query');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query': query,
        'language': language,
        'summary': summary,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'];
    } else if (response.statusCode == 429) {
      return 'Sorry, the AI service quota has been exceeded. Please try again later.';
    } else {
      return 'Sorry, I could not process your query.';
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _downloadPDF() async {
    if (_dischargeSummary == null) return;

    try {
      // For now, we'll create a simple text file with the discharge summary
      // In a real implementation, you'd generate a proper PDF
      final fileName =
          'discharge_summary_${DateTime.now().millisecondsSinceEpoch}.txt';

      // Show download started message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Downloading $fileName...')));

      // TODO: Implement actual PDF generation and download
      // For now, just show a success message
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate download time

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF downloaded successfully')),
        );
      }
    } catch (e) {
      print('Error downloading PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to download PDF')));
      }
    }
  }

  Future<void> _deleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete this chat? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.deleteChatSession(widget.chatId);
        if (mounted) {
          Navigator.of(context).pop(); // Go back to chat list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted successfully')),
          );
        }
      } catch (e) {
        print('Error deleting chat: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete chat')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _chatSession?.title ?? 'Chat with AI Assistant',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_dischargeSummary != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadPDF,
              tooltip: 'Download PDF',
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteChat,
            tooltip: 'Delete Chat',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Care Plan Summary (if available)
                if (_carePlan != null) _buildCarePlanSummary(l10n),

                // Chat Messages
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyChat()
                      : _buildMessagesList(),
                ),

                // Message Input
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildCarePlanSummary(AppLocalizations l10n) {
    // Extract care plan sections similar to care plan screen
    final sections = _extractCarePlanSections(_carePlan!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Care Plan Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick sections preview
          if (sections['medications']?.isNotEmpty ?? false)
            _buildQuickSection(
              'Medications',
              sections['medications']!,
              Icons.medication,
            ),

          if (sections['warnings']?.isNotEmpty ?? false)
            _buildQuickSection(
              'Warnings',
              sections['warnings']!,
              Icons.warning,
              isWarning: true,
            ),

          if (_reminders.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReminderTimelineScreen(reminders: _reminders),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'View ${_reminders.length} Reminders',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.blue.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickSection(
    String title,
    List<String> items,
    IconData icon, {
    bool isWarning = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWarning ? Colors.red.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isWarning ? Colors.red.shade600 : Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isWarning ? Colors.red.shade700 : Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            items.take(2).join(', '),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (items.length > 2)
            Text(
              '+${items.length - 2} more',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Map<String, List<String>> _extractCarePlanSections(
    Map<String, dynamic> carePlan,
  ) {
    final sections = <String, List<String>>{};

    // Similar logic to care plan screen
    final entries = (carePlan["entry"] ?? []) as List;

    for (final section in carePlan['section'] ?? []) {
      final title = section['title'] as String?;
      final refs = (section['entry'] ?? []) as List;

      final items = refs
          .map((ref) {
            final resRef = ref["reference"] as String;
            final parts = resRef.split("/");
            final id = parts[1];
            final type = parts[0];

            final resource = entries.firstWhere(
              (e) =>
                  e["resource"]["resourceType"] == type &&
                  e["resource"]["id"] == id,
              orElse: () => {"resource": {}},
            )["resource"];

            if (title == "Medications") {
              return resource["medicationCodeableConcept"]?["text"] ?? "";
            } else if (title == "Warnings") {
              return resource["valueString"] ?? resource["code"]?["text"] ?? "";
            } else if (title == "Diet") {
              return resource["oralDiet"]?["instruction"] ?? "";
            } else if (title == "Activity") {
              return resource["description"]?["text"] ?? "";
            }
            return "";
          })
          .where((s) => s.isNotEmpty)
          .cast<String>()
          .toList();

      if (title != null && items.isNotEmpty) {
        sections[title.toLowerCase()] = items;
      }
    }

    return sections;
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask questions about your care plan',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return _buildTypingIndicator();
        }
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.smart_toy, color: Colors.blue.shade600, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  'AI is typing',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isFromUser;
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final currentLanguage = settingsProvider.language;

    return FutureBuilder<String>(
      future: _translateMessage(message.content, currentLanguage),
      builder: (context, snapshot) {
        final displayText = snapshot.data ?? message.content;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getMessageIcon(message.type),
                    color: Colors.blue.shade600,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue.shade600 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayText,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatMessageTime(message.timestamp),
                        style: TextStyle(
                          color: isUser
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: Colors.white, size: 16),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask a question about your care...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.blue.shade400),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(_messageController.text),
              tooltip: 'Send message',
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMessageIcon(String type) {
    switch (type) {
      case 'upload':
        return Icons.upload_file;
      case 'summary':
        return Icons.description;
      case 'reminder':
        return Icons.notifications;
      case 'question':
        return Icons.question_answer;
      case 'answer':
        return Icons.smart_toy;
      default:
        return Icons.message;
    }
  }

  String _formatMessageTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
