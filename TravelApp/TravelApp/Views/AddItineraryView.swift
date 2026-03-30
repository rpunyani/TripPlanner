import SwiftUI
import PhotosUI

struct AddItineraryView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    let tripId: UUID
    var editingItem: ItineraryItem? = nil
    
    @State private var title = ""
    @State private var description = ""
    @State private var category: ItineraryCategory = .tour
    @State private var date = Date()
    @State private var endDate: Date? = nil
    @State private var time = Date()
    @State private var endTime: Date? = nil
    @State private var hasEndTime = false
    @State private var location = ""
    @State private var imageData: Data?
    @State private var peopleJoiningText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // Flight fields
    @State private var flightNumber = ""
    @State private var airline = ""
    @State private var departureAirport = ""
    @State private var arrivalAirport = ""
    
    // Hotel fields
    @State private var hotelName = ""
    @State private var checkInDate = Date()
    @State private var checkOutDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var bookingReference = ""
    
    @State private var hasEndDate = false
    
    var isEditing: Bool { editingItem != nil }
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Category Picker
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ItineraryCategory.allCases) { cat in
                                CategoryChip(
                                    category: cat,
                                    isSelected: category == cat
                                ) {
                                    withAnimation(.snappy) { category = cat }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Cover image
                Section("Image") {
                    if let data = imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    imageData = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .shadow(radius: 3)
                                }
                                .padding(6)
                            }
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(imageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo.badge.plus")
                    }
                }
                
                // Basic details
                Section("Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Location", text: $location)
                        .textContentType(.addressCity)
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Toggle("Has End Date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? date },
                            set: { endDate = $0 }
                        ), in: date..., displayedComponents: .date)
                    }
                    
                    DatePicker("Start Time", selection: $time, displayedComponents: .hourAndMinute)
                    
                    Toggle("Has End Time", isOn: $hasEndTime)
                    if hasEndTime {
                        DatePicker("End Time", selection: Binding(
                            get: { endTime ?? time },
                            set: { endTime = $0 }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
                
                // Category-specific fields
                switch category {
                case .flight:
                    flightSection
                case .hotel:
                    hotelSection
                default:
                    EmptyView()
                }
                
                // People joining
                Section("People Joining") {
                    TextField("Names (comma separated)", text: $peopleJoiningText)
                    
                    if let trip = store.trip(for: tripId), !trip.collaborators.isEmpty {
                        Text("Tap to add collaborators:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(trip.collaborators) { collab in
                                Button {
                                    toggleCollaborator(collab.name)
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(collab.avatarColor.color)
                                            .frame(width: 20, height: 20)
                                            .overlay {
                                                Text(collab.initials)
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        Text(collab.name)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        peopleList.contains(collab.name)
                                        ? collab.avatarColor.color.opacity(0.2)
                                        : Color(.tertiarySystemFill)
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            peopleList.contains(collab.name)
                                            ? collab.avatarColor.color
                                            : .clear,
                                            lineWidth: 1.5
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Itinerary" : "Add Itinerary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveItinerary()
                    }
                    .bold()
                    .disabled(!isValid)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run { imageData = data }
                    }
                }
            }
            .onAppear {
                if let item = editingItem {
                    populateFields(from: item)
                }
            }
        }
    }
    
    // MARK: - Flight Section
    private var flightSection: some View {
        Section("Flight Details") {
            TextField("Flight Number", text: $flightNumber)
            TextField("Airline", text: $airline)
            TextField("Departure Airport", text: $departureAirport)
            TextField("Arrival Airport", text: $arrivalAirport)
        }
    }
    
    // MARK: - Hotel Section
    private var hotelSection: some View {
        Section("Hotel Details") {
            TextField("Hotel Name", text: $hotelName)
            DatePicker("Check-in", selection: $checkInDate, displayedComponents: .date)
            DatePicker("Check-out", selection: $checkOutDate, in: checkInDate..., displayedComponents: .date)
            TextField("Booking Reference", text: $bookingReference)
        }
    }
    
    // MARK: - Helpers
    private var peopleList: [String] {
        peopleJoiningText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    private func toggleCollaborator(_ name: String) {
        var list = peopleList
        if list.contains(name) {
            list.removeAll { $0 == name }
        } else {
            list.append(name)
        }
        peopleJoiningText = list.joined(separator: ", ")
    }
    
    private func populateFields(from item: ItineraryItem) {
        title = item.title
        description = item.description
        category = item.category
        date = item.date
        endDate = item.endDate
        hasEndDate = item.endDate != nil
        time = item.time
        location = item.location
        imageData = item.imageData
        peopleJoiningText = item.peopleJoining.joined(separator: ", ")
        endTime = item.endTime
        hasEndTime = item.endTime != nil
        flightNumber = item.flightNumber ?? ""
        airline = item.airline ?? ""
        departureAirport = item.departureAirport ?? ""
        arrivalAirport = item.arrivalAirport ?? ""
        hotelName = item.hotelName ?? ""
        checkInDate = item.checkInDate ?? Date()
        checkOutDate = item.checkOutDate ?? Date()
        bookingReference = item.bookingReference ?? ""
    }
    
    private func saveItinerary() {
        var item = editingItem ?? ItineraryItem(
            title: title,
            category: category,
            date: date
        )
        
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.description = description
        item.category = category
        item.date = date
        item.endDate = hasEndDate ? endDate : nil
        item.time = time
        item.endTime = hasEndTime ? endTime : nil
        item.location = location
        item.imageData = imageData
        item.peopleJoining = peopleList
        item.flightNumber = flightNumber.isEmpty ? nil : flightNumber
        item.airline = airline.isEmpty ? nil : airline
        item.departureAirport = departureAirport.isEmpty ? nil : departureAirport
        item.arrivalAirport = arrivalAirport.isEmpty ? nil : arrivalAirport
        item.hotelName = hotelName.isEmpty ? nil : hotelName
        item.checkInDate = category == .hotel ? checkInDate : nil
        item.checkOutDate = category == .hotel ? checkOutDate : nil
        item.bookingReference = bookingReference.isEmpty ? nil : bookingReference
        
        if isEditing {
            store.updateItinerary(item, in: tripId)
        } else {
            store.addItinerary(item, to: tripId)
        }
        dismiss()
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: ItineraryCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? category.color : Color(.tertiarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], sizes: [CGSize], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }
        
        return (positions, sizes, CGSize(width: maxX, height: currentY + lineHeight))
    }
}

#Preview {
    AddItineraryView(tripId: UUID())
        .environment(DataStore())
}
