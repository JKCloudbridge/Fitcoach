import 'package:flutter/material.dart';

/// Reusable placeholder for shell tabs whose real feature lands in a later
/// milestone (Discover/Progress/Coach/messaging/etc. are explicitly out of
/// scope for Milestones 1-2 per the project's own instructions) -- proves
/// the tab's navigation destination exists without building the feature.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, this.subtitle, this.actions});

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_empty, size: 48),
              const SizedBox(height: 16),
              Text('$title -- coming in a later milestone', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
