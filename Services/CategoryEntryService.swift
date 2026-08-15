import Foundation

enum CategoryCreationKind: String, Identifiable {
    case expense
    case income

    var id: String { rawValue }
    var isIncome: Bool { self == .income }
    var title: String { self == .income ? "新增收入分类" : "新增支出分类" }
    var defaultColorHex: String { self == .income ? "#16A34A" : "#DC2626" }
}

struct CategoryCreationDraft: Equatable {
    let name: String
    let icon: String
    let isIncome: Bool
    let colorHex: String

    var option: LedgerCategoryOption {
        LedgerCategoryOption(name: name, isIncome: isIncome)
    }
}

enum CategoryEntryError: LocalizedError, Equatable {
    case missingName
    case duplicateName

    var errorDescription: String? {
        switch self {
        case .missingName: return "请输入分类名称。"
        case .duplicateName: return "该收入或支出分类已存在。"
        }
    }
}

/// 用户自定义收入或支出分类的纯校验规则。
enum CategoryEntryRules {
    static func makeDraft(
        name: String,
        icon: String,
        kind: CategoryCreationKind,
        existingCategories: [Category]
    ) throws -> CategoryCreationDraft {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { throw CategoryEntryError.missingName }

        let duplicateExists = existingCategories.contains { category in
            category.isIncome == kind.isIncome &&
            category.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(normalizedName) == .orderedSame
        }
        guard !duplicateExists else { throw CategoryEntryError.duplicateName }

        return CategoryCreationDraft(
            name: normalizedName,
            icon: icon.isEmpty ? "tag" : icon,
            isIncome: kind.isIncome,
            colorHex: kind.defaultColorHex
        )
    }
}
