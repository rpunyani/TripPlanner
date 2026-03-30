import SwiftUI
import PhotosUI

struct AddTripView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    var editingTrip: Trip?
    
    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var coverImageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    private var isEditing: Bool { editingTrip != nil }
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destination.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Cover Image
                    ZStack {
                        if let data = coverImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 180)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.largeTitle)
                                        Text("Add Cover Photo")
                                            .font(.subheadline)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .overlay(alignment: .topTrailing) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Image(systemName: "camera.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }
                        .padding(12)
                    }
                }
                
                Section("Trip Details") {
                    TextField("Trip Name", text: $name)
                        .textContentType(.name)
                    
                    TextField("Destination", text: $destination)
                        .textContentType(.addressCity)
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle(isEditing ? "Edit Trip" : "New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        if var existing = editingTrip {
                            existing.name = name.trimmingCharacters(in: .whitespaces)
                            existing.destination = destination.trimmingCharacters(in: .whitespaces)
                            existing.startDate = startDate
                            existing.endDate = endDate
                            existing.coverImageData = coverImageData
                            store.updateTrip(existing)
                        } else {
                            let trip = Trip(
                                name: name.trimmingCharacters(in: .whitespaces),
                                destination: destination.trimmingCharacters(in: .whitespaces),
                                startDate: startDate,
                                endDate: endDate,
                                coverImageData: coverImageData
                            )
                            store.addTrip(trip)
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(!isValid)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run { coverImageData = data }
                    }
                }
            }
            .onAppear {
                if let trip = editingTrip {
                    name = trip.name
                    destination = trip.destination
                    startDate = trip.startDate
                    endDate = trip.endDate
                    coverImageData = trip.coverImageData
                }
            }
        }
    }
}

#Preview {
    AddTripView()
        .environment(DataStore())
}
