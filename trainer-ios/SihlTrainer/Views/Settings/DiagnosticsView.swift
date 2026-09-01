#if DEBUG
import SwiftUI

/// Verbindungstest: ruft die Endpunkte nacheinander auf und zeigt Status,
/// Antwortgrösse und Inhalt. Nur in Debug-Builds — dient dazu, ein leeres
/// Listenbild von einem gescheiterten Aufruf zu unterscheiden.
struct DiagnosticsView: View {
    let trainerId: Int

    @State private var results: [Result] = []
    @State private var isRunning = false

    struct Result: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let status: Int
        let bytes: Int
        let snippet: String

        var ok: Bool { (200..<300).contains(status) }

        var statusText: String {
            switch status {
            case -1: return "kein Token"
            case -2: return "Netzwerk"
            default: return "HTTP \(status)"
            }
        }
    }

    private var endpoints: [(String, String)] {
        [
            ("Trainer", APIConfig.trainerMe),
            ("Kunden", APIConfig.client),
            ("Termine", "\(APIConfig.training)?trainer_id=\(trainerId)"),
            ("Gespräche", "\(APIConfig.feedback)/conversations?trainer_id=\(trainerId)"),
            ("Verfügbarkeit", "\(APIConfig.availability)?trainer_id=\(trainerId)"),
            ("Übungen", APIConfig.exercise),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                Button {
                    Task { await run() }
                } label: {
                    HStack {
                        if isRunning {
                            ProgressView().tint(AppColor.white)
                        } else {
                            Text("Test starten").font(.app(15, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(AppColor.cta)
                    .foregroundStyle(AppColor.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                }
                .disabled(isRunning)

                ForEach(results) { result in
                    Card {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(result.name)
                                    .font(.app(15, weight: .semibold))
                                    .foregroundStyle(AppColor.text)
                                Spacer(minLength: 0)
                                Text(result.statusText)
                                    .font(.app(13, weight: .semibold))
                                    .foregroundStyle(result.ok ? AppColor.green : AppColor.red)
                            }
                            Text(result.path)
                                .font(.app(11))
                                .foregroundStyle(AppColor.muted)
                            Text("\(result.bytes) Bytes")
                                .font(.app(12))
                                .foregroundStyle(AppColor.muted)
                            Text(result.snippet)
                                .font(.app(12, design: .monospaced))
                                .foregroundStyle(result.ok ? AppColor.brass : AppColor.red)
                                .textSelection(.enabled)
                        }
                    }
                }

                if !results.isEmpty {
                    Text("Text lässt sich markieren und kopieren.")
                        .font(.app(11))
                        .foregroundStyle(AppColor.muted)
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.vertical, AppSpacing.stack)
        }
        .background(AppColor.background)
        .navigationTitle("Verbindungstest")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func run() async {
        isRunning = true
        results = []
        defer { isRunning = false }
        for (name, path) in endpoints {
            let probe = await APIClient.shared.probe(path)
            results.append(Result(name: name, path: path,
                                  status: probe.status, bytes: probe.bytes,
                                  snippet: probe.snippet))
        }
    }
}
#endif
