import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

// MARK: - Firebase Service
@Observable
class FirebaseService {
    private var _db: Firestore?
    private var _storage: Storage?
    
    private var db: Firestore {
        if _db == nil { _db = Firestore.firestore() }
        return _db!
    }
    
    private var storage: Storage {
        if _storage == nil { _storage = Storage.storage() }
        return _storage!
    }
    
    var currentUser: User?
    var isSignedIn: Bool = false
    var authError: String?
    var isLoading = false
    
    private var tripsListener: ListenerRegistration?
    private var authListener: AuthStateDidChangeListenerHandle?
    
    /// Call after FirebaseApp.configure()
    func startAuthListener() {
        guard authListener == nil else { return }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isSignedIn = user != nil
        }
    }
    
    deinit {
        if let handle = authListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth
    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        
        // Create user document (store email lowercase for reliable lookup)
        try await db.collection("users").document(result.user.uid).setData([
            "displayName": displayName,
            "email": email.lowercased(),
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        // Auto-resolve: check if any trips have this email as pending collaborator
        try await resolveCollaboratorEmail(email.lowercased(), userId: result.user.uid)
    }
    
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
        // Auto-resolve: when signing in, check if any trips are waiting for this email
        if let uid = Auth.auth().currentUser?.uid {
            try? await resolveCollaboratorEmail(email.lowercased(), userId: uid)
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    // MARK: - Trips CRUD
    func saveTrip(_ trip: Trip) async throws {
        guard let userId = currentUser?.uid else { return }
        
        // Upload images first, get back a trip with URLs populated
        let uploadedTrip = try await uploadTripImages(trip)
        
        var data = tripToDict(uploadedTrip)
        data["ownerId"] = userId
        
        // Check if trip already exists to avoid overwriting collaboratorIds
        let docRef = db.collection("trips").document(trip.id.uuidString)
        let doc = try? await docRef.getDocument()
        
        if doc?.exists == true {
            // Trip exists — don't overwrite collaboratorIds
            data.removeValue(forKey: "collaboratorIds")
            try await docRef.setData(data, merge: true)
        } else {
            // New trip — set owner as first collaborator
            data["collaboratorIds"] = [userId]
            try await docRef.setData(data, merge: true)
        }
    }
    
    func deleteTrip(_ tripId: UUID) async throws {
        // Clean up storage
        let photosRef = storage.reference().child("trips/\(tripId.uuidString)")
        if let result = try? await photosRef.listAll() {
            for item in result.items {
                try? await item.delete()
            }
        }
        try await db.collection("trips").document(tripId.uuidString).delete()
    }
    
    // MARK: - Image Upload
    private func uploadTripImages(_ trip: Trip) async throws -> Trip {
        var updated = trip
        
        // Upload cover image — use a stable path so the URL doesn't change on re-upload
        if let coverData = trip.coverImageData, trip.coverImageURL == nil {
            let ref = storage.reference().child("trips/\(trip.id.uuidString)/photos/cover.jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            let _ = try await ref.putDataAsync(coverData, metadata: metadata)
            let url = try await ref.downloadURL()
            updated.coverImageURL = url.absoluteString
        }
        
        // Upload itinerary images
        for (i, item) in trip.itineraries.enumerated() {
            if let imgData = item.imageData, item.imageURL == nil {
                let url = try await uploadPhoto(imgData, tripId: trip.id, photoId: item.id)
                updated.itineraries[i].imageURL = url
            }
            // Upload itinerary photos
            for (j, photo) in item.photos.enumerated() {
                if photo.imageURL == nil {
                    let url = try await uploadPhoto(photo.imageData, tripId: trip.id, photoId: photo.id)
                    updated.itineraries[i].photos[j].imageURL = url
                }
            }
        }
        
        // Upload trip photos
        for (i, photo) in trip.photos.enumerated() {
            if photo.imageURL == nil {
                let url = try await uploadPhoto(photo.imageData, tripId: trip.id, photoId: photo.id)
                updated.photos[i].imageURL = url
            }
        }
        
        return updated
    }
    
    // MARK: - Image Download
    func downloadMissingImages(for trip: Trip) async -> Trip {
        var updated = trip
        
        // Download cover image
        if updated.coverImageData == nil, let url = updated.coverImageURL {
            updated.coverImageData = try? await downloadPhoto(from: url)
        }
        
        // Download itinerary images
        for (i, item) in updated.itineraries.enumerated() {
            if item.imageData == nil, let url = item.imageURL {
                updated.itineraries[i].imageData = try? await downloadPhoto(from: url)
            }
            for (j, photo) in item.photos.enumerated() {
                if photo.imageData.isEmpty, let url = photo.imageURL {
                    if let data = try? await downloadPhoto(from: url) {
                        updated.itineraries[i].photos[j].imageData = data
                    }
                }
            }
        }
        
        // Download trip photos
        for (i, photo) in updated.photos.enumerated() {
            if photo.imageData.isEmpty, let url = photo.imageURL {
                if let data = try? await downloadPhoto(from: url) {
                    updated.photos[i].imageData = data
                }
            }
        }
        
        return updated
    }
    
    func listenToTrips(onChange: @escaping ([Trip]) -> Void) {
        guard let userId = currentUser?.uid else { return }
        
        tripsListener?.remove()
        tripsListener = db.collection("trips")
            .whereField("collaboratorIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let trips = documents.compactMap { doc -> Trip? in
                    self.dictToTrip(doc.data(), id: doc.documentID)
                }
                onChange(trips.sorted { $0.startDate < $1.startDate })
            }
    }
    
    func stopListening() {
        tripsListener?.remove()
        tripsListener = nil
    }
    
    // MARK: - Collaborators
    func addCollaborator(email: String, to tripId: UUID) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Always store the email on the trip so it can be resolved later
        try await db.collection("trips").document(tripId.uuidString).updateData([
            "collaboratorEmails": FieldValue.arrayUnion([normalizedEmail])
        ])
        
        // Try to look up user by email and add their UID now
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: normalizedEmail)
            .getDocuments()
        
        if let userDoc = snapshot.documents.first {
            let collaboratorId = userDoc.documentID
            let displayName = userDoc.data()["displayName"] as? String ?? email
            
            // Add Firebase UID to collaboratorIds for query access
            try await db.collection("trips").document(tripId.uuidString).updateData([
                "collaboratorIds": FieldValue.arrayUnion([collaboratorId])
            ])
            
            // Add collaborator info subcollection
            try await db.collection("trips").document(tripId.uuidString)
                .collection("collaborators").document(collaboratorId).setData([
                    "name": displayName,
                    "email": normalizedEmail,
                    "joinedAt": FieldValue.serverTimestamp()
                ])
        }
        // If user not found, their email is stored in collaboratorEmails.
        // When they sign up or sign in, resolveCollaboratorEmail will add their UID.
    }
    
    func removeCollaborator(_ collaboratorId: String, from tripId: UUID) async throws {
        try await db.collection("trips").document(tripId.uuidString).updateData([
            "collaboratorIds": FieldValue.arrayRemove([collaboratorId])
        ])
        try await db.collection("trips").document(tripId.uuidString)
            .collection("collaborators").document(collaboratorId).delete()
    }
    
    func removeCollaboratorByEmail(_ email: String, from tripId: UUID) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Remove email from collaboratorEmails
        try? await db.collection("trips").document(tripId.uuidString).updateData([
            "collaboratorEmails": FieldValue.arrayRemove([normalizedEmail])
        ])
        
        // Remove UID from collaboratorIds
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: normalizedEmail)
            .getDocuments()
        if let userDoc = snapshot.documents.first {
            try await removeCollaborator(userDoc.documentID, from: tripId)
        }
    }
    
    // Auto-resolve: find trips with this email in collaboratorEmails and add the UID
    private func resolveCollaboratorEmail(_ email: String, userId: String) async throws {
        let snapshot = try await db.collection("trips")
            .whereField("collaboratorEmails", arrayContains: email)
            .getDocuments()
        
        for doc in snapshot.documents {
            try await doc.reference.updateData([
                "collaboratorIds": FieldValue.arrayUnion([userId])
            ])
        }
    }
    
    // MARK: - Photo Storage
    func uploadPhoto(_ imageData: Data, tripId: UUID, photoId: UUID) async throws -> String {
        let ref = storage.reference().child("trips/\(tripId.uuidString)/photos/\(photoId.uuidString).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
    
    func deletePhoto(_ photoId: UUID, tripId: UUID) async throws {
        let ref = storage.reference().child("trips/\(tripId.uuidString)/photos/\(photoId.uuidString).jpg")
        try await ref.delete()
    }
    
    func downloadPhoto(from urlString: String) async throws -> Data {
        let ref = storage.reference(forURL: urlString)
        let data = try await ref.data(maxSize: 10 * 1024 * 1024) // 10 MB max
        return data
    }
    
    // MARK: - Invite Link
    func generateInviteLink(for tripId: UUID) -> String {
        return "travelapp://join/\(tripId.uuidString)"
    }
    
    func joinTrip(tripId: UUID) async throws {
        guard let userId = currentUser?.uid,
              let email = currentUser?.email,
              let displayName = currentUser?.displayName else { return }
        
        try await db.collection("trips").document(tripId.uuidString).updateData([
            "collaboratorIds": FieldValue.arrayUnion([userId])
        ])
        
        try await db.collection("trips").document(tripId.uuidString)
            .collection("collaborators").document(userId).setData([
                "name": displayName,
                "email": email,
                "joinedAt": FieldValue.serverTimestamp()
            ])
    }
    
    // MARK: - Converters
    private func tripToDict(_ trip: Trip) -> [String: Any] {
        // Strip raw image bytes but keep URLs for cross-device sync
        var lightTrip = trip
        lightTrip.coverImageData = nil
        lightTrip.itineraries = lightTrip.itineraries.map { item in
            var lightItem = item
            lightItem.imageData = nil
            lightItem.photos = item.photos.map { photo in
                var p = photo
                p.imageData = Data() // empty but keep URL
                return p
            }
            return lightItem
        }
        lightTrip.photos = lightTrip.photos.map { photo in
            var p = photo
            p.imageData = Data() // empty but keep URL
            return p
        }
        
        var dict: [String: Any] = [
            "name": trip.name,
            "destination": trip.destination,
            "startDate": Timestamp(date: trip.startDate),
            "endDate": Timestamp(date: trip.endDate),
            "createdBy": trip.createdBy,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Encode full trip structure as JSON to preserve itineraries & collaborators
        if let jsonData = try? JSONEncoder().encode(lightTrip),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            dict["tripJSON"] = jsonString
        }
        
        return dict
    }
    
    private func dictToTrip(_ data: [String: Any], id: String) -> Trip? {
        // Try JSON decode first (includes itineraries, collaborators, etc.)
        if let jsonString = data["tripJSON"] as? String,
           let jsonData = jsonString.data(using: .utf8),
           let trip = try? JSONDecoder().decode(Trip.self, from: jsonData) {
            return trip
        }
        
        // Fallback: basic fields only (for old documents without tripJSON)
        guard let name = data["name"] as? String,
              let destination = data["destination"] as? String,
              let startTimestamp = data["startDate"] as? Timestamp,
              let endTimestamp = data["endDate"] as? Timestamp else { return nil }
        
        return Trip(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            destination: destination,
            startDate: startTimestamp.dateValue(),
            endDate: endTimestamp.dateValue(),
            createdBy: data["createdBy"] as? String ?? "Unknown"
        )
    }
}
