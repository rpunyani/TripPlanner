import SwiftUI

struct ItineraryCardView: View {
    let item: ItineraryItem
    
    var body: some View {
        HStack(spacing: 14) {
            // Image or icon
            ZStack {
                if let data = item.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(item.category.color.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: item.category.icon)
                                .font(.title3)
                                .foregroundStyle(item.category.color)
                        }
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                
                if !item.location.isEmpty {
                    Label(item.location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 10) {
                    let dateFormatter = DateFormatter()
                    let _ = dateFormatter.dateFormat = "MMM d"
                    Label(dateFormatter.string(from: item.date), systemImage: "calendar")
                    
                    let timeFormatter = DateFormatter()
                    let _ = timeFormatter.dateFormat = "h:mm a"
                    Label(timeFormatter.string(from: item.time), systemImage: "clock")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                
                // People joining
                if !item.peopleJoining.isEmpty {
                    HStack(spacing: -4) {
                        ForEach(item.peopleJoining.prefix(3), id: \.self) { person in
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
                        if item.peopleJoining.count > 3 {
                            Text("+\(item.peopleJoining.count - 3)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 6)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Photos count badge
            if !item.photos.isEmpty {
                VStack {
                    Label("\(item.photos.count)", systemImage: "photo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
    
    private func colorForPerson(_ name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .pink, .teal]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}

#Preview {
    VStack(spacing: 12) {
        ItineraryCardView(item: ItineraryItem(
            title: "Flight to Tokyo",
            description: "Direct flight",
            category: .flight,
            location: "SFO Airport",
            peopleJoining: ["Alice", "Bob", "Carol", "Dave"]
        ))
        ItineraryCardView(item: ItineraryItem(
            title: "Park Hyatt Hotel",
            category: .hotel,
            location: "Shinjuku, Tokyo"
        ))
        ItineraryCardView(item: ItineraryItem(
            title: "Temple Tour",
            category: .tour,
            location: "Asakusa"
        ))
    }
}
