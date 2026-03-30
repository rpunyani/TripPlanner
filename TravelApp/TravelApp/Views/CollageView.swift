import SwiftUI

struct CollageView: View {
    let photos: [TripPhoto]
    
    var body: some View {
        if photos.isEmpty {
            emptyCollage
        } else if photos.count == 1 {
            singlePhoto
        } else if photos.count == 2 {
            twoPhotos
        } else if photos.count == 3 {
            threePhotos
        } else if photos.count == 4 {
            fourPhotos
        } else {
            manyPhotos
        }
    }
    
    // MARK: - Empty
    private var emptyCollage: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.tertiarySystemFill))
            .frame(height: 200)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No photos to display")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
    }
    
    // MARK: - Single Photo
    private var singlePhoto: some View {
        photoImage(photos[0])
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Two Photos
    private var twoPhotos: some View {
        HStack(spacing: 3) {
            photoImage(photos[0])
            photoImage(photos[1])
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Three Photos
    private var threePhotos: some View {
        HStack(spacing: 3) {
            photoImage(photos[0])
                .frame(width: UIScreen.main.bounds.width * 0.45)
            
            VStack(spacing: 3) {
                photoImage(photos[1])
                photoImage(photos[2])
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Four Photos
    private var fourPhotos: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                photoImage(photos[0])
                photoImage(photos[1])
            }
            HStack(spacing: 3) {
                photoImage(photos[2])
                photoImage(photos[3])
            }
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 5+ Photos
    private var manyPhotos: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                photoImage(photos[0])
                photoImage(photos[1])
            }
            .frame(height: 140)
            
            HStack(spacing: 3) {
                photoImage(photos[2])
                photoImage(photos[3])
                
                ZStack {
                    photoImage(photos[4])
                    
                    if photos.count > 5 {
                        Color.black.opacity(0.5)
                        Text("+\(photos.count - 5)")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 110)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper
    @ViewBuilder
    private func photoImage(_ photo: TripPhoto) -> some View {
        if let uiImage = UIImage(data: photo.imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            Color(.tertiarySystemFill)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.tertiary)
                }
        }
    }
}

#Preview {
    VStack {
        CollageView(photos: [])
    }
    .padding()
}
