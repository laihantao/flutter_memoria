import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

/// Abstract base class for all app strings.
///
/// To add a new language:
///   1. Create lib/l10n/app_localizations_XX.dart extending this class.
///   2. Add Locale('XX') to [supportedLocales].
///   3. Add a case in [_Delegate.load].
abstract class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const List<Locale> supportedLocales = [
    Locale('zh'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate = _Delegate();

  // ── Common ────────────────────────────────────────────────────────────────
  String get cancel;
  String get confirm;
  String get save;
  String get delete;
  String get add;
  String get close;
  String get required;
  String get today;
  String get selectDate;
  String get savedSuccess;
  String get addedSuccess;
  String get deletedSuccess;
  String errorWith(String e);
  String copied(String label);

  // ── Navigation ────────────────────────────────────────────────────────────
  String get navMemories;
  String get navPeople;
  String get navExpenses;
  String get navSettings;

  // ── Onboarding ────────────────────────────────────────────────────────────
  String get onboardingTitle;
  String get onboardingSubtitle;
  String get onboardingAvatarPlaceholder;
  String get onboardingNameLabel;
  String get onboardingNameRequired;
  String get onboardingBirthdayOptional;
  String get onboardingPhoneSection;
  String get onboardingAddressSection;
  String get onboardingStart;
  String get onboardingAvatarUpdated;

  // ── Shared form field labels ───────────────────────────────────────────────
  String get fieldLabelTag;
  String get fieldPhoneHint;
  String get fieldAddressHint;
  String get fieldCustomTagHint;

  // ── Persons list ──────────────────────────────────────────────────────────
  String get personsTitle;
  String get personsEmpty;
  String get personsEmptyHint;
  String get personsAdd;
  String get personsTabLabel;
  String get groupsTabLabel;
  String get searchByNameHint;
  String get groupsEmpty;
  String get groupsEmptyHint;
  String get groupCreate;
  String get groupNameLabel;
  String get groupDescriptionLabel;
  String get groupNameRequired;
  String get groupMembers;
  String get groupSection;
  String get groupAddMember;
  String get groupAddToGroup;

  // ── Person form ───────────────────────────────────────────────────────────
  List<String> get relationshipTags;
  String get personFormAdd;
  String get personFormEdit;
  String get personNameLabel;
  String get personNameRequired;
  String get personBirthdayOptional;
  String birthdayFormatted(int y, int m, int d);
  String get personRelationship;
  String get personSaveError;
  String get personAvatarUpdated;
  String get personPhoneSection;
  String get personAddressSection;

  // ── Person detail ─────────────────────────────────────────────────────────
  String get personNotFound;
  String get personPartnerTooltip;
  String get personPhoneNumbers;
  String get personAddresses;
  String get personNotes;
  String get personAddNoteHint;
  String get personNoNotes;

  // ── Memories list ─────────────────────────────────────────────────────────
  String get memoriesTitle;
  String get memoriesEmpty;
  String get memoriesEmptyHint;
  String get memoriesAdd;

  // ── Memory form ───────────────────────────────────────────────────────────
  String get memoryFormNew;
  String get memoryFormEdit;
  String get memoryStartRequired;
  String get memoryTypeLabel;
  String memoryTypeName(String type);
  String get memoryTitleLabel;
  String get memoryFormRequired;
  String get memoryDescriptionLabel;
  String get memoryLocationLabel;
  String get memoryStartDateLabel;
  String get memoryEndDateLabel;
  String get memoryParticipantsLabel;

  // ── Memory detail ─────────────────────────────────────────────────────────
  String get memoryNotFound;
  String get memoryExportPdfTooltip;
  String get memoryExportTitle;
  String get memoryExportChoice;
  String get memoryExportKeepsake;
  String get memoryExportSettlement;
  String get memoryExportPdfMobileOnly;
  String memoryExportFailed(String e);
  String get memoryTabOverview;
  String get memoryTabItinerary;
  String get memoryTabGallery;
  String get memoryTabExpenses;
  String get memoryAddExpenseFab;
  String get memoryEditDetails;
  String get memoryEditItinerary;
  String get memoryGroupByDate;
  String get memoryListView;
  String get memoryDeleteItineraryConfirm;
  String get memoryParticipantsSection;
  String get memoryNoItinerary;
  String get memoryAddItinerary;
  String get memoryActivityHint;
  String get memoryDateLabel;
  String get memoryTimeLabel;
  String get memoryAddPhoto;
  String get memoryNoPhotos;
  String get memoryDeletePhoto;
  String get memoryNoExpenses;
  String get memoryRecordExpense;
  String memoryExpenseCount(int n);
  String memoryExpenseTotal(String sym, String amount);

  // ── Expenses screen ────────────────────────────────────────────────────────
  String get expensesTitle;
  String get expensesMonthBalance;
  String get expensesMonthExpense;
  String get expensesMonthIncome;
  String get expensesNoRecord;
  List<String> get weekdays; // index 1=Mon … 7=Sun
  String dayExpenseLabel(String sym, String amount);
  String dayIncomeLabel(String sym, String amount);
  String formatMonthYear(DateTime date);
  String formatMonthDay(DateTime date);

  // ── Wallets ────────────────────────────────────────────────────────────────
  String get walletsTitle;
  String get walletsInitialBalance;
  String get walletsNewWallet;
  String get walletsNameLabel;
  String get walletsCurrencyLabel;
  String get walletsCreateButton;
  String get walletsEmpty;
  String get walletsAddButton;

  // ── Transactions ───────────────────────────────────────────────────────────
  String get transactionsDefaultTitle;
  String get transactionsNotExist;
  String get transactionsBulkTagTooltip;
  String get transactionsBulkTagTitle;
  String get transactionsBulkTagHint;
  String get transactionsNoRecord;
  String get transactionsInitialBalance;
  String get transactionsMonthIncome;
  String get transactionsMonthExpense;
  String get transactionsAccountBalance;
  String get transactionsSurplus;
  String get transactionsOverspend;

  // ── Expense form ───────────────────────────────────────────────────────────
  String get expenseFormExpense;
  String get expenseFormIncome;
  String get expenseFormAmountRequired;
  String get expenseFormCategoryRequired;
  String get expenseFormNoteLabel;
  String get expenseFormNoteHint;
  String get expenseFormWriteNote;
  String get expenseFormNoWallet;
  String get expenseFormDone;
  String get expenseFormToday;

  // ── Transaction form (legacy wallet flow) ─────────────────────────────────
  String get txFormNew;
  String get txFormEdit;
  String get txFormCategoryRequired;
  String get txFormExpense;
  String get txFormIncome;
  String get txFormAmountLabel;
  String get txFormExchangeRateLabel;
  String get txFormCategoryLabel;
  String get txFormTitleLabel;
  String get txFormNoteLabel;
  String get txFormSplitTypeLabel;
  String get txFormPayer;
  String get txFormSplitWith;
  String get txFormAmountRequired;
  String get txFormInvalidAmount;
  String splitTypeName(String type);

  // ── Partner dashboard ──────────────────────────────────────────────────────
  String get partnerTabAnniversaries;
  String get partnerTabWishlist;
  String get partnerTabMemories;
  String get partnerNoAnniversaries;
  String get partnerToday;
  String partnerDaysToGo(int n);
  String get partnerToGo;
  String partnerDeleteConfirm(String label);
  String get partnerAnniversaryLabelHint;
  String get partnerDateLabel;
  String get partnerWishlistEmpty;
  String get partnerWishHint;
  String get partnerMemoriesNote;
  String get partnerConfirm;

  // ── Time categories ───────────────────────────────────────────────────────
  String get settingsSectionMoments;
  String get settingsCategories;
  String get settingsCategoriesSubtitle;
  String get categoryCreateTitle;
  String get categoryEditTitle;
  String get categoryNameLabel;
  String get categoryNameRequired;
  String get categoryCustom;
  String categoryDeleteHasRecords(String name, int count);
  String categoryDeleteConfirm(String name);

  // ── Settings ───────────────────────────────────────────────────────────────
  String get settingsTitle;
  String get settingsSectionPersonal;
  String get settingsMyProfile;
  String get settingsSectionWallets;
  String get settingsMyWallets;
  String get settingsMyWalletsSubtitle;
  String get settingsSectionBackup;
  String get settingsExport;
  String get settingsExportNote;
  String get settingsExportMobileOnly;
  String get settingsImport;
  String get settingsImportNote;
  String get settingsImportMobileOnly;
  String get settingsSectionAbout;
  String get settingsAppVersion;
  String settingsExportFailed(String e);
  String get settingsRestoreTitle;
  String get settingsRestoreContent;
  String get settingsRestoring;
  String get settingsCannotRead;
  String settingsRestoreFailed(String e);
  String get settingsRestoreSuccess;
  String get settingsSectionLanguage;
  String get settingsLanguageLabel;

  // ── Language names ─────────────────────────────────────────────────────────
  String get langZh;
  String get langEn;
}

// ── Delegate ───────────────────────────────────────────────────────────────────

class _Delegate extends LocalizationsDelegate<AppLocalizations> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(
        locale.languageCode == 'en'
            ? const AppLocalizationsEn()
            : const AppLocalizationsZh(),
      );

  @override
  bool shouldReload(_Delegate old) => false;
}

// ── BuildContext extension for ergonomic access ────────────────────────────────

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
