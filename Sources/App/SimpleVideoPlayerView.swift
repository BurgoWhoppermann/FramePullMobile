import SwiftUI
import AVKit
import Photos

struct ErgonomicVideoPlayerView: View {
    let videoURL: URL
    let onRemove: () -> Void
    @StateObject private var playerModel: PlayerModel
    @StateObject private var batchProcessor = BatchProcessor()
    
    init(videoURL: URL, onRemove: @escaping () -> Void) {
        self.videoURL = videoURL
        self.onRemove = onRemove
        _playerModel = StateObject(wrappedValue: PlayerModel(url: videoURL))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Unobstructed Custom Video Player with Export overlay
            ZStack {
                CustomVideoPlayer(player: playerModel.player)
                    .ignoresSafeArea(edges: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                
                VStack {
                    HStack(alignment: .top) {
                        // Remove Button Overlay
                        Button(action: onRemove) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .shadow(radius: 4)
                        }
                        .padding(.leading, 20)
                        // .offset removed to let safe area handle it
                        
                        Spacer()
                        
                        // Export Button Overlay
                        let totalItems = playerModel.stills.count + playerModel.clips.count
                        if totalItems > 0 {
                            Button(action: {
                                playerModel.showExportOptions = true
                            }) {
                                HStack(spacing: 6) {
                                    Text("Export")
                                        .bold()
                                    Text("\(totalItems)")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white)
                                        .foregroundColor(.black)
                                        .clipShape(Capsule())
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.framePullBlue)
                                .cornerRadius(20)
                                .shadow(radius: 4)
                            }
                            .padding(.trailing, 20)
                            // .offset removed to let safe area handle it
                        }
                    }
                    .padding(.top, 16) // Spacing below the Navigation Bar
                    Spacer()
                }
            }
            
            // 2. Control & Marking Area
            VStack(spacing: 16) {
                // Top control bar: Timing details
                HStack {
                    Text(formatTime(playerModel.currentTime))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatTime(playerModel.duration))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Ergonomic High-Impact Buttons Row
                HStack(spacing: 12) {
                    MarkButton(title: "IN", color: Color.framePullAmber.opacity(0.8), action: setInPoint)
                    
                    Button(action: snapFrame) {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                            Text("SNAP")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(16)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    
                    MarkButton(title: "OUT", color: Color.framePullAmber.opacity(0.8), action: setOutPoint)
                }
                .padding(.horizontal)
                
                // Auto Magic Button
                Button(action: { playerModel.showAutoPlacementMode = true }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Auto Magic")
                            .bold()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(gradient: Gradient(colors: [.purple, .indigo]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Fast thumb-scrubbing timeline
                CustomTimelineView(
                    currentTime: $playerModel.currentTime,
                    duration: max(0.1, playerModel.duration),
                    sceneCuts: playerModel.sceneCuts,
                    stills: playerModel.stills,
                    clips: playerModel.clips,
                    onScrub: { isScrubbing in
                        playerModel.isScrubbing = isScrubbing
                    }
                )
                .frame(height: 44) // Thumb-sized height
                .padding(.horizontal)
                
                // Reset Button
                if !playerModel.stills.isEmpty || !playerModel.clips.isEmpty {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        playerModel.stills.removeAll()
                        playerModel.clips.removeAll()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Reset All Markers")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red.opacity(0.8))
                    }
                    .padding(.bottom, 16)
                } else {
                    Spacer().frame(height: 16) // Bottom safe area clearance
                }
            }
            .padding(.top, 16)
            .background(Color(UIColor.systemBackground))
        }
        .onDisappear {
            videoURL.stopAccessingSecurityScopedResource()
            playerModel.player.pause()
            playerModel.sceneDetectorTask?.cancel()
        }
        // Batch processing overlay
        .overlay(
            Group {
                if batchProcessor.isProcessing {
                    ProcessingOverlayView(processor: batchProcessor)
                }
            }
        )
        .alert("Snap Action", isPresented: $playerModel.showFeedback) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(playerModel.feedbackMessage)
        }
        .confirmationDialog("Export \(playerModel.stills.count + playerModel.clips.count) Items", isPresented: $playerModel.showExportOptions, titleVisibility: .visible) {
            Button("Review & Select") {
                playerModel.showReviewMode = true
            }
            Button("Save All to Camera Roll") {
                Task {
                    do {
                        try await batchProcessor.exportItems(
                            stills: playerModel.stills, 
                            clips: playerModel.clips, 
                            from: playerModel.url
                        )
                        await MainActor.run {
                            playerModel.stills.removeAll()
                            playerModel.clips.removeAll()
                        }
                    } catch {
                        playerModel.feedbackMessage = error.localizedDescription
                        playerModel.showFeedback = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $playerModel.showReviewMode) {
            ReviewSelectionView(playerModel: playerModel)
        }
        .sheet(isPresented: $playerModel.showAutoPlacementMode) {
            AutoPlacementDialogView(playerModel: playerModel)
                .presentationDetents([.medium])
        }
    }
    
    private func snapFrame() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let time = playerModel.currentTime
        playerModel.stills.append(MarkedStill(timestamp: time, isManual: true))
        
        // Fast visual feedback instead of pausing to save
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func setInPoint() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        playerModel.pendingInPoint = playerModel.currentTime
    }
    
    private func setOutPoint() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let outPoint = playerModel.currentTime
        if let inPoint = playerModel.pendingInPoint, outPoint > inPoint {
            let newClip = MarkedClip(inPoint: inPoint, outPoint: outPoint, isManual: true)
            playerModel.clips.append(newClip)
            playerModel.pendingInPoint = nil
        } else {
            // Act as "out" point without an in point, maybe default to 3s before
            let calcIn = max(0, outPoint - 3.0)
            playerModel.clips.append(MarkedClip(inPoint: calcIn, outPoint: outPoint, isManual: true))
        }
    }
    
    // extractAndSave has been temporarily removed in favor of the new deferred BatchProcessor workflow
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%1d", mins, secs, ms)
    }
}

// Extract small buttons to keep code clean
struct MarkButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22) // match visual height of snap
                .background(color)
                .cornerRadius(12)
        }
        .buttonStyle(SquishyButtonStyle())
    }
}

// Fun responsive button style
struct SquishyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

@MainActor
class PlayerModel: ObservableObject {
    @Published var currentTime: Double = 0 {
        didSet {
            if isScrubbing {
                let time = CMTime(seconds: currentTime, preferredTimescale: 600)
                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }
    @Published var duration: Double = 0
    @Published var isScrubbing = false
    @Published var isExtracting = false
    @Published var showFeedback = false
    @Published var showExportOptions = false
    @Published var showReviewMode = false
    @Published var showAutoPlacementMode = false
    @Published var feedbackMessage = ""
    
    // Marking state
    @Published var pendingInPoint: Double?
    @Published var clips: [MarkedClip] = []
    @Published var stills: [MarkedStill] = []
    @Published var sceneCuts: [Double] = []
    
    let player: AVPlayer
    private var timeObserverToken: Any?
    let url: URL
    
    var sceneDetectorTask: Task<Void, Never>?
    
    init(url: URL) {
        self.url = url
        let item = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: item)
        
        Task {
            do {
                let duration = try await item.asset.load(.duration)
                await MainActor.run {
                    self.duration = CMTimeGetSeconds(duration)
                }
            } catch {
                print("Failed to load duration.")
            }
        }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                if !self.isScrubbing {
                    self.currentTime = CMTimeGetSeconds(time)
                }
            }
        }
        
        // Automatically start scene detection in the background
        startSceneDetection(url: url)
    }
    
    private func startSceneDetection(url: URL) {
        sceneDetectorTask = Task {
            let detector = SceneDetector()
            do {
                guard let assetURL = url as URL? else { return }
                let asset = AVURLAsset(url: assetURL)
                let cuts = try await detector.detectSceneCuts(from: asset, threshold: 0.35, samplingInterval: 0.1, minimumSceneDuration: 0.15, progress: { _ in })
                
                await MainActor.run {
                    self.sceneCuts = cuts
                }
            } catch {
                print("Scene detection failed silently: \(error)")
            }
        }
    }
    
    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        sceneDetectorTask?.cancel()
    }
}
