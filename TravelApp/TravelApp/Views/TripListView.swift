import SwiftUI

struct TripListView: View {
    @Environment(DataStore.self) private var store
    @Environment(FirebaseService.self) private var firebase
    @State private var showAddTrip = false
    @State private var searchText = ""
    @State private var showSignOutAlert = false
    
    var filteredTrips: [Trip] {
        if searchText.isEmpty {
            return store.trips
        }
        return store.trips.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.destination.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if filteredTrips.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredTrips) { trip in
                            NavigationLink(value: trip.id) {
                                TripCard(trip: trip)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Trips")
            .searchable(text: $searchText, prompt: "Search trips...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSignOutAlert = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTrip = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .alert("Sign Out?", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    store.disconnectFirebase()
                    try? firebase.signOut()
                }
            } message: {
                Text("Your trips are saved and will sync when you sign back in.")
            }
            .sheet(isPresented: $showAddTrip) {
                AddTripView()
            }
            .navigationDestination(for: UUID.self) { tripId in
                if let trip = store.trip(for: tripId) {
                    TripDetailView(trip: trip)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 80)
            Image(systemName: "airplane.circle")
                .font(.system(size: 80))
                .foregroundStyle(.tertiary)
            Text("No Trips Yet")
                .font(.title2.bold())
                .foregroundStyle(.secondary)
            Text("Start planning your next adventure!\nTap + to create your first trip.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button {
                showAddTrip = true
            } label: {
                Label("Create Trip", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

// MARK: - Trip Card
struct TripCard: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover Image
            ZStack(alignment: .bottomLeading) {
                if let data = trip.coverImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "airplane")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(height: 180)
                }
                
                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 90)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(trip.destination)
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
                .padding(16)
            }
            
            // Info bar
            HStack {
                Label(trip.dateRangeText, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Label("\(trip.itineraries.count)", systemImage: "list.bullet")
                    Label("\(trip.collaborators.count + 1)", systemImage: "person.2")
                    Label("\(trip.allPhotos.count)", systemImage: "photo")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

#Preview {
    TripListView()
        .environment(DataStore())
}
