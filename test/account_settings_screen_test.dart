import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinterus_mobile/models/user_model.dart';
import 'package:pinterus_mobile/screens/account_settings_screen.dart';
import 'package:pinterus_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('recommendation choices persist and update the home feed', (
    WidgetTester tester,
  ) async {
    Set<String>? updatedCategories;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsScreen(
          currentUser: _user,
          apiService: ApiService(),
          onEditProfile: (_) async => null,
          onUserUpdated: (_) {},
          onAddAccount: () async => null,
          onSignOut: () {},
          onViewProfile: () {},
          onRecommendationsChanged: (categories) {
            updatedCategories = categories;
          },
          onProfileStatsChanged: (_) {},
        ),
      ),
    );

    await tester.ensureVisible(find.text('Refine your recommendations'));
    await tester.tap(find.text('Refine your recommendations'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Seni'));
    await tester.tap(find.text('Simpan pilihan'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList(recommendedCategoriesPreferenceKey),
      isNot(contains('Seni')),
    );
    expect(updatedCategories, isNot(contains('Seni')));
  });

  testWidgets('notification preferences can be changed and are saved', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsScreen(
          currentUser: _user,
          apiService: ApiService(),
          onEditProfile: (_) async => null,
          onUserUpdated: (_) {},
          onAddAccount: () async => null,
          onSignOut: () {},
          onViewProfile: () {},
          onRecommendationsChanged: (_) {},
          onProfileStatsChanged: (_) {},
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Notifications'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('pinterus_notification_followers'), isFalse);
  });
}

const _user = UserModel(
  id: 1,
  name: 'Pinterus User',
  username: 'pinterus_user',
  email: 'user@example.test',
  bio: '',
  avatarUrl: null,
  followersCount: 0,
  followingCount: 0,
  pinsCount: 0,
);
