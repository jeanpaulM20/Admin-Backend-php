import SwiftUI

/// Pendant zu `screens/clients_screen.dart`: Suchfeld, Liste, Sprung ins Detail.
struct ClientsListView: View {
    @EnvironmentObject private var store: TrainerStore
    @State private var query = ""

    private var filtered: [Client] {
        store.clients.filter { $0.matches(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(placeholder: "Kunden suchen…", text: $query)
                .padding(.horizontal, AppSpacing.screen)
                .padding(.bottom, 10)

            content
        }
        .background(AppColor.background)
        .sectionChrome("Kunden")
    }

    @ViewBuilder private var content: some View {
        if store.clientsLoading && store.clients.isEmpty {
            LoadingState()
        } else if let error = store.clientsError {
            MessageState(icon: "exclamationmark.triangle",
                         title: "Kunden konnten nicht geladen werden",
                         message: error,
                         actionTitle: "Erneut versuchen") {
                Task { await store.loadClients() }
            }
        } else if filtered.isEmpty {
            MessageState(icon: query.isEmpty ? "person.2" : "magnifyingglass",
                         title: query.isEmpty ? "Noch keine Kunden" : "Kein Treffer",
                         message: query.isEmpty
                            ? "Neue Kunden erscheinen hier, sobald sie angelegt sind."
                            : "Für „\(query)“ gibt es keinen Eintrag.")
        } else {
            List(filtered) { client in
                NavigationLink(value: client) {
                    ClientRow(client: client)
                }
                .listRowBackground(AppColor.background)
                .listRowSeparatorTint(AppColor.border)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await store.loadClients() }
            .navigationDestination(for: Client.self) { client in
                ClientDetailView(client: client)
            }
        }
    }
}

struct ClientRow: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            Avatar(initials: client.initials, photo: client.photo)
            VStack(alignment: .leading, spacing: 3) {
                Text(client.name)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.text)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.app(13))
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String? {
        client.email ?? client.phone ?? client.locationName
    }
}

/// Damit `NavigationLink(value:)` funktioniert.
extension Client: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
