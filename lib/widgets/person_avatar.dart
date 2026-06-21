import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/file_ops.dart';

class PersonAvatar extends StatefulWidget {
  /// Pre-loaded bytes take priority — use this on web after reading XFile.
  final Uint8List? imageBytes;

  /// Relative or absolute path. On native, loaded via readAbsoluteFileBytes.
  /// Ignored on web in favour of [imageBytes].
  final String? imagePath;

  final String name;
  final double radius;

  const PersonAvatar({
    super.key,
    this.imageBytes,
    this.imagePath,
    required this.name,
    this.radius = 24,
  });

  @override
  State<PersonAvatar> createState() => _PersonAvatarState();
}

class _PersonAvatarState extends State<PersonAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PersonAvatar old) {
    super.didUpdateWidget(old);
    if (old.imageBytes != widget.imageBytes ||
        old.imagePath != widget.imagePath) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    // Caller-supplied bytes win (used after XFile.readAsBytes on web/native).
    if (widget.imageBytes != null) {
      if (mounted) setState(() => _bytes = widget.imageBytes);
      return;
    }
    if (widget.imagePath == null) {
      if (mounted) setState(() => _bytes = null);
      return;
    }
    // Data URI stored in DB (used on web where file system is unavailable).
    if (widget.imagePath!.startsWith('data:')) {
      final comma = widget.imagePath!.indexOf(',');
      if (comma != -1 && mounted) {
        setState(() => _bytes = base64Decode(widget.imagePath!.substring(comma + 1)));
      }
      return;
    }
    // On web there is no local file system outside of data URIs.
    if (kIsWeb) {
      if (mounted) setState(() => _bytes = null);
      return;
    }
    // Try relative app-docs path first (stored format), fall back to absolute.
    final bytes = await readAppDocFileBytes(widget.imagePath!) ??
        await readAbsoluteFileBytes(widget.imagePath!);
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(widget.name);
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.emphasis, // Psyduck yellow for initials placeholder
      backgroundImage: _bytes != null ? MemoryImage(_bytes!) : null,
      child: _bytes == null
          ? Text(
              initials,
              style: TextStyle(
                fontSize: widget.radius * 0.6,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            )
          : null,
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
