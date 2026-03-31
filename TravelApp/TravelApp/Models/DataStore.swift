import Foundation
import SwiftUI

@Observable
class DataStore {
    var trips: [Trip] = []
    var currentUserName: String = "Me"
    var useFirebase: Bool = false
    var firebaseService: FirebaseService?
    
    private let saveKey = "TravelAppTrips"
    
    init() {
        loadTrips()
    }
    
    // MARK: - Firebase Sync
    func connectFirebase(_ service: FirebaseService) {
        self.firebaseService = service
        self.useFirebase = true
        if let user = service.currentUser {
            currentUserName = user.displayName ?? user.email ?? "Me"
        }
        // Upload any existing local trips to Firestore on first connect
        for trip in trips {
            syncToFirebase(trip)
        }
        service.listenToTrips { [weak self] remoteTrips in
            guard let self else { return }
            var merged: [Trip] = []
            for var remote in remoteTrips {
                if let local = self.trips.first(where: { $0.id == remote.id }) {
                    // Restore local image bytes where remote has none
                    // But NEVER overwrite remote URLs — Firestore is the source of truth for URLs
                    if remote.coverImageData == nil { remote.coverImageData = local.coverImageData }
                    
                    // Merge itinerary data (only restore local bytes, not URLs)
                    remote.itineraries = remote.itineraries.map { var item = $0
                        if let localItem = local.itineraries.first(where: { $0.id == item.id }) {
                            if item.imageData == nil { item.imageData = localItem.imageData }
                            item.photos = item.photos.map { var p = $0
                                if let lp = localItem.photos.first(where: { $0.id == p.id }) {
                                    if p.imageData.isEmpty { p.imageData = lp.imageData }
                                }
                                return p
                            }
                        }
                        return item
                    }
                    // Merge trip photos (only restore local bytes)
                    remote.photos = remote.photos.map { var p = $0
                        if let lp = local.photos.first(where: { $0.id == p.id }) {
                            if p.imageData.isEmpty { p.imageData = lp.imageData }
                        }
                        return p
                    }
                }
                merged.append(remote)
            }
            self.trips = merged
            self.saveTrips()
            
            // Download any images that have URLs but no local data
            self.downloadMissingImages(service: service)
        }
    }
    
    private func downloadMissingImages(service: FirebaseService) {
        for (i, trip) in trips.enumerated() {
            let needsDownload = trip.coverImageData == nil && trip.coverImageURL != nil
                || trip.itineraries.contains(where: { $0.imageData == nil && $0.imageURL != nil })
                || trip.photos.contains(where: { $0.imageData.isEmpty && $0.imageURL != nil })
                || trip.itineraries.contains(where: { $0.photos.contains(where: { $0.imageData.isEmpty && $0.imageURL != nil }) })
            
            if needsDownload {
                let tripIndex = i
                Task {
                    let updated = await service.downloadMissingImages(for: trip)
                    await MainActor.run {
                        if tripIndex < self.trips.count, self.trips[tripIndex].id == updated.id {
                            self.trips[tripIndex] = updated
                            self.saveTrips()
                        }
                    }
                }
            }
        }
    }
    
    func disconnectFirebase() {
        firebaseService?.stopListening()
        firebaseService = nil
        useFirebase = false
        currentUserName = "Me"
        loadTrips()
    }
    
    private func syncToFirebase(_ trip: Trip) {
        guard useFirebase, let service = firebaseService else { return }
        Task {
            try? await service.saveTrip(trip)
            // After upload, URLs are populated on the uploaded trip — update local
            // The Firestore listener will pick up the updated trip with URLs
        }
    }
    
    // MARK: - Persistence
    func saveTrips() {
        if let data = try? JSONEncoder().encode(trips) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    func loadTrips() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Trip].self, from: data) {
            trips = decoded
        }
    }
    
    // MARK: - Trip CRUD
    func addTrip(_ trip: Trip) {
        trips.append(trip)
        saveTrips()
        syncToFirebase(trip)
    }
    
    func updateTrip(_ trip: Trip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            var updated = trip
            // If cover image changed, clear URL so it gets re-uploaded
            if updated.coverImageData != trips[index].coverImageData {
                updated.coverImageURL = nil
            }
            trips[index] = updated
            saveTrips()
            syncToFirebase(trips[index])
        }
    }
    
    func deleteTrip(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        saveTrips()
        if useFirebase, let service = firebaseService {
            Task { try? await service.deleteTrip(trip.id) }
        }
    }
    
    // MARK: - Itinerary CRUD
    func addItinerary(_ item: ItineraryItem, to tripId: UUID) {
        if let index = trips.firstIndex(where: { $0.id == tripId }) {
            trips[index].itineraries.append(item)
            saveTrips()
            syncToFirebase(trips[index])
        }
    }
    
    func updateItinerary(_ item: ItineraryItem, in tripId: UUID) {
        if let tripIndex = trips.firstIndex(where: { $0.id == tripId }),
           let itemIndex = trips[tripIndex].itineraries.firstIndex(where: { $0.id == item.id }) {
            trips[tripIndex].itineraries[itemIndex] = item
            saveTrips()
            syncToFirebase(trips[tripIndex])
        }
    }
    
    func deleteItinerary(_ itemId: UUID, from tripId: UUID) {
        if let tripIndex = trips.firstIndex(where: { $0.id == tripId }) {
            trips[tripIndex].itineraries.removeAll { $0.id == itemId }
            saveTrips()
            syncToFirebase(trips[tripIndex])
        }
    }
    
    // MARK: - Collaborator Management
    func addCollaborator(_ collaborator: Collaborator, to tripId: UUID) {
        if let index = trips.firstIndex(where: { $0.id == tripId }) {
            trips[index].collaborators.append(collaborator)
            saveTrips()
            syncToFirebase(trips[index])
            // Also add their Firebase UID to collaboratorIds so they can see the trip
            if useFirebase, let service = firebaseService, !collaborator.email.isEmpty {
                Task {
                    try? await service.addCollaborator(email: collaborator.email, to: tripId)
                }
            }
        }
    }
    
    func removeCollaborator(_ collaboratorId: UUID, from tripId: UUID) {
        if let index = trips.firstIndex(where: { $0.id == tripId }) {
            let collaborator = trips[index].collaborators.first(where: { $0.id == collaboratorId })
            trips[index].collaborators.removeAll { $0.id == collaboratorId }
            saveTrips()
            syncToFirebase(trips[index])
            // Also remove from Firestore collaboratorIds
            if useFirebase, let service = firebaseService, let email = collaborator?.email, !email.isEmpty {
                Task {
                    try? await service.removeCollaboratorByEmail(email, from: tripId)
                }
            }
        }
    }
    
    // MARK: - Photo Management
    func addPhotoToTrip(_ photo: TripPhoto, tripId: UUID) {
        if let index = trips.firstIndex(where: { $0.id == tripId }) {
            trips[index].photos.append(photo)
            saveTrips()
        }
    }
    
    func addPhotoToItinerary(_ photo: TripPhoto, itineraryId: UUID, tripId: UUID) {
        if let tripIndex = trips.firstIndex(where: { $0.id == tripId }),
           let itemIndex = trips[tripIndex].itineraries.firstIndex(where: { $0.id == itineraryId }) {
            trips[tripIndex].itineraries[itemIndex].photos.append(photo)
            saveTrips()
        }
    }
    
    func deletePhoto(_ photoId: UUID, from tripId: UUID) {
        if let tripIndex = trips.firstIndex(where: { $0.id == tripId }) {
            trips[tripIndex].photos.removeAll { $0.id == photoId }
            for i in trips[tripIndex].itineraries.indices {
                trips[tripIndex].itineraries[i].photos.removeAll { $0.id == photoId }
            }
            saveTrips()
        }
    }
    
    // MARK: - Helper
    func trip(for id: UUID) -> Trip? {
        trips.first { $0.id == id }
    }
    
}
