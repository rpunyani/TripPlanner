import SwiftUI

struct CollaboratorsView: View {
    @Environment(DataStore.self) private var store
    @Binding var trip: Trip
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAddCollaborator = false
    @State private var newName = ""
    @State private var newEmail = ""
    @State private var showShareSheet = false
    @State private var collaboratorNote: String?
    
    private let avatarColors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .pink, .teal, .indigo, .mint]
    
    var body: some View {
        NavigationStack {
            List {
                // Owner section
                Section("Trip Owner") {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text("ME")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.createdBy)
                                .font(.body.bold())
                            Text("Owner")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                
                // Collaborators section
                Section {
                    if trip.collaborators.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.title)
                                .foregroundStyle(.tertiary)
                            Text("No collaborators yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Invite friends to view and add itineraries")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(trip.collaborators) { collaborator in
                            CollaboratorRow(collaborator: collaborator)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let collab = trip.collaborators[index]
                                store.removeCollaborator(collab.id, from: trip.id)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Collaborators (\(trip.collaborators.count))")
                        Spacer()
                    }
                }
                
                // Note banner
                if let note = collaboratorNote {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Invite section
                Section("Invite") {
                    Button {
                        showAddCollaborator = true
                    } label: {
                        Label("Add Collaborator", systemImage: "person.badge.plus")
                    }
                    
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share Invite Link", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Add Collaborator", isPresented: $showAddCollaborator) {
                TextField("Name", text: $newName)
                TextField("Email", text: $newEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                Button("Cancel", role: .cancel) {
                    newName = ""
                    newEmail = ""
                }
                Button("Add") {
                    addCollaborator()
                }
            } message: {
                Text("Enter the name and email of the person you'd like to invite.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheetView(tripName: trip.name)
            }
            .onChange(of: store.trips) { _, newTrips in
                if let updated = newTrips.first(where: { $0.id == trip.id }) {
                    trip = updated
                }
            }
        }
    }
    
    private func addCollaborator() {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let email = newEmail.trimmingCharacters(in: .whitespaces)
        let color = avatarColors.randomElement() ?? .blue
        let collaborator = Collaborator(
            name: newName.trimmingCharacters(in: .whitespaces),
            email: email,
            avatarColor: CodableColor(color)
        )
        store.addCollaborator(collaborator, to: trip.id)
        
        if !email.isEmpty {
            collaboratorNote = "\(newName.trimmingCharacters(in: .whitespaces)) will see this trip when they sign in with \(email). They must have a Safar account."
        }
        
        newName = ""
        newEmail = ""
    }
}

// MARK: - Collaborator Row
struct CollaboratorRow: View {
    let collaborator: Collaborator
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(collaborator.avatarColor.color)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(collaborator.initials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(collaborator.name)
                    .font(.body.bold())
                Text(collaborator.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            let formatter = DateFormatter()
            let _ = formatter.dateStyle = .short
            Text("Joined \(formatter.string(from: collaborator.joinedDate))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheetView: View {
    let tripName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("Share Invite Link")
                    .font(.title2.bold())
                
                Text("Share this link with friends to invite them to collaborate on \"\(tripName)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Simulated share link
                HStack {
                    Text("safar://invite/\(tripName.lowercased().replacingOccurrences(of: " ", with: "-"))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                    
                    Button {
                        UIPasteboard.general.string = "safar://invite/\(tripName.lowercased().replacingOccurrences(of: " ", with: "-"))"
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                
                Spacer()
                
                Text("In a production app, this would generate a real invite link using deep linking or a backend service.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding()
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
    CollaboratorsView(trip: .constant(DataStore().trips.first ?? Trip(name: "Test", destination: "Test")))
        .environment(DataStore())
}
