import Foundation

struct BackupConfiguration: Codable {
    var webDAVURL: URL?
    var webDAVUsername: String?
    var webDAVPassword: String?
    var githubOwner: String?
    var githubRepository: String?
    var githubToken: String?
}

struct WebDAVConfiguration: Equatable {
    let baseURL: URL
    let username: String
    let password: String
}

struct CloudBackupReceipt: Equatable {
    let filename: String
    let byteCount: Int
    let uploadedAt: Date
    let eTag: String?
}

enum WebDAVConfigurationError: LocalizedError, Equatable {
    case missingEndpoint
    case invalidEndpoint
    case insecureEndpoint
    case missingUsername
    case missingPassword
    case invalidFilename

    var errorDescription: String? {
        switch self {
        case .missingEndpoint: return "请输入 WebDAV 服务地址。"
        case .invalidEndpoint: return "WebDAV 服务地址格式无效。"
        case .insecureEndpoint: return "WebDAV 服务地址应使用 HTTPS；本机调试可使用 localhost。"
        case .missingUsername: return "请输入 WebDAV 用户名。"
        case .missingPassword: return "请输入 WebDAV 密码或应用专用密码。"
        case .invalidFilename: return "备份文件名无效。"
        }
    }
}

enum WebDAVSettingsStore {
    private static let endpointKey = "webDAVEndpoint"
    private static let usernameKey = "webDAVUsername"
    private static let passwordKey = "webDAVPassword"
    private static let enabledKey = "webDAVEnabled"

    static func load() throws -> WebDAVConfiguration {
        migrateLegacyCredential()
        return try makeConfiguration(
            endpointText: UserDefaults.standard.string(forKey: endpointKey) ?? "",
            username: UserDefaults.standard.string(forKey: usernameKey) ?? "",
            password: KeychainStore.read(passwordKey) ?? ""
        )
    }

    static func migrateLegacyCredential() {
        if let legacy = UserDefaults.standard.string(forKey: passwordKey),
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           KeychainStore.read(passwordKey) == nil {
            try? KeychainStore.write(legacy, for: passwordKey)
        }
        UserDefaults.standard.removeObject(forKey: passwordKey)
    }

    static func save(endpointText: String, username: String, password: String, enabled: Bool) throws {
        let configuration = try makeConfiguration(
            endpointText: endpointText,
            username: username,
            password: password
        )
        UserDefaults.standard.set(configuration.baseURL.absoluteString, forKey: endpointKey)
        UserDefaults.standard.set(configuration.username, forKey: usernameKey)
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        try KeychainStore.write(configuration.password, for: passwordKey)
    }

    static func isEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func makeConfiguration(
        endpointText: String,
        username: String,
        password: String
    ) throws -> WebDAVConfiguration {
        let normalizedEndpoint = endpointText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEndpoint.isEmpty else { throw WebDAVConfigurationError.missingEndpoint }
        guard let parsedURL = URL(string: normalizedEndpoint),
              let scheme = parsedURL.scheme?.lowercased(),
              parsedURL.host != nil else {
            throw WebDAVConfigurationError.invalidEndpoint
        }
        let isLocalhost = parsedURL.host == "localhost" || parsedURL.host == "127.0.0.1"
        guard scheme == "https" || (scheme == "http" && isLocalhost) else {
            throw WebDAVConfigurationError.insecureEndpoint
        }
        guard !normalizedUsername.isEmpty else { throw WebDAVConfigurationError.missingUsername }
        guard !normalizedPassword.isEmpty else { throw WebDAVConfigurationError.missingPassword }

        return WebDAVConfiguration(
            baseURL: parsedURL.hasDirectoryPath ? parsedURL : parsedURL.appendingPathComponent(""),
            username: normalizedUsername,
            password: normalizedPassword
        )
    }
}

actor BackupManager {
    func localExport(transactions: [BookkeepingTransaction]) throws -> Data {
        let records = transactions.map {
            [
                "编号": $0.id.uuidString,
                "日期": ISO8601DateFormatter().string(from: $0.date),
                "商户": $0.payee,
                "备注": $0.note
            ]
        }
        return try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
    }

    func testWebDAVConnection(configuration: WebDAVConfiguration) async throws {
        var request = authorizedRequest(url: configuration.baseURL, configuration: configuration)
        request.httpMethod = "PROPFIND"
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.setValue("0", forHTTPHeaderField: "Content-Length")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) || http.statusCode == 207 else {
            throw URLError(.badServerResponse)
        }
    }

    func uploadWebDAV(
        data: Data,
        filename: String,
        configuration: WebDAVConfiguration
    ) async throws -> CloudBackupReceipt {
        guard !filename.isEmpty, !filename.contains("/"), !filename.contains("\\") else {
            throw WebDAVConfigurationError.invalidFilename
        }
        let destination = configuration.baseURL.appendingPathComponent(filename)
        var lastError: Error?

        for attempt in 0...1 {
            do {
                var request = authorizedRequest(url: destination, configuration: configuration)
                request.httpMethod = "PUT"
                request.httpBody = data
                request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200..<300).contains(http.statusCode) else {
                    throw WebDAVHTTPError(statusCode: http.statusCode)
                }
                return CloudBackupReceipt(
                    filename: filename,
                    byteCount: data.count,
                    uploadedAt: .now,
                    eTag: http.value(forHTTPHeaderField: "ETag")
                )
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(error) else { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        throw lastError ?? URLError(.badServerResponse)
    }

    func githubCommit(data: Data, filename: String, configuration: BackupConfiguration) async throws {
        guard let owner = configuration.githubOwner,
              let repo = configuration.githubRepository,
              let token = configuration.githubToken else {
            throw URLError(.userAuthenticationRequired)
        }
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(filename)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["message": "备份 51 账务数据", "content": data.base64EncodedString()]
        if let existing = try? await currentSHA(url: url, token: token) {
            body["sha"] = existing
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func saveToICloud(data: Data, filename: String) throws {
        guard let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent(filename) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try data.write(to: url, options: .atomic)
    }

    private func authorizedRequest(url: URL, configuration: WebDAVConfiguration) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 35)
        let credential = Data("\(configuration.username):\(configuration.password)".utf8).base64EncodedString()
        request.setValue("Basic \(credential)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func currentSHA(url: URL, token: String) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sha = json["sha"] as? String else {
            throw URLError(.fileDoesNotExist)
        }
        return sha
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if let error = error as? WebDAVHTTPError {
            return error.statusCode == 408 || error.statusCode == 429 || (500...599).contains(error.statusCode)
        }
        guard let error = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet].contains(error.code)
    }
}

private struct WebDAVHTTPError: LocalizedError {
    let statusCode: Int
    var errorDescription: String? { "WebDAV 上传失败（HTTP \(statusCode)）。" }
}
