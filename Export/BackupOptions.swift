import Foundation

enum BackupScope: String, CaseIterable, Identifiable {
    case complete = "完整账本"
    case transactionsOnly = "仅交易记录"
    case setupOnly = "仅账户与分类"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .complete: return "账户、分类和全部交易，适合完整恢复。"
        case .transactionsOnly: return "仅导出交易和分录，适合归档或迁移账务记录。"
        case .setupOnly: return "仅导出账户与分类，适合初始化新设备。"
        }
    }
}

enum WebDAVBackupTarget: String, CaseIterable, Identifiable {
    case latest = "更新最新备份"
    case snapshot = "创建命名快照"

    var id: String { rawValue }
}

enum BackupFilename {
    static func webDAVFilename(
        scope: BackupScope,
        target: WebDAVBackupTarget,
        snapshotName: String,
        date: Date = .now
    ) -> String {
        guard target == .snapshot else { return "51-accounting-backup-latest.json" }
        let normalized = normalizedSnapshotName(snapshotName)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "51-accounting-\(scope.fileComponent)-\(normalized)-\(formatter.string(from: date)).json"
    }

    static func localFilename(scope: BackupScope, date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "51-accounting-\(scope.fileComponent)-\(formatter.string(from: date)).json"
    }

    static func normalizedSnapshotName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? "snapshot" : trimmed
        let allowed = source.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
                .contains(scalar) ? Character(String(scalar)) : "-"
        }
        let value = String(allowed).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return value.isEmpty ? "snapshot" : String(value.prefix(40))
    }
}

private extension BackupScope {
    var fileComponent: String {
        switch self {
        case .complete: return "complete"
        case .transactionsOnly: return "transactions"
        case .setupOnly: return "setup"
        }
    }
}
