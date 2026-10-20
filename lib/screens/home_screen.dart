import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pin_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/pin_grid.dart';
import '../widgets/profile_avatar.dart';
import 'account_settings_screen.dart';
import 'auth_screen.dart';
import 'create_pin_screen.dart';
import 'pin_detail_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.apiService,
    required this.currentUser,
    required this.onUserUpdated,
    required this.onSignOut,
    super.key,
  });

  final ApiService apiService;
  final UserModel currentUser;
  final ValueChanged<UserModel> onUserUpdated;
  final VoidCallback onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _categories = ['Semua', ...pinCategories];

  final TextEditingController _searchController = TextEditingController();
  late Future<List<PinModel>> _feedFuture;
  late Future<List<PinModel>> _savedFuture;
  int _selectedTab = 0;
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  Set<String> _recommendedCategories = pinCategories.toSet();

  Future<List<PinModel>> get _selectedPinsFuture =>
      _selectedTab == 0 ? _feedFuture : _savedFuture;

  @override
  void initState() {
    super.initState();
    _feedFuture = widget.apiService.fetchPins();
    _savedFuture = widget.apiService.fetchSavedPins();
    _loadRecommendedCategories();
  }

  Future<void> _loadRecommendedCategories() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _recommendedCategories =
          preferences
              .getStringList(recommendedCategoriesPreferenceKey)
              ?.toSet() ??
          pinCategories.toSet();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reloadPins() async {
    setState(() {
      _feedFuture = widget.apiService.fetchPins();
      _savedFuture = widget.apiService.fetchSavedPins();
    });
    try {
      await _selectedPinsFuture;
    } on Exception catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _toggleSave(PinModel pin) async {
    try {
      await widget.apiService.savePin(pin.id, save: !pin.isSaved);
      await _reloadPins();
    } on Exception catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _openPin(PinModel pin) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => PinDetailScreen(
          pin: pin,
          currentUser: widget.currentUser,
          apiService: widget.apiService,
          onChanged: _reloadPins,
        ),
      ),
    );
    if (mounted) {
      await _reloadPins();
    }
  }

  Future<UserModel?> _addAccount() async {
    final user = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute<UserModel>(
        builder: (context) => AuthScreen(
          apiService: widget.apiService,
          onAuthenticated: (user) => Navigator.of(context).pop(user),
        ),
      ),
    );
    if (user == null || !mounted) {
      return null;
    }
    widget.onUserUpdated(user);
    setState(() {
      _selectedTab = 0;
      _feedFuture = widget.apiService.fetchPins();
      _savedFuture = widget.apiService.fetchSavedPins();
    });
    return user;
  }

  void _openProfile(int userId) {
    if (userId == widget.currentUser.id) {
      setState(() {
        _selectedTab = 2;
      });
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ProfileScreen(
          userId: userId,
          currentUser: widget.currentUser,
          apiService: widget.apiService,
          onCurrentUserUpdated: widget.onUserUpdated,
        ),
      ),
    );
  }

  Future<void> _openComposer() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: CreatePinScreen(
          apiService: widget.apiService,
          onCreated: (_) {
            _reloadPins();
            _showMessage('Pin berhasil diterbitkan.');
          },
        ),
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

  Widget _buildPinContent() {
    final isSavedTab = _selectedTab == 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari ide, kategori, atau kreator',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rekomendasi kategori',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final category in _categories)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    showCheckmark: false,
                    selectedColor: const Color(0xFF111111),
                    backgroundColor: const Color(0xFFF1F1F1),
                    labelStyle: TextStyle(
                      color: _selectedCategory == category
                          ? Colors.white
                          : const Color(0xFF222222),
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PinModel>>(
            future: _selectedPinsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 140),
                    const Icon(Icons.cloud_off_outlined, size: 42),
                    const SizedBox(height: 12),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: _reloadPins,
                        child: const Text('Coba lagi'),
                      ),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final pins = snapshot.data!;
              final visiblePins = pins.where((pin) {
                final matchesCategory =
                    _selectedCategory == 'Semua' ||
                    pin.category == _selectedCategory;
                final matchesRecommendations =
                    isSavedTab ||
                    _selectedCategory != 'Semua' ||
                    _recommendedCategories.contains(pin.category);
                final searchableText = [
                  pin.title,
                  pin.description,
                  pin.category,
                  pin.user?.name ?? '',
                  pin.user?.username ?? '',
                ].join(' ').toLowerCase();

                return matchesCategory &&
                    matchesRecommendations &&
                    (_searchQuery.isEmpty ||
                        searchableText.contains(_searchQuery));
              }).toList();

              if (visiblePins.isEmpty) {
                final message = pins.isEmpty
                    ? (isSavedTab
                          ? 'Pin yang kamu simpan akan muncul di sini.'
                          : 'Belum ada pin. Jadilah yang pertama berbagi inspirasi!')
                    : 'Belum ada pin yang cocok. Coba kategori atau kata kunci lain.';
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Icon(
                      pins.isEmpty
                          ? (isSavedTab
                                ? Icons.bookmark_border
                                : Icons.auto_awesome)
                          : Icons.search_off,
                      size: 42,
                      color: const Color(0xFF777777),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(message, textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                );
              }

              return RefreshIndicator(
                onRefresh: _reloadPins,
                child: PinGrid(
                  pins: visiblePins,
                  onOpenPin: _openPin,
                  onToggleSave: _toggleSave,
                  onOpenProfile: _openProfile,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationItem({
    required int tab,
    required IconData icon,
    required String label,
  }) {
    return Expanded(
      child: Center(
        child: Tooltip(
          message: label,
          child: Material(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => setState(() {
                _selectedTab = tab;
              }),
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 56,
                height: 52,
                child: Icon(icon, color: const Color(0xFF111111), size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProfileTab = _selectedTab == 2;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipOval(
            child: Image.asset(
              'assets/images/pinterus_logo.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: const Text(
          'Pinterus',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Buat Pin',
            onPressed: _openComposer,
            icon: const Icon(Icons.add, size: 30),
          ),
          IconButton(
            tooltip: 'Profil',
            onPressed: () => setState(() {
              _selectedTab = 2;
            }),
            icon: ProfileAvatar(
              name: widget.currentUser.name,
              imageUrl: widget.currentUser.avatarUrl,
              radius: 16,
            ),
          ),
        ],
      ),
      body: isProfileTab
          ? ProfileScreen(
              userId: widget.currentUser.id,
              currentUser: widget.currentUser,
              apiService: widget.apiService,
              onCurrentUserUpdated: widget.onUserUpdated,
              onSignOut: widget.onSignOut,
              onAddAccount: _addAccount,
              onRecommendationsChanged: (categories) {
                setState(() {
                  _recommendedCategories = categories;
                });
              },
              showAppBar: false,
            )
          : _buildPinContent(),
      bottomNavigationBar: BottomAppBar(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            _buildNavigationItem(
              tab: 0,
              icon: _selectedTab == 0 ? Icons.home : Icons.home_outlined,
              label: 'Beranda',
            ),
            _buildNavigationItem(
              tab: 1,
              icon: _selectedTab == 1 ? Icons.bookmark : Icons.bookmark_border,
              label: 'Tersimpan',
            ),
            _buildNavigationItem(
              tab: 2,
              icon: _selectedTab == 2 ? Icons.person : Icons.person_outline,
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
