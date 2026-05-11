import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Model
struct Patient: Identifiable, Codable {
    @DocumentID var id: String?
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var createdAt: Date
    var fullName: String { "\(firstName) \(lastName)" }
}

// MARK: - ViewModel
@MainActor
final class PatientsViewModel: ObservableObject {
    @Published var patients: [Patient] = []
    @Published var searchText: String = ""
    @Published var isSaving: Bool = false
    @Published var saveError: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() { listen() }
    deinit { listener?.remove() }

    func listen() {
        listener?.remove()
        listener = db.collection("patients")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error { print("Patients listen error:", error) }
                self.patients = snapshot?.documents.compactMap { try? $0.data(as: Patient.self) } ?? []
            }
    }

    func addPatient(firstName: String, lastName: String, dob: Date) async {
        let f = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !f.isEmpty, !l.isEmpty else {
            saveError = "First and last name are required."
            return
        }
        isSaving = true; saveError = nil
        let new = Patient(firstName: f, lastName: l, dateOfBirth: dob, createdAt: Date())
        do { _ = try db.collection("patients").addDocument(from: new) }
        catch { saveError = "Failed to add patient: \(error.localizedDescription)" }
        isSaving = false
    }

    var filteredPatients: [Patient] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return patients }
        return patients.filter {
            $0.fullName.lowercased().contains(q) ||
            DateFormat.mmddyyyy.string(from: $0.dateOfBirth).contains(q)
        }
    }
}

// MARK: - Patients Page (Adaptive)
struct PatientsListView: View {
    @Environment(\.horizontalSizeClass) private var hSize
    @StateObject private var vm = PatientsViewModel()

    // Add form fields
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var dob: Date = DateComponents(calendar: .current, year: 2000, month: 1, day: 1).date!

    private let maxContentWidth: CGFloat = 800 // cap on large screens

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                addPatientCard
                if hSize == .regular {
                    // WIDE: table look
                    recordsTableCard
                } else {
                    // COMPACT: comfy list
                    recordsListCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Patients")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't Save Patient", isPresented: .constant(vm.saveError != nil), actions: {
            Button("OK", role: .cancel) { vm.saveError = nil }
        }, message: {
            Text(vm.saveError ?? "")
        })
    }

    // MARK: Add Patient Card
    private var addPatientCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Add New Patient")
                        .font(.title3.weight(.semibold))
                }
                Text("Enter the patient's details below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    LabeledField(label: "First Name") {
                        TextField("John", text: $firstName)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledField(label: "Last Name") {
                        TextField("Doe", text: $lastName)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledField(label: "Date of Birth") {
                        if hSize == .regular {
                            DatePicker("", selection: $dob, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        } else {
                            // Friendlier on iPhone
                            DatePicker("DOB", selection: $dob, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                        }
                    }
                }

                Button {
                    Task {
                        await vm.addPatient(firstName: firstName, lastName: lastName, dob: dob)
                        if vm.saveError == nil {
                            firstName = ""; lastName = ""
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isSaving { ProgressView() }
                        Text(vm.isSaving ? "Adding..." : "Add Patient")
                        Image(systemName: "plus.circle")
                    }
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isSaving)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: maxContentWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: Records (Compact = List)
    private var recordsListCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                headerTexts
                SearchBar(text: $vm.searchText, placeholder: "Search patients...")

                if vm.filteredPatients.isEmpty {
                    Text("No patients found.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    // Comfy iPhone list
                    List {
                        ForEach(vm.filteredPatients) { p in
                            NavigationLink {
                                PatientDetailView(patient: p)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.fullName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 12) {
                                        Label(DateFormat.mmddyyyy.string(from: p.dateOfBirth),
                                              systemImage: "calendar")
                                            .labelStyle(.titleAndIcon)
                                            .foregroundStyle(.secondary)
                                        Label(DateFormat.mmddyyyy.string(from: p.createdAt),
                                              systemImage: "clock")
                                            .labelStyle(.titleAndIcon)
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.footnote)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 240, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .frame(maxWidth: maxContentWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: Records (Regular = Table)
    private var recordsTableCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                headerTexts
                SearchBar(text: $vm.searchText, placeholder: "Search patients...")

                TableHeader()
                if vm.filteredPatients.isEmpty {
                    Text("No patients found.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(vm.filteredPatients) { p in
                            PatientRowTable(patient: p)
                            Divider().opacity(0.08)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: maxContentWidth)
        .frame(maxWidth: .infinity)
    }

    private var headerTexts: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Patient Records").font(.title3.weight(.semibold))
            Text("A list of all patients.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Table Row (Regular width)
private struct PatientRowTable: View {
    let patient: Patient
    var body: some View {
        HStack {
            Text(patient.fullName)
                .lineLimit(1)
            Spacer()
            Text(DateFormat.mmddyyyy.string(from: patient.dateOfBirth))
                .frame(width: 120, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(DateFormat.mmddyyyy.string(from: patient.createdAt))
                .frame(width: 120, alignment: .leading)
                .foregroundStyle(.secondary)
            NavigationLink {
                PatientDetailView(patient: patient)
            } label: {
                Text("View Records")
                    .frame(width: 120)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Detail View (shows Name + DOB)
struct PatientDetailView: View {
    let patient: Patient
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(patient.fullName)
                        .font(.title2.weight(.semibold))
                    Text("DOB: " + DateFormat.mmddyyyy.string(from: patient.dateOfBirth))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Card {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("No records found (yet)")
                            .font(.headline)
                        Text("Once tests are run, they will appear here.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 20)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Patient Records")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reusable UI

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

private struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct TableHeader: View {
    var body: some View {
        HStack {
            Text("Name").font(.subheadline.weight(.semibold))
            Spacer()
            Text("Date of Birth").font(.subheadline.weight(.semibold))
                .frame(width: 120, alignment: .leading)
            Text("Date Added").font(.subheadline.weight(.semibold))
                .frame(width: 120, alignment: .leading)
            Text(" ").frame(width: 120) // action column space
        }
        .padding(.vertical, 6)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.black.opacity(0.08)),
            alignment: .bottom
        )
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
            )
    }
}

enum DateFormat {
    static let mmddyyyy: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM/dd/yyyy"
        return df
    }()
}
