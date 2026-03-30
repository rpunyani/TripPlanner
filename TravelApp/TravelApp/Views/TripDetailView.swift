import SwiftUI

struct TripDetailView: View {
    @Environment(DataStore.self) private var store
    @State var trip: Trip
    @State private var selectedCategory: ItineraryCategory? = nil
    @State private var showAddItinerary = false
    @State private var showCollaborators = false
    @State private var showPhotoGallery = false
    @State private var showTripSummary = false
    @State private var showDayWise = false
    @State private var showDeleteAlert = false
    @State private var showEditTrip = false
    @Environment(\.dismiss) private var dismiss
    
    var filteredItineraries: [ItineraryItem] {
        if let cat = selectedCategory {
            return trip.itineraries.filter { $0.category == cat }
        }
        return trip.itineraries
    }
    
    var groupedItineraries: [(ItineraryCategory, [ItineraryItem])] {
        let grouped = Dictionary(grouping: filteredItineraries, by: { $0.category })
        return ItineraryCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items.sorted { $0.date < $1.date })
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                quickActions
                categoryFilter
                itineraryList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showEditTrip = true } label: {
                        Label("Edit Trip", systemImage: "pencil")
                    }
                    Button { showAddItinerary = true } label: {
                        Label("Add Itinerary", systemImage: "plus.circle")
                    }
                    Button { showCollaborators = true } label: {
                        Label("Collaborators", systemImage: "person.2")
                    }
                    Button { showPhotoGallery = true } label: {
                        Label("Photo Gallery", systemImage: "photo.on.rectangle")
                    }
                    Button { showTripSummary = true } label: {
                        Label("Trip Summary", systemImage: "doc.text.image")
                    }
                    Button { showDayWise = true } label: {
                        Label("Day Planner", systemImage: "calendar.day.timeline.leading")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Delete Trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditTrip) {
            AddTripView(editingTrip: trip)
        }
        .sheet(isPresented: $showAddItinerary) {
            AddItineraryView(tripId: trip.id)
        }
        .sheet(isPresented: $showCollaborators) {
            CollaboratorsView(trip: $trip)
        }
        .sheet(isPresented: $showPhotoGallery) {
            PhotoGalleryView(trip: $trip)
        }
        .sheet(isPresented: $showTripSummary) {
            TripSummaryView(trip: trip)
        }
        .sheet(isPresented: $showDayWise) {
            NavigationStack {
                DayWiseView(trip: trip, tripId: trip.id)
                    .navigationTitle("Day Planner")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showDayWise = false }
                        }
                    }
            }
        }
        .alert("Delete Trip?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteTrip(trip)
                dismiss()
            }
        } message: {
            Text("This will permanently delete \"\(trip.name)\" and all its itineraries.")
        }
        .onChange(of: store.trips) { _, newTrips in
            if let updated = newTrips.first(where: { $0.id == trip.id }) {
                trip = updated
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = trip.coverImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [.blue, .purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 220)
                .overlay {
                    Image(systemName: "airplane")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(trip.name)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                HStack(spacing: 16) {
                    Label(trip.destination, systemImage: "mappin.circle.fill")
                    Label(trip.dateRangeText, systemImage: "calendar")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                
                // Collaborator avatars
                if !trip.collaborators.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(trip.collaborators.prefix(5)) { collab in
                            Circle()
                                .fill(collab.avatarColor.color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Text(collab.initials)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                        if trip.collaborators.count > 5 {
                            Circle()
                                .fill(.gray)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Text("+\(trip.collaborators.count - 5)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Quick Actions
    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionButton(title: "Add Itinerary", icon: "plus.circle.fill", color: .blue) {
                    showAddItinerary = true
                }
                QuickActionButton(title: "Collaborators", icon: "person.2.fill", color: .purple) {
                    showCollaborators = true
                }
                QuickActionButton(title: "Photos", icon: "photo.fill", color: .orange) {
                    showPhotoGallery = true
                }
                QuickActionButton(title: "Day Plan", icon: "calendar.day.timeline.leading", color: .teal) {
                    showDayWise = true
                }
                QuickActionButton(title: "Summary", icon: "doc.text.image.fill", color: .green) {
                    showTripSummary = true
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        CategoryFilterView(selectedCategory: $selectedCategory, itineraries: trip.itineraries)
            .padding(.top, 8)
    }
    
    // MARK: - Itinerary List
    private var itineraryList: some View {
        LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
            if groupedItineraries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No itineraries yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Add flights, hotels, tours and more")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 40)
            }
            
            ForEach(groupedItineraries, id: \.0) { category, items in
                Section {
                    ForEach(items) { item in
                        NavigationLink {
                            ItineraryDetailView(item: item, tripId: trip.id)
                        } label: {
                            ItineraryCardView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                        Text(category.rawValue)
                            .font(.headline)
                        Text("(\(items.count))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)
            }
            .frame(width: 80, height: 70)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    NavigationStack {
        TripDetailView(trip: DataStore().trips.first ?? Trip(name: "Test", destination: "Test"))
    }
    .environment(DataStore())
}
