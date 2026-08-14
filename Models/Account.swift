import Foundation
import SwiftData

/// 账户模型：资产、负债、权益、收入和支出均以账户表示。
@Model
final class Account {
    var id: UUID
    var name: String
    var typeRawValue: String
    var currencyCode: String
    var openingBalance: Decimal
    var isLiability: Bool
    var createdAt: Date

    var type: AccountType {
        get { AccountType(rawValue: typeRawValue) ?? .asset }
        set { typeRawValue = newValue.rawValue }
    }

    init(name: String, type: AccountType, currencyCode: String = "CNY", openingBalance: Decimal = 0, isLiability: Bool? = nil) {
        self.id = UUID()
        self.name = name
        self.typeRawValue = type.rawValue
        self.currencyCode = currencyCode
        self.openingBalance = openingBalance
        self.isLiability = isLiability ?? type == .liability
        self.createdAt = .now
    }
}

enum AccountType: String, Codable, CaseIterable {
    case asset, liability, equity, income, expense
}
