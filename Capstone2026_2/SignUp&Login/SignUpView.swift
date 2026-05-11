import SwiftUI

struct SignUpView: View {
    @StateObject private var vm = SignUpViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 6) {
                        Text("Create an Account")
                            .font(.title2.bold())
                        Text("Enter your details below to get started.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)

                    // Card
                    VStack(spacing: 14) {
                        // Name row
                        HStack(spacing: 12) {
                            LabeledField(title: "First Name",
                                         placeholder: "Jane",
                                         text: $vm.firstName)
                            LabeledField(title: "Last Name",
                                         placeholder: "Doe",
                                         text: $vm.lastName)
                        }

                        LabeledField(title: "Email",
                                     placeholder: "new.researcher@kameilab.com",
                                     text: $vm.email,
                                     keyboard: .emailAddress)

                        LabeledSecureField(title: "Password",
                                           placeholder: "••••••••",
                                           text: $vm.password)

                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            vm.createAccount()
                        } label: {
                            HStack {
                                if vm.isLoading { ProgressView().padding(.trailing, 6) }
                                Text(vm.isLoading ? "Creating Account..." : "Create Account")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!vm.canSubmit)
                        .padding(.top, 6)

                        // Link to Login
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            NavigationLink("Sign in") {
                                LoginView()
                            }
                            .font(.footnote.weight(.semibold))
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 6, y: 2)
                    )
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Small helpers for consistent fields

private struct LabeledField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct LabeledSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            SecureField(placeholder, text: $text)
                .textContentType(.newPassword)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
