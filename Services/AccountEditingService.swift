import Foundation
import SwiftData

struct AccountEditDraft: Equatable {
    let name: String
    let type: AccountType
    let currencyCode: String
    let openingBalance: Decimal

    var ledgerName: String {
        Account.ledgerName(for: name, type: type)
    }
}

enum AccountEditingError: LocalizedError, Equatable {
    case missingName
    case missingCurrency
    case duplicateName
    case invalidOpeningBalance
    case precisionExceeded

    var errorDescription: String? {
        switch self {
        case .missingName: return "请输入银行或账户名称。"
        case .missingCurrency: return "请输入币种代码。"
        case .duplicateName: return "已存在同名账户。"
        case .invalidOpeningBalance: return "请输入有效的期初余额。"
        case .precisionExceeded: return "期初余额最多保留两位小数，精确到分。"
        }
    }
}

/// 账户编辑的纯校验与分录路径迁移规则。
enum AccountEditingRules {
    static func makeDraft(
        name: String,
        type: AccountType,
        currencyCode: String,
        openingBalanceInput: String,
        existingAccountNames: [String]
    ) throws -> AccountEditDraft {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCurrency = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedBalance = openingBalanceInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !normalizedName.isEmpty else { throw AccountEditingError.missingName }
        guard !normalizedCurrency.isEmpty else { throw AccountEditingError.missingCurrency }
        guard let openingBalance = Decimal(string: normalizedBalance, locale: Locale(identifier: "en_US_POSIX")) else {
            throw AccountEditingError.invalidOpeningBalance
        }
        guard openingBalance == openingBalance.roundedToCents else {
            throw AccountEditingError.precisionExceeded
        }

        let hasDuplicate = existingAccountNames.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(normalizedName) == .orderedSame
        }
        guard !hasDuplicate else { throw AccountEditingError.duplicateName }

        return AccountEditDraft(
            name: normalizedName,
            type: type,
            currencyCode: normalizedCurrency,
            openingBalance: openingBalance.roundedToCents
        )
    }

    static func rewrittenPostingAccountName(
        currentPostingAccountName: String,
        oldLedgerName: String,
        newLedgerName: String
    ) -> String {
        rewrittenPostingAccountName(
            currentPostingAccountName: currentPostingAccountName,
            oldAccountNames: [oldLedgerName],
            newLedgerName: newLedgerName
        )
    }

    static func rewrittenPostingAccountName(
        currentPostingAccountName: String,
        oldAccountNames: Set<String>,
        newLedgerName: String
    ) -> String {
        oldAccountNames.contains(currentPostingAccountName) ? newLedgerName : currentPostingAccountName
    }
}

/// SwiftData 写入边界：账户更新与历史分录路径重写在同一次保存中完成。
@MainActor
struct AccountEditingService {
    static func update(
        account: Account,
        allAccounts: [Account],
        postings: [Posting],
        draft: AccountEditDraft,
        in context: ModelContext
    ) throws {
        let otherNames = allAccounts
            .filter { $0.id != account.id }
            .map(\.name)
        _ = try AccountEditingRules.makeDraft(
            name: draft.name,
            type: draft.type,
            currencyCode: draft.currencyCode,
            openingBalanceInput: NSDecimalNumber(decimal: draft.openingBalance).stringValue,
            existingAccountNames: otherNames
        )

        let originalName = account.name
        let originalType = account.type
        let originalCurrency = account.currencyCode
        let originalOpeningBalance = account.openingBalance
        let oldLedgerName = account.ledgerName
        let newLedgerName = draft.ledgerName
        let oldAccountNames = Set([oldLedgerName, originalName])
        let affectedPostings = postings.filter { oldAccountNames.contains($0.accountName) }

        account.name = draft.name
        account.type = draft.type
        account.currencyCode = draft.currencyCode
        account.openingBalance = draft.openingBalance
        affectedPostings.forEach { $0.accountName = newLedgerName }

        do {
            try context.save()
        } catch {
            account.name = originalName
            account.type = originalType
            account.currencyCode = originalCurrency
            account.openingBalance = originalOpeningBalance
            affectedPostings.forEach { $0.accountName = oldLedgerName }
            throw error
        }
    }
}
