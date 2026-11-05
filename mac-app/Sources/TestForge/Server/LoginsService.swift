import Foundation

protocol LoginsManaging {
	func logins() async throws -> TestLoginList
	func save(draft: TestLoginDraft) async throws
	func remove(login: TestLogin) async throws
	func mailOtpStatus() async throws -> MailOtpStatus

	/// Starts Outlook's device-code sign-in; the status then carries the URL and code to enter.
	func linkMailOtp() async throws -> MailOtpStatus

	func unlinkMailOtp() async throws
}

/// `/api/credentials` + `/api/mail-otp` (D-044/D-048): secrets only travel to the server, which keeps them in the Keychain.
struct LoginsService: LoginsManaging {
	private static let keychainTimeout: TimeInterval = 30

	let client: DashboardClient

	func logins() async throws -> TestLoginList {
		let data = try await client.get(path: "api/credentials")
		return try JSONDecoder().decode(TestLoginList.self, from: data)
	}

	func save(draft: TestLoginDraft) async throws {
		var body: [String: JSONValue] = [
			"env": .string(draft.environment),
			"profile": .string(draft.profile),
			"email": .string(draft.email),
			"password": .string(draft.password),
		]
		if !draft.otp.isEmpty {
			body["otp"] = .string(draft.otp)
		}
		try await client.post(path: "api/credentials", json: body, timeout: Self.keychainTimeout)
	}

	func remove(login: TestLogin) async throws {
		try await client.delete(path: "api/credentials/\(login.environment)/\(login.profile)")
	}

	func mailOtpStatus() async throws -> MailOtpStatus {
		let data = try await client.get(path: "api/mail-otp")
		return try JSONDecoder().decode(MailOtpStatus.self, from: data)
	}

	func linkMailOtp() async throws -> MailOtpStatus {
		let data = try await client.post(path: "api/mail-otp/link", timeout: Self.keychainTimeout)
		return try JSONDecoder().decode(MailOtpStatus.self, from: data)
	}

	func unlinkMailOtp() async throws {
		try await client.delete(path: "api/mail-otp/link")
	}
}
