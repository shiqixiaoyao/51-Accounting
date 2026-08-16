import Foundation
import SwiftData

/// 复式记账账户：资产、负债、权益、收入与支出统一纳入账户树。
@Model
final class Account {
    var id: UUID
    var name: String
    var typeRawValue: String
    var currencyCode: String
    var openingBalance: Decimal
    var isLiability: Bool
    var lastFourDigits: String
    var createdAt: Date

    var type: AccountType {
        get { AccountType(rawValue: typeRawValue) ?? .asset }
        set {
            typeRawValue = newValue.rawValue
            isLiability = newValue == .liability
        }
    }

    var displayName: String {
        let suffix = lastFourDigits.trimmingCharacters(in: .whitespacesAndNewlines)
        return suffix.isEmpty ? name : "\(name) (\(suffix))"
    }

    var ledgerName: String {
        Self.ledgerName(for: displayName, type: type)
    }

    static func ledgerName(for name: String, type: AccountType) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Assets:Cash" }
        if trimmed.contains(":") { return trimmed }
        return "\(type.ledgerPrefix):\(trimmed)"
    }

    var selectionLabel: String {
        "\(displayName) · \(type.chineseName)"
    }

    init(name: String, type: AccountType, currencyCode: String = "CNY", openingBalance: Decimal = 0, isLiability: Bool? = nil, lastFourDigits: String = "") {
        id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        typeRawValue = type.rawValue
        self.currencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.openingBalance = openingBalance.roundedToCents
        self.isLiability = isLiability ?? (type == .liability)
        self.lastFourDigits = String(lastFourDigits.filter { character in character.isNumber }.prefix(4))
        createdAt = .now
    }
}

enum AccountType: String, Codable, CaseIterable {
    case asset, liability, equity, income, expense

    var chineseName: String {
        switch self {
        case .asset: return "资产"
        case .liability: return "负债"
        case .equity: return "权益"
        case .income: return "收入"
        case .expense: return "支出"
        }
    }

    var ledgerPrefix: String {
        switch self {
        case .asset: return "Assets"
        case .liability: return "Liabilities"
        case .equity: return "Equity"
        case .income: return "Income"
        case .expense: return "Expenses"
        }
    }
}
