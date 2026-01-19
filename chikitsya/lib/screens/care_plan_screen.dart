import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

import 'package:chikitsya/l10n/app_localizations.dart';
import 'package:chikitsya/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/section_card.dart';
import 'symptom_screen.dart';
// 🔹 Reminder imports
import 'package:chikitsya/services/reminder_service.dart';
import 'package:chikitsya/utils/reminder_mapper.dart';
import 'package:chikitsya/models/reminder_model.dart';
import 'reminder_timeline_screen.dart';
import '../services/voice_interaction_service.dart';
import '../services/database_service.dart';

class CarePlanScreen extends StatefulWidget {
  final Map<String, dynamic> carePlan;
  final String dischargeSummary;

  const CarePlanScreen({
    super.key,
    required this.carePlan,
    required this.dischargeSummary,
  });

  @override
  State<CarePlanScreen> createState() => _CarePlanScreenState();
}

class _CarePlanScreenState extends State<CarePlanScreen> {
  bool _scheduled = false;
  late VoiceInteractionService _voiceService;
  List<Reminder> _reminders = [];
  bool _isListening = false;
  String? _chatId;

  @override
  void initState() {
    super.initState();
    _initializeChatSession();
    _voiceService = VoiceInteractionService();
    _voiceService.setDischargeSummary(widget.dischargeSummary);
    _voiceService.setConversationCallback(() {
      // Restart listening after TTS completes
      if (mounted) {
        _restartListening();
      }
    });
    _voiceService.setListeningStateCallback((isListening) {
      if (mounted) {
        setState(() {
          _isListening = isListening;
        });
      }
    });
    _voiceService.initializeTts();
    //  Run AFTER first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleRemindersFromCarePlan();
    });
  }

  Future<void> _initializeChatSession() async {
    try {
      // Generate a meaningful title using Gemini AI
      String title = await _generateChatTitle();

      _chatId = await DatabaseService.createChatSession(
        title,
        carePlanData: jsonEncode(widget.carePlan),
        dischargeSummary: widget.dischargeSummary,
      );

      // Set chatId for voice service
      _voiceService.setChatId(_chatId!);

      // Add initial messages to chat
      final uploadMessage = ChatMessage(
        chatId: _chatId!,
        type: 'upload',
        content: 'Discharge summary uploaded and processed',
        timestamp: DateTime.now(),
        isFromUser: false,
      );
      await DatabaseService.addChatMessage(uploadMessage);

      final summaryMessage = ChatMessage(
        chatId: _chatId!,
        type: 'summary',
        content: widget.dischargeSummary,
        timestamp: DateTime.now(),
        isFromUser: false,
      );
      await DatabaseService.addChatMessage(summaryMessage);
    } catch (e) {
      print('Error creating chat session: $e');
    }
  }

  Future<String> _generateChatTitle() async {
    try {
      final language = Provider.of<SettingsProvider>(
        context,
        listen: false,
      ).language;

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/generate-chat-title'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'discharge_summary': widget.dischargeSummary,
          'language': language,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['title'] ?? 'Medical Consultation';
      }
    } catch (e) {
      print('Error generating chat title: $e');
    }

    // Fallback title
    return 'Medical Consultation';
  }

  Future<void> _scheduleRemindersFromCarePlan() async {
    if (_scheduled) return;
    developer.log("Scheduling reminders from care plan");
    developer.log("🟢 CarePlan keys: ${widget.carePlan.keys}");
    try {
      final reminders = mapSummaryToReminders(widget.carePlan);

      if (reminders.isEmpty) {
        developer.log("⚠️ No reminders generated from care plan");
        return;
      }

      setState(() {
        _reminders = reminders;
      });

      await ReminderService.processAndSchedule(reminders);
      _scheduled = true;

      developer.log("✅ Scheduled ${reminders.length} reminders");

      // Store reminders in chat
      if (_chatId != null) {
        final reminderMessage = ChatMessage(
          chatId: _chatId!,
          type: 'reminder',
          content: 'Generated ${reminders.length} care reminders',
          metadata: reminders
              .map(
                (r) => {
                  'title': r.title,
                  'time': r.time.toIso8601String(),
                  'isCritical': r.isCritical,
                },
              )
              .toList()
              .toString(),
          timestamp: DateTime.now(),
          isFromUser: false,
        );
        await DatabaseService.addChatMessage(reminderMessage);
      }
    } catch (e) {
      developer.log("❌ Reminder scheduling failed: $e");
    }
  }

  Future<void> _restartListening() async {
    // Small delay to ensure TTS has fully stopped
    await Future.delayed(Duration(milliseconds: 500));

    bool started = await _voiceService.startListening(context);
    if (!started && mounted) {
      // If failed, show manual input option
      _showTextInputDialog();
    }
  }

  Future<void> _showTextInputDialog() async {
    final TextEditingController controller = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ask a Question'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Voice recognition is not available. Please type your question:',
                ),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Enter your question here...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Ask'),
              onPressed: () async {
                String query = controller.text.trim();
                if (query.isNotEmpty) {
                  Navigator.of(context).pop();
                  final settings = Provider.of<SettingsProvider>(
                    context,
                    listen: false,
                  );
                  await _voiceService.processTextQuery(
                    query,
                    settings.language,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    developer.log("Received Care Plan Data: ${widget.carePlan}");

    // SAFE Parsing of FHIR Bundle
    final bundle = widget.carePlan;
    final entries = (bundle["entry"] ?? []) as List;

    // Find Composition
    final compositionEntry = entries.firstWhere(
      (e) => (e["resource"]?["resourceType"] == "Composition"),
      orElse: () => null,
    );
    final composition = compositionEntry?["resource"] as Map<String, dynamic>?;
    final sections = (composition?["section"] ?? []) as List;

    // Helper to get resources by reference
    Map<String, dynamic> getResource(String ref) {
      final parts = ref.split("/");
      final id = parts[1];
      final type = parts[0];
      return entries.firstWhere(
        (e) =>
            e["resource"]["resourceType"] == type && e["resource"]["id"] == id,
        orElse: () => {"resource": {}},
      )["resource"];
    }

    // Extract data from sections
    List<String> medications = [];
    List<String> followUps = [];
    List<String> warnings = [];
    List<String> diet = [];
    List<String> activity = [];

    for (final section in sections) {
      final title = section["title"] as String?;
      final entryRefs = (section["entry"] ?? []) as List;
      final items = entryRefs
          .map((ref) {
            final resRef = ref["reference"] as String;
            final resource = getResource(resRef);
            if (title == "Medications") {
              final med = resource["medicationCodeableConcept"]?["text"] ?? "";
              final dosage = resource["dosageInstruction"]?[0]?["text"] ?? "";
              return "$med $dosage";
            } else if (title == "Follow-up") {
              return resource["description"] ?? "";
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
          .toList();

      if (title == "Medications") {
        medications = items.cast<String>();
      } else if (title == "Follow-up") {
        followUps = items.cast<String>();
      } else if (title == "Warnings") {
        warnings = items.cast<String>();
      } else if (title == "Diet") {
        diet = items.cast<String>();
      } else if (title == "Activity") {
        activity = items.cast<String>();
      }
    }

    developer.log("Medications: $medications");
    developer.log("Follow-ups: $followUps");
    developer.log("Warnings: $warnings");
    developer.log("Diet: $diet");
    developer.log("Activity: $activity");

    final bool hasAnyData =
        medications.isNotEmpty ||
        followUps.isNotEmpty ||
        warnings.isNotEmpty ||
        diet.isNotEmpty ||
        activity.isNotEmpty;

    developer.log("Has any data: $hasAnyData");

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          l10n.yourCarePlan,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // First check device capabilities
          Map<String, dynamic> capabilities = await _voiceService
              .checkDeviceCapabilities();

          bool started = await _voiceService.startListening(context);
          if (!started && mounted) {
            String errorMessage =
                'Voice recognition is not available on this device.\n\n';

            if (!(capabilities['speech_recognition_available'] ?? false)) {
              errorMessage += '• Speech recognition not supported\n';
            }
            if (!(capabilities['microphone_permission'] ?? false)) {
              errorMessage += '• Microphone permission denied\n';
            }
            List<String> locales = List<String>.from(
              capabilities['available_locales'] ?? [],
            );
            if (locales.isEmpty) {
              errorMessage += '• No speech recognition locales available\n';
            } else {
              errorMessage +=
                  '• Available locales: ${locales.take(3).join(", ")}\n';
            }

            errorMessage +=
                '\nTry using a device with Google Play Services or check internet connection.';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                duration: const Duration(seconds: 10),
                action: SnackBarAction(
                  label: 'Close',
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
        },
        icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
        label: Text(_isListening ? 'Listening...' : 'Ask Question'),
        backgroundColor: _isListening
            ? Colors.red.shade600
            : Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 6,
        tooltip: _isListening
            ? 'Stop listening'
            : 'Ask a question about your care plan',
      ),
      body: !hasAnyData
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                        Icons.assignment_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.noCareInstructions,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload a discharge summary to get personalized care instructions',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (medications.isNotEmpty)
                    SectionCard(
                      title: l10n.medications,
                      icon: Icons.medication_outlined,
                      items: medications,
                    ),

                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      title: l10n.warningSigns,
                      icon: Icons.warning_amber_rounded,
                      items: warnings.map((e) => e.toString()).toList(),
                      isWarning: true,
                    ),
                  ],

                  if (followUps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      title: l10n.toDoList,
                      icon: Icons.event_available,
                      items: followUps.map((e) => e.toString()).toList(),
                    ),
                  ],

                  if (diet.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      title: l10n.dietNutrition,
                      icon: Icons.restaurant,
                      items: diet.map((e) => e.toString()).toList(),
                    ),
                  ],

                  if (activity.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      title: l10n.activityRules,
                      icon: Icons.directions_walk,
                      items: activity.map((e) => e.toString()).toList(),
                    ),
                  ],

                  const SizedBox(height: 32),

                  if (_reminders.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReminderTimelineScreen(reminders: _reminders),
                            ),
                          );
                        },
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          'View Today\'s Reminders',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SymptomScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_alert_rounded),
                      label: Text(
                        l10n.reportNewSymptoms,
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
