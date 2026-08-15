import Foundation

struct AIServiceConfiguration: Equatable {
    let provider: AIProvider
    let endpoint: URL
    let apiKey: String
}

enum AIConfigurationError: LocalizedError, Equatable {
    case missingEndpoint
    case invalidEndpoint
    case insecureEndpoint
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingEndpoint: return "请输入 AI 服务地址。"
        case .invalidEndpoint: return "AI 服务地址格式无效。"
        case .insecureEndpoint: return "AI 服务地址应使用 HTTPS；本机调试可使用 localhost。"
        case .missingAPIKey: return "请输入并安全保存 API 密钥。"
        }
    }
}

enum AIConfigurationStore {
    private static let providerKey = "aiProvider"
    private static let endpointKey = "aiEndpoint"
    private static let apiKeyKey = "aiAPIKey"

    static func load() throws -> AIServiceConfiguration {
        migrateLegacyCredential()
        return try makeConfiguration(
            provider: AIProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .poke,
            endpointText: UserDefaults.standard.string(forKey: endpointKey) ?? "",
            apiKey: KeychainStore.read(apiKeyKey) ?? ""
        )
    }

    static func migrateLegacyCredential() {
        if let legacy = UserDefaults.standard.string(forKey: apiKeyKey),
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           KeychainStore.read(apiKeyKey) == nil {
            try? KeychainStore.write(legacy, for: apiKeyKey)
        }
        UserDefaults.standard.removeObject(forKey: apiKeyKey)
    }

    static func save(provider: AIProvider, endpointText: String, apiKey: String) throws {
        let configuration = try makeConfiguration(
            provider: provider,
            endpointText: endpointText,
            apiKey: apiKey
        )
        UserDefaults.standard.set(configuration.provider.rawValue, forKey: providerKey)
        UserDefaults.standard.set(configuration.endpoint.absoluteString, forKey: endpointKey)
        try KeychainStore.write(configuration.apiKey, for: apiKeyKey)
    }

    static func makeConfiguration(
        provider: AIProvider,
        endpointText: String,
        apiKey: String
    ) throws -> AIServiceConfiguration {
        let normalizedEndpoint = endpointText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEndpoint.isEmpty else { throw AIConfigurationError.missingEndpoint }
        guard let endpoint = URL(string: normalizedEndpoint), let scheme = endpoint.scheme?.lowercased(), endpoint.host != nil else {
            throw AIConfigurationError.invalidEndpoint
        }
        let isLocalhost = endpoint.host == "localhost" || endpoint.host == "127.0.0.1"
        guard scheme == "https" || (scheme == "http" && isLocalhost) else {
            throw AIConfigurationError.insecureEndpoint
        }
        guard !normalizedKey.isEmpty else { throw AIConfigurationError.missingAPIKey }

        return AIServiceConfiguration(provider: provider, endpoint: endpoint, apiKey: normalizedKey)
    }
}
