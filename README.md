# Memora

A private, offline-first Flutter app for tracking memories, relationships, and shared expenses with the people who matter most.

---

## Features

### 时光 (Moments)
Log personal moments — dates, trips, gatherings, milestones, and more.

- Browse moments in a chronological card list
- Rich detail view: photos, participants, linked expenses, notes
- Dynamic category system (约会 / 日常 / 旅行 / 聚会 / 纪念日 / 美食 / 活动 / 成就)
- Create custom categories on the fly from the moment form
- Manage all categories (add / rename / reorder / delete) in **Settings → 管理时光分类**

### 人脉 (Relationships)
Maintain a contact book of the people in your life.

- Person profiles: name, avatar, phones, addresses, social tags, freeform notes
- Tag someone as your **伴侣 (partner)** — they get a special highlighted card
- **Groups** — organise people into named groups (family, work team, travel buddies, …)
- Per-person view shows linked moments and a quick expense summary

### 伴侣 (Partner Dashboard)
A dedicated view for your partner, surfacing moments and expenses in one place.

- Tabs: 时光 / 账单
- Quick links to create a shared moment or log a shared expense

### 账单 (Expenses)
Track personal and shared spending.

- Wallets — separate money pots (cash, card, WeChat Pay, …)
- Transaction log per wallet with bulk-tag and filter support
- Expenses can be linked to a specific moment
- Settlement helper for splitting shared costs
- PDF export of expense summaries

### Settings
- **Language** — Chinese / English
- **管理时光分类** — full CRUD for moment categories
- **钱包** — wallet management

---

## Tech Stack

| Layer | Library |
|---|---|
| UI | Flutter 3.44 + Material 3 |
| State | flutter_riverpod 2.6 (AsyncNotifier / StreamProvider) |
| Navigation | go_router 14 (ShellRoute) |
| Database | drift 2.28 (SQLite, offline-first) |
| PDF | pdf + printing |
| Localisation | Custom hand-rolled zh / en (no codegen) |

All data is stored locally on-device. No network requests, no accounts, no cloud sync.

---

## Project Structure

```
lib/
├── data/
│   ├── tables.dart            # Drift table definitions
│   ├── app_database.dart      # DB singleton, migrations (schema v5)
│   └── daos/
│       ├── memory_dao.dart    # Moments + time categories
│       ├── person_dao.dart    # Contacts, groups, tags
│       └── expense_dao.dart   # Wallets, transactions, settlements
├── providers/
│   ├── database_provider.dart
│   ├── memory_provider.dart   # timeCategoriesProvider, MemoryNotifier
│   ├── person_provider.dart
│   ├── expense_provider.dart
│   ├── router_provider.dart   # go_router config
│   └── locale_provider.dart
├── screens/
│   ├── home/                  # HomeShell (bottom nav)
│   ├── memory/                # MemoriesListScreen, MemoryDetailScreen, MemoryFormScreen
│   ├── relationship/          # PersonsListScreen, PersonDetailScreen, GroupDetailScreen
│   ├── partner/               # PartnerDashboardScreen
│   ├── expense/               # ExpensesScreen, WalletsScreen, TransactionsScreen
│   ├── settings/              # SettingsScreen, TimeCategoriesScreen
│   └── onboarding/
├── l10n/
│   ├── app_localizations.dart     # Abstract interface
│   ├── app_localizations_zh.dart  # Chinese strings
│   └── app_localizations_en.dart  # English strings
├── services/
│   ├── backup_service.dart
│   ├── media_service.dart
│   ├── notification_service.dart
│   ├── pdf_service.dart
│   └── settle_up_service.dart
├── theme/app_theme.dart
└── widgets/                   # Shared widgets (PersonAvatar, MoneyChip, …)
```

---

## Database Schema (v5)

| Table | Purpose |
|---|---|
| `persons` | Contact profiles |
| `person_tags` | Labels on contacts (e.g. 伴侣, 同事) |
| `person_phones` | Phone numbers |
| `person_addresses` | Addresses |
| `person_groups` | Named groups |
| `group_members` | Group ↔ person join |
| `memories` | Moment records |
| `memory_participants` | Moment ↔ person join |
| `time_categories` | Dynamic moment categories (isDefault + sortOrder) |
| `wallets` | Money pots |
| `transactions` | Expense entries |
| `settlements` | Split-cost records |

Migration history:
- **v1 → v2**: added `wallets` + `transactions`
- **v2 → v3**: added `settlements`
- **v3 → v4**: added `time_categories`, seeded defaults, migrated old type codes (trip/gathering/memory/event/custom) to Chinese names
- **v4 → v5**: re-seeded default categories with 约会 first, 日常 second

---

## Development

### Prerequisites
- Flutter 3.44+ / Dart 3.12+
- Android Studio or VS Code with Flutter plugin

### Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # regenerate Drift code
flutter run
```

### Code generation
Drift generates `.g.dart` files from table definitions. Re-run after any change to `tables.dart` or DAO files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Lint
```bash
flutter analyze
```
One known suppressed warning: `TableMigration` is marked experimental by Drift's own API — not actionable.

---

## Dialog Safety Pattern

All dialogs use the **onChanged + local variable** pattern instead of `TextEditingController` to prevent the `_dependents.isEmpty` assertion crash that occurs when a controller is disposed while the dialog widget tree is still tearing down:

```dart
// CORRECT
String input = '';
await showDialog(
  builder: (ctx) => AlertDialog(
    content: TextFormField(
      onChanged: (v) => input = v,
    ),
  ),
);
// use `input` here — no dispose needed

// WRONG — dispose races with InheritedWidget teardown on Cancel
final ctrl = TextEditingController();
await showDialog(...);
ctrl.dispose(); // crashes with _dependents.isEmpty
```

For edit dialogs, pass the existing value via `initialValue:` on `TextFormField` rather than pre-populating a controller.
