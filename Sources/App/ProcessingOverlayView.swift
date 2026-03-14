import SwiftUI

struct ProcessingOverlayView: View {
    @ObservedObject var processor: BatchProcessor
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(processor.statusMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if processor.progress > 0 {
                    ProgressView(value: processor.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding(.horizontal, 40)
                    
                    Text("\(Int(processor.progress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(30)
            .background(Color(UIColor.secondarySystemBackground).opacity(0.2))
            .cornerRadius(16)
        }
    }
}
