import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct TravelAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var dataStore = DataStore()
    @State private var firebaseService = FirebaseService()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dataStore)
                .environment(firebaseService)
        }
    }
}

struct RootView: View {
    @Environment(FirebaseService.self) private var firebase
    @Environment(DataStore.self) private var store
    
    var body: some View {
        Group {
            if firebase.isSignedIn {
                ContentView()
                    .onAppear {
                        store.connectFirebase(firebase)
                    }
            } else {
                AuthView()
            }
        }
        .onAppear {
            firebase.startAuthListener()
        }
    }
}
