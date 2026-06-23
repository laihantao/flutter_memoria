import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

class AppLocalizationsZh extends AppLocalizations {
  const AppLocalizationsZh() : super(const Locale('zh'));

  // ── Common ────────────────────────────────────────────────────────────────
  @override String get cancel => '取消';
  @override String get confirm => '确定';
  @override String get save => '保存';
  @override String get delete => '删除';
  @override String get add => '添加';
  @override String get close => '关闭';
  @override String get required => '必填';
  @override String get today => '今天';
  @override String get selectDate => '选择';
  @override String get savedSuccess => '已保存';
  @override String get addedSuccess => '已添加';
  @override String get deletedSuccess => '已删除';
  @override String errorWith(String e) => '错误：$e';
  @override String copied(String label) => '$label 已复制';

  // ── Navigation ────────────────────────────────────────────────────────────
  @override String get navMemories => '时光';
  @override String get navPeople => '人脉';
  @override String get navExpenses => '记账';
  @override String get navSettings => '设置';

  // ── Onboarding ────────────────────────────────────────────────────────────
  @override String get onboardingTitle => '欢迎使用 Memora';
  @override String get onboardingSubtitle => '先来设置你的个人资料吧。';
  @override String get onboardingAvatarPlaceholder => '我';
  @override String get onboardingNameLabel => '你的名字 *';
  @override String get onboardingNameRequired => '名字不能为空';
  @override String get onboardingBirthdayOptional => '生日（可选）';
  @override String get onboardingPhoneSection => '手机号码';
  @override String get onboardingAddressSection => '地址';
  @override String get onboardingStart => '开始使用';
  @override String get onboardingAvatarUpdated => '头像已更新';

  // ── Shared form field labels ───────────────────────────────────────────────
  @override String get fieldLabelTag => '标签';
  @override String get fieldPhoneHint => '手机号码';
  @override String get fieldAddressHint => '地址';
  @override String get fieldCustomTagHint => '自定义标签...';

  // ── Persons list ──────────────────────────────────────────────────────────
  @override String get personsTitle => '人脉';
  @override String get personsEmpty => '还没有联系人';
  @override String get personsEmptyHint => '添加你的第一位联系人';
  @override String get personsAdd => '添加联系人';
  @override String get personsTabLabel => '人脉';
  @override String get groupsTabLabel => '群组';
  @override String get searchByNameHint => '搜索姓名...';
  @override String get groupsEmpty => '还没有群组';
  @override String get groupsEmptyHint => '创建群组来管理你的人脉';
  @override String get groupCreate => '创建群组';
  @override String get groupNameLabel => '群组名称 *';
  @override String get groupDescriptionLabel => '描述（可选）';
  @override String get groupNameRequired => '名称不能为空';
  @override String get groupMembers => '成员';
  @override String get groupSection => '所属群组';
  @override String get groupAddMember => '添加成员';
  @override String get groupAddToGroup => '加入群组';

  // ── Person form ───────────────────────────────────────────────────────────
  @override List<String> get relationshipTags =>
      ['家庭', '伴侣', '朋友', '同事', '前同事'];
  @override String get personFormAdd => '添加联系人';
  @override String get personFormEdit => '编辑资料';
  @override String get personNameLabel => '名字 *';
  @override String get personNameRequired => '必填';
  @override String get personBirthdayOptional => '生日（可选）';
  @override String birthdayFormatted(int y, int m, int d) => '$y年$m月$d日';
  @override String get personRelationship => '关系';
  @override String get personSaveError => '保存失败：';
  @override String get personAvatarUpdated => '头像已更新';
  @override String get personPhoneSection => '手机号码';
  @override String get personAddressSection => '地址';

  // ── Person detail ─────────────────────────────────────────────────────────
  @override String get personNotFound => '联系人不存在';
  @override String get personPartnerTooltip => '伴侣中心';
  @override String get personPhoneNumbers => '手机号码';
  @override String get personAddresses => '地址';
  @override String get personNotes => '备注';
  @override String get personAddNoteHint => '添加备注...';
  @override String get personNoNotes => '还没有备注。';

  // ── Memories list ─────────────────────────────────────────────────────────
  @override String get memoriesTitle => '时光';
  @override String get memoriesEmpty => '还没有时光';
  @override String get memoriesEmptyHint => '开始记录你的第一段时光';
  @override String get memoriesAdd => '添加时光';

  // ── Memory form ───────────────────────────────────────────────────────────
  @override String get memoryFormNew => '新建时光';
  @override String get memoryFormEdit => '编辑时光';
  @override String get memoryStartRequired => '请选择开始日期';
  @override String get memoryTypeLabel => '类型';
  @override String memoryTypeName(String type) => const {
    'trip': '旅行',
    'gathering': '聚会',
    'memory': '日常',
    'event': '活动',
    'custom': '日常',
  }[type] ?? type;
  @override String get memoryTitleLabel => '标题 *';
  @override String get memoryFormRequired => '必填';
  @override String get memoryDescriptionLabel => '描述';
  @override String get memoryLocationLabel => '地点';
  @override String get memoryStartDateLabel => '开始日期 *';
  @override String get memoryEndDateLabel => '结束日期';
  @override String get memoryParticipantsLabel => '参与者';
  @override String get memoryBudgetLabel => '预算（可选）';
  @override String get memoryBudgetInvalid => '请输入有效金额';

  // ── Memory detail ─────────────────────────────────────────────────────────
  @override String get memoryNotFound => '时光记录不存在';
  @override String get memoryExportPdfTooltip => '导出PDF';
  @override String get memoryExportTitle => '导出PDF';
  @override String get memoryExportChoice => '选择导出版本';
  @override String get memoryExportKeepsake => '纪念册（含照片）';
  @override String get memoryExportSettlement => '账单结算';
  @override String get memoryExportPdfMobileOnly => 'PDF导出仅支持手机端。';
  @override String memoryExportFailed(String e) => '导出失败：$e';
  @override String get memoryTabOverview => '概览';
  @override String get memoryTabItinerary => '行程';
  @override String get memoryTabGallery => '相册';
  @override String get memoryTabExpenses => '费用';
  @override String get memoryTabSettings => '设定';
  @override String get memoryAddExpenseFab => '记一笔';
  @override String get memoryEditDetails => '编辑详情';
  @override String get memoryEditItinerary => '编辑行程';
  @override String get memoryGroupByDate => '按日期分组';
  @override String get memoryListView => '列表';
  @override String get memoryDeleteItineraryConfirm => '确定要删除这条行程吗？';
  @override String get memoryParticipantsSection => '参与者';
  @override String get memoryNoItinerary => '还没有行程';
  @override String get memoryAddItinerary => '添加行程';
  @override String get memoryActivityHint => '活动名称';
  @override String get memoryDateLabel => '日期';
  @override String get memoryTimeLabel => '时间';
  @override String get memoryAddPhoto => '添加照片/视频';
  @override String get memoryNoPhotos => '还没有照片';
  @override String get memoryDeletePhoto => '删除照片？';
  @override String get memoryNoExpenses => '没有关联的消费记录';
  @override String get memoryRecordExpense => '记一笔';
  @override String memoryExpenseCount(int n) => '$n 笔记录';
  @override String memoryExpenseTotal(String sym, String amount) =>
      '合计 $sym $amount';

  // ── Expenses screen ────────────────────────────────────────────────────────
  @override String get expensesTitle => '记账';
  @override String get expensesMonthBalance => '本月结余';
  @override String get expensesMonthExpense => '支出';
  @override String get expensesMonthIncome => '收入';
  @override String get expensesNoRecord => '本月还没有记录';
  @override List<String> get weekdays =>
      ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  @override String dayExpenseLabel(String sym, String amount) =>
      '支出 $sym $amount';
  @override String dayIncomeLabel(String sym, String amount) =>
      '收入 $sym $amount';
  @override String formatMonthYear(DateTime date) =>
      DateFormat('yyyy年MM月').format(date);
  @override String formatMonthDay(DateTime date) =>
      DateFormat('M月d日').format(date);

  // ── Wallets ────────────────────────────────────────────────────────────────
  @override String get walletsTitle => '钱包管理';
  @override String get walletsInitialBalance => '期初余额';
  @override String get walletsNewWallet => '新建钱包';
  @override String get walletsNameLabel => '钱包名称 *';
  @override String get walletsCurrencyLabel => '货币';
  @override String get walletsCreateButton => '创建钱包';
  @override String get walletsEmpty => '还没有钱包';
  @override String get walletsAddButton => '添加钱包';

  // ── Transactions ───────────────────────────────────────────────────────────
  @override String get transactionsDefaultTitle => '账本';
  @override String get transactionsNotExist => '钱包不存在';
  @override String get transactionsBulkTagTooltip => '批量打标签';
  @override String get transactionsBulkTagTitle => '批量打标签';
  @override String get transactionsBulkTagHint => '标签名称（如：东京2025）';
  @override String get transactionsNoRecord => '本月还没有记录';
  @override String get transactionsInitialBalance => '期初余额';
  @override String get transactionsMonthIncome => '本月收入';
  @override String get transactionsMonthExpense => '本月支出';
  @override String get transactionsAccountBalance => '账户余额';
  @override String get transactionsSurplus => '结余';
  @override String get transactionsOverspend => '超支';

  // ── Expense form ───────────────────────────────────────────────────────────
  @override String get expenseFormExpense => '支出';
  @override String get expenseFormIncome => '收入';
  @override String get expenseFormAmountRequired => '请输入金额';
  @override String get expenseFormCategoryRequired => '请选择分类';
  @override String get expenseFormNoteLabel => '备注';
  @override String get expenseFormNoteHint => '写点什么...';
  @override String get expenseFormWriteNote => '点击写备注...';
  @override String get expenseFormNoWallet => '不关联账本';
  @override String get expenseFormDone => '完成';
  @override String get expenseFormToday => '今天';

  // ── Transaction form ───────────────────────────────────────────────────────
  @override String get txFormNew => '新建交易';
  @override String get txFormEdit => '编辑交易';
  @override String get txFormCategoryRequired => '请选择分类';
  @override String get txFormExpense => '支出';
  @override String get txFormIncome => '收入';
  @override String get txFormAmountLabel => '金额 *';
  @override String get txFormExchangeRateLabel => '汇率';
  @override String get txFormCategoryLabel => '分类 *';
  @override String get txFormTitleLabel => '标题';
  @override String get txFormNoteLabel => '备注';
  @override String get txFormSplitTypeLabel => '分摊方式';
  @override String get txFormPayer => '付款人';
  @override String get txFormSplitWith => '与谁分摊';
  @override String get txFormAmountRequired => '必填';
  @override String get txFormInvalidAmount => '金额无效';
  @override String splitTypeName(String type) => switch (type) {
    'personal' => '个人',
    'split_aa' => 'AA制',
    'treat' => '请客',
    _ => type,
  };

  // ── Partner dashboard ──────────────────────────────────────────────────────
  @override String get partnerTabAnniversaries => '纪念日';
  @override String get partnerTabWishlist => '心愿单';
  @override String get partnerTabMemories => '时光';
  @override String get partnerNoAnniversaries => '还没有纪念日';
  @override String get partnerToday => '就是今天！';
  @override String partnerDaysToGo(int n) => '$n 天';
  @override String get partnerToGo => '后';
  @override String partnerDeleteConfirm(String label) => '删除"$label"？';
  @override String get partnerAnniversaryLabelHint => '标签（如：在一起的日子）';
  @override String get partnerDateLabel => '日期';
  @override String get partnerWishlistEmpty => '心愿单是空的';
  @override String get partnerWishHint => '添加心愿...';
  @override String get partnerMemoriesNote => '与此人有关的记忆\n将在这里显示。';
  @override String get partnerConfirm => '确认';

  // ── Time categories ───────────────────────────────────────────────────────
  @override String get settingsSectionMoments => '时光';
  @override String get settingsCategories => '管理时光分类';
  @override String get settingsCategoriesSubtitle => '自定义分类选项';
  @override String get categoryCreateTitle => '新建分类';
  @override String get categoryEditTitle => '编辑分类名';
  @override String get categoryNameLabel => '分类名称';
  @override String get categoryNameRequired => '名称不能为空';
  @override String get categoryCustom => '自定义';
  @override String categoryDeleteHasRecords(String name, int count) =>
      '「$name」下有 $count 条时光，删除后这些记录将归入「日常」';
  @override String categoryDeleteConfirm(String name) => '确定删除「$name」？';

  // ── Settings ───────────────────────────────────────────────────────────────
  @override String get settingsTitle => '设置';
  @override String get settingsSectionPersonal => '个人';
  @override String get settingsMyProfile => '我的资料';
  @override String get settingsSectionWallets => '账本管理';
  @override String get settingsMyWallets => '我的钱包';
  @override String get settingsMyWalletsSubtitle => '管理钱包和查看交易明细';
  @override String get settingsSectionBackup => '备份与恢复';
  @override String get settingsExport => '导出备份';
  @override String get settingsExportNote => '保存全部数据与媒体文件为 .zip';
  @override String get settingsExportMobileOnly => '备份功能需要手机端';
  @override String get settingsImport => '导入备份';
  @override String get settingsImportNote => '从 .zip 文件恢复（将覆盖当前数据）';
  @override String get settingsImportMobileOnly => '备份功能需要手机端';
  @override String get settingsSectionAbout => '关于';
  @override String get settingsAppVersion =>
      'Version 1.0.0 · 离线优先，无需账号';
  @override String settingsExportFailed(String e) => '导出失败：$e';
  @override String get settingsRestoreTitle => '恢复备份？';
  @override String get settingsRestoreContent =>
      '这将用备份替换你的全部当前数据，操作不可撤销。';
  @override String get settingsRestoring => '正在恢复备份...';
  @override String get settingsCannotRead => '无法读取所选文件。';
  @override String settingsRestoreFailed(String e) => '恢复失败：$e';
  @override String get settingsRestoreSuccess => '备份已恢复！请重启应用。';
  @override String get settingsSectionLanguage => '语言';
  @override String get settingsLanguageLabel => '界面语言';

  // ── Language names ─────────────────────────────────────────────────────────
  @override String get langZh => '简体中文';
  @override String get langEn => 'English';
}
