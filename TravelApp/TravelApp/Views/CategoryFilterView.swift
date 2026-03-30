import SwiftUI

struct CategoryFilterView: View {
    @Binding var selectedCategory: ItineraryCategory?
    let itineraries: [ItineraryItem]
    
    private func count(for category: ItineraryCategory) -> Int {
        itineraries.filter { $0.category == category }.count
    }
    
    private var activeCategories: [ItineraryCategory] {
        ItineraryCategory.allCases.filter { count(for: $0) > 0 }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All filter
                FilterChip(
                    label: "All",
                    icon: "square.grid.2x2",
                    count: itineraries.count,
                    color: .gray,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.snappy) { selectedCategory = nil }
                }
                
                // Category filters
                ForEach(activeCategories) { category in
                    FilterChip(
                        label: category.rawValue,
                        icon: category.icon,
                        count: count(for: category),
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.snappy) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let icon: String
    let count: Int
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption.bold())
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                        ? Color.white.opacity(0.3)
                        : Color(.tertiarySystemFill)
                    )
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 4, y: 2)
        }
    }
}

#Preview {
    CategoryFilterView(
        selectedCategory: .constant(nil),
        itineraries: DataStore().trips.first?.itineraries ?? []
    )
}
