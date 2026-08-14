import Foundation

/// 备份设置；敏感信息应改为保存在钥匙串中。
struct BackupConfiguration: Codable {
    var webDAVURL: URL?
    var webDAVUsername: String?
    var webDAVPassword: String?
    var githubOwner: String?
    var githubRepository: String?
    var githubToken: String?
}

actor BackupManager {
    /// 导出本地账务数据，并输出中文字段。
    func localExport(transactions: [BookkeepingTransaction]) throws -> Data {
        let records = transactions.map { ["编号": $0.id.uuidString, "日期": ISO8601DateFormatter().string(from: $0.date), "商户": $0.payee, "备注": $0.note] }
        return try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
    }

    func uploadWebDAV(data: Data, filename: String, configuration: BackupConfiguration) async throws {
        guard let base = configuration.webDAVURL else { throw URLError(.badURL) }
        var request = URLRequest(url: base.appendingPathComponent(filename)); request.httpMethod = "PUT"; request.httpBody = data
        if let user = configuration.webDAVUsername, let password = configuration.webDAVPassword {
            let token = Data("\(user):\(password)".utf8).base64EncodedString(); request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }
        _ = try await URLSession.shared.data(for: request)
    }

    func githubCommit(data: Data, filename: String, configuration: BackupConfiguration) async throws {
        guard let owner = configuration.githubOwner, let repo = configuration.githubRepository, let token = configuration.githubToken else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(filename)")!
        var request = URLRequest(url: url); request.httpMethod = "PUT"; request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["提交说明": "备份 51 账务数据", "文件内容": data.base64EncodedString()])
        _ = try await URLSession.shared.data(for: request)
    }

    func saveToICloud(data: Data, filename: String) throws {
        guard let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent(filename) else { throw CocoaError(.fileNoSuchFile) }
        try data.write(to: url, options: .atomic)
    }
}
