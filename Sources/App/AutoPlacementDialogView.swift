import SwiftUI
import AVFoundation

struct AutoPlacementConfig {
    var numberOfStills: Int = 10
    var numberOfClips: Int = 5
    var maxCutsPerClip: Int = 2
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
                    
                    Stepper("Clips contain up to \(config.maxCutsPerClip) cuts", value: $config.maxCutsPerClip, in: 1...10)
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
        
        // 2. Generate Clips (incorporating scene cuts and avoiding overlap)
        var newClips: [MarkedClip] = []
        if config.numberOfClips > 0 {
            let cuts = playerModel.sceneCuts.sorted()
            let clipInterval = duration / Double(config.numberOfClips)
            var lastOutPoint: Double = 0.0
            
            for i in 0..<config.numberOfClips {
                let targetStart = clipInterval * Double(i)
                
                // Find nearest cut that is >= lastOutPoint
                var bestStart: Double = max(targetStart, lastOutPoint)
                let validCuts = cuts.filter { $0 >= lastOutPoint }
                
                if let closest = validCuts.min(by: { abs($0 - targetStart) < abs($1 - targetStart) }), closest >= lastOutPoint {
                    bestStart = closest
                }
                
                // Find the out point: `maxCutsPerClip` cuts ahead
                let subsequentCuts = cuts.filter { $0 > bestStart }
                
                var bestEnd: Double
                if subsequentCuts.count >= config.maxCutsPerClip {
                    bestEnd = subsequentCuts[config.maxCutsPerClip - 1]
                } else if let last = subsequentCuts.last {
                    bestEnd = last
                } else {
                    bestEnd = duration
                }
                
                // Set a reasonable fallback duration if no cuts exist to bound it
                if bestEnd - bestStart < 0.5 {
                    bestEnd = min(bestStart + 2.0, duration)
                }
                
                // Ensure no overlap: the loop will update lastOutPoint to bestEnd
                newClips.append(MarkedClip(inPoint: bestStart, outPoint: bestEnd, isManual: false))
                lastOutPoint = bestEnd
            }
        }
        
        // Apply instantly
        playerModel.stills.append(contentsOf: newStills)
        playerModel.clips.append(contentsOf: newClips)
        
        dismiss()
    }
}
