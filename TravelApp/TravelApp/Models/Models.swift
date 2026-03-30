import Foundation
import SwiftUI

// MARK: - Itinerary Category
enum ItineraryCategory: String, CaseIterable, Codable, Identifiable {
    case flight = "Flight"
    case hotel = "Hotel"
    case tour = "City Tour"
    case activity = "Activity"
    case transport = "Transport"
    case dining = "Dining"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "building.2"
        case .tour: return "map"
        case .activity: return "figure.walk"
        case .transport: return "car"
        case .dining: return "fork.knife"
        }
    }
    
    var color: Color {
        switch self {
        case .flight: return .blue
        case .hotel: return .purple
        case .tour: return .orange
        case .activity: return .green
        case .transport: return .cyan
        case .dining: return .red
        }
    }
}

// MARK: - Collaborator
struct Collaborator: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var email: String
    var avatarColor: CodableColor
    var joinedDate: Date
    
    init(id: UUID = UUID(), name: String, email: String, avatarColor: CodableColor = CodableColor(.blue), joinedDate: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarColor = avatarColor
        self.joinedDate = joinedDate
    }
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Codable Color wrapper
struct CodableColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double
    
    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - Trip Photo
struct TripPhoto: Identifiable, Codable, Equatable {
    var id: UUID
    var imageData: Data
    var imageURL: String?
    var caption: String
    var takenDate: Date
    var addedBy: String
    var itineraryId: UUID?
    
    init(id: UUID = UUID(), imageData: Data, imageURL: String? = nil, caption: String = "", takenDate: Date = Date(), addedBy: String = "Me", itineraryId: UUID? = nil) {
        self.id = id
        self.imageData = imageData
        self.imageURL = imageURL
        self.caption = caption
        self.takenDate = takenDate
        self.addedBy = addedBy
        self.itineraryId = itineraryId
    }
}

// MARK: - Itinerary Item
struct ItineraryItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var description: String
    var category: ItineraryCategory
    var date: Date
    var endDate: Date?
    var time: Date
    var endTime: Date?
    var location: String
    var imageData: Data?
    var imageURL: String?
    var peopleJoining: [String]
    var addedBy: String
    var photos: [TripPhoto]
    
    // Category-specific fields
    var flightNumber: String?
    var airline: String?
    var departureAirport: String?
    var arrivalAirport: String?
    var hotelName: String?
    var checkInDate: Date?
    var checkOutDate: Date?
    var bookingReference: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        category: ItineraryCategory,
        date: Date = Date(),
        endDate: Date? = nil,
        time: Date = Date(),
        endTime: Date? = nil,
        location: String = "",
        imageData: Data? = nil,
        imageURL: String? = nil,
        peopleJoining: [String] = [],
        addedBy: String = "Me",
        photos: [TripPhoto] = [],
        flightNumber: String? = nil,
        airline: String? = nil,
        departureAirport: String? = nil,
        arrivalAirport: String? = nil,
        hotelName: String? = nil,
        checkInDate: Date? = nil,
        checkOutDate: Date? = nil,
        bookingReference: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.date = date
        self.endDate = endDate
        self.time = time
        self.endTime = endTime
        self.location = location
        self.imageData = imageData
        self.imageURL = imageURL
        self.peopleJoining = peopleJoining
        self.addedBy = addedBy
        self.photos = photos
        self.flightNumber = flightNumber
        self.airline = airline
        self.departureAirport = departureAirport
        self.arrivalAirport = arrivalAirport
        self.hotelName = hotelName
        self.checkInDate = checkInDate
        self.checkOutDate = checkOutDate
        self.bookingReference = bookingReference
    }
}

// MARK: - Trip
struct Trip: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var coverImageData: Data?
    var coverImageURL: String?
    var itineraries: [ItineraryItem]
    var collaborators: [Collaborator]
    var photos: [TripPhoto]
    var createdBy: String
    
    init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        coverImageData: Data? = nil,
        coverImageURL: String? = nil,
        itineraries: [ItineraryItem] = [],
        collaborators: [Collaborator] = [],
        photos: [TripPhoto] = [],
        createdBy: String = "Me"
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.coverImageData = coverImageData
        self.coverImageURL = coverImageURL
        self.itineraries = itineraries
        self.collaborators = collaborators
        self.photos = photos
        self.createdBy = createdBy
    }
    
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: startDate)) - \(endFormatter.string(from: endDate))"
    }
    
    var itinerariesByCategory: [ItineraryCategory: [ItineraryItem]] {
        Dictionary(grouping: itineraries, by: { $0.category })
    }
    
    var allPhotos: [TripPhoto] {
        var all = photos
        for item in itineraries {
            all.append(contentsOf: item.photos)
        }
        return all.sorted { $0.takenDate < $1.takenDate }
    }
    
    var uniquePlacesVisited: [String] {
        let places = itineraries.compactMap { $0.location.isEmpty ? nil : $0.location }
        return Array(Set(places)).sorted()
    }
}
