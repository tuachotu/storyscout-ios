import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var accessSession: AccessSession?
    @Published private(set) var isCheckingAccess = false
    @Published var accessError: String?

    private let apiClient: APIClient?

    init(apiClient: APIClient? = try? .configured()) {
        self.apiClient = apiClient
    }

    func continueWithAccessCode(_ accessCode: String) async {
        guard !isCheckingAccess else { return }
        guard let apiClient else {
            accessError = APIClientError.invalidConfiguration.localizedDescription
            return
        }

        isCheckingAccess = true
        accessError = nil
        defer { isCheckingAccess = false }

        do {
            accessSession = try await apiClient.createAccessSession(guid: accessCode)
        } catch {
            accessError = error.localizedDescription
        }
    }

    func clearExpiredSession() {
        accessSession = nil
        accessError = nil
    }
}
