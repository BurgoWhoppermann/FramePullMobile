import Foundation
import Photos
import UIKit
import AVFoundation

@MainActor
class BatchProcessor: ObservableObject {
    @Published var progress: Double = 0
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = ""
    
    private let coreProcessor = VideoProcessor()
    
    func exportItems(stills: [MarkedStill], clips: [MarkedClip], from url: URL) async throws {
        self.isProcessing = true
        self.progress = 0
        self.statusMessage = "Starting Export..."
        
        defer {
            self.isProcessing = false
        }
        
        // 1. Request photo library permission first
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "FramePull", code: 2, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied. We need write access to save to an album."])
        }
        
        // 2. Get or create "FramePull" Album
        let album = try await getOrCreateFramePullAlbum()
        
        let hasStills = !stills.isEmpty
        let hasClips = !clips.isEmpty
        
        if hasStills {
            self.statusMessage = "Extracting \(stills.count) frames..."
            try await exportStills(stills: stills, from: url, to: album, progressWeight: hasClips ? 0.5 : 1.0)
        }
        
        if hasClips {
            self.statusMessage = "Exporting \(clips.count) video clips..."
            try await exportClips(clips: clips, from: url, to: album, progressOffset: hasStills ? 0.5 : 0.0, progressWeight: hasStills ? 0.5 : 1.0)
        }
        
        self.statusMessage = "Export Complete!"
        self.progress = 1.0
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    // MARK: - Album Management
    
    private func getOrCreateFramePullAlbum() async throws -> PHAssetCollection {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", "FramePull")
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let album = collection.firstObject {
            return album
        }
        
        var placeholderID: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "FramePull")
            placeholderID = request.placeholderForCreatedAssetCollection.localIdentifier
        }
        
        guard let identifier = placeholderID,
              let createdAlbum = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            throw NSError(domain: "FramePull", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create FramePull album."])
        }
        
        return createdAlbum
    }
    
    // MARK: - Stills Export (uses AVAssetImageGenerator directly instead of VideoProcessor to avoid subdirectory issues)
    
    private func exportStills(stills: [MarkedStill], from url: URL, to album: PHAssetCollection, progressWeight: Double) async throws {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let total = Double(stills.count)
        
        for (index, still) in stills.enumerated() {
            let time = CMTime(seconds: still.timestamp, preferredTimescale: 600)
            
            do {
                let (cgImage, _) = try await generator.image(at: time)
                let uiImage = UIImage(cgImage: cgImage)
                
                guard let jpegData = uiImage.jpegData(compressionQuality: 0.95) else { continue }
                
                // Write to temp file
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("frame_\(UUID().uuidString).jpg")
                try jpegData.write(to: tempURL)
                
                // Save to Camera Roll and add to FramePull Album
                try await PHPhotoLibrary.shared().performChanges {
                    let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
                    if let placeholder = assetRequest?.placeholderForCreatedAsset,
                       let albumRequest = PHAssetCollectionChangeRequest(for: album) {
                        albumRequest.addAssets([placeholder] as NSArray)
                    }
                }
                
                try? FileManager.default.removeItem(at: tempURL)
            } catch {
                print("Failed to extract still at \(still.timestamp): \(error)")
            }
            
            self.progress = (Double(index + 1) / total) * progressWeight
            self.statusMessage = "Saved frame \(index + 1) of \(stills.count)"
        }
    }
    
    // MARK: - Clips Export
    
    private func exportClips(clips: [MarkedClip], from url: URL, to album: PHAssetCollection, progressOffset: Double, progressWeight: Double) async throws {
        let asset = AVURLAsset(url: url)
        let total = Double(clips.count)
        
        for (index, clip) in clips.enumerated() {
            self.statusMessage = "Exporting clip \(index + 1) of \(clips.count)..."
            
            let start = CMTime(seconds: clip.inPoint, preferredTimescale: 600)
            let duration = CMTime(seconds: clip.duration, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: start, duration: duration)
            
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("clip_\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: outputURL)
            
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                continue
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.timeRange = timeRange
            
            await exportSession.export()
            
            if exportSession.status == .completed {
                try await PHPhotoLibrary.shared().performChanges {
                    let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                    if let placeholder = assetRequest?.placeholderForCreatedAsset,
                       let albumRequest = PHAssetCollectionChangeRequest(for: album) {
                        albumRequest.addAssets([placeholder] as NSArray)
                    }
                }
            } else if let error = exportSession.error {
                print("Clip export failed: \(error)")
            }
            
            try? FileManager.default.removeItem(at: outputURL)
            self.progress = progressOffset + ((Double(index + 1) / total) * progressWeight)
        }
    }
}
