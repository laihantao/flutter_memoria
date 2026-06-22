import 'package:drift/drift.dart';

// ── Persons ──────────────────────────────────────────────────────────────────

class Persons extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatarPath => text().nullable()();
  DateTimeColumn get birthday => dateTime().nullable()();
  BoolColumn get isSelf => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PersonPhones extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text().references(Persons, #id)();
  TextColumn get label => text()();
  TextColumn get phoneNumber => text()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class PersonAddresses extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text().references(Persons, #id)();
  TextColumn get label => text()();
  TextColumn get address => text()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class PersonTags extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text().references(Persons, #id)();
  TextColumn get tagLabel => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class PersonRemarks extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text().references(Persons, #id)();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Partner Extensions ────────────────────────────────────────────────────────

class PartnerExtensions extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text().references(Persons, #id).unique()();

  @override
  Set<Column> get primaryKey => {id};
}

class PartnerAnniversaries extends Table {
  TextColumn get id => text()();
  TextColumn get partnerExtensionId =>
      text().references(PartnerExtensions, #id)();
  TextColumn get label => text()();
  DateTimeColumn get date => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PartnerWishlistItems extends Table {
  TextColumn get id => text()();
  TextColumn get partnerExtensionId =>
      text().references(PartnerExtensions, #id)();
  TextColumn get content => text()();
  BoolColumn get isFulfilled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Memories ──────────────────────────────────────────────────────────────────

class Memories extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get type => text()(); // trip/gathering/memory/event/custom
  TextColumn get description => text().nullable()();
  TextColumn get coverMediaPath => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get locationName => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MemoryParticipants extends Table {
  TextColumn get id => text()();
  TextColumn get memoryId => text().references(Memories, #id)();
  TextColumn get personId => text().references(Persons, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class ItineraryItems extends Table {
  TextColumn get id => text()();
  TextColumn get memoryId => text().references(Memories, #id)();
  DateTimeColumn get itemDate => dateTime()();
  TextColumn get itemTime => text().nullable()();
  TextColumn get title => text()();
  TextColumn get locationName => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class MediaAssets extends Table {
  TextColumn get id => text()();
  TextColumn get memoryId => text().references(Memories, #id)();
  TextColumn get type => text()(); // photo/video
  TextColumn get filePath => text()(); // relative path
  TextColumn get thumbnailPath => text().nullable()(); // relative, video only
  TextColumn get caption => text().nullable()();
  DateTimeColumn get takenAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class MemoryLocations extends Table {
  TextColumn get id => text()();
  TextColumn get memoryId => text().references(Memories, #id)();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Wallets & Transactions ────────────────────────────────────────────────────

class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get currencyCode => text()();
  TextColumn get iconName => text().nullable()();
  TextColumn get colorHex => text().nullable()();
  RealColumn get initialBalance => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // income/expense
  TextColumn get iconName => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get walletId => text().references(Wallets, #id).nullable()();
  TextColumn get memoryId => text().references(Memories, #id).nullable()();
  TextColumn get type => text()(); // income/expense
  TextColumn get categoryId => text().references(Categories, #id)();
  RealColumn get amount => real()();
  TextColumn get currencyCode => text()();
  RealColumn get exchangeRateToBase =>
      real().withDefault(const Constant(1.0))();
  DateTimeColumn get txnDate => dateTime()();
  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get receiptMediaPath => text().nullable()();
  TextColumn get splitType =>
      text().withDefault(const Constant('personal'))();
  TextColumn get payerPersonId => text().references(Persons, #id).nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionSplits extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get personId => text().references(Persons, #id)();
  TextColumn get shareType =>
      text()(); // equal/custom_amount/percentage
  RealColumn get shareAmount => real()();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Tags ─────────────────────────────────────────────────────────────────────

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get memoryId => text().references(Memories, #id).nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionTags extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Person Groups ─────────────────────────────────────────────────────────────

class PersonGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PersonGroupMembers extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(PersonGroups, #id)();
  TextColumn get personId => text().references(Persons, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class GroupMediaAssets extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(PersonGroups, #id)();
  TextColumn get type => text()(); // photo/video
  TextColumn get filePath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get caption => text().nullable()();
  DateTimeColumn get takenAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Time Categories ───────────────────────────────────────────────────────────

class TimeCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
