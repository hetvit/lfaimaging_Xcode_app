import SwiftUI

struct AutoCaptureView: View {
    @StateObject private var camera = CameraViewModel()

    // Returns the saved local file URL string
    let onCaptured: (String) -> Void
    let onCancel: () -> Void

    @State private var didAutoCapture = false
    @State private var statusText = "Initializing camera…"

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button("Cancel") { onCancel() }
                        .padding(10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                .padding()

                Spacer()

                Text(statusText)
                    .font(.headline)
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 24)
            }
        }
        .task {
            let granted = await camera.requestPermission()
            guard granted else {
                statusText = "Camera permission denied. Enable it in Settings."
                return
            }

            do {
                try camera.configureSession()
                camera.startSession()
                statusText = "Center the test strip… capturing automatically."

                // Auto-capture after a short delay so exposure settles
                try await Task.sleep(nanoseconds: 1_000_000_000)

                if !didAutoCapture {
                    didAutoCapture = true
                    statusText = "Capturing…"

                    let data = try await camera.capturePhoto()
                    let filename = "analysis-photo-\(Int(Date().timeIntervalSince1970)).jpg"
                    let urlString = try camera.saveJPEGToDocuments(data, filename: filename)

                    camera.stopSession()
                    onCaptured(urlString)
                }
            } catch {
                statusText = "Camera error: \(error.localizedDescription)"
            }
        }
        .onDisappear {
            camera.stopSession()
        }
    }
}
