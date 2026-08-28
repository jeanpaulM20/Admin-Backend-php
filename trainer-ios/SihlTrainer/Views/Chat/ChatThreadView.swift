import SwiftUI

/// Ein Gesprächsfaden. Entspricht dem Chat-Teil von
/// `workout_feedback_screen.dart` — die Datenkarten (Aufzeichnungen,
/// Leistungstests) dieses Screens folgen in einer späteren Etappe.
struct ChatThreadView: View {
    let conversation: Conversation

    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var model: ChatThreadViewModel
    @FocusState private var inputFocused: Bool

    init(conversation: Conversation) {
        self.conversation = conversation
        // Der Trainer steht beim Erzeugen noch nicht zur Verfügung; die ID
        // wird beim Senden aus der Sitzung nachgereicht.
        _model = StateObject(wrappedValue: ChatThreadViewModel(
            clientId: conversation.clientId,
            trainerId: 0
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            inputBar
        }
        .background(AppColor.background)
        .navigationTitle(conversation.clientName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            model.adopt(trainerId: auth.trainer?.id ?? 0, isPreview: auth.previewFlag)
            await model.load()
            model.startLiveUpdates()
        }
        .onDisappear { model.stopLiveUpdates() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if model.isLoading && model.messages.isEmpty {
                        ProgressView().tint(AppColor.primary).padding(.top, 40)
                    }
                    ForEach(model.messages) { message in
                        MessageBubble(message: message).id(message.id)
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.vertical, AppSpacing.stack)
            }
            .onChange(of: model.messages.count) {
                guard let last = model.messages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            if let error = model.error {
                Text(error)
                    .font(.app(12))
                    .foregroundStyle(AppColor.red)
            }
            HStack(spacing: 10) {
                TextField("Nachricht…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.app(15))
                    .foregroundStyle(AppColor.text)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.control)
                            .stroke(AppColor.border, lineWidth: 1)
                    )

                Button {
                    Task { await model.send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.app(16, weight: .semibold))
                        .foregroundStyle(AppColor.white)
                        .frame(width: 38, height: 38)
                        .background(canSend ? AppColor.cta : AppColor.surface2)
                        .clipShape(Circle())
                }
                .disabled(!canSend)
                .accessibilityLabel("Senden")
            }
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.vertical, 10)
        .background(AppColor.background)
    }

    private var canSend: Bool {
        !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isSending
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isTrainer { Spacer(minLength: 40) }
            Text(message.text)
                .font(.app(15))
                .foregroundStyle(message.isTrainer ? AppColor.white : AppColor.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isTrainer ? AppColor.primary : AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(message.isTrainer ? .clear : AppColor.border, lineWidth: 1)
                )
            if !message.isTrainer { Spacer(minLength: 40) }
        }
    }
}
