import SwiftUI

struct TripSummaryView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Trip header
                    summaryHeader
                    
                    // Stats overview
                    statsGrid
                    
                    // Places visited
                    if !trip.uniquePlacesVisited.isEmpty {
                        placesSection
                    }
                    
                    // Itinerary timeline
                    timelineSection
                    
                    // Photo collage
                    if !trip.allPhotos.isEmpty {
                        photoCollageSection
                    }
                    
                    // Collaborators
                    if !trip.collaborators.isEmpty {
                        collaboratorsSection
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trip Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSummaryView(trip: trip)
            }
        }
    }
    
    // MARK: - Summary Header
    private var summaryHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = trip.coverImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 200)
            }
            
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
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
            }
            .padding(20)
        }
    }
    
    // MARK: - Stats Grid
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(value: "\(trip.itineraries.count)", label: "Itineraries", icon: "list.bullet", color: .blue)
            StatCard(value: "\(trip.allPhotos.count)", label: "Photos", icon: "photo", color: .orange)
            StatCard(value: "\(trip.uniquePlacesVisited.count)", label: "Places", icon: "mappin", color: .red)
            StatCard(value: "\(trip.collaborators.count + 1)", label: "Travelers", icon: "person.2", color: .purple)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Places Section
    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Places Visited", icon: "mappin.and.ellipse")
            
            FlowLayout(spacing: 8) {
                ForEach(trip.uniquePlacesVisited, id: \.self) { place in
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text(place)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Timeline
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Itinerary Timeline", icon: "clock.arrow.circlepath")
            
            let sorted = trip.itineraries.sorted { $0.date < $1.date }
            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 14) {
                        // Timeline line
                        VStack(spacing: 0) {
                            Circle()
                                .fill(item.category.color)
                                .frame(width: 12, height: 12)
                            if index < sorted.count - 1 {
                                Rectangle()
                                    .fill(Color(.separator))
                                    .frame(width: 2)
                                    .frame(minHeight: 50)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: item.category.icon)
                                    .font(.caption)
                                    .foregroundStyle(item.category.color)
                                Text(item.title)
                                    .font(.subheadline.bold())
                            }
                            
                            if !item.location.isEmpty {
                                Label(item.location, systemImage: "mappin")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            let dateFormatter = DateFormatter()
                            let _ = dateFormatter.dateFormat = "MMM d, h:mm a"
                            Text(dateFormatter.string(from: item.date))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        if let data = item.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Photo Collage
    private var photoCollageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Photo Memories", icon: "photo.on.rectangle.angled")
            
            CollageView(photos: trip.allPhotos)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Collaborators
    private var collaboratorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Travel Companions", icon: "person.2.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Owner
                    VStack(spacing: 6) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 50, height: 50)
                            .overlay {
                                Text("ME")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "crown.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                    .offset(x: 2, y: 2)
                            }
                        Text(trip.createdBy)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    
                    ForEach(trip.collaborators) { collab in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(collab.avatarColor.color)
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Text(collab.initials)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            Text(collab.name.split(separator: " ").first.map(String.init) ?? collab.name)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal)
    }
}

// MARK: - Share Summary View
struct ShareSummaryView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("Share Trip Summary")
                    .font(.title2.bold())
                
                Text("In a production app, this would render the summary as an image or PDF and present the system share sheet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary includes:")
                        .font(.subheadline.bold())
                    Label("\(trip.uniquePlacesVisited.count) places visited", systemImage: "mappin")
                    Label("\(trip.allPhotos.count) photos", systemImage: "photo")
                    Label("\(trip.itineraries.count) itineraries", systemImage: "list.bullet")
                    Label("\(trip.collaborators.count + 1) travelers", systemImage: "person.2")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 30)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    TripSummaryView(trip: DataStore().trips.first ?? Trip(name: "Test", destination: "Test"))
        .environment(DataStore())
}
