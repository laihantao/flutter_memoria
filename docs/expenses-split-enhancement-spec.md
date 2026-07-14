# Expenses Split Enhancement — Discovery & Architecture Spec

**Project:** Memora (时光) — Flutter + Riverpod + Drift
**Status:** Design document (discovery + brainstorm). No implementation.
**Scope:** 分摊方式 gating, split/exclude logic, per-currency Payment Statement + Final Consolidate, PDF export rework (Pocket Gold pattern).

> This document is a hand-off. A follow-up tool will turn it into an implementation plan. It intentionally stops at "what & where", not "write the code".

---

## 1. Current State (as-found)

### 1.1 Expense data model

The expense entity is **`Transactions`** (there is no table literally named "expenses"). Defined in `lib/data/tables.dart:185`:

```dart
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get walletId => text().references(Wallets, #id).nullable()();
  TextColumn get memoryId => text().references(Memories, #id).nullable()();   // ← direct 记忆 link
  TextColumn get type => text()();                        // income/expense
  TextColumn get categoryId => text().references(Categories, #id)();
  RealColumn get amount => real()();
  TextColumn get currencyCode => text()();                // per-transaction currency
  RealColumn get exchangeRateToBase => real().withDefault(const Constant(1.0))();
  DateTimeColumn get txnDate => dateTime()();
  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get receiptMediaPath => text().nullable()();
  TextColumn get splitType => text().withDefault(const Constant('personal'))(); // personal/split_aa/treat
  TextColumn get payerPersonId => text().references(Persons, #id).nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override Set<Column> get primaryKey => {id};
}
```

Per-participant shares live in **`TransactionSplits`** (`lib/data/tables.dart:209`):

```dart
class TransactionSplits extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get personId => text().references(Persons, #id)();
  TextColumn get shareType => text()();          // equal/custom_amount/percentage  (only 'equal' used today)
  RealColumn get shareAmount => real()();        // materialized per-head amount
  @override Set<Column> get primaryKey => {id};
}
```

Key facts:
- **Currency** is stored per-transaction (`currencyCode`) plus an `exchangeRateToBase` multiplier. A trip can therefore already hold mixed currencies.
- **Mode** is a free-text string column `splitType` ∈ `{personal, split_aa, treat}` (default `personal`).
- **Paid-by** is `payerPersonId` (nullable FK to `Persons`).
- **Shares** are **materialized** rows in `TransactionSplits` written at save time — `shareAmount = amount / participantCount` (see §1.3). There is **no exclude list**; the split set is stored as an *include* list of participants.
- DB schema version is **8** (`lib/data/app_database.dart:50`). Migrations are hand-written per version in `onUpgrade`. Adding columns/tables requires bumping to 9 and adding a `if (v == 9)` branch.
- README mentions a `settlements` table — **stale**; no such table exists. Settlements are computed, never persisted.

### 1.2 记忆 ↔ expense link — TWO mechanisms, and they are mismatched ⚠️

There are **two independent linking paths**, and the app writes one but reads the other in the PDF flow:

**(a) Direct FK — `Transactions.memoryId`** — this is what the UI actually uses.
- Written by both add-expense forms (`memoryId: Value(_memoryId)` / `_linkedMemoryId`).
- Read by `ExpenseDao.watchTransactionsByMemory` (`lib/data/daos/expense_dao.dart:89`) → `transactionsByMemoryProvider` (`lib/providers/expense_provider.dart:59`).
- Used by the memory Overview stat card and the **Expenses tab** (`_ExpensesTab`, `memory_detail_screen.dart:2850`).

**(b) Tag join — `Tags.memoryId` + `TransactionTags`** — legacy/parallel, effectively unused by the UI.
- `Tags` has a nullable `memoryId` (`tables.dart:226`); `TransactionTags` joins tags to transactions.
- Read only by `ExpenseDao.getTransactionsForMemory` (`expense_dao.dart:111`), which resolves memory→tags→transactionTags→transactions.
- **The add-expense forms never create tags.** So this path returns `[]` for normally-entered expenses.

**Consequence:** `_exportPdf` (settlement branch) calls `getTransactionsForMemory` (the tag path) — see `memory_detail_screen.dart:194`:

```dart
final transactions = await ref.read(databaseProvider)
    .expenseDao.getTransactionsForMemory(widget.id);   // tag path → empty in practice
```

…so the settlement PDF is fed an empty transaction list on real data. This is almost certainly why the PDF is "built but never tested / broken". **The rework must standardize on the `memoryId` FK path** (option to drop the tag path for expenses entirely).

**Auto-tag-on-add:** Pressing "add expense" inside a 记忆 routes to `/memories/:id/expenses/new` (`lib/providers/router_provider.dart:95`), which constructs `ExpenseFormScreen(memoryId: state.pathParameters['id'])`. The form seeds `_memoryId = widget.memoryId` (`expense_form_screen.dart:71`) and persists it as the FK. "Auto-tag" = pre-selecting the memory chip; the user can still change it in the form's 记忆 selector.

### 1.3 Add-expense UI flow

**State management:** Riverpod (`flutter_riverpod`) for data (`StreamProvider`/`AsyncNotifierProvider`), plus local `ConsumerStatefulWidget` state for form fields. There are **two** expense form screens:

| Screen | File | Role |
|---|---|---|
| `ExpenseFormScreen` | `lib/screens/expense/expense_form_screen.dart` | **Primary.** Numpad-style entry. Used by every current route (standalone `/expenses/new`, memory-embedded `/memories/:id/expenses/new`, edit `/expenses/:id/edit`). See router lines 95–145. |
| `TransactionFormScreen` | `lib/screens/expense/transaction_form_screen.dart` | **Legacy** wallet-scoped flow (form-field style, has exchange-rate field). Not on any active-looking route; kept around. |

Both already have a **分摊方式 selector** — a 3-way `ChoiceChip` row over `['personal','split_aa','treat']` (`expense_form_screen.dart:614`, `transaction_form_screen.dart:333`). Labels come from `AppLocalizations.splitTypeName` (`app_localizations_zh.dart:224`): `personal→个人`, `split_aa→AA制`, `treat→请客`.

Current split behaviour (the include-multiselect, `expense_form_screen.dart:170`):

```dart
final splits = _splitType == 'split_aa' && _splitParticipants.isNotEmpty
    ? _splitParticipants.map((pid) => (
          personId: pid, shareType: 'equal',
          shareAmount: amount / _splitParticipants.length,   // equal split over the INCLUDE set
        )).toList()
    : <...>[];
```

- When `split_aa` is chosen, a payer picker + a participant **include** multiselect (`FilterChip`s) appear.
- `personal` and `treat` write **no** split rows.
- **No gating**: all three modes are always enabled regardless of whether a 记忆 is linked.
- **No exclude concept** exists anywhere.
- Payer defaults to self (`_initSelf`, line 82); self is force-added to `_splitParticipants`.

### 1.4 Participants source (人脉) and "me"

- People come from the **人脉 / relationship module**, table `Persons` (`tables.dart:5`) with a boolean `isSelf` flag.
- `PersonDao.getSelfPerson()` returns the single `isSelf == true` row; `watchAllPersons()` returns **everyone except self** (`person_dao.dart:29`, `where(isSelf.equals(false))`).
- **A trip's participants are already persisted** in the link table **`MemoryParticipants`** (`tables.dart:112`: `memoryId`, `personId`). Managed via `_ParticipantPickerSheet` (`memory_detail_screen.dart:1746`) → `MemoryNotifier.addParticipant/removeParticipant` (`memory_provider.dart:116`). Streamed via `memoryParticipantsProvider` (`memory_provider.dart:27`).
- The participant sheet composes the pickable list as `[?self, ...persons]` (`memory_detail_screen.dart:1808`) because `watchAllPersons` excludes self. So **self is a participant only if explicitly added** to the memory; it is not auto-included.

⚠️ **Gap:** the add-expense form's payer/split pickers bind to `personsProvider` (= `watchAllPersons`, **self excluded**), *not* to the trip's `MemoryParticipants`. So today the pickers show all non-self contacts and never show "me" as a selectable chip — inconsistent with the requirement that payer/exclude pickers be **restricted to the trip's participant list** (which includes me).

### 1.5 Existing PDF export

- Service: `lib/services/pdf_service.dart`, using the `pdf` package (`pw.*`) + `intl` (`NumberFormat('#,##0.00')`, `DateFormat`). Two generators:
  - `generateKeepsake(...)` — cover + itinerary + photo grid.
  - `generateSettlement(...)` (`pdf_service.dart:120`) — an "Expenses" table + a flat "Who Owes Whom" list.
- Entry point: 记忆 detail **设定 (Settings) tab** → `_SettingsTab` (`memory_detail_screen.dart:3760`) shows a single "导出 PDF" row calling `onExport` → `_exportPdf(memory)` (`memory_detail_screen.dart:148`).
- Current UX is a **2-button `AlertDialog`** ("keepsake" vs "settlement") — **no preview, no per-section toggles.** Output is generated then handed to `Share.shareXFiles`.
- Known defects in the settlement path (`_exportPdf`, lines 194–222):
  - Pulls transactions via the **empty tag path** (§1.2).
  - `personNames: const {}` is passed empty → payer names render blank in the table.
  - `baseCurrency: 'MYR'` hardcoded; everything is netted to one currency.
  - Netting uses `SettleUpService` (global greedy), not pairwise (§1.6).
- **No preview mechanism** exists. Reusable: the `pw.*` widget-building patterns (headers, `TableHelper.fromTextArray`, brown theme colors) are fine to keep; the *data plumbing* and *structure* need rebuilding.

### 1.6 Money / util layer

There is **no central money/aggregation utility**. What exists:
- `SettleUpService` (`lib/services/settle_up_service.dart`) — the only computation layer. It:
  - Considers only `splitType == 'split_aa'` rows (skips personal/treat) ✓.
  - Converts every amount to base via `exchangeRateToBase` and **collapses all currencies into one** ✗ (conflicts with per-currency requirement F).
  - Nets to per-person balances, then does **global greedy debt-minimization** (largest creditor ↔ largest debtor) ✗ (conflicts with pairwise requirement E).
  - Rounds with `toStringAsFixed(2)` and a `0.01` epsilon.
- Formatting is duplicated: `NumberFormat('#,##0.00')` in `pdf_service.dart:12` and `money_chip.dart:19`.
- Currency **symbol** map is scattered and incomplete: `_kCurrencySymbols` (`expense_form_screen.dart:14`, 5 currencies) and `_currencySym` (`memory_detail_screen.dart:75`, only MYR/SGD, else falls back to the code).
- Rounding today relies on Dart's `double.toStringAsFixed`, which rounds ties away-from-zero — close to 四舍五入 for positive money, but not a named/centralized helper.

---

## 2. Gap Analysis (per requirement)

| Req | Exists today | Missing / needs change |
|---|---|---|
| **A. 分摊方式 gating on 记忆 tag** | 3-way selector exists in both forms. | No gating. Must force `personal` and disable `split_aa`/`treat` when `memoryId == null`; enable all three when linked. Needs to react to the memory selector changing within the form. |
| **B. Split logic (aa=equal, exclude set, payer always in)** | Equal split over an **include** set; `shareAmount` materialized. | Invert to an **exclude** model: share = `amount ÷ (participants − excluded)`. Enforce payer ∉ exclude. Persist the exclude set (or the effective participant set). Personal/Treat already produce no debt ✓ but should be explicitly treated as identical no-op for netting. |
| **C. Participants from 人脉, one "me"** | `MemoryParticipants` + `Persons.isSelf` exist. | Form pickers must bind to the trip's `MemoryParticipants` (incl. self), not global `watchAllPersons` (self-excluded). Decide whether self is auto-added to a trip. |
| **D. Payment Statement matrix** | Nothing. Flat "who owes whom" list only. | New computation: rows = all participants, columns = payees who fronted `split_aa` expenses; cell = row-owes-column. Per currency. |
| **E. Final Consolidate (pairwise net)** | `SettleUpService` does **global** greedy minimization. | Replace with **pairwise** netting per (debtor,payee) pair. No global optimization. |
| **F. Multi-currency separate groups** | All currencies collapsed to base. | Group everything by `currencyCode`; produce a separate Statement + Consolidate per currency; never mix. Drop/ignore `exchangeRateToBase` for these views. |
| **G. PDF rework (Pocket Gold pattern)** | 2-choice dialog, no preview/toggles, broken data path. | Preview screen + section toggles (expenses table / statement / consolidate). Defaults: expenses + consolidate ON, statement OFF. Per-currency sections. Fix data source to the `memoryId` FK path and pass real `personNames`. |
| **H. Rounding 2dp round-half-up** | Ad-hoc `toStringAsFixed(2)`. | Centralize a `roundHalfUp(x, 2)` helper; apply consistently in statement/consolidate; accept non-reconciliation. |

---

## 3. Proposed Architecture

### 3.1 Data model changes

**Decision point — how to store the exclude list + mode.** Mode already has a column (`splitType`). For the exclude set, three viable options:

- **Option A (recommended): reuse `TransactionSplits` as the effective participant set.**
  Keep storing one row per person **who shares** (participants − excluded), with `shareAmount` = per-head amount, `shareType = 'equal'`. This is exactly today's include model, just fed by `(tripParticipants − excluded)` instead of a free multiselect. Pros: **no migration**, computation code can read splits directly, payer-always-in is enforced at write time. Cons: the *exclude* selection itself isn't persisted verbatim — on edit you reconstruct it as `tripParticipants − splitPersonIds`. That reconstruction is deterministic and fine.
- **Option B: add an explicit exclude join table** (`TransactionExclusions(transactionId, personId)`) and/or a `TransactionSplits.isExcluded` flag. Pros: exclude intent stored verbatim; robust if trip roster changes after the fact. Cons: schema migration (v9), two sources of truth to keep consistent with `TransactionSplits`.
- **Option C: store nothing extra; compute shares on read** from `splitType` + payer + current trip roster. Pros: minimal storage. Cons: shares drift if the roster changes later; loses the historical snapshot; more read-time work.

**Recommendation: Option A.** Reuse `TransactionSplits` as the persisted *effective sharers*, keep `shareAmount` materialized (snapshot semantics — matches "not a strict ledger"). Reconstruct the exclude set on edit as `tripParticipants − sharers`. No migration needed. Persist shares (don't compute on read) so a later roster edit doesn't silently rewrite past expenses.

If the team wants exclude intent preserved verbatim across roster edits, escalate to **Option B** (adds schema v9). This is the main open modeling decision (see §4).

`splitType` values stay `personal | split_aa | treat`. Consider a code-level enum wrapper for safety, but the DB stays string (no migration).

### 3.2 Computation layer (new)

Create a pure, testable service (e.g. `lib/services/expense_split_service.dart`) that supersedes/absorbs `SettleUpService`. All functions are **grouped by `currencyCode` first**; each currency yields its own result set. Signature sketch (design, not final):

```
Input:  List<Transaction> (memory-scoped, via memoryId FK)
        Map<txId, List<TransactionSplit>>
        List<personId> tripParticipants
        Map<personId, name>

Per currency group (transactions where t.currencyCode == C, splitType == 'split_aa'):

  1. PaymentStatement (Req D):
     - payees  = distinct payerPersonId across that currency's split_aa txns
     - rows    = all tripParticipants
     - cell[row][payee] = Σ over txns paid by `payee` of that row's shareAmount
                          (a participant's own share to a txn they paid = 0 / self-cell blank)
     - values rounded half-up to 2dp.

  2. FinalConsolidate (Req E, pairwise):
     - For each unordered pair {X, Y}:
         owe_XtoY = Σ shares X owes to expenses Y paid
         owe_YtoX = Σ shares Y owes to expenses X paid
         net = owe_XtoY − owe_YtoX
         if net > 0  →  "X pays Y  net"
         if net < 0  →  "Y pays X  |net|"
         if 0        →  settled, omit
     - Pairwise only; NO global minimization.
```

Sanity check against the brief's example (single currency): A owes Me 25, Me owes A 120 → pair {A,Me}: net = 120 − 25 = 95 in Me's favor → **"A pays Me 95"** ✓.

Rounding helper (Req H) lives here or in a small `lib/utils/money.dart`:

```
double roundHalfUp(double v, [int dp = 2]);   // e.g. (v*100).round()/100 with half-up semantics
```

Apply rounding at **presentation of each cell / each pair total**, not mid-aggregation, and accept that row/column sums may be a cent off (explicitly allowed).

**Reuse note:** `SettleUpService.compute` can be retired or refactored into the pairwise path. Its per-person balance loop is a useful starting point but its greedy matcher (`settle_up_service.dart:49-88`) and base-currency collapse must go.

### 3.3 UI changes

**Gating (Req A)** — in `ExpenseFormScreen` (primary; mirror in `TransactionFormScreen` if still reachable):
- Derive `linked = _memoryId != null`.
- When `!linked`: force `_splitType = 'personal'`; render `split_aa`/`treat` chips **disabled** (greyed, non-selectable). If the memory selector is cleared while a split mode is active, reset to `personal`.
- When `linked`: enable all three.

**Participant / exclude picker (Req B, C)** — when `split_aa` and linked:
- Source the person list from **the trip's `MemoryParticipants`** (resolve `personId`→`Person`, include self), not `personsProvider`. A new provider like `memoryParticipantPersonsProvider(memoryId)` (join `MemoryParticipants` × `Persons`, self included) is the clean way.
- Payer picker: restricted to trip participants.
- Convert the current **include** multiselect into an **exclude** multiselect (default: nobody excluded → everyone shares). Enforce **payer cannot be excluded** (disable the payer's exclude chip; if payer changes to a currently-excluded person, drop them from the exclude set).
- Live per-head preview: `amount ÷ (participants − excluded)`.
- On save, write `TransactionSplits` for `(participants − excluded)` with `shareAmount = roundHalfUp(amount / n)` (Option A).

**Statement / Consolidate display** — optionally surface in the app (e.g., in `_ExpensesTab`) in addition to the PDF, grouped per currency. Not strictly required by the brief but the same computation feeds both; at minimum it feeds the PDF preview.

### 3.4 PDF rework (Req G — Pocket Gold pattern)

- Replace the `_exportPdf` `AlertDialog` with a **preview screen/sheet** (new widget, e.g. `lib/screens/memory/expense_export_screen.dart`) launched from the same `_SettingsTab` "导出 PDF" row.
- **Section toggles** (checkboxes/switches):
  1. Expenses table (expenses where `memoryId == this` via the **FK path**) — **default ON**
  2. Payment Statement — **default OFF**
  3. Final Consolidate — **default ON**
- **Per-currency grouping** honored inside each toggled section: one sub-block per `currencyCode`.
- Live **preview** of the composed PDF (the `pdf`/`printing` package supports a preview widget; if `printing` isn't a dep yet, either add it or render an in-app approximation then export via existing `Share`).
- Fix data plumbing: fetch transactions by `memoryId` FK (`watchTransactionsByMemory`/`getTransactionsByMemoryId`), build a real `personNames` map from `Persons`, drop the hardcoded `'MYR'`.
- `PdfService`: refactor `generateSettlement` into a parameterized builder that takes the toggle flags + the per-currency computed structures and emits only the enabled sections. Keep `generateKeepsake` as-is (separate concern).

### 3.5 Where the logic should live (code-sharing consideration)

Because both the standalone and memory-embedded expense entry go through the **same `ExpenseFormScreen`**, the gating must be driven purely by `_memoryId` (data), not by "which route launched me". That keeps one code path. The split math belongs in the **service layer** (§3.2), consumed by the form (save-time share computation), any in-app statement view, and the PDF builder — so all three agree.

---

## 4. Open Questions / Risks

1. **Exclude storage model (main decision):** Option A (reuse `TransactionSplits`, no migration, reconstruct exclude on edit) vs Option B (explicit exclude table, schema v9, verbatim intent). Recommend A unless preserving exclude intent across later roster changes matters.
2. **Self auto-membership:** Should "me" be auto-added to a trip's `MemoryParticipants` (so it always appears in payer/exclude pickers), or must the user add self manually as today? The split math assumes a fixed "me" is present.
3. **Roster changes after expenses exist:** If a participant is removed from the trip after they were part of splits, how do Statement/Consolidate treat them? (Materialized shares in Option A preserve history; a pure-compute approach would drop them.)
4. **Broken tag path cleanup:** Confirm the `Tags`/`TransactionTags` expense linkage can be abandoned for expenses (nothing else depends on it). If other features use tags, keep the table but stop routing expense-for-memory through it.
5. **`TransactionFormScreen` fate:** Is the legacy screen still reachable? If yes, gating/exclude must be mirrored there; if dead, consider deleting to avoid divergent behaviour.
6. **PDF preview dependency:** Is `printing` available/desired for a true preview, or should preview be an in-app Flutter approximation? (`pdf` alone builds bytes but has no live preview widget.)
7. **Currency identity:** Grouping keys on the raw `currencyCode` string. Confirm codes are normalized (e.g., always uppercase) so "myr"/"MYR" don't split into two groups.
8. **Rounding edge:** Round-half-up per cell means a row's cells may not sum exactly to the row total. Confirmed acceptable per Req H, but the PDF should not print a "total" that implies reconciliation.
9. **income vs expense rows:** Splits only make sense for `type == 'expense'`. Confirm income transactions are excluded from Statement/Consolidate (and probably from the expenses table too, or shown separately).

---

## 5. Locked Decisions (restated — do not re-litigate)

- **Modes:** `个人 = Self`, `AA制 = Split`, `请客 = Treat`. **Self and Treat both create no debt** (mathematically identical; labels differ).
- **Gating:** memory-linked → all three modes enabled; not linked → force **个人**, disable AA制 & 请客.
- **Split math:** AA制 = equal split; per-head = `amount ÷ (participants − excluded)`. **Payer is always in the split and cannot be excluded.** Payer + exclude pickers are restricted to the trip's participant list.
- **Participants:** from 人脉; exactly one fixed "me" per trip.
- **Netting:** **pairwise** per pair — each debtor pays each payee directly. **No** global debt-minimization.
- **Multi-currency:** a trip may hold multiple currencies → **fully separate view groups per currency** (separate Payment Statement + Final Consolidate each). Never mix currencies in one table.
- **PDF defaults:** Expenses table + Final Consolidate **ON**; Payment Statement **optional / default OFF**. Respect per-currency grouping. Preview + selectable sections (Pocket Gold pattern).
- **Rounding:** 2 decimals, round-half-up (四舍五入). Not a strict financial ledger; no cent-level reconciliation required.
