import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_service.dart';

class VoiceInteractionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _dischargeSummary = '';
  Function? _onConversationEnd;
  Function(bool)? _onListeningStateChanged;
  String? _chatId;

  VoiceInteractionService();

  void setDischargeSummary(String summary) {
    _dischargeSummary = summary;
  }

  void setConversationCallback(Function callback) {
    _onConversationEnd = callback;
  }

  void setListeningStateCallback(Function(bool) callback) {
    _onListeningStateChanged = callback;
  }

  void setChatId(String chatId) {
    _chatId = chatId;
  }

  bool get isListening => _isListening;

  Future<void> initializeTts() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Set completion handler to restart listening after speaking
    _flutterTts.setCompletionHandler(() {
      developer.log('TTS completed, triggering conversation end callback');
      if (_onConversationEnd != null) {
        _onConversationEnd!();
      }
    });

    // Log available TTS languages for debugging
    List<dynamic> languages = await _flutterTts.getLanguages;
    developer.log('Available TTS languages: $languages');
  }

  Future<Map<String, dynamic>> checkDeviceCapabilities() async {
    Map<String, dynamic> capabilities = {};

    try {
      // Check if speech recognition is available
      bool speechAvailable = await _speech.initialize();
      capabilities['speech_recognition_available'] = speechAvailable;

      // Get available locales
      List<stt.LocaleName> locales = await _speech.locales();
      capabilities['available_locales'] = locales
          .map((l) => l.localeId)
          .toList();

      // Check microphone permission
      var micStatus = await Permission.microphone.status;
      capabilities['microphone_permission'] = micStatus.isGranted;

      // Check TTS languages
      List<dynamic> ttsLanguages = await _flutterTts.getLanguages;
      capabilities['tts_languages'] = ttsLanguages;

      developer.log('Device capabilities: $capabilities');
    } catch (e) {
      developer.log('Error checking device capabilities: $e');
      capabilities['error'] = e.toString();
    }

    return capabilities;
  }

  Future<bool> startListening(BuildContext context) async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      developer.log('Microphone permission denied');
      return false;
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    String language = settings.language;

    // Check if speech recognition is available on this device
    developer.log('Checking speech recognition availability...');
    bool isAvailable = await _speech.initialize();
    if (!isAvailable) {
      developer.log('Speech recognition not available on this device');
      developer.log('Possible reasons:');
      developer.log('1. Device does not support speech recognition');
      developer.log('2. Google Play Services not available or outdated');
      developer.log('3. No internet connection for cloud-based recognition');
      return false;
    }

    // Log available locales for debugging
    await checkDeviceCapabilities();

    if (!_isListening) {
      String localeId = _getSttLocale(language);
      developer.log('Attempting to initialize speech with locale: $localeId');

      // Try with the selected locale first
      bool available = await _tryInitializeWithLocale(localeId);
      if (!available) {
        // If that fails, try with English as fallback
        developer.log('Trying with English fallback');
        available = await _tryInitializeWithLocale('en-US');
      }

      if (available) {
        _isListening = true;
        _onListeningStateChanged?.call(true);
        developer.log('Speech recognition initialized successfully');

        // Store settings before async operation
        final storedLanguage = language;

        await _speech.listen(
          localeId: available ? localeId : 'en-US',
          onResult: (val) async {
            if (val.finalResult) {
              String query = val.recognizedWords;
              developer.log('Recognized speech: $query');
              await _processQueryWithLanguage(query, storedLanguage);
            }
          },
          listenFor: Duration(seconds: 10), // Listen for 10 seconds
          pauseFor: Duration(seconds: 5), // Pause detection
          onSoundLevelChange: (level) => developer.log('Sound level: $level'),
        );
        return true;
      } else {
        developer.log(
          'Failed to initialize speech recognition with any locale',
        );
        return false;
      }
    }
    return false;
  }

  Future<bool> _tryInitializeWithLocale(String localeId) async {
    bool available = await _speech.initialize(
      onStatus: (val) => developer.log('Speech status for $localeId: $val'),
      onError: (val) => developer.log('Speech error for $localeId: $val'),
    );
    return available;
  }

  Future<void> processTextQuery(String query, String language) async {
    await _processQueryWithLanguage(query, language);
  }

  Future<void> _processQueryWithLanguage(String query, String language) async {
    // Stop current listening before processing
    await _speech.stop();
    _isListening = false;
    _onListeningStateChanged?.call(false);

    // Store question in chat
    if (_chatId != null) {
      final questionMessage = ChatMessage(
        chatId: _chatId!,
        type: 'question',
        content: query,
        timestamp: DateTime.now(),
        isFromUser: true,
      );
      await DatabaseService.addChatMessage(questionMessage);
    }

    // Send query to server
    String response = await _sendQueryToGemini(
      query,
      language,
      _dischargeSummary,
    );

    // Store answer in chat
    if (_chatId != null) {
      final answerMessage = ChatMessage(
        chatId: _chatId!,
        type: 'answer',
        content: response,
        timestamp: DateTime.now(),
        isFromUser: false,
      );
      await DatabaseService.addChatMessage(answerMessage);
    }

    // Speak the response
    await _speakResponse(response, language);

    // Restart listening after TTS completes
    _onConversationEnd?.call();
  }

  Future<String> _sendQueryToGemini(
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
      return 'Sorry, the AI service quota has been exceeded. Please try again later or contact support to upgrade the API plan.';
    } else {
      return 'Sorry, I could not process your query.';
    }
  }

  Future<void> _speakResponse(String response, String language) async {
    String ttsLanguage = _getTtsLanguage(language);
    await _flutterTts.setLanguage(ttsLanguage);
    await _flutterTts.speak(response);
  }

  String _getTtsLanguage(String appLanguage) {
    switch (appLanguage) {
      case 'Hindi':
        return 'hi-IN';
      case 'Telugu':
        return 'te-IN';
      default:
        return 'en-US';
    }
  }

  String _getSttLocale(String appLanguage) {
    switch (appLanguage) {
      case 'Hindi':
        return 'hi-IN';
      case 'Telugu':
        return 'te-IN';
      default:
        return 'en-US';
    }
  }
}
