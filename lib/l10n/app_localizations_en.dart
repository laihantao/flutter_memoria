import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  const AppLocalizationsEn() : super(const Locale('en'));

  // ── Common ────────────────────────────────────────────────────────────────
  @override String get cancel => 'Cancel';
  @override String get confirm => 'Confirm';
  @override String get save => 'Save';
  @override String get delete => 'Delete';
  @override String get add => 'Add';
  @override String get close => 'Close';
  @override String get required => 'Required';
  @override String get today => 'Today';
  @override String get selectDate => 'Select';
  @override String get savedSuccess => 'Saved';
  @override String get addedSuccess => 'Added';
  @override String get deletedSuccess => 'Deleted';
  @override String errorWith(String e) => 'Error: $e';
  @override String copied(String label) => '$label copied';

  // ── Navigation ────────────────────────────────────────────────────────────
  @override String get navMemories => 'Moments';
  @override String get navPeople => 'Contacts';
  @override String get navExpenses => 'Expenses';
  @override String get navSettings => 'Settings';

  // ── Onboarding ────────────────────────────────────────────────────────────
  @override String get onboardingTitle => 'Welcome to Memora';
  @override String get onboardingSubtitle => "Let's set up your profile.";
  @override String get onboardingAvatarPlaceholder => 'Me';
  @override String get onboardingNameLabel => 'Your Name *';
  @override String get onboardingNameRequired => 'Name is required';
  @override String get onboardingBirthdayOptional => 'Birthday (optional)';
  @override String get onboardingPhoneSection => 'Phone Numbers';
  @override String get onboardingAddressSection => 'Addresses';
  @override String get onboardingStart => 'Get Started';
  @override String get onboardingAvatarUpdated => 'Avatar updated';

  // ── Shared form field labels ───────────────────────────────────────────────
  @override String get fieldLabelTag => 'Label';
  @override String get fieldPhoneHint => 'Phone number';
  @override String get fieldAddressHint => 'Address';
  @override String get fieldCustomTagHint => 'Custom tag...';

  // ── Persons list ──────────────────────────────────────────────────────────
  @override String get personsTitle => 'Contacts';
  @override String get personsEmpty => 'No contacts yet';
  @override String get personsEmptyHint => 'Add your first contact';
  @override String get personsAdd => 'Add Contact';
  @override String get personsTabLabel => 'Contacts';
  @override String get groupsTabLabel => 'Groups';
  @override String get searchByNameHint => 'Search by name...';
  @override String get groupsEmpty => 'No groups yet';
  @override String get groupsEmptyHint => 'Create groups to organize your contacts';
  @override String get groupCreate => 'Create Group';
  @override String get groupNameLabel => 'Group Name *';
  @override String get groupDescriptionLabel => 'Description (optional)';
  @override String get groupNameRequired => 'Name is required';
  @override String get groupMembers => 'Members';
  @override String get groupSection => 'Groups';
  @override String get groupAddMember => 'Add Member';
  @override String get groupAddToGroup => 'Add to Group';

  // ── Person form ───────────────────────────────────────────────────────────
  @override List<String> get relationshipTags =>
      ['Family', 'Partner', 'Friend', 'Colleague', 'Ex-colleague'];
  @override String get personFormAdd => 'Add Contact';
  @override String get personFormEdit => 'Edit Profile';
  @override String get personNameLabel => 'Name *';
  @override String get personNameRequired => 'Required';
  @override String get personBirthdayOptional => 'Birthday (optional)';
  @override String birthdayFormatted(int y, int m, int d) =>
      '$d/$m/$y';
  @override String get personRelationship => 'Relationship';
  @override String get personSaveError => 'Save failed: ';
  @override String get personAvatarUpdated => 'Avatar updated';
  @override String get personPhoneSection => 'Phone Numbers';
  @override String get personAddressSection => 'Addresses';

  // ── Person detail ─────────────────────────────────────────────────────────
  @override String get personNotFound => 'Person not found';
  @override String get personPartnerTooltip => 'Partner Dashboard';
  @override String get personPhoneNumbers => 'Phone Numbers';
  @override String get personAddresses => 'Addresses';
  @override String get personNotes => 'Notes';
  @override String get personAddNoteHint => 'Add a note...';
  @override String get personNoNotes => 'No notes yet.';

  // ── Memories list ─────────────────────────────────────────────────────────
  @override String get memoriesTitle => 'Moments';
  @override String get memoriesEmpty => 'No moments yet';
  @override String get memoriesEmptyHint => 'Start recording your first moment';
  @override String get memoriesAdd => 'Add Moment';

  // ── Memory form ───────────────────────────────────────────────────────────
  @override String get memoryFormNew => 'New Moment';
  @override String get memoryFormEdit => 'Edit Moment';
  @override String get memoryStartRequired => 'Start date is required';
  @override String get memoryTypeLabel => 'Type';
  @override String memoryTypeName(String type) => const {
    'trip': 'Travel',
    'gathering': 'Gathering',
    'memory': 'Daily',
    'event': 'Event',
    'custom': 'Daily',
  }[type] ?? type;
  @override String get memoryTitleLabel => 'Title *';
  @override String get memoryFormRequired => 'Required';
  @override String get memoryDescriptionLabel => 'Description';
  @override String get memoryLocationLabel => 'Location';
  @override String get memoryStartDateLabel => 'Start Date *';
  @override String get memoryEndDateLabel => 'End Date';
  @override String get memoryParticipantsLabel => 'Participants';
  @override String get memoryBudgetLabel => 'Budget (optional)';
  @override String get memoryBudgetInvalid => 'Enter a valid amount';

  // ── Memory detail ─────────────────────────────────────────────────────────
  @override String get memoryNotFound => 'Moment not found';
  @override String get memoryExportPdfTooltip => 'Export PDF';
  @override String get memoryExportTitle => 'Export PDF';
  @override String get memoryExportChoice =>
      'Which version would you like to export?';
  @override String get memoryExportKeepsake => 'Keepsake (with photos)';
  @override String get memoryExportSettlement => 'Settlement (expenses)';
  @override String get memoryExportPdfMobileOnly =>
      'PDF export requires the mobile app.';
  @override String memoryExportFailed(String e) => 'Export failed: $e';
  @override String get memoryTabOverview => 'Overview';
  @override String get memoryTabItinerary => 'Itinerary';
  @override String get memoryTabGallery => 'Gallery';
  @override String get memoryTabExpenses => 'Expenses';
  @override String get memoryAddExpenseFab => 'Add Expense';
  @override String get memoryEditDetails => 'Edit Details';
  @override String get memoryEditItinerary => 'Edit Item';
  @override String get memoryGroupByDate => 'Group by date';
  @override String get memoryListView => 'List';
  @override String get memoryDeleteItineraryConfirm => 'Delete this itinerary item?';
  @override String get memoryParticipantsSection => 'Participants';
  @override String get memoryNoItinerary => 'No itinerary items yet';
  @override String get memoryAddItinerary => 'Add Item';
  @override String get memoryActivityHint => 'Activity title';
  @override String get memoryDateLabel => 'Date';
  @override String get memoryTimeLabel => 'Time';
  @override String get memoryAddPhoto => 'Add Photo / Video';
  @override String get memoryNoPhotos => 'No photos yet';
  @override String get memoryDeletePhoto => 'Delete photo?';
  @override String get memoryNoExpenses => 'No expenses linked yet';
  @override String get memoryRecordExpense => 'Add Expense';
  @override String memoryExpenseCount(int n) => '$n transactions';
  @override String memoryExpenseTotal(String sym, String amount) =>
      'Total $sym $amount';

  // ── Expenses screen ────────────────────────────────────────────────────────
  @override String get expensesTitle => 'Expenses';
  @override String get expensesMonthBalance => 'Balance';
  @override String get expensesMonthExpense => 'Expense';
  @override String get expensesMonthIncome => 'Income';
  @override String get expensesNoRecord => 'No records this month';
  @override List<String> get weekdays =>
      ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  @override String dayExpenseLabel(String sym, String amount) =>
      'Out $sym $amount';
  @override String dayIncomeLabel(String sym, String amount) =>
      'In $sym $amount';
  @override String formatMonthYear(DateTime date) =>
      DateFormat('MMMM yyyy').format(date);
  @override String formatMonthDay(DateTime date) =>
      DateFormat('MMM d').format(date);

  // ── Wallets ────────────────────────────────────────────────────────────────
  @override String get walletsTitle => 'Wallets';
  @override String get walletsInitialBalance => 'Initial Balance';
  @override String get walletsNewWallet => 'New Wallet';
  @override String get walletsNameLabel => 'Wallet Name *';
  @override String get walletsCurrencyLabel => 'Currency';
  @override String get walletsCreateButton => 'Create Wallet';
  @override String get walletsEmpty => 'No wallets yet';
  @override String get walletsAddButton => 'Add Wallet';

  // ── Transactions ───────────────────────────────────────────────────────────
  @override String get transactionsDefaultTitle => 'Wallet';
  @override String get transactionsNotExist => 'Wallet not found';
  @override String get transactionsBulkTagTooltip => 'Bulk Tag';
  @override String get transactionsBulkTagTitle => 'Bulk Tag';
  @override String get transactionsBulkTagHint => 'Tag name (e.g. Tokyo2025)';
  @override String get transactionsNoRecord => 'No records this month';
  @override String get transactionsInitialBalance => 'Opening Balance';
  @override String get transactionsMonthIncome => 'Month Income';
  @override String get transactionsMonthExpense => 'Month Expense';
  @override String get transactionsAccountBalance => 'Account Balance';
  @override String get transactionsSurplus => 'Surplus';
  @override String get transactionsOverspend => 'Overspent';

  // ── Expense form ───────────────────────────────────────────────────────────
  @override String get expenseFormExpense => 'Expense';
  @override String get expenseFormIncome => 'Income';
  @override String get expenseFormAmountRequired => 'Please enter an amount';
  @override String get expenseFormCategoryRequired =>
      'Please select a category';
  @override String get expenseFormNoteLabel => 'Note';
  @override String get expenseFormNoteHint => 'Write something...';
  @override String get expenseFormWriteNote => 'Tap to add note...';
  @override String get expenseFormNoWallet => 'No wallet';
  @override String get expenseFormDone => 'Done';
  @override String get expenseFormToday => 'Today';

  // ── Transaction form ───────────────────────────────────────────────────────
  @override String get txFormNew => 'New Transaction';
  @override String get txFormEdit => 'Edit Transaction';
  @override String get txFormCategoryRequired => 'Select a category';
  @override String get txFormExpense => 'Expense';
  @override String get txFormIncome => 'Income';
  @override String get txFormAmountLabel => 'Amount *';
  @override String get txFormExchangeRateLabel => 'Exchange Rate to Base';
  @override String get txFormCategoryLabel => 'Category *';
  @override String get txFormTitleLabel => 'Title';
  @override String get txFormNoteLabel => 'Note';
  @override String get txFormSplitTypeLabel => 'Split Type';
  @override String get txFormPayer => 'Payer';
  @override String get txFormSplitWith => 'Split With';
  @override String get txFormAmountRequired => 'Required';
  @override String get txFormInvalidAmount => 'Invalid amount';
  @override String splitTypeName(String type) => switch (type) {
    'personal' => 'Personal',
    'split_aa' => 'Split AA',
    'treat' => 'Treat',
    _ => type,
  };

  // ── Partner dashboard ──────────────────────────────────────────────────────
  @override String get partnerTabAnniversaries => 'Anniversaries';
  @override String get partnerTabWishlist => 'Wishlist';
  @override String get partnerTabMemories => 'Moments';
  @override String get partnerNoAnniversaries => 'No anniversaries yet';
  @override String get partnerToday => 'Today!';
  @override String partnerDaysToGo(int n) => '$n days';
  @override String get partnerToGo => 'to go';
  @override String partnerDeleteConfirm(String label) => 'Delete "$label"?';
  @override String get partnerAnniversaryLabelHint =>
      'Label (e.g. Together Since)';
  @override String get partnerDateLabel => 'Date';
  @override String get partnerWishlistEmpty => 'Wishlist is empty';
  @override String get partnerWishHint => 'Add a wish...';
  @override String get partnerMemoriesNote =>
      'Memories featuring this person\nwill appear here.';
  @override String get partnerConfirm => 'Confirm';

  // ── Time categories ───────────────────────────────────────────────────────
  @override String get settingsSectionMoments => 'Moments';
  @override String get settingsCategories => 'Manage Moment Categories';
  @override String get settingsCategoriesSubtitle => 'Customize category options';
  @override String get categoryCreateTitle => 'New Category';
  @override String get categoryEditTitle => 'Rename Category';
  @override String get categoryNameLabel => 'Category name';
  @override String get categoryNameRequired => 'Name is required';
  @override String get categoryCustom => 'Custom';
  @override String categoryDeleteHasRecords(String name, int count) =>
      '"$name" has $count moment(s). They will be moved to "Daily" on deletion.';
  @override String categoryDeleteConfirm(String name) => 'Delete "$name"?';

  // ── Settings ───────────────────────────────────────────────────────────────
  @override String get settingsTitle => 'Settings';
  @override String get settingsSectionPersonal => 'Personal';
  @override String get settingsMyProfile => 'My Profile';
  @override String get settingsSectionWallets => 'Wallet Management';
  @override String get settingsMyWallets => 'My Wallets';
  @override String get settingsMyWalletsSubtitle =>
      'Manage wallets and view transactions';
  @override String get settingsSectionBackup => 'Backup & Restore';
  @override String get settingsExport => 'Export Backup';
  @override String get settingsExportNote =>
      'Save all data and media as .zip';
  @override String get settingsExportMobileOnly =>
      'Backup requires the mobile app';
  @override String get settingsImport => 'Import Backup';
  @override String get settingsImportNote =>
      'Restore from .zip (overwrites current data)';
  @override String get settingsImportMobileOnly =>
      'Backup requires the mobile app';
  @override String get settingsSectionAbout => 'About';
  @override String get settingsAppVersion =>
      'Version 1.0.0 · Offline-first, no account needed';
  @override String settingsExportFailed(String e) => 'Export failed: $e';
  @override String get settingsRestoreTitle => 'Restore Backup?';
  @override String get settingsRestoreContent =>
      'This will replace all your current data. This cannot be undone.';
  @override String get settingsRestoring => 'Restoring backup...';
  @override String get settingsCannotRead => 'Cannot read the selected file.';
  @override String settingsRestoreFailed(String e) => 'Restore failed: $e';
  @override String get settingsRestoreSuccess =>
      'Backup restored! Please restart the app.';
  @override String get settingsSectionLanguage => 'Language';
  @override String get settingsLanguageLabel => 'App Language';

  // ── Language names ─────────────────────────────────────────────────────────
  @override String get langZh => '简体中文';
  @override String get langEn => 'English';
}
