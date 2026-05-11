import SwiftUI
import UserNotifications

struct AnalyzePatientView: View {
    enum TestState { case initial, testing, complete }
    @State private var state: TestState = .initial
    @State private var newAnalysisId: String?
    @State private var notes = ""
    @State private var errorText: String?
    @StateObject private var svc = FirestoreService()

    let patient: PatientRecord

    var body: some View {
        VStack(spacing: 0) {
            Text("Analysis for: \(patient.name)")
                .font(.title3.bold())
                .padding(.top, 8)

            Spacer(minLength: 4)

            Group {
                switch state {
                case .initial:
                    VStack(spacing: 12) {
                        Text("Prepare for Analysis").font(.title2.bold())
                        Text("Ensure the LFA strip is positioned. Add any technician notes. The run takes ~30 minutes.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        TextField("Technician notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(10)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                        Button {
                            Task { await startTest() }
                        } label: {
                            Label("Click here to start test", systemImage: "play.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                case .testing:
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.2)
                        Text("Analysis in progress…").font(.title3.bold)
                        Text("Please wait. You’ll be notified when it’s complete.")
                            .foregroundStyle(.secondary)
                    }

                case .complete:
                    VStack(spacing: 16) {
                        Text("Analysis Complete!").font(.title2.bold())
                        if let id = newAnalysisId, let pid = patient.id {
                            NavigationLink("View Results", destination: ResultDetailView(patientId: pid, analysisId: id))
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 8, y: 3)
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)

            if let e = errorText {
                Text(e).foregroundStyle(.red).padding(.top, 10)
            }

            Spacer()
        }
        .navigationTitle("Start Analysis")
    }

    private func startTest() async {
        guard let pid = patient.id else { return }
        errorText = nil
        state = .testing

        // Ask for local notification permission
        let center = UNUserNotificationCenter.current()
        let _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        do {
            // DEV: short delay (1s) instead of 30 minutes
            try await Task.sleep(nanoseconds: 1_000_000_000)

            // --- mock data to match your web app ---
            let mockConcentration = Double.random(in: 100...2500).rounded(.toNearestOrEven)
            let temps = stride(from: 25.0, through: 60.0, by: 5.0).map { $0 }
            let concByTemp = temps.map { t in
                TempConcPoint(temperature: t,
                              concentration: (100 * exp(0.05 * (t - 25)) + Double.random(in: 0...50)).rounded(.toNearestOrEven))
            }
            let record = AnalysisRecord(
                patientId: pid,
                timestamp: Date(),
                eColiConcentration: mockConcentration,
                temperatureValues: temps,
                deltaT: Double.random(in: 0...15).rounded(.toNearestOrEven),
                concentrationByTemp: concByTemp,
                imageUrl: "https://images.unsplash.com/photo-1595154038355-f717191eaab4?q=80&w=1080",
                graphUrl: "",
                notes: notes.isEmpty ? nil : notes
            )

            let id = try await svc.addAnalysisRecord(for: pid, record: record)
            newAnalysisId = id
            state = .complete

            // Local notification
            let content = UNMutableNotificationContent()
            content.title = "Analysis Complete!"
            content.body = "The test for Patient \(patient.name) is finished."
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            try await UNUserNotificationCenter.current().add(req)

        } catch {
            errorText = "Could not save the test results. Please try again."
            state = .initial
        }
    }
}
