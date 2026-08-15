import Foundation

enum ShortcutRoute: String {
    case addTransaction
    case aiAccounting
}

enum ShortcutRouteStore {
    private static let key = "pendingShortcutRoute"

    static func set(_ route: ShortcutRoute) {
        UserDefaults.standard.set(route.rawValue, forKey: key)
    }

    static func consume() -> ShortcutRoute? {
        defer { UserDefaults.standard.removeObject(forKey: key) }
        guard let value = UserDefaults.standard.string(forKey: key) else { return nil }
        return ShortcutRoute(rawValue: value)
    }
}
