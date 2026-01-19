import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'care_plan_screen.dart';
import '../services/api_service.dart';
import '../providers/settings_provider.dart';

class LoadingScreen extends StatefulWidget {
  final String deidentifiedText;

  const LoadingScreen({super.key, required this.deidentifiedText});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateCarePlan();
    });
  }

  Future<void> _generateCarePlan() async {
    setState(() => _error = null);
    try {
      final settings = context.read<SettingsProvider>();
      final carePlan = await ApiService.generateCarePlan(
        widget.deidentifiedText,
        settings.language,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CarePlanScreen(carePlan: carePlan, dischargeSummary: widget.deidentifiedText)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Creating your care plan…"),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Could not generate care plan",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Back"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _generateCarePlan,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
