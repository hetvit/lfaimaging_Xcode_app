import SwiftUI

struct PatientPickerView: View {
    @StateObject private var svc = FirestoreService()
    @State private var patients: [PatientRecord] = []   // <- renamed
    @State private var query = ""
    @State private var showAdd = false
    @State private var loading = true

    let onSelect: (PatientRecord) -> Void               // <- renamed

    var filtered: [PatientRecord] {                     // <- renamed
        let q = query.lowercased()
        return q.isEmpty ? patients :
        patients.filter { $0.name.lowercased().contains(q) || ($0.email ?? "").lowercased().contains(q) }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(.sRGB, red: 0.15, green: 0.45, blue: 0.85, opacity: 1),
                                    Color(.sRGB, red: 0.05, green: 0.25, blue: 0.55, opacity: 1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack {
                VStack(spacing: 6) {
                    Text("Start Analysis").font(.title2.bold()).foregroundStyle(.white)
                    Text("Choose a patient or add a new one.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                }
                .padding(.vertical, 16)

                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Search by name or email", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    if loading {
                        ProgressView().frame(height: 220)
                    } else {
                        List {
                            ForEach(filtered) { p in
                                Button { onSelect(p) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.name).font(.body.weight(.semibold))
                                            if let email = p.email {
                                                Text(email).font(.footnote).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 320)
                    }

                    HStack {
                        Button { showAdd = true } label: {
                            Label("Add New Patient", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 8, y: 3)
                )
                .padding(.horizontal, 20)

                Spacer()
                Text("© UCLA Capstone 2026")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 12)
            }
        }
        .task {
            do {
                patients = try await svc.fetchPatients()    // returns [PatientRecord]
            } catch {
                patients = []
            }
            loading = false
        }
        .sheet(isPresented: $showAdd, onDismiss: {
            Task {
                loading = true
                patients = (try? await svc.fetchPatients()) ?? []
                loading = false
            }
        }) {
            AddPatientForm(onSave: { name, dob, email in
                Task { _ = try? await svc.addPatient(name: name, dob: dob, email: email) }
            })
            .presentationDetents([.medium, .large])
        }
    }
}

struct AddPatientForm: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (_ name: String, _ dob: Date?, _ email: String?) -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var hasDOB = true
    @State private var dob = Date(timeIntervalSince1970: 915_177_600)

    var body: some View {
        NavigationStack {
            Form {
                Section("Patient Info") {
                    TextField("Full name", text: $name)
                    Toggle("Include date of birth", isOn: $hasDOB)
                    if hasDOB {
                        DatePicker("Date of birth", selection: $dob, displayedComponents: .date)
                    }
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("New Patient")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, hasDOB ? dob : nil, email.isEmpty ? nil : email)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

