import SwiftUI
import SwiftData

@MainActor
struct CategoryManagementView: View {
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var creationKind: CategoryCreationKind?

    private var expenseCategories: [Category] {
        categories.filter { !$0.isIncome }
    }

    private var incomeCategories: [Category] {
        categories.filter(\.isIncome)
    }

    var body: some View {
        List {
            Section("支出分类") {
                if expenseCategories.isEmpty {
                    Text("暂未创建自定义支出分类，可使用新增记账页中的预置分类。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(expenseCategories) { category in
                        categoryRow(category)
                    }
                }
                Button {
                    creationKind = .expense
                } label: {
                    Label("新增支出分类", systemImage: "plus.circle")
                }
            }

            Section("收入分类") {
                if incomeCategories.isEmpty {
                    Text("暂未创建自定义收入分类，可使用新增记账页中的预置分类。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(incomeCategories) { category in
                        categoryRow(category)
                    }
                }
                Button {
                    creationKind = .income
                } label: {
                    Label("新增收入分类", systemImage: "plus.circle")
                }
            }

            Section("预置分类") {
                Text("支出包含餐饮、交通、购物、居住、娱乐、医疗健康、教育学习、通信网络、人情往来、保险、宠物和旅行等；收入包含工资、奖金、兼职收入、报销、利息、投资收益、租金、礼金和退款等。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("分类管理")
        .sheet(item: $creationKind) { kind in
            CategoryCreationSheet(kind: kind, onCreated: nil)
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .frame(width: 22)
                .foregroundStyle(category.isIncome ? .green : .red)
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                Text(category.isIncome ? "收入 · \(LedgerCategoryOption(name: category.name, isIncome: true).ledgerName)" : "支出 · \(LedgerCategoryOption(name: category.name, isIncome: false).ledgerName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
struct CategoryCreationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name) private var categories: [Category]

    let kind: CategoryCreationKind
    var onCreated: ((Category) -> Void)?

    @State private var name = ""
    @State private var icon = "tag"
    @State private var errorMessage: String?

    private let iconOptions = [
        "tag", "fork.knife", "car", "cart", "house", "gamecontroller",
        "cross.case", "book", "wifi", "gift", "banknote", "chart.line.uptrend",
        "building.2", "arrow.uturn.left.circle"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("分类信息") {
                    TextField("分类名称", text: $name)
                    Picker("图标", selection: $icon) {
                        ForEach(iconOptions, id: \.self) { option in
                            Label(option, systemImage: option).tag(option)
                        }
                    }
                    LabeledContent("分类类型") {
                        Text(kind.isIncome ? "收入" : "支出")
                            .foregroundStyle(kind.isIncome ? .green : .red)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(kind.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加", action: createCategory)
                }
            }
        }
    }

    private func createCategory() {
        do {
            let draft = try CategoryEntryRules.makeDraft(
                name: name,
                icon: icon,
                kind: kind,
                existingCategories: categories
            )
            let category = Category(
                name: draft.name,
                icon: draft.icon,
                isIncome: draft.isIncome,
                colorHex: draft.colorHex
            )
            modelContext.insert(category)
            do {
                try modelContext.save()
            } catch {
                modelContext.delete(category)
                throw error
            }
            onCreated?(category)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
