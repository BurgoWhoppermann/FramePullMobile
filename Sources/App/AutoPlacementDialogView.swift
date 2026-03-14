import SwiftUI
import AVFoundation

struct AutoPlacementConfig {
    var numberOfStills: Int = 10
    var numberOfClips: Int = 5
    var targetClipDuration: Double = 3.0
}

struct AutoPlacementDialogView: View {
    @Environment(\.dismiss) var dismiss
    @State private var config = AutoPlacementConfig()
    @ObservedObject var playerModel: PlayerModel
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Auto-Placement Setup")) {
                    Stepper("Number of Stills: \(config.numberOfStills)", value: $config.numberOfStills, in: 0...50)
                    Stepper("Number of Clips: \(config.numberOfClips)", value: $config.numberOfClips, in: 0...20)
                    
                    VStack(alignment: .leading) {
                        Text("Target Clip Duration: \(String(format: "%.1f", config.targetClipDuration)) sec")
                        Slider(value: $config.targetClipDuration, in: 1.0...10.0, step: 0.5)
                    }
                }
                
                Section(footer: Text("Auto-placement will evenly distribute markers across the video. Clips will attempt to snap to detected scene cuts where possible.")) {
                    Button(action: applyAutoPlacement) {
                        Text("Generate Markers")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .bold()
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Auto Magic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func applyAutoPlacement() {
        let duration = playerModel.duration
        guard duration > 0 else { return }
        
        // 1. Generate Stills (evenly distributed)
        var newStills: [MarkedStill] = []
        if config.numberOfStills > 0 {
            let interval = duration / Double(config.numberOfStills + 1)
            for i in 1...config.numberOfStills {
                let timestamp = interval * Double(i)
                newStills.append(MarkedStill(timestamp: timestamp, isManual: false))
            }
        }
        
        // 2. Generate Clips (attempting to use scene cuts)
        var newClips: [MarkedClip] = []
        if config.numberOfClips > 0 {
            // Very simple approach first: Even distribution
            // Then adjust to closest scene cut if it's within a window
            
            let clipInterval = duration / Double(config.numberOfClips + 1)
            let cuts = playerModel.sceneCuts
            
            for i in 1...config.numberOfClips {
                let targetCenter = clipInterval * Double(i)
                var bestStart = targetCenter - (config.targetClipDuration / 2.0)
                
                // See if there's a scene cut nearby (e.g. within 5 seconds) to snap the start point to
                if let closestCut = cuts.min(by: { abs($0 - bestStart) < abs($1 - bestStart) }) {
                    if abs(closestCut - bestStart) < 5.0 {
                        bestStart = closestCut
                    }
                }
                
                // Ensure boundaries
                bestStart = max(0, min(bestStart, duration - config.targetClipDuration))
                let end = bestStart + config.targetClipDuration
                
                newClips.append(MarkedClip(inPoint: bestStart, outPoint: end, isManual: false))
            }
        }
        
        // Apply instantly
        playerModel.stills.append(contentsOf: newStills)
        playerModel.clips.append(contentsOf: newClips)
        
        dismiss()
    }
}
