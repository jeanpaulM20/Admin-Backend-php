import SwiftUI

// MARK: - SavedRoutesSheet („Meine Routen")

/// Liste der gespeicherten Planungen: Tipp öffnet die Route (Details,
/// Höhenprofil, Starten); das Menü je Zeile bietet Bearbeiten (zurück in
/// den Planer), Umbenennen und Löschen.
struct SavedRoutesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let repository: SavedRouteRepository
    let onOpen: (TourDetail) -> Void
    let onEdit: (SavedRoute) -> Void

    @State private var routes: [SavedRoute] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var openingID: Int?
    @State private var openTask: Task<Void, Never>?
    @State private var renaming: SavedRoute?
    @State private var renameText = ""
    @State private var deleting: SavedRoute?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Meine Routen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(AppColor.text)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await load() }
        // Wird die Liste geschlossen, soll ein noch ladendes Detail nicht
        // später unerwartet aufgehen
        .onDisappear { openTask?.cancel() }
        .alert("Route umbenennen", isPresented: Binding(
            get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Speichern") { rename() }
            Button("Abbrechen", role: .cancel) {}
        }
        .confirmationDialog(
            deleting.map { "„\($0.name)“ löschen?" } ?? "",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { route in
            Button("Route löschen", role: .destructive) { delete(route) }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Die gespeicherte Route wird endgültig entfernt.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            LoadingView(message: "Lade Routen…")
        } else if routes.isEmpty {
            VStack(spacing: 10) {
                if let error { InlineErrorBanner(message: error) }
                Image(systemName: "bookmark")
                    .font(.app(28))
                    .foregroundStyle(AppColor.muted)
                Text("Noch keine gespeicherten Routen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.text)
                Text("Plane eine Route und tippe im Planer auf das Lesezeichen.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.screen)
        } else {
            ScrollView {
                VStack(spacing: AppSpacing.stack) {
                    if let error { InlineErrorBanner(message: error) }
                    ForEach(routes) { route in
                        row(route)
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.vertical, AppSpacing.stack)
            }
        }
    }

    private func row(_ route: SavedRoute) -> some View {
        HStack(spacing: 12) {
            Image(systemName: route.activity.icon)
                .font(.app(15))
                .foregroundStyle(AppColor.primary)
                .frame(width: 36, height: 36)
                .background(AppColor.surface2, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(route.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(route.statsLine + (route.roundtrip ? " · Rundkurs" : ""))
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)

            if openingID == route.id {
                ProgressView().tint(AppColor.primary)
            }

            Menu {
                Button { onEdit(route) } label: {
                    Label("Im Planer bearbeiten", systemImage: "point.3.connected.trianglepath.dotted")
                }
                Button {
                    renameText = route.name
                    renaming = route
                } label: {
                    Label("Umbenennen", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) { deleting = route } label: {
                    Label("Löschen", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Aktionen für \(route.name)")
        }
        .padding(.leading, AppSpacing.card)
        .padding(.vertical, 10)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { open(route) }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Daten

    private func load() async {
        do {
            routes = try await repository.list()
            error = nil
        } catch {
            self.error = "Routen konnten nicht geladen werden."
        }
        isLoading = false
    }

    private func open(_ route: SavedRoute) {
        guard openingID == nil else { return }
        openingID = route.id
        openTask = Task {
            defer { openingID = nil }
            let detail = try? await repository.detail(route)
            guard !Task.isCancelled else { return }
            if let detail {
                onOpen(detail)
            } else {
                error = "Route konnte nicht geladen werden."
            }
        }
    }

    private func rename() {
        guard let route = renaming else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        renaming = nil
        guard !name.isEmpty, name != route.name else { return }
        Task {
            do {
                if let updated = try await repository.rename(route, to: name),
                   let i = routes.firstIndex(where: { $0.id == route.id }) {
                    routes[i] = updated
                }
            } catch {
                self.error = "Umbenennen fehlgeschlagen."
            }
        }
    }

    private func delete(_ route: SavedRoute) {
        Task {
            do {
                try await repository.delete(route)
                routes.removeAll { $0.id == route.id }
            } catch {
                self.error = "Löschen fehlgeschlagen."
            }
        }
    }
}
