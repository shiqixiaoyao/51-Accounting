import Foundation

/// 新账户创建完成后应回填的账户选择器。
enum AccountSelectionTarget: Equatable {
    case source
    case destination
}

/// 已通过输入校验、可转换为 Account 持久化模型的账户数据。
struct AccountCreationDraft: Equatable {
    let name: String
    let type: AccountType
    let currencyCode: String
}

/// 账户选择器的纯状态，便于在 SwiftUI 之外测试新增账户后的回填行为。
struct AccountSelectionState: Equatable {
    var sourceAccountID: UUID?
    var destinationAccountID: UUID?
}

enum AccountEntryError: LocalizedError, Equatable {
    case missingName
    case missingCurrency
    case duplicateName

    var errorDescription: String? {
        switch self {
        case .missingName: return "请输入账户名称。"
        case .missingCurrency: return "请输入币种代码。"
        case .duplicateName: return "已存在同名账户。"
        }
    }
}

/// 集中处理账户新增输入和新增后选择器回填的规则；不依赖 SwiftUI 或 SwiftData。
struct AccountEntryCoordinator {
    static func makeDraft(
        name: String,
        type: AccountType,
        currencyCode: String,
        existingAccountNames: [String]
    ) throws -> AccountCreationDraft {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCurrency = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !normalizedName.isEmpty else { throw AccountEntryError.missingName }
        guard !normalizedCurrency.isEmpty else { throw AccountEntryError.missingCurrency }

        let isDuplicate = existingAccountNames.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(normalizedName) == .orderedSame
        }
        guard !isDuplicate else { throw AccountEntryError.duplicateName }

        return AccountCreationDraft(
            name: normalizedName,
            type: type,
            currencyCode: normalizedCurrency
        )
    }

    static func selecting(
        accountID: UUID,
        for target: AccountSelectionTarget,
        from currentState: AccountSelectionState
    ) -> AccountSelectionState {
        var state = currentState
        switch target {
        case .source:
            state.sourceAccountID = accountID
        case .destination:
            state.destinationAccountID = accountID
        }
        return state
    }
}
