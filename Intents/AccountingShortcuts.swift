import AppIntents
import Foundation

struct RecordExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "记录一笔支出"
    static var description = IntentDescription("按账户、分类和金额快速创建一笔已平衡的支出交易。")

    @Parameter(title: "金额") var amount: Double
    @Parameter(title: "账户名称") var accountName: String
    @Parameter(title: "支出分类") var categoryName: String
    @Parameter(title: "商户", default: "") var payee: String
    @Parameter(title: "备注") var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("记录支出 \(\.$amount) 元，账户 \(\.$accountName)，分类 \(\.$categoryName)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let receipt = try await MainActor.run {
            try ShortcutTransactionService.record(
                kind: .expense,
                amount: amount,
                accountName: accountName,
                categoryName: categoryName,
                payee: payee,
                note: note
            )
        }
        return .result(dialog: "已记录 \(MoneyInput.display(receipt.amount)) \(receipt.currencyCode) 的\(receipt.ledgerCategory)支出。")
    }
}

struct RecordIncomeIntent: AppIntent {
    static var title: LocalizedStringResource = "记录一笔收入"
    static var description = IntentDescription("按资产账户、分类和金额快速创建一笔已平衡的收入交易。")

    @Parameter(title: "金额") var amount: Double
    @Parameter(title: "到账账户") var accountName: String
    @Parameter(title: "收入分类") var categoryName: String
    @Parameter(title: "收入来源", default: "") var payee: String
    @Parameter(title: "备注") var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("记录收入 \(\.$amount) 元，到账 \(\.$accountName)，分类 \(\.$categoryName)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let receipt = try await MainActor.run {
            try ShortcutTransactionService.record(
                kind: .income,
                amount: amount,
                accountName: accountName,
                categoryName: categoryName,
                payee: payee,
                note: note
            )
        }
        return .result(dialog: "已记录 \(MoneyInput.display(receipt.amount)) \(receipt.currencyCode) 的\(receipt.ledgerCategory)收入。")
    }
}

struct OpenAIAccountingIntent: AppIntent {
    static var title: LocalizedStringResource = "打开 AI 记账"
    static var description = IntentDescription("打开应用的 AI 记账页面；需要用户确认分录后才会保存。")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        ShortcutRouteStore.set(.aiAccounting)
        return .result(dialog: "已打开 AI 记账，请描述收支并确认分录。")
    }
}

struct OpenNewTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "打开新增记账"
    static var description = IntentDescription("打开手动新增记账页面，便于在应用中检查完整分录后保存。")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        ShortcutRouteStore.set(.addTransaction)
        return .result(dialog: "已打开新增记账。")
    }
}

struct BackupToCloudIntent: AppIntent {
    static var title: LocalizedStringResource = "备份 51 账务数据"
    static var description = IntentDescription("将完整账务 JSON 备份上传到已配置的 WebDAV 云端目录。")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let receipt = try await ShortcutBackupService.backupNow()
        return .result(dialog: "云端备份完成，已上传 \(receipt.byteCount) bytes。")
    }
}

struct AccountingAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordExpenseIntent(),
            phrases: ["在\(.applicationName)记录支出", "用\(.applicationName)记一笔支出"],
            shortTitle: "记录支出",
            systemImageName: "minus.circle"
        )
        AppShortcut(
            intent: RecordIncomeIntent(),
            phrases: ["在\(.applicationName)记录收入", "用\(.applicationName)记一笔收入"],
            shortTitle: "记录收入",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenAIAccountingIntent(),
            phrases: ["在\(.applicationName)打开AI记账"],
            shortTitle: "AI 记账",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: OpenNewTransactionIntent(),
            phrases: ["在\(.applicationName)打开新增记账"],
            shortTitle: "新增记账",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: BackupToCloudIntent(),
            phrases: ["在\(.applicationName)备份账务数据"],
            shortTitle: "云端备份",
            systemImageName: "icloud.and.arrow.up"
        )
    }
}
