import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pin_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/profile_avatar.dart';
import 'profile_screen.dart';

class PinDetailScreen extends StatefulWidget {
  const PinDetailScreen({
    required this.pin,
    required this.currentUser,
    required this.apiService,
    required this.onChanged,
    super.key,
  });

  final PinModel pin;
  final UserModel currentUser;
  final ApiService apiService;
  final VoidCallback onChanged;

  @override
  State<PinDetailScreen> createState() => _PinDetailScreenState();
}

class _PinDetailScreenState extends State<PinDetailScreen> {
  late PinModel _pin = widget.pin;
  bool _isSaving = false;

  bool get _isOwner => _pin.user?.id == widget.currentUser.id;

  Future<void> _toggleSave() async {
    setState(() {
      _isSaving = true;
    });
    try {
      final save = !_pin.isSaved;
      await widget.apiService.savePin(_pin.id, save: save);
      if (!mounted) {
        return;
      }
      setState(() {
        _pin = _pin.copyWith(isSaved: save);
      });
      widget.onChanged();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } on Exception catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _sharePin() async {
    final lines = <String>[
      _pin.title,
      if (_pin.description.isNotEmpty) _pin.description,
      _pin.imageUrl,
      if (_pin.linkUrl != null) 'Kunjungi: ${_pin.linkUrl}',
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n\n')));
  }

  Future<void> _visitLink() async {
    final value = _pin.linkUrl;
    if (value == null || value.isEmpty) {
      _showMessage('Pin ini belum memiliki tautan tujuan.');
      return;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showMessage('Tautan tujuan pin tidak valid.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showMessage('Tautan tidak dapat dibuka di perangkat ini.');
    }
  }

  Future<void> _showMoreActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Hapus Pin'),
                onTap: () => Navigator.pop(context, 'delete'),
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Laporkan Pin'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Bagikan Pin'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    switch (action) {
      case 'delete':
        await _deletePin();
        break;
      case 'report':
        await _reportPin();
        break;
      case 'share':
        await _sharePin();
        break;
      default:
        break;
    }
  }

  Future<void> _deletePin() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pin?'),
        content: const Text('Pin yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }

    try {
      await widget.apiService.deletePin(_pin.id);
      widget.onChanged();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } on Exception catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _reportPin() async {
    const reasons = [
      'Spam atau konten menyesatkan',
      'Konten tidak pantas',
      'Pelanggaran hak cipta',
      'Konten berbahaya',
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Alasan melaporkan'),
        children: [
          for (final value in reasons)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(value),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Alasan lainnya'),
            child: const Text('Alasan lainnya'),
          ),
        ],
      ),
    );
    if (reason == null) {
      return;
    }

    try {
      await widget.apiService.reportPin(_pin.id, reason);
      _showMessage('Terima kasih, laporanmu sudah dikirim.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } on Exception catch (error) {
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openProfile(int userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileScreen(
          userId: userId,
          currentUser: widget.currentUser,
          apiService: widget.apiService,
          onCurrentUserUpdated: (_) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = _pin.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin'),
        actions: [
          IconButton(
            tooltip: 'Bagikan',
            onPressed: _sharePin,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Lainnya',
            onPressed: _showMoreActions,
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Hero(
              tag: 'pin-image-${_pin.id}',
              child: Image.network(
                ApiService.resolveImageUrl(_pin.imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 300,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  _pin.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.icon(
                onPressed: _isSaving ? null : _toggleSave,
                icon: Icon(
                  _pin.isSaved ? Icons.bookmark : Icons.bookmark_border,
                ),
                label: Text(_pin.isSaved ? 'Tersimpan' : 'Simpan'),
              ),
            ],
          ),
          if (_pin.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_pin.description),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pin.linkUrl?.isNotEmpty == true ? _visitLink : null,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Kunjungi'),
          ),
          if (author != null) ...[
            const Divider(height: 28),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ProfileAvatar(
                name: author.name,
                imageUrl: author.avatarUrl,
                radius: 24,
              ),
              title: Text(author.name),
              subtitle: Text('@${author.username}'),
              trailing: author.id == widget.currentUser.id
                  ? null
                  : const Icon(Icons.chevron_right),
              onTap: author.id == widget.currentUser.id
                  ? null
                  : () => _openProfile(author.id),
            ),
          ],
        ],
      ),
    );
  }
}
