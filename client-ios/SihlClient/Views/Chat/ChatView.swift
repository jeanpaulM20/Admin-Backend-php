import SwiftUI

// MARK: - ChatView (Konversationsliste)

/// Pendant zu `ChatScreen` + `_ConversationList` in Flutter `chat_screen.dart`.
/// Zeigt alle Konversationen; NavigationLink pusht auf `ChatThreadView`.
struct ChatView: View {
    @Environment(AuthViewModel.self)  private var auth
    @Environment(ChatViewModel.self)  private var chat

    // Automatisches Öffnen bei genau EINER Konversation (Flutter `_loadConversations`)
    @State private var autoOpenConversation: ChatConversation? = nil
    @State private var didAutoOpen = false

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if chat.isLoading && chat.conversations.isEmpty {
                ProgressView().tint(AppColor.primary)
            } else if let e = chat.error {
                ErrorStateView(message: e) {
                    Task { await chat.fetchConversations(clientId: auth.clientId ?? "") }
                }
            } else if chat.conversations.isEmpty {
                EmptyStateView(
                    icon:    "bubble.left.and.bubble.right",
                    message: "Sobald dein Trainer eine Nachricht sendet, erscheint sie hier."
                )
            } else {
                conversationList
            }
        }
        .navigationDestination(for: ChatConversation.self) { conv in
            thread(for: conv)
        }
        .navigationDestination(item: $autoOpenConversation) { conv in
            thread(for: conv)
        }
        .task {
            // Beim ersten Erscheinen laden; beim Tab-Wechsel wird .task nicht erneut ausgelöst
            if chat.conversations.isEmpty {
                await chat.fetchConversations(clientId: auth.clientId ?? "")
            }
            // Bei genau einer Konversation direkt den Thread öffnen (wie Flutter)
            if !didAutoOpen, chat.conversations.count == 1, let only = chat.conversations.first {
                didAutoOpen = true
                autoOpenConversation = only
            }
        }
        .refreshable {
            await chat.fetchConversations(clientId: auth.clientId ?? "")
        }
    }

    private func thread(for conv: ChatConversation) -> some View {
        ChatThreadView(
            trainerId:   conv.trainerId,
            trainerName: conv.trainerName,
            trainerPicture: conv.trainerPicture
        )
    }

    // MARK: - Conversation list

    private var conversationList: some View {
        List {
            ForEach(chat.conversations) { conv in
                NavigationLink(value: conv) {
                    ConversationTile(conversation: conv)
                }
                .listRowBackground(AppColor.surface)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - ConversationTile

/// Pendant zu `_ConversationTile` in `chat_screen.dart`.
private struct ConversationTile: View {
    let conversation: ChatConversation

    var body: some View {
        HStack(spacing: 12) {
            // Avatar-Kreis (Initialen)
            ZStack {
                Circle()
                    .fill(AppColor.primary.opacity(0.25))
                    .frame(width: 48, height: 48)
                Text(conversation.initials)
                    .font(.headline.bold())
                    .foregroundStyle(AppColor.primary)
            }
            .overlay(alignment: .topTrailing) {
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.red, in: Circle())
                        .offset(x: 4, y: -4)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conversation.trainerName)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.text)
                    Spacer()
                    if let at = conversation.lastMessageAt {
                        Text(at, format: .relative(presentation: .numeric))
                            .font(.caption2)
                            .foregroundStyle(AppColor.muted)
                    }
                }
                Text(conversation.lastMessage ?? "")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
