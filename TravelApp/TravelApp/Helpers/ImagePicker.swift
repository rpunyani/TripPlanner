import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.7)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct PhotosPicker17: View {
    @Binding var imageData: Data?
    var label: String = "Select Photo"
    
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Label(label, systemImage: "photo.on.rectangle")
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        imageData = data
                    }
                }
            }
        }
    }
}

struct MultiPhotoPicker: View {
    var onPhotosSelected: ([Data]) -> Void
    var label: String = "Add Photos"
    
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .images) {
            Label(label, systemImage: "photo.on.rectangle.angled")
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                var photoDatas: [Data] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        photoDatas.append(data)
                    }
                }
                await MainActor.run {
                    onPhotosSelected(photoDatas)
                    selectedItems = []
                }
            }
        }
    }
}
