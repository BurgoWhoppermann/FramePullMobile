import SwiftUI
import AVKit
import Photos

// MARK: - Review Item Model

struct ReviewItem: Identifiable {
    let id = UUID()
    let type: ItemType
    
    enum ItemType {
        case still(MarkedStill)
        case clip(MarkedClip)
    }
}

// MARK: - Main Review View (Tinder-style, rebuilt from scratch)

struct ReviewSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var playerModel: PlayerModel
    
    @State private var items: [ReviewItem] = []
    @State private var currentIndex: Int = 0
    @State private var approvedItems: [ReviewItem] = []
    @State private var cardOffset: CGSize = .zero
    @State private var cardRotation: Double = 0
    
    @State private var isAnimating: Bool = false
    @State private var hasStartedExport: Bool = false
    
    @StateObject private var batchProcessor = BatchProcessor()
    
    private var currentItem: ReviewItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            if batchProcessor.isProcessing {
                // Processing overlay
                VStack(spacing: 24) {
                    ProgressView(value: batchProcessor.progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .padding(.horizontal, 40)
                    
                    Text(batchProcessor.statusMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(Int(batchProcessor.progress * 100))%")
                        .font(.title.bold())
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if currentItem != nil {
                // Active review card
                VStack(spacing: 0) {
                    // Top bar
                    topBar
                    
                    Spacer()
                    
                    ZStack {
                        // Render up to 2 cards for the visual stack
                        ForEach(Array(items.enumerated())[currentIndex..<min(items.count, currentIndex + 2)], id: \.element.id) { index, item in
                            let isTopCard = index == currentIndex
                            
                            // The Card
                            cardView(for: item, isTopCard: isTopCard)
                                .id(item.id)
                                .zIndex(isTopCard ? 1.0 : 0.0)
                                .offset(x: isTopCard ? cardOffset.width : 0, 
                                        y: isTopCard ? cardOffset.height * 0.3 : 20)
                                .scaleEffect(isTopCard ? 1.0 : 0.95)
                                .rotationEffect(.degrees(isTopCard ? cardRotation : 0))
                                .animation(isTopCard ? .interactiveSpring(response: 0.3, dampingFraction: 0.7) : .spring(), value: cardOffset)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Apply the gesture to the entire stack container
                    .gesture(swipeGesture)
                    
                    Spacer()
                    
                    // Bottom buttons
                    bottomButtons
                }
            } else if approvedItems.isEmpty {
                // Done reviewing, but kept nothing
                doneEmptyView
            } else {
                // Done reviewing, export in progress (batchProcessor handles the overlay)
                Color.black.ignoresSafeArea()
                    .onAppear {
                        if !hasStartedExport {
                            hasStartedExport = true
                            startExport()
                        }
                    }
            }
        }
        .onAppear {
            prepareQueue()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title3.bold())
                    .foregroundColor(.white.opacity(0.7))
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Progress indicator
            Text("\(currentIndex + 1) / \(items.count)")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            // Approved count
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("\(approvedItems.count)")
            }
            .font(.headline)
            .foregroundColor(.green)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    // MARK: - Card View
    
    @ViewBuilder
    private func cardView(for item: ReviewItem, isTopCard: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemGray6))
            
            // Content
            switch item.type {
            case .still(let still):
                StillCard(timestamp: still.timestamp, videoURL: playerModel.url)
            case .clip(let clip):
                // Optimization: Don't load video players for cards buried in the stack
                if isTopCard {
                    ClipCard(clip: clip, videoURL: playerModel.url)
                } else {
                    ProgressView().tint(.white)
                }
            }
            
            // Swipe overlay stamps
            if isTopCard {
                if cardOffset.width > 30 {
                    VStack {
                        HStack {
                            Text("KEEP")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundColor(.green)
                                .padding(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green, lineWidth: 4)
                                )
                                .rotationEffect(.degrees(-15))
                                .opacity(min(1, Double(cardOffset.width / 100)))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(24)
                }
                
                if cardOffset.width < -30 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("NOPE")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundColor(.red)
                                .padding(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red, lineWidth: 4)
                                )
                                .rotationEffect(.degrees(15))
                                .opacity(min(1, Double(abs(cardOffset.width) / 100)))
                        }
                        Spacer()
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: isTopCard ? 10 : 2)
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isAnimating else { return }
                // Adding a small scale down factor on drag can look nice, but direct tracking is best
                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9)) {
                    cardOffset = value.translation
                    cardRotation = Double(value.translation.width / 20)
                }
            }
            .onEnded { value in
                guard !isAnimating else { return }
                let threshold: CGFloat = 120
                if value.translation.width > threshold {
                    // Swipe right = KEEP
                    approveAndAdvance()
                } else if value.translation.width < -threshold {
                    // Swipe left = NOPE
                    rejectAndAdvance()
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        cardOffset = .zero
                        cardRotation = 0
                    }
                }
            }
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        HStack(spacing: 60) {
            // Reject
            Button(action: {
                guard !isAnimating else { return }
                rejectAndAdvance()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.red)
                    .frame(width: 64, height: 64)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            
            // Approve
            Button(action: {
                guard !isAnimating else { return }
                approveAndAdvance()
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.green)
                    .frame(width: 64, height: 64)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Done Empty View
    
    private var doneEmptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.gray)
            
            Text("Review Complete")
                .font(.title.bold())
                .foregroundColor(.white)
            
            Text("No items were kept.")
                .foregroundColor(.white.opacity(0.6))
            
            Button("Close") { dismiss() }
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
                .padding(.top, 20)
        }
    }
    
    // MARK: - Actions
    
    private func prepareQueue() {
        var queue: [ReviewItem] = []
        queue.append(contentsOf: playerModel.stills.map { .init(type: .still($0)) })
        queue.append(contentsOf: playerModel.clips.map { .init(type: .clip($0)) })
        items = queue
        currentIndex = 0
    }
    
    private func approveAndAdvance() {
        guard let item = currentItem else { return }
        approvedItems.append(item)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        animateOut(direction: 1)
    }
    
    private func rejectAndAdvance() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        animateOut(direction: -1)
    }
    
    private func animateOut(direction: CGFloat) {
        isAnimating = true
        withAnimation(.easeOut(duration: 0.25)) {
            cardOffset = CGSize(width: direction * 500, height: direction * 100)
            cardRotation = Double(direction * 25)
        }
        
        // Wait for the swipe-out animation to finish before snapping to the next item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // Disable animation for the reset
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                cardOffset = .zero
                cardRotation = 0
                currentIndex += 1
                isAnimating = false
            }
        }
    }
    
    private func startExport() {
        let stills = approvedItems.compactMap { item -> MarkedStill? in
            if case .still(let s) = item.type { return s }
            return nil
        }
        let clips = approvedItems.compactMap { item -> MarkedClip? in
            if case .clip(let c) = item.type { return c }
            return nil
        }
        
        Task {
            do {
                try await batchProcessor.exportItems(stills: stills, clips: clips, from: playerModel.url)
                await MainActor.run {
                    playerModel.stills.removeAll()
                    playerModel.clips.removeAll()
                    dismiss()
                }
            } catch {
                print("Batch export failed: \(error)")
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Still Card (shows a single frame thumbnail)

struct StillCard: View {
    let timestamp: Double
    let videoURL: URL
    @State private var image: UIImage?
    @State private var frameNumber: Int?
    
    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .tint(.white)
                    .onAppear { loadFrame() }
            }
            
            // Label
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "camera.fill")
                    if let fNum = frameNumber {
                        Text("Frame \(fNum)")
                    } else {
                        Text(String(format: "%.1fs", timestamp))
                    }
                }
                .font(.subheadline.bold())
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(12)
            }
        }
    }
    
    private func loadFrame() {
        Task {
            let asset = AVAsset(url: videoURL)
            
            // Fetch frame rate to calculate exact frame number
            var frameRate: Float = 30.0
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                frameRate = try await track.load(.nominalFrameRate)
            }
            let fNum = Int(timestamp * Double(frameRate))
            
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            let time = CMTime(seconds: timestamp, preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                await MainActor.run {
                    self.image = UIImage(cgImage: cgImage)
                    self.frameNumber = fNum
                }
            } catch {
                print("Failed to load thumbnail: \(error)")
            }
        }
    }
}

// MARK: - Clip Card (shows a looping video preview)

struct ClipCard: View {
    let clip: MarkedClip
    let videoURL: URL
    
    @State private var looper: AVPlayerLooper?
    @State private var queuePlayer: AVQueuePlayer?
    
    var body: some View {
        ZStack {
            if let player = queuePlayer {
                CustomVideoPlayer(player: player)
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                ProgressView()
                    .tint(.white)
                    .onAppear { setupLooper() }
            }
            
            // Label
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "video.fill")
                    Text(String(format: "Clip %.1fs", clip.duration))
                }
                .font(.subheadline.bold())
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(12)
            }
        }
    }
    
    private func setupLooper() {
        let asset = AVAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        let start = CMTime(seconds: clip.inPoint, preferredTimescale: 600)
        let duration = CMTime(seconds: clip.duration, preferredTimescale: 600)
        let range = CMTimeRange(start: start, duration: duration)
        
        let player = AVQueuePlayer()
        let looper = AVPlayerLooper(player: player, templateItem: item, timeRange: range)
        
        self.looper = looper
        self.queuePlayer = player
    }
}
