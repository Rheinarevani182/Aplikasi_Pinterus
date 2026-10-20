import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pin_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/profile_avatar.dart';

const recommendedCategoriesPreferenceKey = 'pinterus_recommended_categories';
const showProfileStatsPreferenceKey = 'pinterus_show_profile_stats';
const allowProfileSharingPreferenceKey = 'pinterus_allow_profile_sharing';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    required this.currentUser,
    required this.apiService,
    required this.onEditProfile,
    required this.onUserUpdated,
    required this.onAddAccount,
    required this.onSignOut,
    required this.onViewProfile,
    required this.onRecommendationsChanged,
    required this.onProfileStatsChanged,
    super.key,
  });

  final UserModel currentUser;
  final ApiService apiService;
  final Future<UserModel?> Function(UserModel user) onEditProfile;
  final ValueChanged<UserModel> onUserUpdated;
  final Future<UserModel?> Function() onAddAccount;
  final VoidCallback onSignOut;
  final VoidCallback onViewProfile;
  final ValueChanged<Set<String>> onRecommendationsChanged;
  final ValueChanged<bool> onProfileStatsChanged;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late UserModel _user = widget.currentUser;
  bool _isUpdatingVisibility = false;

  Future<void> _shareProfile() async {
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool(allowProfileSharingPreferenceKey) ?? true)) {
      _showMessage('Izin berbagi profil sedang dimatikan.');
      return;
    }

    final details = [
      '${_user.name} (@${_user.username}) di Pinterus',
      if (_user.bio.isNotEmpty) _user.bio,
    ];
    await SharePlus.instance.share(ShareParams(text: details.join('\n\n')));
  }

  Future<void> _editProfile() async {
    final updatedUser = await widget.onEditProfile(_user);
    if (updatedUser == null || !mounted) {
      return;
    }
    setState(() {
      _user = updatedUser;
    });
  }

  Future<void> _addAccount() async {
    final authenticatedUser = await widget.onAddAccount();
    if (authenticatedUser == null || !mounted) {
      return;
    }
    setState(() {
      _user = authenticatedUser;
    });
    _showMessage('Sekarang masuk sebagai @${authenticatedUser.username}.');
    if (mounted) {
      Navigator.of(context).pop(authenticatedUser);
    }
  }

  Future<void> _toggleVisibility(bool isPrivate) async {
    setState(() {
      _isUpdatingVisibility = true;
    });
    try {
      final updatedUser = await widget.apiService.updateProfileVisibility(
        user: _user,
        isPrivate: isPrivate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _user = updatedUser;
      });
      widget.onUserUpdated(updatedUser);
      _showMessage(
        isPrivate ? 'Profil sekarang privat.' : 'Profil sekarang publik.',
      );
    } on Exception catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingVisibility = false;
        });
      }
    }
  }

  Future<void> _editRecommendations() async {
    final preferences = await SharedPreferences.getInstance();
    final selected =
        (preferences.getStringList(recommendedCategoriesPreferenceKey) ??
                pinCategories)
            .toSet();
    if (!mounted) {
      return;
    }
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RecommendationSheet(initialSelection: selected),
    );
    if (result == null) {
      return;
    }
    await preferences.setStringList(
      recommendedCategoriesPreferenceKey,
      pinCategories.where(result.contains).toList(),
    );
    widget.onRecommendationsChanged(result);
    _showMessage(
      result.isEmpty
          ? 'Semua kategori rekomendasi disembunyikan.'
          : 'Preferensi rekomendasi disimpan.',
    );
  }

  Future<void> _showSocialPermissions() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Social permissions and activity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Atur informasi profil dan tindakan berbagi yang tersedia di aplikasi.',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tampilkan statistik profil'),
                    subtitle: const Text(
                      'Jumlah pin, pengikut, dan yang diikuti',
                    ),
                    value:
                        preferences.getBool(showProfileStatsPreferenceKey) ??
                        true,
                    onChanged: (value) async {
                      await preferences.setBool(
                        showProfileStatsPreferenceKey,
                        value,
                      );
                      if (sheetContext.mounted) {
                        setSheetState(() {});
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Izinkan berbagi profil'),
                    subtitle: const Text(
                      'Tampilkan tombol untuk membagikan profil',
                    ),
                    value:
                        preferences.getBool(allowProfileSharingPreferenceKey) ??
                        true,
                    onChanged: (value) async {
                      await preferences.setBool(
                        allowProfileSharingPreferenceKey,
                        value,
                      );
                      if (sheetContext.mounted) {
                        setSheetState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    widget.onProfileStatsChanged(
      preferences.getBool(showProfileStatsPreferenceKey) ?? true,
    );
  }

  Future<void> _showNotifications() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    const notificationKeys = {
      'Pengikut baru': 'pinterus_notification_followers',
      'Aktivitas pin': 'pinterus_notification_pins',
      'Inspirasi pilihan': 'pinterus_notification_recommendations',
    };
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Simpan pilihan notifikasi di perangkat. Push notification belum diaktifkan di aplikasi ini.',
                  ),
                  const SizedBox(height: 12),
                  for (final entry in notificationKeys.entries)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key),
                      value: preferences.getBool(entry.value) ?? true,
                      onChanged: (value) async {
                        await preferences.setBool(entry.value, value);
                        if (sheetContext.mounted) {
                          setSheetState(() {});
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacyAndData() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy and data'),
        content: const Text(
          'Preferensi rekomendasi, statistik profil, dan notifikasi tersimpan di perangkat ini. Kamu bisa mengembalikan preferensi lokal ke pengaturan awal tanpa menghapus akun atau pin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset preferensi'),
          ),
        ],
      ),
    );
    if (shouldReset != true) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(recommendedCategoriesPreferenceKey);
    await preferences.remove(showProfileStatsPreferenceKey);
    await preferences.remove(allowProfileSharingPreferenceKey);
    await preferences.remove('pinterus_notification_followers');
    await preferences.remove('pinterus_notification_pins');
    await preferences.remove('pinterus_notification_recommendations');
    widget.onRecommendationsChanged(pinCategories.toSet());
    widget.onProfileStatsChanged(true);
    _showMessage('Preferensi lokal berhasil direset.');
  }

  Future<void> _showReports() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ReportsSheet(apiService: widget.apiService),
    );
  }

  Future<void> _changePassword() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ChangePasswordSheet(apiService: widget.apiService),
    );
    if (updated == true) {
      _showMessage('Kata sandi berhasil diperbarui.');
    }
  }

  Future<void> _openTesterSignUp() async {
    final launched = await launchUrl(
      Uri(
        scheme: 'mailto',
        queryParameters: {'subject': 'Pinterus - pendaftaran beta tester'},
      ),
    );
    if (!launched) {
      _showMessage('Aplikasi email tidak tersedia di perangkat ini.');
    }
  }

  Future<void> _showSupportInfo(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        title: const Text('Your account'),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ProfileAvatar(
                          name: _user.name,
                          imageUrl: _user.avatarUrl,
                          radius: 34,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '@${_user.username}',
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _AccountButton(
                            label: 'View profile',
                            onPressed: widget.onViewProfile,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AccountButton(
                            label: 'Share profile',
                            onPressed: _shareProfile,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _SettingsHeading('Settings'),
            _SettingsRow(label: 'Account management', onTap: _editProfile),
            _SettingsRow(
              label: 'Profile visibility',
              detail: _user.isPrivate ? 'Privat' : 'Publik',
              onTap: _showProfileVisibility,
            ),
            _SettingsRow(
              label: 'Refine your recommendations',
              onTap: _editRecommendations,
            ),
            _SettingsRow(label: 'Link to Pinterus', onTap: _shareProfile),
            _SettingsRow(
              label: 'Social permissions and activity',
              onTap: _showSocialPermissions,
            ),
            _SettingsRow(label: 'Notifications', onTap: _showNotifications),
            _SettingsRow(label: 'Privacy and data', onTap: _showPrivacyAndData),
            _SettingsRow(
              label: 'Reports and violations center',
              onTap: _showReports,
            ),
            const SizedBox(height: 26),
            _SettingsHeading('Login'),
            _SettingsRow(label: 'Add account', onTap: _addAccount),
            _SettingsRow(label: 'Security', onTap: _changePassword),
            _SettingsRow(
              label: 'Be a beta tester',
              trailing: Icons.north_east,
              onTap: _openTesterSignUp,
            ),
            _SettingsRow(
              label: 'Log out',
              showChevron: false,
              onTap: widget.onSignOut,
            ),
            const SizedBox(height: 26),
            _SettingsHeading('Support'),
            _SettingsRow(
              label: 'Help center',
              trailing: Icons.north_east,
              onTap: () => _showSupportInfo(
                'Help center',
                'Untuk saat ini, bantuan akun dan penggunaan Pinterus tersedia melalui pengembang aplikasi.',
              ),
            ),
            _SettingsRow(
              label: 'Terms of service',
              trailing: Icons.north_east,
              onTap: () => _showSupportInfo(
                'Terms of service',
                'Gunakan Pinterus untuk menyimpan dan berbagi inspirasi secara bertanggung jawab. Hormati karya, privasi, dan hak pengguna lain.',
              ),
            ),
            _SettingsRow(
              label: 'Privacy policy',
              trailing: Icons.north_east,
              onTap: () => _showSupportInfo(
                'Privacy policy',
                'Informasi akun digunakan untuk menyediakan profil, pin, penyimpanan, dan fitur sosial. Preferensi pengaturan lokal disimpan di perangkat.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProfileVisibility() async {
    final isPrivate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile visibility'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              enabled: !_isUpdatingVisibility,
              leading: Icon(
                _user.isPrivate
                    ? Icons.radio_button_unchecked
                    : Icons.radio_button_checked,
              ),
              title: const Text('Publik'),
              subtitle: const Text('Semua pengguna dapat melihat pin kamu.'),
              onTap: _isUpdatingVisibility
                  ? null
                  : () => Navigator.pop(context, false),
            ),
            ListTile(
              enabled: !_isUpdatingVisibility,
              leading: Icon(
                _user.isPrivate
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: const Text('Privat'),
              subtitle: const Text(
                'Hanya pengikut yang dapat melihat pin kamu.',
              ),
              onTap: _isUpdatingVisibility
                  ? null
                  : () => Navigator.pop(context, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (isPrivate == null || isPrivate == _user.isPrivate) {
      return;
    }
    await _toggleVisibility(isPrivate);
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: onPressed,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF666666), fontSize: 16),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.onTap,
    this.detail,
    this.trailing = Icons.chevron_right,
    this.showChevron = true,
  });

  final String label;
  final String? detail;
  final IconData trailing;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      subtitle: detail == null
          ? null
          : Text(detail!, style: const TextStyle(color: Color(0xFF666666))),
      trailing: showChevron
          ? Icon(
              trailing,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _RecommendationSheet extends StatefulWidget {
  const _RecommendationSheet({required this.initialSelection});

  final Set<String> initialSelection;

  @override
  State<_RecommendationSheet> createState() => _RecommendationSheetState();
}

class _RecommendationSheetState extends State<_RecommendationSheet> {
  late final Set<String> _selected = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Refine your recommendations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Pilih kategori yang ingin muncul di beranda.'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in pinCategories)
                  FilterChip(
                    label: Text(category),
                    selected: _selected.contains(category),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selected.add(category);
                        } else {
                          _selected.remove(category);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: const Text('Simpan pilihan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.apiService});

  final ApiService apiService;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _error;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.apiService.updatePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          8,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Security', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata sandi saat ini',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Masukkan kata sandi saat ini.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata sandi baru',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.length ?? 0) < 8
                    ? 'Kata sandi minimal 8 karakter.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi kata sandi baru',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value != _newPassword.text
                    ? 'Konfirmasi kata sandi belum cocok.'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _isSubmitting ? null : _save,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Perbarui kata sandi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsSheet extends StatefulWidget {
  const _ReportsSheet({required this.apiService});

  final ApiService apiService;

  @override
  State<_ReportsSheet> createState() => _ReportsSheetState();
}

class _ReportsSheetState extends State<_ReportsSheet> {
  late final Future<List<Map<String, dynamic>>> _reports = widget.apiService
      .fetchReports();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports and violations center',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _reports,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('Kamu belum mengirim laporan.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final report = snapshot.data![index];
                        final pin = report['pin'] as Map<String, dynamic>?;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            pin?['title'] as String? ?? 'Pin sudah dihapus',
                          ),
                          subtitle: Text(report['reason'] as String? ?? ''),
                          trailing: const Icon(Icons.flag_outlined),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
