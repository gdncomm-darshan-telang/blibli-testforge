import Foundation

/// A Keychain-stored test account (D-044); the server never sends its password or OTP back.
struct TestLogin: Decodable, Equatable, Identifiable {
	let environment: String
	let profile: String
	let email: String
	let hasOtp: Bool

	var id: String { "\(environment)/\(profile)" }

	private enum CodingKeys: String, CodingKey {
		case environment = "env"
		case profile
		case email
		case hasOtp
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		environment = (try? container.decodeIfPresent(String.self, forKey: .environment)) ?? ""
		profile = (try? container.decodeIfPresent(String.self, forKey: .profile)) ?? ""
		email = (try? container.decodeIfPresent(String.self, forKey: .email)) ?? ""
		hasOtp = (try? container.decodeIfPresent(Bool.self, forKey: .hasOtp)) ?? false
	}
}

struct TestLoginList: Decodable {
	let logins: [TestLogin]

	/// Environments whose OTP is fixed and can be stored (UAT B); prod OTPs come by email or a popup.
	let staticOtpEnvironments: [String]

	private enum CodingKeys: String, CodingKey {
		case logins
		case staticOtpEnvironments
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		logins = (try? container.decodeIfPresent([TestLogin].self, forKey: .logins)) ?? []
		staticOtpEnvironments = (try? container.decodeIfPresent([String].self, forKey: .staticOtpEnvironments)) ?? ["uatb"]
	}
}

/// D-048: Outlook sign-in that lets prod runs read their OTP from email.
struct MailOtpStatus: Decodable, Equatable {
	let state: String
	let username: String?
	let sender: String?
	let verificationURL: URL?
	let userCode: String?
	let error: String?

	private enum CodingKeys: String, CodingKey {
		case state
		case username
		case sender
		case verificationURL = "verificationUri"
		case userCode
		case error
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		state = (try? container.decodeIfPresent(String.self, forKey: .state)) ?? "unlinked"
		username = try? container.decodeIfPresent(String.self, forKey: .username)
		sender = try? container.decodeIfPresent(String.self, forKey: .sender)
		verificationURL = (try? container.decodeIfPresent(String.self, forKey: .verificationURL)).flatMap { $0.flatMap(URL.init(string:)) }
		userCode = try? container.decodeIfPresent(String.self, forKey: .userCode)
		error = try? container.decodeIfPresent(String.self, forKey: .error)
	}
}

struct TestLoginDraft: Equatable {
	var environment = "uatb"
	var profile = "internal"
	var email = ""
	var password = ""
	var otp = ""
}

enum LoginsState: Equatable {
	case loading
	case failed(message: String)
	case loaded([TestLogin])
}

enum MailOtpAction: Equatable {
	case link
	case unlink
}

/// D-213: the Outlook button's own progress and last failure.
struct MailOtpProgress: Equatable {
	let busyAction: MailOtpAction?
	let failure: String?
}

/// D-213: a saved login's Remove progress and last failure, drawn on its row.
struct LoginRemovalState: Equatable {
	let isRemoving: Bool
	let failure: String?
}
