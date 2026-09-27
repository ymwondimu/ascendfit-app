import Foundation
import Security

struct WorkoutTextServiceConfiguration: Sendable {
    let endpoint: URL
    let accessToken: String

    init(baseURL: URL, accessToken: String, allowLocalDevelopment: Bool = false) throws {
        let local = allowLocalDevelopment && baseURL.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(baseURL.host ?? "")
        guard (baseURL.scheme == "https" || local), baseURL.host != nil,
              baseURL.user == nil, baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil,
              !accessToken.isEmpty, !accessToken.contains(where: { $0.isWhitespace }) else {
            throw WorkoutImportError.invalid("Text conversion is not configured securely. You can still import JSON offline.")
        }
        endpoint = baseURL.appendingPathComponent("v1/imports/interpret")
        self.accessToken = accessToken
    }

    static func current() throws -> Self {
        var address = Bundle.main.object(forInfoDictionaryKey: "AscendImportServiceURL") as? String
        var token: String?
        #if DEBUG && targetEnvironment(simulator)
        address = ProcessInfo.processInfo.environment["ASCEND_IMPORT_SERVICE_URL"] ?? address
        token = ProcessInfo.processInfo.environment["ASCEND_IMPORT_ACCESS_TOKEN"]
        #endif
        if token == nil {
            var result: CFTypeRef?
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.ascendfit.import.access", kSecAttrAccount as String: "private-service",
                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
            if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
                token = String(data: data, encoding: .utf8)
            }
        }
        guard let address, let url = URL(string: address), let token else {
            throw WorkoutImportError.invalid("Text conversion is not available in this build. Use Format help to get workout JSON from your coach; JSON import works offline.")
        }
        #if DEBUG && targetEnvironment(simulator)
        return try Self(baseURL: url, accessToken: token, allowLocalDevelopment: true)
        #else
        return try Self(baseURL: url, accessToken: token)
        #endif
    }
}

// Refuse redirects so the private service token and workout text cannot be
// forwarded to another address. Use an ephemeral session with no cookie/cache store.
private final class ImportSessionDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct WorkoutTextInterpreter: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    let configuration: WorkoutTextServiceConfiguration
    let transport: Transport
    static let maximumResponseBytes = 1_000_000

    init(configuration: WorkoutTextServiceConfiguration, transport: Transport? = nil) {
        self.configuration = configuration
        self.transport = transport ?? Self.send
    }

    private static func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 40
        config.timeoutIntervalForResource = 45
        let session = URLSession(configuration: config, delegate: ImportSessionDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard response.expectedContentLength <= Int64(maximumResponseBytes) else {
            throw WorkoutImportError.invalid("The conversion response was too large. Your source is saved; try a smaller workout.")
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumResponseBytes else {
                throw WorkoutImportError.invalid("The conversion response was too large. Your source is saved; try a smaller workout.")
            }
            data.append(byte)
        }
        return (data, response)
    }

    func interpret(text: String, kind: ImportSourceKind, sourceURL: URL?) async throws -> WorkoutImportResponse {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf16.count <= 12_000,
              [.paste, .shareSheet].contains(kind), sourceURL == nil || sourceURL?.scheme == "https" else {
            throw WorkoutImportError.invalid("Use one workout of up to 12,000 characters. Source links must use HTTPS; links are not fetched.")
        }
        let body: [String: Any] = ["schemaVersion": 1, "text": text, "sourceKind": kind.rawValue,
                                   "sourceURL": sourceURL?.absoluteString as Any? ?? NSNull()]
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        let data: Data
        let response: HTTPURLResponse
        do { (data, response) = try await transport(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch let error as WorkoutImportError { throw error }
        catch {
            throw WorkoutImportError.invalid("Text conversion could not connect. Your source is saved on this iPhone. Try again when connected or import JSON offline.")
        }
        try Task.checkCancellation()
        guard data.count <= Self.maximumResponseBytes else { throw WorkoutImportError.invalid("The conversion response was too large. Try a smaller workout.") }
        guard response.statusCode == 200 else {
            let message: String
            switch response.statusCode {
            case 401, 403: message = "Text conversion access needs to be renewed. JSON import is still available offline."
            case 429: message = "Text conversion is busy or has reached its limit. Wait before retrying, or import JSON offline."
            case 413: message = "The workout text is too large. Try one shorter workout."
            case 422: message = "This text could not be converted into a workout. Check the source or use workout JSON."
            default: message = "Text conversion could not finish. Your source is saved; try again or import JSON offline."
            }
            throw WorkoutImportError.invalid(message)
        }
        guard response.mimeType == "application/json",
              var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let source = object.removeValue(forKey: "source") as? [String: Any],
              Set(source.keys) == ["kind", "originalText", "sourceURL"],
              source["kind"] as? String == kind.rawValue, source["originalText"] as? String == text,
              (sourceURL == nil ? source["sourceURL"] is NSNull : source["sourceURL"] as? String == sourceURL?.absoluteString) else {
            throw WorkoutImportError.invalid("The conversion response did not preserve your source. Nothing was accepted; retry or import JSON.")
        }
        let canonical = try JSONSerialization.data(withJSONObject: object)
        guard let json = String(data: canonical, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        var decoded = try WorkoutJSONImporter.decode(json, allowMultiple: true)
        decoded.source = WorkoutImportSource(kind: kind.rawValue, originalText: text, sourceURL: sourceURL?.absoluteString)
        return decoded
    }
}
