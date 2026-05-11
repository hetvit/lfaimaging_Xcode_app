import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName  = ""
    @Published var email     = ""
    @Published var password  = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    var canSubmit: Bool {
        // Mirror your zod rules: names non-empty, email has "@", password >= 6
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        !isLoading
    }

    func createAccount() {
        errorMessage = nil
        guard canSubmit else { return }
        isLoading = true

        Task {
            do {
                // 1) Create user
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                let user   = result.user
                let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)

                // 2) Update profile displayName
                let change = user.createProfileChangeRequest()
                change.displayName = displayName
                try await change.commitChanges()

                // 3) Create Firestore user doc
                try await db.collection("users").document(user.uid).setData([
                    "displayName": displayName,
                    "email": user.email ?? email,
                    "createdAt": FieldValue.serverTimestamp()
                ])

                // No manual navigation needed: AuthSession will see user != nil and RootView will show Dashboard
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
        case .emailAlreadyInUse: return "This email is already in use. Please sign in or use a different email."
        case .invalidEmail:      return "Please enter a valid email address."
        case .weakPassword:      return "Password must be at least 6 characters."
        case .networkError:      return "Network error. Please try again."
        default:                 return ns.localizedDescription
        }
    }
}
