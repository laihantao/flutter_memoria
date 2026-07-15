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
  @override String get memorySearchLocationHint => 'Search places…';
  @override String get memoryNoLocationFound => 'No matching places';
  @override String get memoryAddManually => 'Add manually';
  @override String get memoryViewOnMap => 'View on map';
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
  @override String get memoryTabSettings => 'Settings';
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
  @override String memoryDurationNights(int days, int nights) =>
      '$days ${days == 1 ? 'day' : 'days'} $nights ${nights == 1 ? 'night' : 'nights'}';
  @override String memoryDateRange(DateTime start, DateTime? end) {
    final full = DateFormat('d MMM yyyy');
    if (end == null) return full.format(start);
    final startStr = start.year == end.year
        ? DateFormat('d MMM').format(start)
        : full.format(start);
    return '$startStr – ${full.format(end)}';
  }
  @override String memoryCountdownDays(int n) =>
      n == 1 ? '1 day to go' : '$n days to go';
  @override String get memoryCountdownToday => 'Today ✦';
  @override String get memoryCountdownPast => 'A memory now';
  @override String memoryParticipantCount(int n) =>
      n == 1 ? '1 person' : '$n people';
  @override String get memoryDeleteTitle => 'Delete Moment';
  @override String memoryDeleteBody(String title) =>
      'This permanently deletes "$title" and everything linked to it — itinerary, gallery and expenses. This cannot be undone.';
  @override String get memoryDeleteConfirm => 'Delete';
  @override String memoryDeleteFailed(String e) => 'Delete failed: $e';
  @override String get memoryDeleteIrreversible => 'This cannot be undone';
  @override String get memoryStatStops => 'Stops';
  @override String get memoryStatBudget => 'Budget';
  @override String get memoryMapOpenFailed => 'Could not open maps';
  @override String get memoryLocationsTitle => 'Places';
  @override String memoryStopCount(int n) =>
      n == 1 ? '· 1 stop' : '· $n stops';
  @override String memoryStopNumber(int n) => 'Stop $n';
  @override String get memoryNoContacts => 'No contacts yet';
  @override String get memoryYouSuffix => '(you)';
  @override String get memoryAddFirstDay => 'Add the first day';
  @override String get memoryAddDay => 'Add another day';
  @override String get memoryDeleteStopTitle => 'Delete stop';
  @override String get memoryDeleteStopBody => 'Delete this stop?';
  @override String get memoryDeleteDayTitle => 'Delete this day';
  @override String get memoryDeleteDayBody =>
      'Every stop on this day will be deleted too.';
  @override String memoryDayLabel(int n) => 'Day $n';
  @override String get memoryNoStops => 'No stops yet — add one below';
  @override String get memoryAddStop => 'Add stop';
  @override String get memoryEditStop => 'Edit stop';
  @override String get memoryPickLocation => 'Pick a place';
  @override String get memoryPickLocationOptional => 'Pick a place (optional)';
  @override String get memoryNoLocation => 'No place';
  @override String get memoryAddLocation => 'Add a place';
  @override String get memoryLocationNameHint => 'Place name';
  @override String get memoryStopActivityHint => 'What happens here?';
  @override String get memoryTimeOptional => 'Time (optional)';
  @override String get memoryItineraryStopsTitle => 'Itinerary stops';
  @override String memoryDaysAndStops(int days, int stops) {
    final s = stops == 1 ? '1 stop' : '$stops stops';
    if (days <= 0) return '· $s';
    return '· ${days == 1 ? '1 day' : '$days days'} · $s';
  }
  @override String get memoryVideoFailed => 'Could not play video';
  @override String get memoryExportSection => 'Export';
  @override String get memoryExportPdfButton => 'Export PDF';
  @override String get memoryThemeSection => 'Theme';

  // ── Memory expenses tab ────────────────────────────────────────────────────
  @override String get memoryExpensesStatsTab => 'Stats';
  @override String get memoryExpensesListTab => 'List';
  @override String get memoryLensTeam => 'Everyone';
  @override String get memoryLensMine => 'Mine';
  @override String get memoryMyExpenses => 'My spending';
  @override String get memoryTotalExpenses => 'Total spending';
  @override String get memoryNoMyExpenses => 'You bear none of the costs here';
  @override String get memoryNoExpensesYet => 'No expenses yet';
  @override String get memoryBudgetTeamTitle => 'Budget · Everyone';
  @override String get memoryBudgetTeamOnlyHint =>
      'The budget covers the whole moment; it is not split per person';
  @override String get memoryBudgetEditTooltip => 'Edit budget';
  @override String get memoryBudgetSetCta => 'Set a budget for this moment';
  @override String get memoryBudgetSetButton => 'Set budget';
  @override String memoryBudgetOver(String amount) => '$amount over';
  @override String memoryBudgetLeft(String amount) => '$amount left';
  @override String memoryBudgetSpent(String amount) => 'Spent $amount';
  @override String get memoryMyShareTitle => 'What I bear';
  @override String get memoryTeamTotalTitle => 'Team total';
  @override String memoryTxnCount(int n) => n == 1 ? '1 item' : '$n items';
  @override String get memoryCategoryBreakdown => 'By category';
  @override String get memoryNoSpendInCurrency =>
      'No spending in this currency';
  @override String get memoryTotal => 'Total';
  @override String get memoryPersonRemoved => 'Removed';
  @override String get memoryPerPersonTitle => 'Per person';
  @override String memoryPaidUpfront(String amount) => 'Paid $amount';
  @override String get memoryBudgetSheetHint =>
      'Set one per currency; leave blank for no budget';

  // ── Memory PDF export ──────────────────────────────────────────────────────
  @override String get exportPdfTitle => 'Export PDF';
  @override String get exportBlockExpenses => 'Expense list';
  @override String get exportBlockExpensesHint =>
      'Every expense, grouped by currency';
  @override String get exportBlockCategory => 'By category';
  @override String get exportBlockCategoryHint =>
      'What each category cost, with a chart';
  @override String get exportBlockPersonSpend => 'Per person';
  @override String get exportBlockPersonSpendHint =>
      'What each person actually bore, with the maths';
  @override String get exportBlockStatement => 'Payment table';
  @override String get exportBlockStatementHint => 'Who owes whom (matrix)';
  @override String get exportBlockConsolidate => 'Final settlement';
  @override String get exportBlockConsolidateHint =>
      'What is owed after cancelling out';
  @override String get exportIncludePersonal => 'Include personal spending';
  @override String get exportIncludePersonalHint =>
      'Personal spending is not settled, and usually not for others to see';
  @override String get exportPickAtLeastOne => 'Pick at least one section';
  @override String exportLoadFailed(String e) => 'Failed to load: $e';

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
  @override String get expenseFormManage => 'Manage';
  @override String get expenseFormMemory => 'Moment';
  @override String get expenseFormLinkMemoryHint =>
      '(link a moment to split it)';
  @override String get expenseFormTreatWho => 'Who is treating (bears it all)';
  @override String get expenseFormPersonalHint =>
      'This one is not settled — nobody else shares it';
  @override String get expenseFormNoParticipants =>
      'No participants yet — add them to the moment first';
  @override String get expenseFormExcluded => 'Not sharing';
  @override String expenseFormPayerSuffix(String name) => '$name (paid)';
  @override String expenseFormPerHead(String amount, int n) =>
      '$amount each · split $n ways';

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
