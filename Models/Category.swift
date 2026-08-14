import Foundation
import SwiftData

/// 账务分类，用于展示和统计收入、支出。
@Model
final class Category {
    var id: UUID
    var name: String
    var icon: String
    var isIncome: Bool
    var colorHex: String

    init(name: String, icon: String = "标签", isIncome: Bool = false, colorHex: String = "#6B7280") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.isIncome = isIncome
        self.colorHex = colorHex
    }
}
