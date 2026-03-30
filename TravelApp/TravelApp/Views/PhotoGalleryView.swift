import SwiftUI
import PhotosUI

struct PhotoGalleryView: View {
    @Environment(DataStore.self) private var store
    @Binding var trip: Trip
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPhoto: TripPhoto?
    @State private var showPhotoDetail = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]
    
    var allPhotos: [TripPhoto] {
        trip.allPhotos
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if allPhotos.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Photos (\(allPhotos.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 20, matching: .images) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            let photo = TripPhoto(imageData: data, addedBy: store.currentUserName)
                            await MainActor.run {
                                store.addPhotoToTrip(photo, tripId: trip.id)
                            }
                        }
                    }
                    await MainActor.run { selectedPhotoItems = [] }
                }
            }
            .onChange(of: store.trips) { _, newTrips in
                if let updated = newTrips.first(where: { $0.id == trip.id }) {
                    trip = updated
                }
            }
            .sheet(isPresented: $showPhotoDetail) {
                if let photo = selectedPhoto {
                    PhotoDetailView(photo: photo, tripId: trip.id)
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 80)
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("No Photos Yet")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            Text("Capture your travel memories!\nAdd photos from your trip.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 20, matching: .images) {
                Label("Add Photos", systemImage: "photo.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }
    
    // MARK: - Photo Grid
    private var photoGrid: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(allPhotos) { photo in
                if let uiImage = UIImage(data: photo.imageData) {
                    Button {
                        selectedPhoto = photo
                        showPhotoDetail = true
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minHeight: 120)
                            .clipped()
                    }
                }
            }
        }
    }
}

// MARK: - Photo Detail View
struct PhotoDetailView: View {
    @Environment(DataStore.self) private var store
    let photo: TripPhoto
    let tripId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.body)
                    }
                    
                    HStack {
                        Label(photo.addedBy, systemImage: "person.circle")
                        Spacer()
                        let formatter = DateFormatter()
                        let _ = formatter.dateStyle = .medium
                        let _ = formatter.timeStyle = .short
                        Text(formatter.string(from: photo.takenDate))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .alert("Delete Photo?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    store.deletePhoto(photo.id, from: tripId)
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    PhotoGalleryView(trip: .constant(DataStore().trips.first ?? Trip(name: "Test", destination: "Test")))
        .environment(DataStore())
}
