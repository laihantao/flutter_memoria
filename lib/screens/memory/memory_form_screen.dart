import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/database_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/person_avatar.dart';

class MemoryFormScreen extends ConsumerStatefulWidget {
  final String? memoryId;
  const MemoryFormScreen({super.key, this.memoryId});

  @override
  ConsumerState<MemoryFormScreen> createState() => _MemoryFormScreenState();
}

class _MemoryFormScreenState extends ConsumerState<MemoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _type = '旅行';
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _participantIds = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final self = await ref.read(databaseProvider).personDao.getSelfPerson();
    if (self != null) _participantIds.add(self.id);

    if (widget.memoryId != null) {
      final memory = await ref.read(memoryProvider(widget.memoryId!).future);
      if (memory != null) {
        _titleCtrl.text = memory.title;
        _descCtrl.text = memory.description ?? '';
        _locationCtrl.text = memory.locationName ?? '';
        _type = memory.type;
        _startDate = memory.startDate;
        _endDate = memory.endDate;
      }
      final participants = await ref
          .read(databaseProvider)
          .memoryDao
          .getParticipants(widget.memoryId!);
      _participantIds.addAll(participants.map((p) => p.personId));
    }

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCustomCategoryDialog() async {
    final l10n = context.l10n;
    // Use onChanged + local variable to avoid TextEditingController.dispose()
    // race with dialog widget teardown (causes _dependents.isEmpty assertion).
    String inputText = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.categoryCreateTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.categoryNameLabel),
            onChanged: (v) => inputText = v,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.categoryNameRequired : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final cat = await ref
          .read(memoryNotifierProvider.notifier)
          .createTimeCategory(inputText.trim());
      if (mounted) setState(() => _type = cat.name);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.memoryStartRequired)));
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref.read(memoryNotifierProvider.notifier).saveMemory(
            existingId: widget.memoryId,
            title: _titleCtrl.text.trim(),
            type: _type,
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            startDate: _startDate!,
            endDate: _endDate,
            locationName: _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            participantIds: _participantIds.toList(),
          );
      if (mounted) {
        if (widget.memoryId == null) {
          context.go('/memories/$id');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.savedSuccess),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l10n = context.l10n;
    final categoriesAsync = ref.watch(timeCategoriesProvider);
    final selfAsync = ref.watch(selfPersonStreamProvider);
    final personsAsync = ref.watch(personsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memoryId == null
            ? l10n.memoryFormNew
            : l10n.memoryFormEdit),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.memoryTypeLabel,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              categoriesAsync.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (categories) => Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ...categories.map((cat) => ChoiceChip(
                          label: Text(cat.name),
                          selected: _type == cat.name,
                          onSelected: (_) => setState(() => _type = cat.name),
                        )),
                    ChoiceChip(
                      label: Text(l10n.categoryCustom),
                      selected: false,
                      showCheckmark: false,
                      avatar: const Icon(Icons.add, size: 16),
                      onSelected: (_) => _showCustomCategoryDialog(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                    labelText: l10n.memoryTitleLabel,
                    prefixIcon: const Icon(Icons.title)),
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? l10n.memoryFormRequired
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(
                    labelText: l10n.memoryDescriptionLabel,
                    prefixIcon: const Icon(Icons.notes)),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _LocationField(
                controller: _locationCtrl,
                label: l10n.memoryLocationLabel,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: l10n.memoryStartDateLabel,
                      value: _startDate,
                      onPick: (d) => setState(() => _startDate = d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: l10n.memoryEndDateLabel,
                      value: _endDate,
                      onPick: (d) => setState(() => _endDate = d),
                      clearable: true,
                      onClear: () => setState(() => _endDate = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(l10n.memoryParticipantsLabel,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              personsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text(l10n.errorWith('$e')),
                data: (persons) {
                  final self = selfAsync.value;
                  final all = [
                    ?self,
                    ...persons,
                  ];
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: all
                        .map((p) => FilterChip(
                              avatar: PersonAvatar(
                                  name: p.name,
                                  imagePath: p.avatarPath,
                                  radius: 12),
                              label: Text(p.name),
                              selected: _participantIds.contains(p.id),
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _participantIds.add(p.id);
                                } else {
                                  _participantIds.remove(p.id);
                                }
                              }),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const _LocationField({required this.controller, required this.label});

  @override
  State<_LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<_LocationField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(
          Icons.location_on_outlined,
          color: hasText ? AppColors.primary : AppColors.warmBrown,
        ),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => widget.controller.clear(),
              )
            : null,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final bool clearable;
  final VoidCallback? onClear;

  const _DateField({
    required this.label,
    this.value,
    required this.onPick,
    this.clearable = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: clearable && value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear)
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value == null
              ? l10n.selectDate
              : '${value!.day}/${value!.month}/${value!.year}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
