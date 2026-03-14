import SwiftUI
import AVFoundation
import PhotosUI

struct ContentView: View {
    @State private var selectedVideoURL: URL?
    @State private var showingVideoPicker = false
    
    // Photo Library Picker State
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isImportingFromPhotos = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if isImportingFromPhotos {
                    ProgressView("Importing from Photos...")
                        .padding()
                } else if let url = selectedVideoURL {
                    ErgonomicVideoPlayerView(videoURL: url, onRemove: {
                        selectedVideoURL = nil
                    })
                        // No padding here so the video can truly ignore safe areas if needed
                } else {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            "No Video Selected",
                            systemImage: "film",
                            description: Text("Select a video to start snapping frames.")
                        )
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "film")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No Video Selected")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Select a video to start snapping frames.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("FramePull Mobile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .videos, photoLibrary: .shared()) {
                            Image(systemName: "photo.on.rectangle")
                        }
                        
                        Button(action: { showingVideoPicker = true }) {
                            Image(systemName: "folder")
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingVideoPicker,
                allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        selectedVideoURL = url
                    } else {
                        selectedVideoURL = url
                    }
                case .failure(let error):
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    guard let item = newItem else { return }
                    isImportingFromPhotos = true
                    defer { isImportingFromPhotos = false }
                    
                    do {
                        // Load the video as an MP4 or QuickTime movie
                        if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
                            self.selectedVideoURL = movie.url
                        }
                    } catch {
                        print("Failed to load video from photos: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// Helper struct to handle moving the video file out of the Photos sandbox
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            // Move from the temporary system location to our app's temp directory
            let tempDir = FileManager.default.temporaryDirectory
            let targetURL = tempDir.appendingPathComponent(received.file.lastPathComponent)
            
            try? FileManager.default.removeItem(at: targetURL)
            try FileManager.default.copyItem(at: received.file, to: targetURL)
            
            return VideoTransferable(url: targetURL)
        }
    }
}
