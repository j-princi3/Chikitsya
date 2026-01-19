import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SymptomScreen extends StatefulWidget {
  const SymptomScreen({super.key});

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> {
  final Map<String, bool> symptoms = {
    "Fever": false,
    "Pain": false,
    "Breathing difficulty": false,
    "Confused about medicines": false,
  };

  final TextEditingController otherSymptomsController = TextEditingController();

  bool isSubmitting = false;

  Future<void> submitSymptoms() async {
    final selectedSymptoms = symptoms.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final otherSymptoms = otherSymptomsController.text.trim();

    if (selectedSymptoms.isEmpty && otherSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select or enter at least one symptom"),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final response = await ApiService.reportSymptoms(
        selectedSymptoms: selectedSymptoms,
        otherSymptoms: otherSymptoms,
      );

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Report Submitted"),
          content: Text(response),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // back to care plan
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to submit: $e")));
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  void dispose() {
    otherSymptomsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("How are you feeling?")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...symptoms.keys.map(
              (key) => CheckboxListTile(
                title: Text(key),
                value: symptoms[key],
                onChanged: (val) {
                  setState(() => symptoms[key] = val!);
                },
              ),
            ),

            const SizedBox(height: 12),

            /// Other symptoms text field
            TextField(
              controller: otherSymptomsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Other symptoms (optional)",
                hintText: "E.g. dizziness, nausea, headache",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : submitSymptoms,
                child: isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text("Submit"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
