import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';
import 'profile_providers.dart';

class ClientProfileEditScreen extends ConsumerStatefulWidget {
  const ClientProfileEditScreen({super.key});

  @override
  ConsumerState<ClientProfileEditScreen> createState() => _ClientProfileEditScreenState();
}

class _ClientProfileEditScreenState extends ConsumerState<ClientProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalsController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String? _error;
  DateTime? _dateOfBirth;

  void _initFrom(ClientProfile profile) {
    if (_initialized) return;
    _nameController.text = profile.displayName ?? '';
    _heightController.text = profile.heightCm?.toString() ?? '';
    _weightController.text = profile.weightKg?.toString() ?? '';
    _goalsController.text = profile.goals.join(', ');
    _dateOfBirth = profile.dateOfBirth;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
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
      await ref.read(profileRepositoryProvider).updateClientProfile(
        userId: userId,
        displayName: _nameController.text.trim(),
        dateOfBirth: _dateOfBirth,
        heightCm: num.tryParse(_heightController.text.trim()),
        weightKg: num.tryParse(_weightController.text.trim()),
        goals: parseCommaSeparated(_goalsController.text),
      );
      ref.invalidate(clientProfileProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(clientProfileProvider);

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
                InkWell(
                  onTap: _saving ? null : _pickDateOfBirth,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date of birth', border: OutlineInputBorder()),
                    child: Text(_dateOfBirth != null ? DateFormat.yMMMd().format(_dateOfBirth!) : 'Not set'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _goalsController,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Goals (comma separated)', border: OutlineInputBorder()),
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
