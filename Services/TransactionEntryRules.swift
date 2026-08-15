import Foundation

/// 新增记账页面和领域规则共用的交易类型。
enum TransactionEntryKind: String, CaseIterable, Identifiable {
    case expense = "支出"
    case income = "收入"
    case transfer = "转账"

    var id: String { rawValue }
}

/// 可在 UI 中展示、并可映射为标准 Beancount 账户路径的分类。
struct LedgerCategoryOption: Identifiable, Equatable {
    let name: String
    let isIncome: Bool

    var id: String {
        "\(isIncome ? "income" : "expense"):\(name.lowercased())"
    }

    var ledgerName: String {
        "\(isIncome ? "Income" : "Expenses"):\(name)"
    }
}

/// 动态分类目录：优先使用已保存的分类，并补全用户尚未创建时的默认分类。
enum LedgerCategoryCatalog {
    private static let expenseDefaults = ["餐饮", "交通", "购物", "居住", "娱乐", "其他"]
    private static let incomeDefaults = ["工资", "奖金", "利息", "投资收益", "其他收入"]

    static func options(
        for entryKind: TransactionEntryKind,
        storedCategories: [Category]
    ) -> [LedgerCategoryOption] {
        guard entryKind != .transfer else { return [] }
        let wantsIncome = entryKind == .income
        let stored = storedCategories.compactMap { category -> LedgerCategoryOption? in
            let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard category.isIncome == wantsIncome, !name.isEmpty else { return nil }
            return LedgerCategoryOption(name: name, isIncome: category.isIncome)
        }
        let defaults = (wantsIncome ? incomeDefaults : expenseDefaults).map {
            LedgerCategoryOption(name: $0, isIncome: wantsIncome)
        }

        var seen = Set<String>()
        return (stored + defaults).filter { option in
            seen.insert(option.id).inserted
        }
    }
}

enum MoneyInputError: LocalizedError, Equatable {
    case invalidAmount
    case precisionExceeded

    var errorDescription: String? {
        switch self {
        case .invalidAmount: return "请输入大于零的有效金额。"
        case .precisionExceeded: return "金额最多保留两位小数，精确到分。"
        }
    }
}

/// 所有手动记账金额的解析和展示入口。
enum MoneyInput {
    static func validatedDecimal(from input: String) throws -> Decimal {
        let normalized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), amount > 0 else {
            throw MoneyInputError.invalidAmount
        }
        guard amount == amount.roundedToCents else {
            throw MoneyInputError.precisionExceeded
        }
        return amount.roundedToCents
    }

    static func display(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0.00"
    }
}

enum TransactionEntryRuleError: LocalizedError, Equatable {
    case missingSourceAccount
    case missingDestinationAccount
    case sameSourceAndDestination
    case missingCategory
    case invalidCategoryForEntryType
    case expenseMustUseAssetOrLiability
    case incomeMustEnterAnAssetAccount

    var errorDescription: String? {
        switch self {
        case .missingSourceAccount: return "请选择账户。"
        case .missingDestinationAccount: return "请选择转入账户。"
        case .sameSourceAndDestination: return "转出账户和转入账户不得相同。"
        case .missingCategory: return "请选择分类。"
        case .invalidCategoryForEntryType: return "所选分类与交易类型不匹配。"
        case .expenseMustUseAssetOrLiability: return "支出只能从资产账户扣减或记入负债账户。"
        case .incomeMustEnterAnAssetAccount: return "收入必须记入资产账户。"
        }
    }
}

/// 已解析的手动录入交易；负责输出经校验的标准 Beancount 分录。
struct TransactionEntryDraft {
    let kind: TransactionEntryKind
    let amount: Decimal
    let sourceAccount: Account?
    let destinationAccount: Account?
    let category: LedgerCategoryOption?
    let payee: String

    func makePostings() throws -> [Posting] {
        let value = amount.roundedToCents
        guard amount > 0, amount == value else {
            throw amount > 0 ? MoneyInputError.precisionExceeded : MoneyInputError.invalidAmount
        }
        guard let sourceAccount else { throw TransactionEntryRuleError.missingSourceAccount }

        switch kind {
        case .expense:
            guard sourceAccount.type == .asset || sourceAccount.type == .liability else {
                throw TransactionEntryRuleError.expenseMustUseAssetOrLiability
            }
            let category = try requiredCategory(isIncome: false)
            // 正数记入费用，负数扣减资产；若付款账户为负债，负数会使负债余额增加。
            return [
                Posting(accountName: category.ledgerName, amount: value, memo: payee),
                Posting(accountName: sourceAccount.ledgerName, amount: -value)
            ]

        case .income:
            guard sourceAccount.type == .asset else {
                throw TransactionEntryRuleError.incomeMustEnterAnAssetAccount
            }
            let category = try requiredCategory(isIncome: true)
            // 正数增加资产，负数记入收入账户，保持交易零和。
            return [
                Posting(accountName: sourceAccount.ledgerName, amount: value),
                Posting(accountName: category.ledgerName, amount: -value, memo: payee)
            ]

        case .transfer:
            guard let destinationAccount else {
                throw TransactionEntryRuleError.missingDestinationAccount
            }
            guard sourceAccount.id != destinationAccount.id else {
                throw TransactionEntryRuleError.sameSourceAndDestination
            }
            // 转入端为正、转出端为负；两端均使用账户的标准账本路径。
            return [
                Posting(accountName: destinationAccount.ledgerName, amount: value),
                Posting(accountName: sourceAccount.ledgerName, amount: -value)
            ]
        }
    }

    private func requiredCategory(isIncome: Bool) throws -> LedgerCategoryOption {
        guard let category else { throw TransactionEntryRuleError.missingCategory }
        guard category.isIncome == isIncome else {
            throw TransactionEntryRuleError.invalidCategoryForEntryType
        }
        return category
    }
}
