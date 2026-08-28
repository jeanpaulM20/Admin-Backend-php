import SwiftUI

/// Der QR-Code des Trainers, mit dem sich Kunden verknüpfen.
/// Pendant zu `screens/qr_code_screen.dart`.
struct QRCodeView: View {
    let trainerId: Int
    let isPreview: Bool

    @State private var code: String?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            if isLoading {
                LoadingState()
            } else if let image {
                // Weisse Fläche unter dem Code: dunkle Hintergründe machen
                // QR-Codes für viele Scanner unlesbar.
                image
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .padding(AppSpacing.card)
                    .background(AppColor.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                Text("Kunden scannen diesen Code, um sich mit dir zu verknüpfen.")
                    .font(.app(13))
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.screen)
            } else {
                MessageState(icon: "qrcode", title: "Kein QR-Code",
                             message: error ?? "Das Backend hat keinen Code geliefert.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background)
        .navigationTitle("QR-Code")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    /// Das Backend liefert den Code als Data-URL oder als nacktes Base64.
    private var image: Image? {
        guard let code else { return nil }
        let base64 = code.contains(",") ? String(code.split(separator: ",").last ?? "") : code
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    private func load() async {
        defer { isLoading = false }
        #if DEBUG
        if isPreview {
            error = "Im Vorschaumodus wird kein Code geladen."
            return
        }
        #endif
        do {
            code = try await ClientRecordsService().qrCode(trainerId: trainerId)
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "QR-Code konnte nicht geladen werden"
        }
    }
}
