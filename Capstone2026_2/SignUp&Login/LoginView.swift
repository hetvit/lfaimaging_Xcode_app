import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Darker blue gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.45, blue: 0.85),
                        Color(red: 0.05, green: 0.25, blue: 0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()

                    // Header with IR camera logo
                    VStack(spacing: 10) {
                        Image("ir_lfa_logo") // ensure this PNG exists in Assets.xcassets
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .shadow(radius: 4, y: 2)
                            .accessibilityLabel("IR camera illuminating a lateral flow assay")

                        Text("Welcome to Thermal LFA Pro")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 12)

                    // Login card
                    VStack(spacing: 14) {
                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.subheadline.weight(.semibold))
                            TextField("researcher@kameilab.com", text: $vm.email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.subheadline.weight(.semibold))
                            SecureField("••••••••", text: $vm.password)
                                .textContentType(.password)
                                .submitLabel(.go)
                                .onSubmit { if vm.canSubmit { vm.signIn() } }
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Error text
                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("loginErrorLabel")
                        }

                        // Sign In
                        Button(action: vm.signIn) {
                            HStack {
                                if vm.isLoading { ProgressView().padding(.trailing, 6) }
                                Text(vm.isLoading ? "Signing In..." : "Sign In")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!vm.canSubmit || vm.isLoading)
                        .padding(.top, 6)

                        // Sign Up link
                        HStack(spacing: 4) {
                            Text("Don’t have an account?")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            NavigationLink("Sign up") { SignUpView() }
                                .font(.footnote.weight(.semibold))
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 8, y: 3)
                    )
                    .padding(.horizontal, 20)

                    Spacer()

                    // Footer
                    Text("© UCLA Capstone 2026")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 12)
                }
            }
            // After sign-in: choose patient → analyze
            .navigationDestination(isPresented: $vm.didSignIn) {
                PatientPickerView { selectedPatient in
                    AnalyzePatientView(patient: selectedPatient)  // selectedPatient should be PatientRecord if you renamed
                }
            }
        }
    }
}
