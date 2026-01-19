import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final profile = context.read<ProfileProvider>();
    final controller = TextEditingController(text: profile.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName == null) return;
    await profile.setName(newName);
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will be returned to the welcome screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await AuthService.logout();
    await context.read<ProfileProvider>().clearForLogout();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Consumer<ProfileProvider>(
        builder: (context, profile, _) {
          final phone = profile.phoneNumber.isNotEmpty
              ? profile.phoneNumber
              : 'Phone not available';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(48),
                      onTap: profile.busy
                          ? null
                          : () async {
                              await profile.pickAndSaveProfileImage();
                              final err = profile.lastError;
                              if (err != null && context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(err)));
                              }
                            },
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.teal,
                        backgroundImage: profile.profileImage,
                        child: profile.profileImage == null
                            ? const Icon(
                                Icons.person,
                                size: 48,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.surface,
                      child: Icon(
                        Icons.edit,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Edit name',
                      onPressed: () => _editName(context),
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                ),
                Text(phone, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo_camera),
                        title: Text(
                          profile.busy
                              ? 'Uploading…'
                              : 'Upload/change profile photo',
                        ),
                        onTap: profile.busy
                            ? null
                            : () async {
                                await profile.pickAndSaveProfileImage();
                                final err = profile.lastError;
                                if (err != null && context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text(err)));
                                }
                              },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Logout'),
                        onTap: () => _logout(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
