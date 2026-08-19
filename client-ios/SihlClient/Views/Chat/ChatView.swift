import SwiftUI

// MARK: - ChatView (Konversationsliste)

/// Pendant zu `ChatScreen` + `_ConversationList` in Flutter `chat_screen.dart`.
/// Zeigt alle Konversationen; NavigationLink pusht auf `ChatThreadView`.
struct ChatView: View {
    @Environment(AuthViewModel.self)  private var auth
    @Environment(ChatViewModel.self)  private var chat

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if chat.isLoading && chat.conversations.isEmpty {
                ProgressView().tint(AppColor.primary)
            } else if let e = chat.error {
                ChatErrorView(message: e) {
                    Task { await chat.fetchConversations(clientId: auth.clientId) }
                }
            } else if chat.conversations.isEmpty {
                emptyChatView
            } else {
                conversationList
            }
        }
        .task {
            // Beim ersten Erscheinen laden; beim Tab-Wechsel wird .task nicht erneut ausgelöst
            if chat.conversations.isEmpty {
                await chat.fetchConversations(clientId: auth.clientId)
            }
        }
        .refreshable {
            await chat.fetchConversations(clientId: auth.clientId)
        }
    }

    // MARK: - Conversation list

    private var conversationList: some View {
        List {
            // Ungelesene Nachrichten-Header (wie Flutter's unread badge section)
            if chat.totalUnreadCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "message.fill")
                        .font(.caption)
                        .foregroundStyle(AppColor.primary)
                    Text("\(chat.totalUnreadCount) ungelesene Nachricht\(chat.totalUnreadCount == 1 ? "" : "en")")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
                .listRowBackground(AppColor.surface)
                .listRowSeparator(.hidden)
            }

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
        .navigationDestination(for: ChatConversation.self) { conv in
            ChatThreadView(
                trainerId:   conv.trainerId,
                trainerName: conv.trainerName,
                trainerPicture: conv.trainerPicture
            )
        }
    }

    // MARK: - Empty

    private var emptyChatView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.muted)
            Text("Noch keine Chats")
                .font(.headline)
                .foregroundStyle(AppColor.text)
            Text("Sobald dein Trainer eine Nachricht sendet, erscheint sie hier.")
                .font(.caption)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
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

// MARK: - Error

private struct ChatErrorView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.title).foregroundStyle(.orange)
            Text(message).font(.caption).foregroundStyle(AppColor.muted).multilineTextAlignment(.center)
            Button("Erneut laden", action: retry)
                .buttonStyle(.bordered).tint(AppColor.primary)
        }.padding()
    }
}
