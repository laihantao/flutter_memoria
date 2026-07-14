# Ledger App Kickoff Prompt

> 用法：新建空目录（如 `C:\p\flutter_ledger`），在里面开新的 Claude Code session，把下面整段贴进去。
> 前提：本机保留 `C:\p\flutter_memoria` 仓库，作为搬运代码的来源。

---

我要从零搭一个**独立的个人记账 Flutter app**（暂定名 `ledger`，正式名和 package id 先问我再定）。它是从我另一个项目 Memora（`C:\p\flutter_memoria`，回忆记录 app）里拆出来的：Memora 里有一个完整但定位违和的记账模块，我们决定把"个人记账"拆成独立 app，Memora 以后只保留挂在回忆上的费用。

## 技术栈（与 Memora 一致，方便我维护）

- Flutter（最新 stable），本地优先，无后端
- 状态：`flutter_riverpod` + `riverpod_annotation` / `riverpod_generator`
- 路由：`go_router`
- 数据库：`drift` + `drift_dev` + `build_runner`
- 其他：`intl`、`uuid`、`shared_preferences`、`google_fonts`（NotoSansSc）、`path_provider`
- l10n：中文（主）+ 英文，仿照 Memora 的 `lib/l10n/` 结构（`app_localizations.dart` + `_zh` + `_en`）
- 平台：先 Android 为主，保持 iOS 可编译

## 从 Memora 搬运的资产（搬之前先读源文件）

| Memora 源文件 | 处理方式 |
|---|---|
| `lib/utils/money.dart` | **原样复制**（纯 Dart：round-half-up、货币符号表、格式化） |
| `test/utils/` 下 money 相关测试 | 原样复制 |
| `lib/data/tables.dart` 中 `Wallets` / `Categories` / `Transactions` | 复制后**裁剪**（见下方数据模型） |
| `lib/data/daos/expense_dao.dart` | 参考重写，去掉 memory 相关查询 |
| `lib/screens/expense/expenses_screen.dart` | **UI 蓝本**：明细/统计/钱包三 tab、月份导航、汇总卡、按日分组列表、donut 图统计、类目/明细排行——整体交互和视觉照搬 |
| `lib/screens/expense/transaction_form_screen.dart`、`wallets_screen.dart`、`transactions_screen.dart` | 参考重写 |
| `lib/utils/split_math.dart` | **不搬**（AA 分账是 Memora 的社交场景，个人记账不需要） |

## 数据模型（裁剪规则）

保留 `Transactions` 的：id、walletId（必填，不再 nullable）、type（income/expense）、categoryId、amount、currencyCode、exchangeRateToBase、txnDate、title、note、receiptMediaPath、createdAt/updatedAt。

**删掉**：`memoryId`、`splitType`、`payerPersonId`、整个 `TransactionSplits` 表、`Tags`/`TransactionTags`（v1 不做标签）。

`Wallets` 和 `Categories` 原样保留（钱包多币种 + initialBalance；分类分收/支、含默认分类集 + 自定义）。

## 主题（重要）

Memora 的 `expenses_screen.dart` 顶部有一套硬编码调色板（`_kPageBg #F5ECD7` 米黄底、`_kGold #F0C23E` 金、`_kNeg #F2637C` 粉红支出、`_kPos #5BAD8B` 绿收入、`_kIconBg #FBDCE4` 等）。这套配色**升格为新 app 的正式主题**：做成 `ThemeData` + `ThemeExtension`，全 app 统一取用，**任何 screen 不允许再硬编码颜色**。先只做 light theme，dark 留 TODO。

## v1 功能范围（MVP）

1. 交易 CRUD：金额、收/支、分类、钱包、日期、标题、备注、可选收据照片
2. 明细页：月份导航、按日分组、每日结余、多币种月度汇总卡（结余/支出/收入）
3. 统计页：收/支切换、donut 占比图、类目排行（进度条）、明细排行 top10
4. 钱包页：多钱包多币种、余额 = initialBalance + 收入 − 支出、钱包交易流水页
5. 分类管理：默认分类 seed + 用户自定义（emoji 图标）
6. 设置页：默认币种、语言、数据导出 CSV（v1 只要导出）

**v1 明确不做**：预算、周期账、同步/云备份、多人分账、图表以外的报表、dark mode。

## 交付节奏

按里程碑推进，每个里程碑结束跑 `flutter analyze` + 已有测试：
M1 项目骨架 + 主题 + 路由 + 数据库 schema + seed 分类 → M2 交易 CRUD + 明细页 → M3 统计页 → M4 钱包 + 分类管理 + 设置 → M5 CSV 导出 + 打磨（空态、图标、splash）。

开始前先确认三件事再动手：① app 正式名 + Android package id；② 默认币种（我人在马来西亚，倾向 MYR）；③ 是否需要 v1 就支持记账时拍收据照片（不需要的话砍掉 image_picker 依赖）。
