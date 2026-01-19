import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/reminder_model.dart';

class ChatMessage {
  final int? id;
  final String chatId;
  final String type; // 'upload', 'summary', 'reminder', 'question', 'answer'
  final String content;
  final String? metadata; // JSON string for additional data
  final DateTime timestamp;
  final bool isFromUser;

  ChatMessage({
    this.id,
    required this.chatId,
    required this.type,
    required this.content,
    this.metadata,
    required this.timestamp,
    required this.isFromUser,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'type': type,
      'content': content,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'isFromUser': isFromUser ? 1 : 0,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      chatId: map['chatId'],
      type: map['type'],
      content: map['content'],
      metadata: map['metadata'],
      timestamp: DateTime.parse(map['timestamp']),
      isFromUser: map['isFromUser'] == 1,
    );
  }
}

class ChatSession {
  final int? id;
  final String chatId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? carePlanData; // JSON string of care plan
  final String? dischargeSummary;

  ChatSession({
    this.id,
    required this.chatId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.carePlanData,
    this.dischargeSummary,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'carePlanData': carePlanData,
      'dischargeSummary': dischargeSummary,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      chatId: map['chatId'],
      title: map['title'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      carePlanData: map['carePlanData'],
      dischargeSummary: map['dischargeSummary'],
    );
  }
}

class GeminiCache {
  final int? id;
  final String cacheKey;
  final String response;
  final DateTime timestamp;

  GeminiCache({
    this.id,
    required this.cacheKey,
    required this.response,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cacheKey': cacheKey,
      'response': response,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory GeminiCache.fromMap(Map<String, dynamic> map) {
    return GeminiCache(
      id: map['id'],
      cacheKey: map['cacheKey'],
      response: map['response'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'chikitsya.db');

    return openDatabase(
      path,
      version: 4, // Increased version for chat session enhancements
      onCreate: (db, _) async {
        //  Reminders table
        await db.execute('''
          CREATE TABLE reminders (
            id INTEGER PRIMARY KEY,
            title TEXT,
            time TEXT,
            critical INTEGER,
            dosage TEXT,
            isCompleted INTEGER DEFAULT 0
          )
        ''');

        //  Adherence table
        await db.execute('''
          CREATE TABLE adherence (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reminder TEXT,
            taken INTEGER,
            timestamp TEXT
          )
        ''');

        // Create chat sessions table
        await db.execute('''
          CREATE TABLE chat_sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chatId TEXT UNIQUE,
            title TEXT,
            createdAt TEXT,
            updatedAt TEXT,
            carePlanData TEXT,
            dischargeSummary TEXT
          )
        ''');

        // Create chat messages table
        await db.execute('''
          CREATE TABLE chat_messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chatId TEXT,
            type TEXT,
            content TEXT,
            metadata TEXT,
            timestamp TEXT,
            isFromUser INTEGER,
            FOREIGN KEY (chatId) REFERENCES chat_sessions (chatId)
          )
        ''');

        // Create gemini cache table
        await db.execute('''
          CREATE TABLE gemini_cache(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cacheKey TEXT UNIQUE,
            response TEXT,
            timestamp TEXT
          )
        ''');

        // Create indexes for better performance
        await db.execute(
          'CREATE INDEX idx_chat_messages_chatId ON chat_messages(chatId)',
        );
        await db.execute(
          'CREATE INDEX idx_chat_messages_timestamp ON chat_messages(timestamp)',
        );
        await db.execute(
          'CREATE INDEX idx_gemini_cache_key ON gemini_cache(cacheKey)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Create chat sessions table
          await db.execute('''
            CREATE TABLE chat_sessions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              chatId TEXT UNIQUE,
              title TEXT,
              createdAt TEXT,
              updatedAt TEXT
            )
          ''');

          // Create chat messages table
          await db.execute('''
            CREATE TABLE chat_messages(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              chatId TEXT,
              type TEXT,
              content TEXT,
              metadata TEXT,
              timestamp TEXT,
              isFromUser INTEGER,
              FOREIGN KEY (chatId) REFERENCES chat_sessions (chatId)
            )
          ''');

          // Create gemini cache table
          await db.execute('''
            CREATE TABLE gemini_cache(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              cacheKey TEXT UNIQUE,
              response TEXT,
              timestamp TEXT
            )
          ''');

          // Create indexes for better performance
          await db.execute(
            'CREATE INDEX idx_chat_messages_chatId ON chat_messages(chatId)',
          );
          await db.execute(
            'CREATE INDEX idx_chat_messages_timestamp ON chat_messages(timestamp)',
          );
          await db.execute(
            'CREATE INDEX idx_gemini_cache_key ON gemini_cache(cacheKey)',
          );
        }

        if (oldVersion < 3) {
          // Add dosage and isCompleted columns to reminders table
          await db.execute('ALTER TABLE reminders ADD COLUMN dosage TEXT');
          await db.execute(
            'ALTER TABLE reminders ADD COLUMN isCompleted INTEGER DEFAULT 0',
          );
        }

        if (oldVersion < 4) {
          // Add carePlanData and dischargeSummary columns to chat_sessions table
          await db.execute(
            'ALTER TABLE chat_sessions ADD COLUMN carePlanData TEXT',
          );
          await db.execute(
            'ALTER TABLE chat_sessions ADD COLUMN dischargeSummary TEXT',
          );
        }
      },
    );
  }

  // ================= REMINDERS =================

  static Future<void> saveReminder(Reminder r) async {
    final db = await database;
    await db.insert('reminders', {
      'id': r.id,
      'title': r.title,
      'time': r.time.toIso8601String(),
      'critical': r.isCritical ? 1 : 0,
      'dosage': r.dosage,
      'isCompleted': r.isCompleted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Reminder>> getReminders() async {
    final db = await database;
    final rows = await db.query('reminders');

    return rows.map((r) {
      return Reminder(
        id: r['id'] as int,
        title: r['title'] as String,
        time: DateTime.parse(r['time'] as String),
        isCritical: (r['critical'] as int) == 1,
        dosage: r['dosage'] as String?,
        isCompleted: (r['isCompleted'] as int?) == 1,
      );
    }).toList();
  }

  static Future<void> updateReminderCompletion(
    int reminderId,
    bool isCompleted,
  ) async {
    final db = await database;
    await db.update(
      'reminders',
      {'isCompleted': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  // ================= ADHERENCE =================

  static Future<void> saveAdherence(String reminder, bool taken) async {
    final db = await database;
    await db.insert('adherence', {
      'reminder': reminder,
      'taken': taken ? 1 : 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ================= CHAT SESSIONS =================

  static Future<String> createChatSession(
    String title, {
    String? carePlanData,
    String? dischargeSummary,
  }) async {
    final db = await database;
    final chatId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    await db.insert('chat_sessions', {
      'chatId': chatId,
      'title': title,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'carePlanData': carePlanData,
      'dischargeSummary': dischargeSummary,
    });

    return chatId;
  }

  static Future<List<ChatSession>> getChatSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_sessions',
      orderBy: 'updatedAt DESC',
    );

    return List.generate(maps.length, (i) => ChatSession.fromMap(maps[i]));
  }

  static Future<void> updateChatSession(String chatId) async {
    final db = await database;
    await db.update(
      'chat_sessions',
      {'updatedAt': DateTime.now().toIso8601String()},
      where: 'chatId = ?',
      whereArgs: [chatId],
    );
  }

  static Future<void> deleteChatSession(String chatId) async {
    final db = await database;
    await db.delete('chat_messages', where: 'chatId = ?', whereArgs: [chatId]);
    await db.delete('chat_sessions', where: 'chatId = ?', whereArgs: [chatId]);
  }

  // ================= CHAT MESSAGES =================

  static Future<void> addChatMessage(ChatMessage message) async {
    final db = await database;
    await db.insert('chat_messages', message.toMap());
    await updateChatSession(message.chatId);
  }

  static Future<List<ChatMessage>> getChatMessages(String chatId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: 'chatId = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) => ChatMessage.fromMap(maps[i]));
  }

  // ================= GEMINI CACHE =================

  static Future<String?> getCachedResponse(String cacheKey) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'gemini_cache',
      where: 'cacheKey = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first['response'];
    }
    return null;
  }

  static Future<void> setCachedResponse(
    String cacheKey,
    String response,
  ) async {
    final db = await database;
    final cache = GeminiCache(
      cacheKey: cacheKey,
      response: response,
      timestamp: DateTime.now(),
    );

    await db.insert(
      'gemini_cache',
      cache.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> clearOldCache({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(maxAge);
    await db.delete(
      'gemini_cache',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  static Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('gemini_cache');
  }
}
