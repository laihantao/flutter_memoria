import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_ops.dart';
import '../../widgets/person_avatar.dart';

bool _isPartnerTagLabel(String t) =>
    t == '伴侣' || t.toLowerCase() == 'partner';

class PersonFormScreen extends ConsumerStatefulWidget {
  final String? personId;
  const PersonFormScreen({super.key, this.personId});

  @override
  ConsumerState<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends ConsumerState<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  XFile? _newAvatarFile;
  Uint8List? _avatarBytes;
  Uint8List? _existingAvatarBytes;
  DateTime? _birthday;
  bool _isSelf = false;
  final Set<String> _selectedTags = {};
  final _customTagCtrl = TextEditingController();
  final List<({TextEditingController label, TextEditingController phone})>
      _phones = [];
  final List<
      ({TextEditingController label, TextEditingController address})>
      _addresses = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.personId != null) {
      _loadExisting();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadExisting() async {
    try {
      final person =
          await ref.read(personProvider(widget.personId!).future);
      if (!mounted) return;
      if (person == null) {
        setState(() => _loading = false);
        return;
      }
      _nameCtrl.text = person.name;
      _birthday = person.birthday;
      _isSelf = person.isSelf;

      if (person.avatarPath != null) {
        if (person.avatarPath!.startsWith('data:')) {
          final comma = person.avatarPath!.indexOf(',');
          if (comma != -1) {
            _existingAvatarBytes = base64Decode(person.avatarPath!.substring(comma + 1));
          }
        } else if (!kIsWeb) {
          final absPath = await resolveAvatarAbsPath(person.avatarPath);
          if (absPath != null) {
            _existingAvatarBytes = await readAbsoluteFileBytes(absPath);
          }
        }
      }

      final phones =
          await ref.read(phonesProvider(widget.personId!).future);
      for (final p in phones) {
        _phones.add((
          label: TextEditingController(text: p.label),
          phone: TextEditingController(text: p.phoneNumber),
        ));
      }

      final addresses =
          await ref.read(addressesProvider(widget.personId!).future);
      for (final a in addresses) {
        _addresses.add((
          label: TextEditingController(text: a.label),
          address: TextEditingController(text: a.address),
        ));
      }

      final tags =
          await ref.read(personTagsProvider(widget.personId!).future);
      _selectedTags.addAll(tags.map((t) => t.tagLabel));
    } catch (e) {
      // Swallow — show form in empty state
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customTagCtrl.dispose();
    for (final p in _phones) {
      p.label.dispose();
      p.phone.dispose();
    }
    for (final a in _addresses) {
      a.label.dispose();
      a.address.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _newAvatarFile = file;
      _avatarBytes = bytes;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.personAvatarUpdated),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(personNotifierProvider.notifier).savePerson(
            existingId: widget.personId,
            name: _nameCtrl.text.trim(),
            avatarFile: _newAvatarFile,
            birthday: _birthday,
            phones: _phones
                .map((p) => (
                      label: p.label.text,
                      phone: p.phone.text,
                      isPrimary: _phones.indexOf(p) == 0,
                    ))
                .where((p) => p.phone.isNotEmpty)
                .toList(),
            addresses: _addresses
                .map((a) => (
                      label: a.label.text,
                      address: a.address.text,
                      isPrimary: _addresses.indexOf(a) == 0,
                    ))
                .where((a) => a.address.isNotEmpty)
                .toList(),
            tagLabels: _selectedTags.toList(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.savedSuccess),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${context.l10n.personSaveError}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Uint8List? get _displayBytes => _avatarBytes ?? _existingAvatarBytes;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final l10n = context.l10n;
    final partnerPersonId =
        ref.watch(partnerTagsProvider).value?.firstOrNull?.personId;
    final hasOtherPartner =
        partnerPersonId != null && partnerPersonId != (widget.personId ?? '');
    // Use l10n tags as base, hiding 伴侣/Partner if another person already holds that tag.
    final baseTags = hasOtherPartner
        ? l10n.relationshipTags.where((t) => !_isPartnerTagLabel(t)).toList()
        : l10n.relationshipTags;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.personId == null
            ? l10n.personFormAdd
            : l10n.personFormEdit),
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
              // Avatar
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PersonAvatar(
                        imageBytes: _displayBytes,
                        name: _nameCtrl.text.isEmpty
                            ? '?'
                            : _nameCtrl.text,
                        radius: 40,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                    labelText: l10n.personNameLabel,
                    prefixIcon: const Icon(Icons.person_outline)),
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? l10n.personNameRequired
                        : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_outlined,
                    color: AppColors.warmBrown),
                title: Text(_birthday == null
                    ? l10n.personBirthdayOptional
                    : l10n.birthdayFormatted(
                        _birthday!.year,
                        _birthday!.month,
                        _birthday!.day)),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _birthday ?? DateTime(1990),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) setState(() => _birthday = p);
                },
                trailing: _birthday != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            setState(() => _birthday = null))
                    : null,
              ),
              const Divider(),
              // Tags — hidden for own profile
              if (!_isSelf) ...[
                Text(l10n.personRelationship,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ...baseTags.map((tag) => FilterChip(
                          label: Text(tag),
                          selected: _selectedTags.contains(tag),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          }),
                        )),
                    ..._selectedTags
                        .where((t) => !baseTags.contains(t))
                        .map((t) => FilterChip(
                              label: Text(t),
                              selected: true,
                              onSelected: (_) =>
                                  setState(() => _selectedTags.remove(t)),
                            )),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customTagCtrl,
                        decoration: InputDecoration(
                            hintText: l10n.fieldCustomTagHint,
                            isDense: true),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final t = _customTagCtrl.text.trim();
                        if (t.isNotEmpty) {
                          setState(() {
                            _selectedTags.add(t);
                            _customTagCtrl.clear();
                          });
                        }
                      },
                      child: Text(l10n.add),
                    ),
                  ],
                ),
                const Divider(),
              ],
              // Phones
              _FieldListSection(
                title: l10n.personPhoneSection,
                onAdd: () => setState(() => _phones.add((
                      label: TextEditingController(),
                      phone: TextEditingController(),
                    ))),
                children: _phones
                    .asMap()
                    .entries
                    .map((e) => _InlinePhoneRow(
                          entry: e.value,
                          onRemove: () =>
                              setState(() => _phones.removeAt(e.key)),
                        ))
                    .toList(),
              ),
              _FieldListSection(
                title: l10n.personAddressSection,
                onAdd: () => setState(() => _addresses.add((
                      label: TextEditingController(),
                      address: TextEditingController(),
                    ))),
                children: _addresses
                    .asMap()
                    .entries
                    .map((e) => _InlineAddressRow(
                          entry: e.value,
                          onRemove: () =>
                              setState(() => _addresses.removeAt(e.key)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldListSection extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  final List<Widget> children;

  const _FieldListSection({
    required this.title,
    required this.onAdd,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.l10n.add),
            ),
          ],
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}

const _kCountryCodes = [
  ('+60', '🇲🇾 MY'),
  ('+65', '🇸🇬 SG'),
  ('+86', '🇨🇳 CN'),
  ('+1',  '🇺🇸 US'),
  ('+44', '🇬🇧 UK'),
  ('+61', '🇦🇺 AU'),
  ('+81', '🇯🇵 JP'),
  ('+82', '🇰🇷 KR'),
  ('+66', '🇹🇭 TH'),
  ('+62', '🇮🇩 ID'),
  ('+63', '🇵🇭 PH'),
  ('+84', '🇻🇳 VN'),
  ('+91', '🇮🇳 IN'),
  ('+852', '🇭🇰 HK'),
  ('+886', '🇹🇼 TW'),
];

class _InlinePhoneRow extends StatefulWidget {
  final ({TextEditingController label, TextEditingController phone}) entry;
  final VoidCallback onRemove;
  const _InlinePhoneRow({required this.entry, required this.onRemove});

  @override
  State<_InlinePhoneRow> createState() => _InlinePhoneRowState();
}

class _InlinePhoneRowState extends State<_InlinePhoneRow> {
  String _code = '+60';

  @override
  void initState() {
    super.initState();
    final existing = widget.entry.label.text;
    final known = _kCountryCodes.any((c) => c.$1 == existing);
    if (known) _code = existing;
    widget.entry.label.text = _code;
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.warmBeige),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _code,
                isDense: true,
                items: _kCountryCodes
                    .map((c) => DropdownMenuItem<String>(
                          value: c.$1,
                          child: Text('${c.$2} ${c.$1}',
                              style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _code = v);
                    widget.entry.label.text = v;
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: widget.entry.phone,
              decoration: InputDecoration(
                hintText: context.l10n.fieldPhoneHint,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType: TextInputType.phone,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: widget.onRemove,
              icon: const Icon(Icons.remove_circle_outline,
                  size: 20, color: AppColors.dustyRose),
            ),
          ),
        ]),
      );
}

class _InlineAddressRow extends StatelessWidget {
  final ({TextEditingController label, TextEditingController address}) entry;
  final VoidCallback onRemove;
  const _InlineAddressRow({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 64,
            child: TextFormField(
              controller: entry.label,
              decoration: InputDecoration(
                hintText: context.l10n.fieldLabelTag,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: entry.address,
              decoration: InputDecoration(
                hintText: context.l10n.fieldAddressHint,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline,
                  size: 20, color: AppColors.dustyRose),
            ),
          ),
        ]),
      );
}
