import SwiftUI

// MARK: - Time Slot (scheduled or free)
struct TimeSlot: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let item: ItineraryItem?
    
    var isFree: Bool { item == nil }
    
    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
    var durationText: String {
        let hours = durationMinutes / 60
        let mins = durationMinutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
    }
}

// MARK: - DayWiseView
struct DayWiseView: View {
    @State var trip: Trip
    let tripId: UUID
    @Environment(DataStore.self) private var store
    @State private var selectedDayIndex: Int = 0
    @State private var showAddItinerary = false
    @State private var prefillDate: Date = Date()
    @State private var prefillTime: Date = Date()
    
    private let calendar = Calendar.current
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    
    private var tripDays: [Date] {
        var days: [Date] = []
        var current = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        while current <= end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }
    
    private var selectedDate: Date {
        guard selectedDayIndex < tripDays.count else { return trip.startDate }
        return tripDays[selectedDayIndex]
    }
    
    private func itinerariesForDay(_ day: Date) -> [ItineraryItem] {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        return trip.itineraries.filter { item in
            let itemDay = calendar.startOfDay(for: item.date)
            return itemDay >= dayStart && itemDay < dayEnd
        }
        .sorted { $0.time < $1.time }
    }
    
    private func timeSlotsForDay(_ day: Date) -> [TimeSlot] {
        let items = itinerariesForDay(day)
        guard !items.isEmpty else { return [] }
        
        var slots: [TimeSlot] = []
        let dayStart = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
        let dayEnd = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day)!
        
        var cursor = dayStart
        
        for item in items {
            let itemStart = item.time
            let itemEnd = item.endTime ?? calendar.date(byAdding: .hour, value: 1, to: itemStart)!
            
            let normalizedStart = normalizeTime(itemStart, to: day)
            let normalizedEnd = normalizeTime(itemEnd, to: day)
            
            if normalizedStart > cursor {
                let gap = TimeSlot(startTime: cursor, endTime: normalizedStart, item: nil)
                if gap.durationMinutes >= 15 {
                    slots.append(gap)
                }
            }
            
            slots.append(TimeSlot(startTime: normalizedStart, endTime: normalizedEnd, item: item))
            cursor = normalizedEnd
        }
        
        if cursor < dayEnd {
            let gap = TimeSlot(startTime: cursor, endTime: dayEnd, item: nil)
            if gap.durationMinutes >= 15 {
                slots.append(gap)
            }
        }
        
        return slots
    }
    
    private func normalizeTime(_ time: Date, to day: Date) -> Date {
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: day)!
    }
    
    var body: some View {
        VStack(spacing: 0) {
            dayPicker
            dayContent
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { selectToday() }
        .sheet(isPresented: $showAddItinerary) {
            AddItineraryView(tripId: tripId)
        }
        .onChange(of: store.trips) { _, newTrips in
            if let updated = newTrips.first(where: { $0.id == tripId }) {
                trip = updated
            }
        }
    }
    
    private func openAddItinerary(date: Date, time: Date) {
        prefillDate = date
        prefillTime = time
        showAddItinerary = true
    }
    
    // MARK: - Day Picker
    private var dayPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(tripDays.enumerated()), id: \.offset) { index, day in
                        DayChip(
                            day: day,
                            dayNumber: index + 1,
                            isSelected: index == selectedDayIndex,
                            hasItems: !itinerariesForDay(day).isEmpty
                        ) {
                            withAnimation(.snappy) { selectedDayIndex = index }
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .onChange(of: selectedDayIndex) { _, newVal in
                withAnimation { proxy.scrollTo(newVal, anchor: .center) }
            }
        }
    }
    
    // MARK: - Day Content
    private var dayContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                dayHeader
                
                let slots = timeSlotsForDay(selectedDate)
                let items = itinerariesForDay(selectedDate)
                
                if items.isEmpty {
                    emptyDayContent
                } else {
                    daySummaryBar(items: items, slots: slots)
                    timelineView(slots: slots)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Day Header
    private var dayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                let dayFormatter = DateFormatter()
                let _ = dayFormatter.dateFormat = "EEEE"
                Text(dayFormatter.string(from: selectedDate))
                    .font(.title2.bold())
                
                let fullFormatter = DateFormatter()
                let _ = fullFormatter.dateFormat = "MMMM d, yyyy"
                Text(fullFormatter.string(from: selectedDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Day \(selectedDayIndex + 1)")
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        }
        .padding()
    }
    
    // MARK: - Summary Bar
    private func daySummaryBar(items: [ItineraryItem], slots: [TimeSlot]) -> some View {
        let scheduledMinutes = slots.filter { !$0.isFree }.reduce(0) { $0 + $1.durationMinutes }
        let freeMinutes = slots.filter { $0.isFree }.reduce(0) { $0 + $1.durationMinutes }
        let freeSlotCount = slots.filter { $0.isFree }.count
        
        return HStack(spacing: 16) {
            SummaryPill(icon: "list.bullet", value: "\(items.count)", label: "Activities", color: .blue)
            SummaryPill(icon: "clock.fill", value: formatMinutes(scheduledMinutes), label: "Scheduled", color: .orange)
            SummaryPill(icon: "clock.badge.checkmark", value: formatMinutes(freeMinutes), label: "Free", color: .green)
            SummaryPill(icon: "sparkles", value: "\(freeSlotCount)", label: "Gaps", color: .purple)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    // MARK: - Empty Day
    private var emptyDayContent: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "sun.max")
                .font(.system(size: 50))
                .foregroundStyle(.orange.opacity(0.5))
            Text("Free Day!")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            Text("Nothing planned for this day.\nPerfect time to explore!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            Button {
                openAddItinerary(date: selectedDate, time: selectedDate)
            } label: {
                Label("Plan Something", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Timeline
    private func timelineView(slots: [TimeSlot]) -> some View {
        VStack(spacing: 0) {
            ForEach(slots) { slot in
                if slot.isFree {
                    FreeSlotRow(slot: slot, timeFormatter: timeFormatter) {
                        openAddItinerary(date: selectedDate, time: slot.startTime)
                    }
                } else if let item = slot.item {
                    ScheduledSlotRow(slot: slot, item: item, timeFormatter: timeFormatter)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    private func selectToday() {
        let today = calendar.startOfDay(for: Date())
        if let index = tripDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: today) }) {
            selectedDayIndex = index
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - Day Chip
struct DayChip: View {
    let day: Date
    let dayNumber: Int
    let isSelected: Bool
    let hasItems: Bool
    let action: () -> Void
    
    private let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    
    private let dayNumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayNameFormatter.string(from: day))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                Text(dayNumFormatter.string(from: day))
                    .font(.title3.bold())
                    .foregroundStyle(isSelected ? .white : .primary)
                
                if hasItems {
                    Circle()
                        .fill(isSelected ? .white : .blue)
                        .frame(width: 5, height: 5)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(width: 50, height: 64)
            .background(isSelected ? .blue : Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Summary Pill
struct SummaryPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Scheduled Slot Row
struct ScheduledSlotRow: View {
    let slot: TimeSlot
    let item: ItineraryItem
    let timeFormatter: DateFormatter
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(spacing: 2) {
                Text(timeFormatter.string(from: slot.startTime))
                    .font(.caption.bold())
                Rectangle()
                    .fill(item.category.color)
                    .frame(width: 3)
                    .frame(minHeight: 30)
                Text(timeFormatter.string(from: slot.endTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)
            
            // Card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.category.icon)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(item.category.color)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    Text(item.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(slot.durationText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if !item.location.isEmpty {
                    Label(item.location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                if !item.peopleJoining.isEmpty {
                    HStack(spacing: -4) {
                        ForEach(item.peopleJoining.prefix(4), id: \.self) { person in
                            Circle()
                                .fill(colorForPerson(person))
                                .frame(width: 18, height: 18)
                                .overlay {
                                    Text(String(person.prefix(1)).uppercased())
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                        }
                        if item.peopleJoining.count > 4 {
                            Text("+\(item.peopleJoining.count - 4)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 6)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.vertical, 4)
    }
    
    private func colorForPerson(_ name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .pink, .teal]
        return colors[abs(name.hashValue) % colors.count]
    }
}

// MARK: - Free Slot Row
struct FreeSlotRow: View {
    let slot: TimeSlot
    let timeFormatter: DateFormatter
    var onTap: () -> Void = {}
    
    var body: some View {
        Button(action: onTap) {
        HStack(alignment: .center, spacing: 12) {
            // Time column
            VStack(spacing: 2) {
                Text(timeFormatter.string(from: slot.startTime))
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text("to")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(timeFormatter.string(from: slot.endTime))
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
            .frame(width: 60)
            
            // Free slot card
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Time")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Text(slot.durationText + " available")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle")
                    .font(.caption)
                    .foregroundStyle(.green.opacity(0.6))
            }
            .padding(10)
            .background(Color.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(.green.opacity(0.3))
            )
        }
        .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let store = DataStore()
    NavigationStack {
        DayWiseView(trip: store.trips.first ?? Trip(name: "Test", destination: "Test"), tripId: store.trips.first?.id ?? UUID())
    }
    .environment(store)
}
