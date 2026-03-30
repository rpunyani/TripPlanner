import Foundation
import SwiftUI

// MARK: - AI Suggestion
struct AISuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let category: ItineraryCategory
    let estimatedDuration: String
    let location: String
    let reasoning: String
}

// MARK: - AI Suggestion Service
@Observable
class AISuggestionService {
    var isLoading = false
    var suggestions: [UUID: [AISuggestion]] = [:] // keyed by TimeSlot id
    var error: String?
    
    // Set this to enable OpenAI-powered suggestions
    var openAIAPIKey: String = ""
    
    var isOpenAIEnabled: Bool {
        !openAIAPIKey.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Generate Suggestions
    func generateSuggestions(
        for slot: TimeSlot,
        destination: String,
        existingItineraries: [ItineraryItem],
        dayDate: Date
    ) async {
        await MainActor.run { isLoading = true; error = nil }
        
        do {
            let results: [AISuggestion]
            if isOpenAIEnabled {
                results = try await fetchOpenAISuggestions(
                    slot: slot,
                    destination: destination,
                    existingItineraries: existingItineraries,
                    dayDate: dayDate
                )
            } else {
                results = generateLocalSuggestions(
                    slot: slot,
                    destination: destination,
                    existingItineraries: existingItineraries,
                    dayDate: dayDate
                )
            }
            await MainActor.run {
                suggestions[slot.id] = results
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func clearSuggestions(for slotId: UUID) {
        suggestions.removeValue(forKey: slotId)
    }
    
    // MARK: - Convert Suggestion to ItineraryItem
    func toItineraryItem(
        _ suggestion: AISuggestion,
        date: Date,
        startTime: Date,
        endTime: Date
    ) -> ItineraryItem {
        ItineraryItem(
            title: suggestion.title,
            description: suggestion.description,
            category: suggestion.category,
            date: date,
            time: startTime,
            endTime: endTime,
            location: suggestion.location
        )
    }
    
    // MARK: - OpenAI Integration
    private func fetchOpenAISuggestions(
        slot: TimeSlot,
        destination: String,
        existingItineraries: [ItineraryItem],
        dayDate: Date
    ) async throws -> [AISuggestion] {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        
        let existingNames = existingItineraries.map { "- \($0.title) (\($0.category.rawValue)) at \($0.location)" }.joined(separator: "\n")
        
        let prompt = """
        You are a travel activity planner. Suggest 3 activities for a traveler visiting \(destination) on \(dateFormatter.string(from: dayDate)).
        
        They have a free time slot from \(timeFormatter.string(from: slot.startTime)) to \(timeFormatter.string(from: slot.endTime)) (\(slot.durationText)).
        
        Their existing plans for the day:
        \(existingNames.isEmpty ? "None yet" : existingNames)
        
        For each suggestion provide a JSON array with objects containing:
        - "title": short activity name
        - "description": 1-2 sentence description
        - "category": one of "City Tour", "Activity", "Dining", "Transport"
        - "estimatedDuration": e.g. "1h 30m"
        - "location": specific location in \(destination)
        - "reasoning": why this is a good fit for this time slot
        
        Return ONLY the JSON array, no other text.
        """
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a helpful travel activity planner. Always respond with valid JSON only."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.8,
            "max_tokens": 800
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String ?? "[]"
        
        return parseOpenAIResponse(content)
    }
    
    private func parseOpenAIResponse(_ content: String) -> [AISuggestion] {
        // Extract JSON array from response (handle markdown code blocks)
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```") {
            jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard let data = jsonString.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return generateFallbackSuggestions()
        }
        
        return items.compactMap { item in
            guard let title = item["title"],
                  let description = item["description"],
                  let categoryStr = item["category"],
                  let duration = item["estimatedDuration"],
                  let location = item["location"],
                  let reasoning = item["reasoning"] else { return nil }
            
            let category = ItineraryCategory.allCases.first { $0.rawValue == categoryStr } ?? .activity
            
            return AISuggestion(
                title: title,
                description: description,
                category: category,
                estimatedDuration: duration,
                location: location,
                reasoning: reasoning
            )
        }
    }
    
    // MARK: - Smart Local Suggestion Engine
    private func generateLocalSuggestions(
        slot: TimeSlot,
        destination: String,
        existingItineraries: [ItineraryItem],
        dayDate: Date
    ) -> [AISuggestion] {
        let hour = Calendar.current.component(.hour, from: slot.startTime)
        let durationMins = slot.durationMinutes
        let existingCategories = Set(existingItineraries.map { $0.category })
        let existingTitles = Set(existingItineraries.map { $0.title.lowercased() })
        
        var pool: [AISuggestion] = []
        
        // Morning suggestions (7-11)
        if hour >= 7 && hour < 11 {
            pool.append(contentsOf: morningActivities(destination: destination, duration: durationMins))
        }
        
        // Midday (11-14)
        if hour >= 11 && hour < 14 {
            pool.append(contentsOf: middayActivities(destination: destination, duration: durationMins))
        }
        
        // Afternoon (14-17)
        if hour >= 14 && hour < 17 {
            pool.append(contentsOf: afternoonActivities(destination: destination, duration: durationMins))
        }
        
        // Evening (17-21)
        if hour >= 17 && hour < 21 {
            pool.append(contentsOf: eveningActivities(destination: destination, duration: durationMins))
        }
        
        // Late evening (21+)
        if hour >= 21 {
            pool.append(contentsOf: lateEveningActivities(destination: destination, duration: durationMins))
        }
        
        // Always-available activities
        pool.append(contentsOf: flexibleActivities(destination: destination, duration: durationMins))
        
        // Filter out activities similar to existing ones
        pool = pool.filter { suggestion in
            !existingTitles.contains(suggestion.title.lowercased())
        }
        
        // Prefer variety - deprioritize categories already heavily scheduled
        pool.sort { a, b in
            let aExists = existingCategories.contains(a.category)
            let bExists = existingCategories.contains(b.category)
            if aExists != bExists { return !aExists }
            return false
        }
        
        // Simulate a brief delay for realism
        Thread.sleep(forTimeInterval: 0.5)
        
        return Array(pool.prefix(3))
    }
    
    // MARK: - Activity Pools
    private func morningActivities(destination: String, duration: Int) -> [AISuggestion] {
        var activities: [AISuggestion] = []
        
        activities.append(AISuggestion(
            title: "Morning Walking Tour",
            description: "Explore the charming streets of \(destination) before the crowds arrive. Perfect for photography.",
            category: .tour,
            estimatedDuration: duration >= 120 ? "2h" : "1h",
            location: "Historic center, \(destination)",
            reasoning: "Mornings are the best time for walking tours — cooler weather and fewer tourists."
        ))
        
        if duration >= 60 {
            activities.append(AISuggestion(
                title: "Local Breakfast Spot",
                description: "Start the day with an authentic local breakfast experience at a popular neighborhood cafe.",
                category: .dining,
                estimatedDuration: "1h",
                location: "Local district, \(destination)",
                reasoning: "A great way to experience local food culture and fuel up for the day."
            ))
        }
        
        if duration >= 90 {
            activities.append(AISuggestion(
                title: "Morning Temple/Shrine Visit",
                description: "Visit a local temple or cultural site during the peaceful morning hours.",
                category: .tour,
                estimatedDuration: "1h 30m",
                location: "Cultural district, \(destination)",
                reasoning: "Religious and cultural sites are most serene in the morning."
            ))
        }
        
        activities.append(AISuggestion(
            title: "Sunrise Yoga or Park Jog",
            description: "Get energized with morning exercise at a scenic park or waterfront area.",
            category: .activity,
            estimatedDuration: "45m",
            location: "City park, \(destination)",
            reasoning: "Morning exercise helps combat jet lag and energizes you for the day."
        ))
        
        return activities
    }
    
    private func middayActivities(destination: String, duration: Int) -> [AISuggestion] {
        var activities: [AISuggestion] = []
        
        activities.append(AISuggestion(
            title: "Lunch at Local Market",
            description: "Explore a bustling local food market and sample street food favorites of \(destination).",
            category: .dining,
            estimatedDuration: duration >= 90 ? "1h 30m" : "1h",
            location: "Central market, \(destination)",
            reasoning: "Midday is prime time for food markets — freshest ingredients and peak atmosphere."
        ))
        
        if duration >= 90 {
            activities.append(AISuggestion(
                title: "Museum Visit",
                description: "Escape the midday heat and explore world-class art and history exhibits.",
                category: .activity,
                estimatedDuration: "2h",
                location: "Museum district, \(destination)",
                reasoning: "Museums are ideal midday — air-conditioned and less crowded during lunch hours."
            ))
        }
        
        activities.append(AISuggestion(
            title: "Cafe & People Watching",
            description: "Relax at a charming sidewalk cafe, sip local coffee, and soak in the city vibes.",
            category: .dining,
            estimatedDuration: "45m",
            location: "Popular boulevard, \(destination)",
            reasoning: "A midday break recharges you for the afternoon and lets you absorb the local atmosphere."
        ))
        
        return activities
    }
    
    private func afternoonActivities(destination: String, duration: Int) -> [AISuggestion] {
        var activities: [AISuggestion] = []
        
        if duration >= 120 {
            activities.append(AISuggestion(
                title: "Neighborhood Walking Tour",
                description: "Discover hidden gems, street art, and local boutiques in a vibrant neighborhood.",
                category: .tour,
                estimatedDuration: "2h",
                location: "Trendy district, \(destination)",
                reasoning: "Afternoon light is perfect for exploring neighborhoods and taking photos."
            ))
        }
        
        activities.append(AISuggestion(
            title: "Shopping & Souvenirs",
            description: "Browse local shops for unique crafts, fashion, and souvenirs to bring home.",
            category: .activity,
            estimatedDuration: duration >= 120 ? "2h" : "1h",
            location: "Shopping area, \(destination)",
            reasoning: "Afternoon is great for shopping — stores are fully stocked and less rushed."
        ))
        
        if duration >= 90 {
            activities.append(AISuggestion(
                title: "Cooking Class",
                description: "Learn to make local dishes with a hands-on cooking class led by a local chef.",
                category: .activity,
                estimatedDuration: "2h",
                location: "Culinary school, \(destination)",
                reasoning: "A cooking class is a memorable, interactive way to experience local culture."
            ))
        }
        
        activities.append(AISuggestion(
            title: "Scenic Viewpoint Visit",
            description: "Head to a famous viewpoint for panoramic views of the city and surroundings.",
            category: .tour,
            estimatedDuration: "1h",
            location: "Observation point, \(destination)",
            reasoning: "Afternoon golden light makes for stunning panoramic views and photos."
        ))
        
        return activities
    }
    
    private func eveningActivities(destination: String, duration: Int) -> [AISuggestion] {
        var activities: [AISuggestion] = []
        
        activities.append(AISuggestion(
            title: "Sunset Watching Spot",
            description: "Find the perfect vantage point to watch the sunset paint the sky over \(destination).",
            category: .activity,
            estimatedDuration: "1h",
            location: "Waterfront/hilltop, \(destination)",
            reasoning: "Sunset is a magical time — don't miss it during your trip!"
        ))
        
        if duration >= 90 {
            activities.append(AISuggestion(
                title: "Evening Food Tour",
                description: "Join a guided food tour through the best evening eateries and street food stalls.",
                category: .dining,
                estimatedDuration: "2h",
                location: "Food district, \(destination)",
                reasoning: "Evening food tours let you taste multiple dishes and learn the culinary culture."
            ))
        }
        
        activities.append(AISuggestion(
            title: "Night Market or Bar Hopping",
            description: "Experience the vibrant nightlife — explore a night market or try local cocktails.",
            category: .activity,
            estimatedDuration: duration >= 120 ? "2h" : "1h",
            location: "Entertainment district, \(destination)",
            reasoning: "Evening is when cities truly come alive — embrace the local nightlife scene."
        ))
        
        if duration >= 60 {
            activities.append(AISuggestion(
                title: "Cultural Performance",
                description: "Attend a local cultural show, live music performance, or traditional dance.",
                category: .activity,
                estimatedDuration: "1h 30m",
                location: "Theater district, \(destination)",
                reasoning: "Cultural performances offer a unique insight into local traditions and art."
            ))
        }
        
        return activities
    }
    
    private func lateEveningActivities(destination: String, duration: Int) -> [AISuggestion] {
        return [
            AISuggestion(
                title: "Rooftop Bar & City Lights",
                description: "End the day at a rooftop bar with stunning views of \(destination) lit up at night.",
                category: .dining,
                estimatedDuration: "1h",
                location: "Skyline area, \(destination)",
                reasoning: "A rooftop nightcap is the perfect way to wind down and reflect on the day."
            ),
            AISuggestion(
                title: "Night Photography Walk",
                description: "Capture the city's beauty after dark — illuminated landmarks, neon streets, and city life.",
                category: .activity,
                estimatedDuration: "1h",
                location: "City center, \(destination)",
                reasoning: "Night photography reveals a completely different side of the city."
            )
        ]
    }
    
    private func flexibleActivities(destination: String, duration: Int) -> [AISuggestion] {
        var activities: [AISuggestion] = []
        
        if duration >= 30 && duration < 90 {
            activities.append(AISuggestion(
                title: "Quick Coffee Break",
                description: "Recharge at a top-rated local coffee shop between activities.",
                category: .dining,
                estimatedDuration: "30m",
                location: "Nearby cafe, \(destination)",
                reasoning: "Short breaks keep your energy up — fits perfectly in this gap."
            ))
        }
        
        if duration >= 60 {
            activities.append(AISuggestion(
                title: "Local Park & Gardens",
                description: "Stroll through a beautiful park or botanical garden for some fresh air and greenery.",
                category: .activity,
                estimatedDuration: "1h",
                location: "City gardens, \(destination)",
                reasoning: "Parks offer a peaceful break from sightseeing and are great for relaxation."
            ))
        }
        
        return activities
    }
    
    private func generateFallbackSuggestions() -> [AISuggestion] {
        [
            AISuggestion(
                title: "Explore the Area",
                description: "Take a casual walk and discover what's nearby.",
                category: .tour,
                estimatedDuration: "1h",
                location: "Nearby area",
                reasoning: "Sometimes the best experiences come from unplanned exploration."
            ),
            AISuggestion(
                title: "Local Cafe Visit",
                description: "Find a cozy cafe and enjoy the local coffee culture.",
                category: .dining,
                estimatedDuration: "45m",
                location: "Local cafe",
                reasoning: "A perfect way to relax and recharge between activities."
            )
        ]
    }
}
