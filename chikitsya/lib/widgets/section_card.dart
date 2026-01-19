import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final bool isWarning; // 1. Add the field

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.isWarning = false, // 2. Make it optional with a default of false
  });

  @override
  Widget build(BuildContext context) {
    // 3. Determine colors based on the flag
    // If it's a warning, use Red. If not, use your original Teal.
    final themeColor = isWarning ? Colors.red[700] : Colors.teal;
    final bgColor = isWarning ? Colors.red[50] : Colors.white;

    return Card(
      color: bgColor, // 4. Apply background color (subtle tint for warnings)
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: themeColor), // 5. Apply dynamic icon color
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: themeColor, // 6. Match text color to icon
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...items.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bullet point matches the theme color
                      Text("• ", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}