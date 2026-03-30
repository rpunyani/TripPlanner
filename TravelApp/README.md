# TravelApp - iOS Travel Itinerary & Collaboration App

A modern SwiftUI iOS app for managing travel itineraries, collaborating with travel companions, and capturing trip memories.

## Requirements
- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Features

### 1. Itinerary Management
- Add itineraries across **6 categories**: Flights, Hotels, City Tours, Activities, Transport, Dining
- Category-specific fields (flight numbers, hotel booking refs, etc.)
- Filter and view itineraries grouped by category with color-coded chips
- Easy add/edit/delete with a form-based UI

### 2. Collaboration
- Invite collaborators by name and email
- Collaborator avatars shown throughout the app
- Share invite links (deep-link ready)
- Collaborators can view all itineraries and add their own

### 3. Rich Itinerary Details
- **Cover images** for easy recognition
- **Description**, **location**, **date/time** fields
- **People joining** each itinerary (tap-to-add from collaborators)
- Category-specific details (flight route, hotel check-in/out, booking references)

### 4. Photo Gallery & Trip Summary
- Add photos to trips or specific itineraries
- Multi-photo picker support (up to 20 at once)
- **Trip Summary** with:
  - Stats overview (itineraries, photos, places, travelers)
  - Places visited list
  - Chronological itinerary timeline
  - **Photo collage** (auto-layout for 1-5+ photos)
  - Travel companions overview

## Architecture

```
TravelApp/
├── TravelAppApp.swift          # App entry point
├── ContentView.swift           # Root view
├── Models/
│   ├── Models.swift            # Trip, ItineraryItem, Collaborator, TripPhoto
│   └── DataStore.swift         # Observable data store with UserDefaults persistence
├── Views/
│   ├── TripListView.swift      # Trip list with search
│   ├── TripDetailView.swift    # Trip detail with grouped itineraries
│   ├── AddTripView.swift       # Create new trip
│   ├── AddItineraryView.swift  # Add/edit itinerary with category-specific fields
│   ├── ItineraryDetailView.swift # Itinerary detail with photos
│   ├── CollaboratorsView.swift # Manage & invite collaborators
│   ├── PhotoGalleryView.swift  # Trip photo gallery grid
│   ├── TripSummaryView.swift   # Trip summary with stats & timeline
│   ├── CategoryFilterView.swift # Horizontal category filter chips
│   ├── ItineraryCardView.swift # Itinerary list card component
│   └── CollageView.swift       # Adaptive photo collage layout
└── Helpers/
    └── ImagePicker.swift       # UIImagePicker + PhotosPicker wrappers
```

## Getting Started

1. Open `TravelApp.xcodeproj` in Xcode
2. Select an iOS 17+ simulator or device
3. Build and run (⌘R)

The app ships with sample data (a "Tokyo Adventure" trip) so you can explore immediately.

## Data Persistence
Data is persisted locally via `UserDefaults` with JSON encoding. In a production app, this would be replaced with SwiftData/CloudKit for sync across devices.
