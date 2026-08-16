import Foundation

struct AIServiceConfiguration: Equatable {
    let provider: AIProvider
    let endpoint: URL
    let model: String
    let apiKey: String
}

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAICompatible = "OpenAI 兼容接口"
    case deepSeek = "DeepSeek"
    case claude = "Claude Proxy"
    case custom = "自定义接口"

    var id: String { identifier }
    var identifier: String {
        switch self {
        case .openAICompatible: return "openai-compatible"
        case .deepSeek: return "deepseek"
        case .claude: return "claude"
        case .custom: return "custom"
        }
    }
    var configurationHint: String {
        switch self {
        case .openAICompatible: return "兼容 Chat Completions 的服务均可使用。"
        case .deepSeek: return "使用 DeepSeek Chat Completions 接口。"
        case .claude: return "请填写支持 OpenAI Chat Completions 协议的 Claude 代理。"
        case .custom: return "自定义服务必须支持标准 Chat Completions 协议。"
        }
    }
    var defaultEndpoint: String {
        switch self {
        case .openAICompatible: return "https://api.openai.com/v1/chat/completions"
        case .deepSeek: return "https://api.deepseek.com/chat/completions"
        case .claude, .custom: return ""
        }
    }
    var defaultModel: String {
        switch self {
        case .openAICompatible: return "gpt-4.1-mini"
        case .deepSeek: return "deepseek-chat"
        case .claude, .custom: return ""
        }
    }
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
        provider = configuration.provider.identifier
        model = configuration.model
        self.input = normalizedInput
    }
}

enum AIConfigurationError: LocalizedError, Equatable {
    case missingEndpoint, invalidEndpoint, insecureEndpoint, missingModel, missingAPIKey
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
    static func selectedProvider() -> AIProvider { AIProvider(rawValue: UserDefaults.standard.string(forKey: selectedProviderKey) ?? "") ?? .openAICompatible }
    static func load(provider: AIProvider? = nil) throws -> AIServiceConfiguration {
        let selected = provider ?? selectedProvider()
        return try makeConfiguration(provider: selected, endpointText: endpoint(for: selected), model: model(for: selected), apiKey: apiKey(for: selected))
    }
    static func endpoint(for provider: AIProvider) -> String { UserDefaults.standard.string(forKey: endpointKey(for: provider)) ?? provider.defaultEndpoint }
    static func model(for provider: AIProvider) -> String { UserDefaults.standard.string(forKey: modelKey(for: provider)) ?? provider.defaultModel }
    static func apiKey(for provider: AIProvider) -> String { KeychainStore.read(apiKeyKey(for: provider)) ?? "" }
    static func migrateLegacyCredential() {}
    static func save(provider: AIProvider, endpointText: String, model: String, apiKey: String) throws {
        let configuration = try makeConfiguration(provider: provider, endpointText: endpointText, model: model, apiKey: apiKey)
        UserDefaults.standard.set(configuration.provider.rawValue, forKey: selectedProviderKey)
        UserDefaults.standard.set(configuration.endpoint.absoluteString, forKey: endpointKey(for: provider))
        UserDefaults.standard.set(configuration.model, forKey: modelKey(for: provider))
        try KeychainStore.write(configuration.apiKey, for: apiKeyKey(for: provider))
    }
    static func makeConfiguration(provider: AIProvider, endpointText: String, model: String, apiKey: String) throws -> AIServiceConfiguration {
        let endpointText = endpointText.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpointText.isEmpty else { throw AIConfigurationError.missingEndpoint }
        guard let endpoint = URL(string: endpointText), let scheme = endpoint.scheme?.lowercased(), endpoint.host != nil else { throw AIConfigurationError.invalidEndpoint }
        let localhost = endpoint.host == "localhost" || endpoint.host == "127.0.0.1"
        guard scheme == "https" || (scheme == "http" && localhost) else { throw AIConfigurationError.insecureEndpoint }
        guard !model.isEmpty else { throw AIConfigurationError.missingModel }
        guard !apiKey.isEmpty else { throw AIConfigurationError.missingAPIKey }
        return AIServiceConfiguration(provider: provider, endpoint: endpoint, model: model, apiKey: apiKey)
    }
    static func apiKeyKey(for provider: AIProvider) -> String { "aiAPIKey.\(provider.identifier)" }
    private static func endpointKey(for provider: AIProvider) -> String { "aiEndpoint.\(provider.identifier)" }
    private static func modelKey(for provider: AIProvider) -> String { "aiModel.\(provider.identifier)" }
}
