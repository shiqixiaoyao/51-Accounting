import SwiftUI
import SwiftData

/// 51 记账应用入口。
@main
struct FiftyOneApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(for: [Account.self, BookkeepingTransaction.self, Posting.self, Category.self])
    }
}
