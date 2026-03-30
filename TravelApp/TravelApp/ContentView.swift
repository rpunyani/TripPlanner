import SwiftUI

struct ContentView: View {
    var body: some View {
        TripListView()
    }
}

#Preview {
    ContentView()
        .environment(DataStore())
}
