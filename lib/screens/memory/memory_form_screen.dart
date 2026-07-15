import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  String _type = '旅行';
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _participantIds = {};
  List<String> _locations = [];
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
        _type = memory.type;
        _startDate = memory.startDate;
        _endDate = memory.endDate;
      }
      final participants = await ref
          .read(databaseProvider)
          .memoryDao
          .getParticipants(widget.memoryId!);
      _participantIds.addAll(participants.map((p) => p.personId));
      final locs = await ref
          .read(databaseProvider)
          .memoryDao
          .getLocations(widget.memoryId!);
      _locations = locs.map((l) => l.name).toList();
    }

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
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
            locationNames: _locations,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWith('$e')),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
              // Budget moved to the 费用 tab (per-currency MemoryBudgets).
              _LocationsEditor(
                locations: _locations,
                onChanged: (updated) => setState(() => _locations = updated),
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

// ── Multi-location editor ──────────────────────────────────────────────────────

class _NominatimResult {
  final String displayName;
  final String name;

  const _NominatimResult({required this.displayName, required this.name});

  factory _NominatimResult.fromJson(Map<String, dynamic> json) =>
      _NominatimResult(
        displayName: json['display_name'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  // Short label to save — the venue/place name, or first segment of address
  String get saveName {
    if (name.isNotEmpty) return name;
    return displayName.split(',').first.trim();
  }

  // Muted address line shown in dropdown below the main name
  String get subtitle {
    final parts = displayName.split(',');
    final skip = name.isNotEmpty ? 1 : 0;
    if (parts.length <= skip) return '';
    return parts.skip(skip).take(2).join(',').trim();
  }
}

class _LocationsEditor extends StatefulWidget {
  final List<String> locations;
  final ValueChanged<List<String>> onChanged;
  const _LocationsEditor({required this.locations, required this.onChanged});

  @override
  State<_LocationsEditor> createState() => _LocationsEditorState();
}

class _LocationsEditorState extends State<_LocationsEditor> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<_NominatimResult> _suggestions = [];
  bool _isSearching = false;
  bool _noResults = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _noResults = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _noResults = false;
    });
    _debounce =
        Timer(const Duration(milliseconds: 350), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '6',
        'addressdetails': '0',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'MemoraApp/1.0 (personal offline memory tracker)',
        'Accept-Language': 'zh,en',
      });
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        final results = data
            .map((e) => _NominatimResult.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _suggestions = results;
          _isSearching = false;
          _noResults = results.isEmpty;
        });
      } else {
        setState(() => _isSearching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _pick(_NominatimResult result) {
    widget.onChanged([...widget.locations, result.saveName]);
    _searchCtrl.clear();
    setState(() {
      _suggestions = [];
      _noResults = false;
    });
  }

  void _addManual() {
    final text = _searchCtrl.text.trim();
    if (text.isEmpty) return;
    widget.onChanged([...widget.locations, text]);
    _searchCtrl.clear();
    setState(() {
      _suggestions = [];
      _noResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Saved locations
        if (widget.locations.isNotEmpty) ...[
          ...widget.locations.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _LocationCard(
                    name: e.value,
                    onDelete: () {
                      final updated = [...widget.locations]..removeAt(e.key);
                      widget.onChanged(updated);
                    },
                  ),
                ),
              ),
          const SizedBox(height: 4),
        ],
        // Search field
        TextField(
          controller: _searchCtrl,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: context.l10n.memorySearchLocationHint,
            prefixIcon:
                const Icon(Icons.search, size: 20),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _suggestions = [];
                            _noResults = false;
                          });
                        },
                      )
                    : null,
            isDense: true,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            if (_suggestions.isNotEmpty) {
              _pick(_suggestions.first);
            } else {
              _addManual();
            }
          },
        ),
        // Suggestions dropdown
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDC9A8)),
            ),
            child: Column(
              children: _suggestions.asMap().entries.map((e) {
                final r = e.value;
                final isLast = e.key == _suggestions.length - 1;
                return InkWell(
                  onTap: () => _pick(r),
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.saveName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (r.subtitle.isNotEmpty)
                                    Text(
                                      r.subtitle,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.warmBrown,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                            height: 1,
                            indent: 38,
                            color: Color(0xFFEDD3A8)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        // No results — offer manual add
        if (_noResults)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppColors.warmBrown),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.l10n.memoryNoLocationFound,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.warmBrown),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: _addManual,
                  child: Text(context.l10n.memoryAddManually,
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String name;
  final VoidCallback onDelete;
  const _LocationCard({required this.name, required this.onDelete});

  Future<void> _openMaps(BuildContext context) async {
    final uri = Uri.parse(
        'https://maps.google.com/?q=${Uri.encodeComponent(name)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.memoryMapOpenFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.location_on_outlined,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined,
                size: 18, color: AppColors.warmBrown),
            tooltip: context.l10n.memoryViewOnMap,
            onPressed: () => _openMaps(context),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                size: 18, color: AppColors.warmBrown),
            tooltip: context.l10n.delete,
            onPressed: onDelete,
          ),
        ],
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
