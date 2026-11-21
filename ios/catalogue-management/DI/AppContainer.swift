import Foundation

public struct AppContainer: Sendable {
    public let apiClient: any APIClient
    public let productRepository: any ProductRepository
    public let enquiryRepository: any EnquiryRepository

    public init(
        baseURL: URL,
        transport: any HTTPTransport = URLSessionTransport(),
        timeoutInterval: TimeInterval = 15
    ) {
        let apiClient = URLSessionAPIClient(
            baseURL: baseURL,
            transport: transport,
            timeoutInterval: timeoutInterval
        )
        self.apiClient = apiClient
        productRepository = ProductRepositoryImplementation(apiClient: apiClient)
        enquiryRepository = EnquiryRepositoryImplementation(apiClient: apiClient)
    }

    public static func configured(bundle: Bundle? = nil) throws -> AppContainer {
        let configurationBundle = bundle ?? Bundle(for: AppContainerBundleToken.self)
        guard let value = configurationBundle.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              let baseURL = URL(string: value),
              baseURL.host != nil
        else {
            throw APIError.invalidURL
        }
        return AppContainer(baseURL: baseURL)
    }
}

private final class AppContainerBundleToken: NSObject {}
