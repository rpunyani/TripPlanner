import SwiftUI
import PhotosUI

struct ItineraryDetailView: View {
    @Environment(DataStore.self) private var store
    @State var item: ItineraryItem
    let tripId: UUID
    @State private var showEditSheet = false
    @State private var showAddPhoto = false
    @State private var showDeleteAlert = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        mainScrollView
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showEditSheet) {
                AddItineraryView(tripId: tripId, editingItem: item)
            }
            .alert("Delete Itinerary?", isPresented: $showDeleteAlert) {
                deleteAlertButtons
            }
            .onChange(of: store.trips) { _, newTrips in
                handleTripsChange(newTrips)
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                handlePhotoSelection(newItems)
            }
    }
    
    private var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerImage
                contentSection
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showEditSheet = true } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    @ViewBuilder
    private var deleteAlertButtons: some View {
        Button("Cancel", role: .cancel) {}
        Button("Delete", role: .destructive) {
            store.deleteItinerary(item.id, from: tripId)
            dismiss()
        }
    }
    
    private func handleTripsChange(_ newTrips: [Trip]) {
        if let trip = newTrips.first(where: { $0.id == tripId }),
           let updated = trip.itineraries.first(where: { $0.id == item.id }) {
            item = updated
        }
    }
    
    private func handlePhotoSelection(_ newItems: [PhotosPickerItem]) {
        Task {
            for photoItem in newItems {
                if let data = try? await photoItem.loadTransferable(type: Data.self) {
                    let photo = TripPhoto(imageData: data, addedBy: store.currentUserName, itineraryId: item.id)
                    await MainActor.run {
                        store.addPhotoToItinerary(photo, itineraryId: item.id, tripId: tripId)
                    }
                }
            }
            await MainActor.run { selectedPhotoItems = [] }
        }
    }
    
    // MARK: - Header Image
    private var headerImage: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 240)
                    .clipped()
            } else {
                ZStack {
                    item.category.color.opacity(0.15)
                    Image(systemName: item.category.icon)
                        .font(.system(size: 60))
                        .foregroundStyle(item.category.color.opacity(0.4))
                }
                .frame(height: 200)
            }
            
            // Category badge
            HStack {
                Spacer()
                Label(item.category.rawValue, systemImage: item.category.icon)
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(item.category.color)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(16)
            }
        }
    }
    
    // MARK: - Content
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            titleSection
            infoCardsSection
            peopleSection
            photosSection
            addedBySection
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.title2.bold())
            
            if !item.description.isEmpty {
                Text(item.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var infoCardsSection: some View {
        VStack(spacing: 12) {
            if !item.location.isEmpty {
                InfoRow(icon: "mappin.circle.fill", title: "Location", value: item.location, color: .red)
            }
            
            InfoRow(icon: "calendar", title: "Date", value: formattedDate, color: .blue)
            InfoRow(icon: "clock.fill", title: "Time", value: formattedTime, color: .orange)
            
            if let ref = item.bookingReference {
                InfoRow(icon: "number", title: "Booking Ref", value: ref, color: .purple)
            }
            
            flightInfoRows
            hotelInfoRows
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var flightInfoRows: some View {
        if let flight = item.flightNumber {
            InfoRow(icon: "airplane", title: "Flight", value: flight, color: .blue)
        }
        if let airline = item.airline {
            InfoRow(icon: "building.2", title: "Airline", value: airline, color: .cyan)
        }
        if let dep = item.departureAirport, let arr = item.arrivalAirport {
            InfoRow(icon: "arrow.right", title: "Route", value: "\(dep) → \(arr)", color: .teal)
        }
    }
    
    @ViewBuilder
    private var hotelInfoRows: some View {
        if let hotel = item.hotelName {
            InfoRow(icon: "building.2.fill", title: "Hotel", value: hotel, color: .purple)
        }
        if let checkIn = item.checkInDate, let checkOut = item.checkOutDate {
            InfoRow(icon: "bed.double.fill", title: "Stay", value: formattedStay(checkIn: checkIn, checkOut: checkOut), color: .indigo)
        }
    }
    
    @ViewBuilder
    private var peopleSection: some View {
        if !item.peopleJoining.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("People Joining (\(item.peopleJoining.count))", systemImage: "person.2.fill")
                    .font(.headline)
                
                FlowLayout(spacing: 8) {
                    ForEach(item.peopleJoining, id: \.self) { person in
                        PersonChip(name: person, color: colorForPerson(person))
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Photos (\(item.photos.count))", systemImage: "photo.on.rectangle")
                    .font(.headline)
                
                Spacer()
                
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline.bold())
                }
            }
            
            if item.photos.isEmpty {
                photosEmptyState
            } else {
                photosScroller
            }
        }
        .padding(.horizontal)
    }
    
    private var photosEmptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.title)
                    .foregroundStyle(.tertiary)
                Text("No photos yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
    
    private var photosScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(item.photos) { photo in
                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
    
    private var addedBySection: some View {
        HStack {
            Text("Added by \(item.addedBy)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    // MARK: - Helpers
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        var text = formatter.string(from: item.date)
        if let end = item.endDate {
            text += " - \(formatter.string(from: end))"
        }
        return text
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: item.time)
    }
    
    private func colorForPerson(_ name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .pink, .teal]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
    
    private func formattedStay(checkIn: Date, checkOut: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: checkIn)) - \(formatter.string(from: checkOut))"
    }
}

// MARK: - Person Chip
struct PersonChip: View {
    let name: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            Text(name)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill))
        .clipShape(Capsule())
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        ItineraryDetailView(
            item: ItineraryItem(title: "Test Flight", description: "A sample flight", category: .flight, location: "SFO"),
            tripId: UUID()
        )
    }
    .environment(DataStore())
}
