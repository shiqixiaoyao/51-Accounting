import Foundation

struct AIServiceConfiguration: Equatable {
    let provider: AIProvider
    let endpoint: URL
    let model: String
    let apiKey: String
}

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case poke = "Poke（绯儿 Fei Er）"
    case openAICompatible = "OpenAI 兼容接口"
    case deepSeek = "DeepSeek"
    case claude = "Claude"
    case custom = "自定义接口"

    var id: String { identifier }

    var identifier: String {
        switch self {
        case .poke: return "poke"
        case .openAICompatible: return "openai-compatible"
        case .deepSeek: return "deepseek"
        case .claude: return "claude"
        case .custom: return "custom"
        }
    }

    var configurationHint: String {
        switch self {
        case .poke: return "请填写绯儿（Poke）账号提供的 HTTPS Endpoint、模型名称与 API Key。"
        case .openAICompatible: return "兼容 Chat Completions 的服务均可使用；可修改 Endpoint 与模型名称。"
        case .deepSeek: return "已填入 DeepSeek Chat Completions 端点，模型可按账号权限调整。"
        case .claude: return "已填入 Claude Messages 端点，使用 Anthropic API Key 与模型名称。"
        case .custom: return "自定义服务需接受 provider、model、input 字段，并返回本应用约定的 JSON 分录。"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .openAICompatible: return "https://api.openai.com/v1/chat/completions"
        case .deepSeek: return "https://api.deepseek.com/chat/completions"
        case .claude: return "https://api.anthropic.com/v1/messages"
        case .poke, .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openAICompatible: return "gpt-4.1-mini"
        case .deepSeek: return "deepseek-v4-flash"
        case .claude: return "claude-sonnet-4-5"
        case .poke, .custom: return ""
        }
    }

    var requestStyle: AIRequestStyle {
        switch self {
        case .openAICompatible, .deepSeek: return .chatCompletions
        case .claude: return .anthropicMessages
        case .poke, .custom: return .genericJSON
        }
    }
}

enum AIRequestStyle {
    case genericJSON
    case chatCompletions
    case anthropicMessages
}

struct AIRequestPayload: Encodable, Equatable {
    let provider: String
    let model: String
    let input: [String: String]

    init(configuration: AIServiceConfiguration, input: [String: String]) throws {
        let normalizedInput = input.reduce(into: [String: String]()) { result, item in
            let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !value.isEmpty { result[key] = value }
        }
        guard !normalizedInput.isEmpty else { throw AIBookkeepingError.invalidInput }
        self.provider = configuration.provider.identifier
        self.model = configuration.model
        self.input = normalizedInput
    }
}

enum AIConfigurationError: LocalizedError, Equatable {
    case missingEndpoint
    case invalidEndpoint
    case insecureEndpoint
    case missingModel
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingEndpoint: return "请输入 AI 服务地址。"
        case .invalidEndpoint: return "AI 服务地址格式无效。"
        case .insecureEndpoint: return "AI 服务地址应使用 HTTPS；本机调试可使用 localhost。"
        case .missingModel: return "请输入要调用的模型名称。"
        case .missingAPIKey: return "请输入并安全保存 API 密钥。"
        }
    }
}

enum AIConfigurationStore {
    private static let selectedProviderKey = "aiProvider"
    private static let legacyEndpointKey = "aiEndpoint"
    private static let legacyAPIKey = "aiAPIKey"
    private static let legacyModelKey = "aiModel"

    static func selectedProvider() -> AIProvider {
        AIProvider(rawValue: UserDefaults.standard.string(forKey: selectedProviderKey) ?? "") ?? .poke
    }

    static func load(provider: AIProvider? = nil) throws -> AIServiceConfiguration {
        migrateLegacyCredential()
        let selected = provider ?? selectedProvider()
        return try makeConfiguration(
            provider: selected,
            endpointText: endpoint(for: selected),
            model: model(for: selected),
            apiKey: KeychainStore.read(apiKeyKey(for: selected)) ?? ""
        )
    }

    static func endpoint(for provider: AIProvider) -> String {
        UserDefaults.standard.string(forKey: endpointKey(for: provider)) ?? provider.defaultEndpoint
    }

    static func model(for provider: AIProvider) -> String {
        UserDefaults.standard.string(forKey: modelKey(for: provider)) ?? provider.defaultModel
    }

    static func apiKey(for provider: AIProvider) -> String {
        KeychainStore.read(apiKeyKey(for: provider)) ?? ""
    }

    static func migrateLegacyCredential() {
        let provider = selectedProvider()
        let providerEndpointKey = endpointKey(for: provider)
        let providerModelKey = modelKey(for: provider)
        let credentialKey = apiKeyKey(for: provider)
        if UserDefaults.standard.string(forKey: providerEndpointKey) == nil,
           let legacyEndpoint = UserDefaults.standard.string(forKey: legacyEndpointKey) {
            UserDefaults.standard.set(legacyEndpoint, forKey: providerEndpointKey)
        }
        if UserDefaults.standard.string(forKey: providerModelKey) == nil,
           let legacyModel = UserDefaults.standard.string(forKey: legacyModelKey) {
            UserDefaults.standard.set(legacyModel, forKey: providerModelKey)
        }
        if let legacyKey = UserDefaults.standard.string(forKey: legacyAPIKey),
           !legacyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           KeychainStore.read(credentialKey) == nil {
            try? KeychainStore.write(legacyKey, for: credentialKey)
        }
        if let unsuffixedKey = KeychainStore.read(legacyAPIKey),
           KeychainStore.read(credentialKey) == nil {
            try? KeychainStore.write(unsuffixedKey, for: credentialKey)
            try? KeychainStore.delete(legacyAPIKey)
        }
        UserDefaults.standard.removeObject(forKey: legacyAPIKey)
        UserDefaults.standard.removeObject(forKey: legacyEndpointKey)
        UserDefaults.standard.removeObject(forKey: legacyModelKey)
    }

    static func save(provider: AIProvider, endpointText: String, model: String, apiKey: String) throws {
        let configuration = try makeConfiguration(provider: provider, endpointText: endpointText, model: model, apiKey: apiKey)
        UserDefaults.standard.set(configuration.provider.rawValue, forKey: selectedProviderKey)
        UserDefaults.standard.set(configuration.endpoint.absoluteString, forKey: endpointKey(for: provider))
        UserDefaults.standard.set(configuration.model, forKey: modelKey(for: provider))
        try KeychainStore.write(configuration.apiKey, for: apiKeyKey(for: provider))
    }

    static func makeConfiguration(provider: AIProvider, endpointText: String, model: String, apiKey: String) throws -> AIServiceConfiguration {
        let normalizedEndpoint = endpointText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEndpoint.isEmpty else { throw AIConfigurationError.missingEndpoint }
        guard let endpoint = URL(string: normalizedEndpoint), let scheme = endpoint.scheme?.lowercased(), endpoint.host != nil else {
            throw AIConfigurationError.invalidEndpoint
        }
        let isLocalhost = endpoint.host == "localhost" || endpoint.host == "127.0.0.1"
        guard scheme == "https" || (scheme == "http" && isLocalhost) else { throw AIConfigurationError.insecureEndpoint }
        guard !normalizedModel.isEmpty else { throw AIConfigurationError.missingModel }
        guard !normalizedKey.isEmpty else { throw AIConfigurationError.missingAPIKey }
        return AIServiceConfiguration(provider: provider, endpoint: endpoint, model: normalizedModel, apiKey: normalizedKey)
    }

    static func apiKeyKey(for provider: AIProvider) -> String { "aiAPIKey.\(provider.identifier)" }
    private static func endpointKey(for provider: AIProvider) -> String { "aiEndpoint.\(provider.identifier)" }
    private static func modelKey(for provider: AIProvider) -> String { "aiModel.\(provider.identifier)" }
}
