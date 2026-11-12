import Foundation

struct AppEnvironment: Sendable {
    let apiBaseURL: URL
    let supabaseAnonKey: String?
    let appAttestEnvironment: String
    let usesSimulatedBackend: Bool
    let pinnedCertificateSHA256: Set<String>

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        let configuredURL = info["API_BASE_URL"] as? String
        self.apiBaseURL = configuredURL.flatMap(URL.init(string:)) ?? URLComponents(string: "https://localhost.invalid")?.url ?? URL(fileURLWithPath: "/")
        self.supabaseAnonKey = info["SUPABASE_ANON_KEY"] as? String
        self.appAttestEnvironment = info["APP_ATTEST_ENV"] as? String ?? "development"
        if let flag = info["FOCUSQUEST_SIMULATED_BACKEND"] as? String { self.usesSimulatedBackend = ["YES", "TRUE", "1"].contains(flag.uppercased()) }
        else { self.usesSimulatedBackend = info["FOCUSQUEST_SIMULATED_BACKEND"] as? Bool ?? true }
        self.pinnedCertificateSHA256 = Set((info["PINNED_CERTIFICATE_SHA256"] as? String ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })
    }
}