import 'package:chikitsya/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(l10n.medicineReminders),
            subtitle: Text(l10n.medicineRemindersDesc),
            value: settings.medicineReminders,
            onChanged: settings.toggleMedicineReminders,
          ),
          SwitchListTile(
            title: Text(l10n.followUpAlerts),
            subtitle: Text(l10n.followUpAlertsDesc),
            value: settings.followUpAlerts,
            onChanged: settings.toggleFollowUpAlerts,
          ),
          SwitchListTile(
            title: Text(l10n.largeText),
            subtitle: Text(l10n.largeTextDesc),
            value: settings.largeText,
            onChanged: settings.toggleLargeText,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(settings.language),
            onTap: () => _showLanguagePicker(context, settings, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(l10n.privacyPolicy),
            onTap: () => _showPrivacyDialog(context, l10n),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [l10n.english, l10n.hindi, l10n.telugu].map((lang) {
          return ListTile(
            title: Text(lang),
            onTap: () {
              settings.changeLanguage(lang);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.privacyPolicy),
        content: Text(l10n.privacyPolicyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}
