import 'package:chikitsya/main.dart';
import 'package:chikitsya/services/auth_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'upload_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () {
              requireLogin(
                context,
                onAuthenticated: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.person, color: Colors.white),
            ),
            onSelected: (value) {
              requireLogin(
                context,
                onAuthenticated: () {
                  if (value == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  } else if (value == 'settings') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  }
                },
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('Profile')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Chikitsya',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your Care Companion',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chat History'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Upload Document'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UploadScreen()),
                );
              },
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Hero Section
            Center(
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png', height: 100),
                  const SizedBox(height: 16),
                  const Text(
                    "Chikitsya",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "The Discharge Care Companion",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await notifications.show(
                        999,
                        "Test Notification",
                        "Take Paracetomal now!!",
                        const NotificationDetails(
                          android: AndroidNotificationDetails(
                            'test_channel',
                            'Test Channel',
                            importance: Importance.max,
                            priority: Priority.high,
                          ),
                        ),
                      );
                    },
                    child: const Text("TEST NOTIFICATION"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            /// Problem Statement
            const Text(
              "Leaving the hospital shouldn’t be confusing.",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Chikitsya transforms complex discharge instructions into a clear, simple care plan so patients and caregivers know exactly what to do at home.",
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),

            const SizedBox(height: 32),

            /// Feature Cards
            Row(
              children: const [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.description,
                    title: "Understand Instructions",
                    subtitle: "Clear, one-page care plan",
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.notifications_active,
                    title: "Smart Reminders",
                    subtitle: "Never miss medicines",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: const [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.warning_amber,
                    title: "Early Alerts",
                    subtitle: "Know when to seek help",
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.family_restroom,
                    title: "Caregiver Friendly",
                    subtitle: "Easy for family members",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            /// CTA Button (AUTH PROTECTED)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  requireLogin(
                    context,
                    onAuthenticated: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UploadScreen()),
                      );
                    },
                  );
                },
                child: const Text(
                  "Upload Discharge Summary",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feature Card Widget
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.teal),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
