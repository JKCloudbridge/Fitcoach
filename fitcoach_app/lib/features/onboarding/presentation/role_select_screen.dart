import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../profile/data/profile_repository.dart';

/// Shown once per new user, right after their first sign-in, whenever
/// resolveRole() finds neither a trainer_profiles nor client_profiles row --
/// per Plan.md's "Role selection at signup" scope. Neither sibling app has
/// this screen (both are single-role apps), so this is FitCoach-specific,
/// built fresh rather than copied.
class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  final _nameController = TextEditingController();

  String? _selectedRole; // 'trainer' | 'client'
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final role = _selectedRole;
    final userId = ref.read(authProvider).userId;
    final displayName = _nameController.text.trim();

    if (role == null) {
      setState(() => _error = 'Choose whether you\'re a trainer or a client');
      return;
    }
    if (displayName.isEmpty) {
      setState(() => _error = 'Enter your name');
      return;
    }
    if (userId == null) {
      setState(() => _error = 'Your session expired -- sign in again');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repository = ref.read(profileRepositoryProvider);
      if (role == 'trainer') {
        await repository.createTrainerProfile(userId: userId, displayName: displayName);
      } else {
        await repository.createClientProfile(userId: userId, displayName: displayName);
      }
      await ref.read(authProvider.notifier).refreshRole();
      if (mounted) context.go(role == 'trainer' ? '/trainer' : '/client');
    } catch (e) {
      setState(() => _error = 'Could not save your profile: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to FitCoach')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('What brings you here?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                _RoleCard(
                  icon: Icons.sports_gymnastics,
                  title: 'I\'m a trainer',
                  subtitle: 'Build workout cards and coach clients',
                  selected: _selectedRole == 'trainer',
                  onTap: _submitting ? null : () => setState(() => _selectedRole = 'trainer'),
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  icon: Icons.self_improvement,
                  title: 'I\'m a client',
                  subtitle: 'Follow a plan and log my workouts',
                  selected: _selectedRole == 'client',
                  onTap: _submitting ? null : () => setState(() => _selectedRole = 'client'),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Continue'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: selected ? scheme.primary : null),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
