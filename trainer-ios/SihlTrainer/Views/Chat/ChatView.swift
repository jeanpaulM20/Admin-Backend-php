import SwiftUI

/// Pendant zu `screens/nachrichten_screen.dart`: Gesprächsliste mit
/// Ungelesen-Zähler, Sprung in den Faden.
struct ChatView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var store: TrainerStore
    @EnvironmentObject private var chat: ChatStore

    var body: some View {
        Group {
            if chat.isLoading && chat.conversations.isEmpty {
                LoadingState()
            } else if let error = chat.error {
                MessageState(icon: "exclamationmark.triangle",
                             title: "Nachrichten konnten nicht geladen werden",
                             message: error,
                             actionTitle: "Erneut versuchen") {
                    Task { await reload() }
                }
            } else if chat.conversations.isEmpty {
                MessageState(icon: "bubble.left.and.bubble.right",
                             title: "Noch keine Gespräche",
                             message: "Sobald ein Kunde schreibt, erscheint der Faden hier.")
            } else {
                list
            }
        }
        .background(AppColor.background)
        .sectionChrome("Nachrichten")
        .navigationDestination(for: Conversation.self) { conversation in
            ChatThreadView(conversation: conversation)
        }
    }

    private var list: some View {
        List(chat.conversations) { conversation in
            NavigationLink(value: conversation) {
                ConversationRow(conversation: conversation,
                                client: client(for: conversation))
            }
            .listRowBackground(AppColor.background)
            .listRowSeparatorTint(AppColor.border)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await reload() }
    }

    /// Der Kunde aus dem Store liefert Foto und Initialen; das Backend liefert
    /// im Gesprächsfaden nur Name und ID.
    private func client(for conversation: Conversation) -> Client? {
        store.clients.first { $0.id == conversation.clientId }
    }

    private func reload() async {
        guard let id = auth.trainer?.id else { return }
        await chat.load(trainerId: id)
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let client: Client?

    var body: some View {
        HStack(spacing: 12) {
            Avatar(initials: client?.initials ?? conversation.clientName.initials,
                   photo: client?.photo)
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.clientName)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.text)
                    .lineLimit(1)
                Text(conversation.lastMessage)
                    .font(.app(13))
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.app(12, weight: .bold))
                    .foregroundStyle(AppColor.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColor.primary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

extension Conversation: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(clientId) }
}
