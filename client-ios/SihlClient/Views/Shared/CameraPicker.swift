import SwiftUI
import UIKit
import Photos

/// Kamera-Aufnahme für das Trainings-Foto (SwiftUI hat keinen eigenen
/// Kamera-Picker, daher die UIKit-Brücke).
///
/// Das Schliessen läuft über `onDismiss` (die Bindung des Aufrufers), nicht
/// über `@Environment(\.dismiss)` aus dem Coordinator heraus — diese Kopie
/// der Umgebung im Coordinator ist unzuverlässig.
///
/// Das Bild wird über mehrere Wege gelesen: Je nach iOS-Version und
/// Zugriffsmodus („Private Access") liefert der Picker nicht mehr
/// zuverlässig `.originalImage`, sondern nur eine Datei-URL oder ein
/// PHAsset — vorher kam dann still gar kein Bild an.
struct CameraPicker: UIViewControllerRepresentable {
    /// Rückgabe per Binding statt Closure: Ein Closure hält eine KOPIE der
    /// aufrufenden View, und ein @State-Schreibzugriff über eine nicht
    /// installierte Kopie wird von SwiftUI still verworfen — das Bild kam
    /// dann nie an, obwohl der Picker es geliefert hatte. Eine Binding
    /// schreibt immer in den lebenden Speicher; die View verarbeitet das
    /// Bild in `onChange`.
    @Binding var image: UIImage?
    let onDismiss: () -> Void
    var onFailure: () -> Void = {}

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        #if targetEnvironment(simulator)
        // Die Simulator-Kamera kann nicht auslösen — Mediathek nutzen, damit
        // der Rückgabepfad (Übergabe + Schliessen) dort testbar bleibt
        picker.sourceType = .photoLibrary
        #else
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        #endif
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let parent = self.parent
            Self.extractImage(from: info) { image in
                DispatchQueue.main.async {
                    if let image { parent.image = image } else { parent.onFailure() }
                    parent.onDismiss()
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
        }

        /// Reihenfolge: bearbeitetes Bild, Original, Datei-URL, PHAsset.
        private static func extractImage(from info: [UIImagePickerController.InfoKey: Any],
                                         completion: @escaping (UIImage?) -> Void) {
            if let img = info[.editedImage] as? UIImage { return completion(img) }
            if let img = info[.originalImage] as? UIImage { return completion(img) }
            if let url = info[.imageURL] as? URL {
                // Die URL kann security-scoped sein (Private Access) — ohne
                // Freigabe schlägt das Lesen still fehl
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let img = UIImage(contentsOfFile: url.path)
                    ?? (try? Data(contentsOf: url)).flatMap(UIImage.init(data:)) {
                    return completion(img)
                }
                NSLog("CameraPicker: imageURL nicht lesbar: %@", url.path)
            }
            if let asset = info[.phAsset] as? PHAsset {
                let opts = PHImageRequestOptions()
                opts.isNetworkAccessAllowed = true
                opts.deliveryMode = .highQualityFormat
                PHImageManager.default().requestImage(
                    for: asset, targetSize: CGSize(width: 2160, height: 3840),
                    contentMode: .aspectFill, options: opts) { img, _ in completion(img) }
                return
            }
            NSLog("CameraPicker: kein Bild extrahierbar")
            completion(nil)
        }
    }
}
