import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';
import 'profile_providers.dart';

/// Plain `Form`/`TextFormField`/`GlobalKey<FormState>`, same shape as
/// baker_ally's edit_profile_screen.dart -- flutter_form_builder is a dead
/// dependency in both sibling apps for exactly this kind of screen.
class TrainerProfileEditScreen extends ConsumerStatefulWidget {
  const TrainerProfileEditScreen({super.key});

  @override
  ConsumerState<TrainerProfileEditScreen> createState() => _TrainerProfileEditScreenState();
}

class _TrainerProfileEditScreenState extends ConsumerState<TrainerProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _certificationsController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String? _error;

  void _initFrom(TrainerProfile profile) {
    if (_initialized) return;
    _nameController.text = profile.displayName ?? '';
    _bioController.text = profile.bio ?? '';
    _certificationsController.text = profile.certifications.join(', ');
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _certificationsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateTrainerProfile(
        userId: userId,
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        certifications: parseCommaSeparated(_certificationsController.text),
      );
      ref.invalidate(trainerProfileProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(trainerProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load your profile: $error')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('No profile found.'));
          _initFrom(profile);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioController,
                  enabled: !_saving,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder(), alignLabelWithHint: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _certificationsController,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Certifications (comma separated)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                      : const Text('Save'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
