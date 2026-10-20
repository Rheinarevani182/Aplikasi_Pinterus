import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pin_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/pin_grid.dart';
import '../widgets/profile_avatar.dart';
import 'account_settings_screen.dart';
import 'pin_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.userId,
    required this.currentUser,
    required this.apiService,
    required this.onCurrentUserUpdated,
    this.onSignOut,
    this.onAddAccount,
    this.onRecommendationsChanged,
    this.showAppBar = true,
    super.key,
  });

  final int userId;
  final UserModel currentUser;
  final ApiService apiService;
  final ValueChanged<UserModel> onCurrentUserUpdated;
  final VoidCallback? onSignOut;
  final Future<UserModel?> Function()? onAddAccount;
  final ValueChanged<Set<String>>? onRecommendationsChanged;
  final bool showAppBar;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;
  bool _isFollowing = false;
  bool _isUpdatingFollow = false;
  bool _showProfileStats = true;

  bool get _isCurrentUser => widget.userId == widget.currentUser.id;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.apiService.fetchProfile(widget.userId);
    _loadProfilePreferences();
  }

  Future<void> _loadProfilePreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _showProfileStats =
          preferences.getBool(showProfileStatsPreferenceKey) ?? true;
    });
  }

  Future<void> _reload() async {
    setState(() {
      _profileFuture = widget.apiService.fetchProfile(widget.userId);
    });
    await _profileFuture;
  }

  Future<void> _toggleFollow() async {
    setState(() {
      _isUpdatingFollow = true;
    });
    try {
      _isFollowing = await widget.apiService.followUser(
        widget.userId,
        follow: !_isFollowing,
      );
      await _reload();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } on Exception catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingFollow = false;
        });
      }
    }
  }

  Future<void> _shareProfile(UserModel user) async {
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool(allowProfileSharingPreferenceKey) ?? true)) {
      _showMessage('Izin berbagi profil sedang dimatikan.');
      return;
    }
    final details = [
      '${user.name} (@${user.username}) di Pinterus',
      if (user.bio.isNotEmpty) user.bio,
    ];
    await SharePlus.instance.share(ShareParams(text: details.join('\n\n')));
  }

  Future<UserModel?> _editProfile(UserModel user) async {
    final updatedUser = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          EditProfileSheet(apiService: widget.apiService, user: user),
    );
    if (updatedUser == null || !mounted) {
      return null;
    }

    widget.onCurrentUserUpdated(updatedUser);
    await _reload();
    return updatedUser;
  }

  Future<UserModel?> _addAccount() async {
    final onAddAccount = widget.onAddAccount;
    if (onAddAccount == null) {
      _showMessage('Fitur tambah akun tidak tersedia di halaman ini.');
      return null;
    }
    return onAddAccount();
  }

  Future<void> _openSettings(UserModel user) async {
    final updatedUser = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute<UserModel>(
        builder: (context) => AccountSettingsScreen(
          currentUser: user,
          apiService: widget.apiService,
          onEditProfile: _editProfile,
          onUserUpdated: widget.onCurrentUserUpdated,
          onAddAccount: _addAccount,
          onSignOut: _signOut,
          onViewProfile: () => Navigator.of(context).pop(user),
          onRecommendationsChanged: widget.onRecommendationsChanged ?? (_) {},
          onProfileStatsChanged: (showStats) {
            if (mounted) {
              setState(() {
                _showProfileStats = showStats;
              });
            }
          },
        ),
      ),
    );
    if (updatedUser != null && mounted) {
      widget.onCurrentUserUpdated(updatedUser);
      await _reload();
    }
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu bisa masuk lagi kapan saja.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true) {
      return;
    }

    try {
      await widget.apiService.logout();
      widget.onSignOut?.call();
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

  void _openPin(PinModel pin) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PinDetailScreen(
          pin: pin,
          currentUser: widget.currentUser,
          apiService: widget.apiService,
          onChanged: _reload,
        ),
      ),
    );
  }

  void _openProfile(int userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileScreen(
          userId: userId,
          currentUser: widget.currentUser,
          apiService: widget.apiService,
          onCurrentUserUpdated: widget.onCurrentUserUpdated,
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    final pins = (data['pins'] as List<dynamic>)
        .map((pin) => PinModel.fromJson(pin as Map<String, dynamic>))
        .toList();
    _isFollowing = data['is_following'] as bool? ?? false;
    final isPrivate =
        !(data['is_current_user'] as bool? ?? false) &&
        (data['is_private'] as bool? ?? false);

    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileAvatar(
                        name: user.name,
                        imageUrl: user.avatarUrl,
                        radius: 42,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '@${user.username}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(user.bio),
                  ],
                  if (_showProfileStats) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _ProfileCount(
                          value: user.followersCount,
                          label: 'Pengikut',
                        ),
                        const SizedBox(width: 24),
                        _ProfileCount(
                          value: user.followingCount,
                          label: 'Mengikuti',
                        ),
                        const SizedBox(width: 24),
                        _ProfileCount(value: user.pinsCount, label: 'Pin'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (_isCurrentUser)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF0F0F0),
                            foregroundColor: const Color(0xFF111111),
                          ),
                          onPressed: () => _editProfile(user),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit profil'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: _isUpdatingFollow ? null : _toggleFollow,
                          icon: Icon(
                            _isFollowing ? Icons.check : Icons.person_add_alt,
                          ),
                          label: Text(_isFollowing ? 'Mengikuti' : 'Ikuti'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _shareProfile(user),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Bagikan'),
                      ),
                    ],
                  ),
                  if (isPrivate) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Profil ini privat. Ikuti akun ini untuk melihat pin yang dibagikan.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isPrivate ? 'Pin privat' : 'Pin dibuat',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isPrivate || pins.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Belum ada pin untuk ditampilkan.')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childCount: pins.length,
                itemBuilder: (context, index) => PinGridItem(
                  pin: pins[index],
                  onOpenPin: _openPin,
                  onToggleSave: (pin) async {
                    try {
                      await widget.apiService.savePin(
                        pin.id,
                        save: !pin.isSaved,
                      );
                      await _reload();
                    } on Exception catch (error) {
                      _showMessage(error.toString());
                    }
                  },
                  onOpenProfile: _openProfile,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final profile = UserModel.fromJson(
          data['user'] as Map<String, dynamic>,
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Bagikan profil',
                    onPressed: () => _shareProfile(profile),
                    icon: const Icon(Icons.share_outlined),
                  ),
                  if (_isCurrentUser)
                    IconButton(
                      tooltip: 'Edit profil',
                      onPressed: () => _editProfile(profile),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (_isCurrentUser)
                    IconButton(
                      tooltip: 'Pengaturan akun',
                      onPressed: () => _openSettings(profile),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  if (_isCurrentUser)
                    IconButton(
                      tooltip: 'Keluar',
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody(data)),
          ],
        );
      },
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCurrentUser ? 'Profil' : 'Profil pengguna'),
      ),
      body: content,
    );
  }
}

class _ProfileCount extends StatelessWidget {
  const _ProfileCount({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    required this.apiService,
    required this.user,
    super.key,
  });

  final ApiService apiService;
  final UserModel user;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.user.name,
  );
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.user.username,
  );
  late final TextEditingController _bioController = TextEditingController(
    text: widget.user.bio,
  );
  final _imagePicker = ImagePicker();
  XFile? _avatar;
  Uint8List? _avatarBytes;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _chooseAvatar() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 900,
    );
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _avatar = image;
      _avatarBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _usernameController.text.trim().length < 3) {
      setState(() {
        _errorMessage = 'Isi nama dan username minimal 3 karakter.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final updated = await widget.apiService.updateProfile(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: _avatar,
      );
      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } on Exception catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Profil',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Center(
              child: InkWell(
                onTap: _isSaving ? null : _chooseAvatar,
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 42,
                  backgroundImage: _avatarBytes != null
                      ? MemoryImage(_avatarBytes!)
                      : widget.user.avatarUrl == null
                      ? const AssetImage('assets/images/pinterus_logo.jpg')
                      : NetworkImage(
                          ApiService.resolveImageUrl(widget.user.avatarUrl!),
                        ),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: CircleAvatar(
                      radius: 14,
                      child: Icon(Icons.camera_alt_outlined, size: 16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? 'Menyimpan...' : 'Simpan perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}
