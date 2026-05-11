import Foundation
import FirebaseAuth

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var didSignIn: Bool = false

    var canSubmit: Bool {
        // basic validation similar to zod rules
        !email.isEmpty && email.contains("@") && password.count >= 6 && !isLoading
    }

    func signIn() {
        errorMessage = nil
        guard canSubmit else { return }
        isLoading = true

        Task {
            do {
                _ = try await Auth.auth().signIn(withEmail: email, password: password)
                didSignIn = true
            } catch {
                errorMessage = humanize(error)
            }
            isLoading = false
        }
    }

    private func humanize(_ error: Error) -> String {
        let ns = error as NSError
        let code = AuthErrorCode.Code(rawValue: ns.code)
        switch code {
        case .wrongPassword: return "Incorrect password."
        case .invalidEmail:  return "Please enter a valid email address."
        case .userNotFound:  return "No account found for this email."
        case .networkError:  return "Network error. Please try again."
        default:             return ns.localizedDescription
        }
    }
}
