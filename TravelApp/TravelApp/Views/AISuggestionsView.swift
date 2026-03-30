import SwiftUI

struct AISuggestionsView: View {
    let slot: TimeSlot
    let destination: String
    let dayDate: Date
    let existingItineraries: [ItineraryItem]
    let tripId: UUID
    let onAdd: (ItineraryItem) -> Void
    
    @Environment(AISuggestionService.self) private var aiService
    @State private var hasRequested = false
    
    private var suggestions: [AISuggestion] {
        aiService.suggestions[slot.id] ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            
            if aiService.isLoading && suggestions.isEmpty {
                loadingView
            } else if let error = aiService.error, suggestions.isEmpty {
                errorView(error)
            } else if suggestions.isEmpty && !hasRequested {
                requestButton
            } else {
                suggestionCards
            }
        }
    }
    
    // MARK: - Header
    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.purple)
            Text("AI Suggestions")
                .font(.caption.bold())
                .foregroundStyle(.purple)
            Spacer()
            if !suggestions.isEmpty {
                Button {
                    fetchSuggestions()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Request Button
    private var requestButton: some View {
        Button {
            fetchSuggestions()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Get AI Suggestions")
                        .font(.caption.bold())
                    Text("Tap to get activity ideas for this time slot")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.purple.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Loading
    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Finding activities for you...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Error
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't load suggestions")
                .font(.caption.bold())
                .foregroundStyle(.red)
            Text(error)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button("Retry") { fetchSuggestions() }
                .font(.caption.bold())
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Suggestion Cards
    private var suggestionCards: some View {
        VStack(spacing: 8) {
            ForEach(suggestions) { suggestion in
                SuggestionCard(suggestion: suggestion) {
                    acceptSuggestion(suggestion)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func fetchSuggestions() {
        hasRequested = true
        Task {
            await aiService.generateSuggestions(
                for: slot,
                destination: destination,
                existingItineraries: existingItineraries,
                dayDate: dayDate
            )
        }
    }
    
    private func acceptSuggestion(_ suggestion: AISuggestion) {
        let item = aiService.toItineraryItem(
            suggestion,
            date: dayDate,
            startTime: slot.startTime,
            endTime: slot.endTime
        )
        onAdd(item)
        aiService.clearSuggestions(for: slot.id)
    }
}

// MARK: - Suggestion Card
struct SuggestionCard: View {
    let suggestion: AISuggestion
    let onAccept: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: suggestion.category.icon)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(suggestion.category.color)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.title)
                        .font(.caption.bold())
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Label(suggestion.estimatedDuration, systemImage: "clock")
                        Label(suggestion.location, systemImage: "mappin")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: onAccept) {
                    Text("Add")
                        .font(.caption2.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            
            // Expandable details
            if isExpanded {
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                    Text(suggestion.reasoning)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(6)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(.snappy) { isExpanded.toggle() }
        }
    }
}

#Preview {
    VStack {
        let slot = TimeSlot(
            startTime: Date(),
            endTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
            item: nil
        )
        AISuggestionsView(
            slot: slot,
            destination: "Tokyo, Japan",
            dayDate: Date(),
            existingItineraries: [],
            tripId: UUID(),
            onAdd: { _ in }
        )
    }
    .padding()
    .environment(AISuggestionService())
}
