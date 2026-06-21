import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/person_avatar.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  XFile? _avatarFile;
  Uint8List? _avatarBytes;
  DateTime? _birthday;
  final List<({TextEditingController label, TextEditingController phone})>
      _phones = [];
  final List<
      ({TextEditingController label, TextEditingController address})>
      _addresses = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
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
      _avatarFile = file;
      _avatarBytes = bytes;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.onboardingAvatarUpdated),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  void _addPhone() => setState(() => _phones.add((
        label: TextEditingController(),
        phone: TextEditingController(),
      )));

  void _addAddress() => setState(() => _addresses.add((
        label: TextEditingController(),
        address: TextEditingController(),
      )));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(personNotifierProvider.notifier).savePerson(
            name: _nameCtrl.text.trim(),
            avatarFile: _avatarFile,
            birthday: _birthday,
            isSelf: true,
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
          );
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text(l10n.onboardingTitle,
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  l10n.onboardingSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF8A7060)),
                ),
                const SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PersonAvatar(
                          imageBytes: _avatarBytes,
                          name: _nameCtrl.text.isEmpty
                              ? l10n.onboardingAvatarPlaceholder
                              : _nameCtrl.text,
                          radius: 48,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.background, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.onboardingNameLabel,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty
                          ? l10n.onboardingNameRequired
                          : null,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake_outlined,
                      color: AppColors.warmBrown),
                  title: Text(
                    _birthday == null
                        ? l10n.onboardingBirthdayOptional
                        : l10n.birthdayFormatted(
                            _birthday!.year,
                            _birthday!.month,
                            _birthday!.day),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  onTap: _pickBirthday,
                  trailing: _birthday != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _birthday = null),
                        )
                      : null,
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.onboardingPhoneSection,
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton.icon(
                      onPressed: _addPhone,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.add),
                    ),
                  ],
                ),
                ..._phones.asMap().entries.map((e) => _PhoneRow(
                      entry: e.value,
                      onRemove: () =>
                          setState(() => _phones.removeAt(e.key)),
                    )),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.onboardingAddressSection,
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton.icon(
                      onPressed: _addAddress,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.add),
                    ),
                  ],
                ),
                ..._addresses.asMap().entries.map((e) => _AddressRow(
                      entry: e.value,
                      onRemove: () =>
                          setState(() => _addresses.removeAt(e.key)),
                    )),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.onboardingStart),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
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

class _PhoneRow extends StatefulWidget {
  final ({TextEditingController label, TextEditingController phone}) entry;
  final VoidCallback onRemove;
  const _PhoneRow({required this.entry, required this.onRemove});

  @override
  State<_PhoneRow> createState() => _PhoneRowState();
}

class _PhoneRowState extends State<_PhoneRow> {
  String _code = '+60';

  @override
  void initState() {
    super.initState();
    final existing = widget.entry.label.text;
    if (_kCountryCodes.any((c) => c.$1 == existing)) _code = existing;
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

class _AddressRow extends StatelessWidget {
  final ({TextEditingController label, TextEditingController address}) entry;
  final VoidCallback onRemove;
  const _AddressRow({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  color: AppColors.dustyRose, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
