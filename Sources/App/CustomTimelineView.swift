import SwiftUI

/// Ergonomic Thumb-Scrubbing Timeline
struct CustomTimelineView: View {
    @Binding var currentTime: Double
    let duration: Double
    let sceneCuts: [Double]
    let stills: [MarkedStill]
    let clips: [MarkedClip]
    
    var onScrub: (Bool) -> Void // True when starts, false when ends
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)
                
                // Scene Cuts
                ForEach(sceneCuts, id: \.self) { cutTime in
                    let xPos = (cutTime / duration) * width
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 1, height: height)
                        .position(x: xPos, y: height / 2)
                }
                
                // Marked Clips (Green Bars)
                ForEach(clips) { clip in
                    let startX = (clip.inPoint / duration) * width
                    let endX = (clip.outPoint / duration) * width
                    let clipWidth = max(endX - startX, 2)
                    
                    Rectangle()
                        .fill(Color.framePullAmber.opacity(0.7))
                        .frame(width: clipWidth, height: height)
                        .position(x: startX + (clipWidth / 2), y: height / 2)
                        .cornerRadius(2)
                }
                
                // Marked Stills (Orange Dots)
                ForEach(stills) { still in
                    let xPos = (still.timestamp / duration) * width
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .position(x: xPos, y: height / 2)
                }
                
                // Progress Fill
                let progressWidth = width * (currentTime / duration)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.framePullBlue.opacity(0.6))
                    .frame(width: progressWidth.isNaN ? 0 : progressWidth, height: height)
                
                // Playhead Knob
                Circle()
                    .fill(Color.white)
                    .shadow(radius: 2)
                    .frame(width: 24, height: 24)
                    .position(x: progressWidth.isNaN ? 0 : progressWidth, y: height / 2)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onScrub(true)
                        let percent = max(0, min(1, value.location.x / width))
                        currentTime = percent * duration
                    }
                    .onEnded { _ in
                        onScrub(false)
                    }
            )
        }
    }
}
