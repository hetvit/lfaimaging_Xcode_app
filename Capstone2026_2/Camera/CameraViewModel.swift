import Foundation
import AVFoundation
import UIKit

@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var lastError: String?

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()

    private var onPhotoCaptured: ((Data) -> Void)?

    func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    cont.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw NSError(domain: "Camera", code: 1, userInfo: [NSLocalizedDescriptionKey: "No back camera found"])
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw NSError(domain: "Camera", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input"])
        }
        session.addInput(input)

        guard session.canAddOutput(output) else {
            throw NSError(domain: "Camera", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot add photo output"])
        }
        session.addOutput(output)

        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else {
            isRunning = true
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            self.onPhotoCaptured = { data in
                cont.resume(returning: data)
            }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    // Save JPEG to Documents and return file URL string
    func saveJPEGToDocuments(_ data: Data, filename: String) throws -> String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic])
        return url.absoluteString
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            lastError = error.localizedDescription
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            lastError = "Could not read photo data."
            return
        }
        onPhotoCaptured?(data)
        onPhotoCaptured = nil
    }
}
