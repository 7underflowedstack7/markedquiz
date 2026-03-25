import SwiftUI

// MARK: - Chat Hub (hero + navigation cards)

struct ChatView: View {
    var body: some View {
        ZStack {
            BlobBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // MARK: - Hero
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Molten.Accent.primary.opacity(0.10))
                                .frame(width: 100, height: 100)

                            Circle()
                                .fill(Molten.Accent.primary.opacity(0.06))
                                .frame(width: 140, height: 140)

                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Molten.Accent.primary)
                        }

                        Text("Leah")
                            .font(.moltenTitle())
                            .foregroundStyle(Molten.Text.primary)

                        Text("Your AI assistant, powered via Tailscale")
                            .font(.moltenCaption())
                            .foregroundStyle(Molten.Text.tertiary)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 8)

                    // MARK: - Cards
                    VStack(spacing: 14) {
                        NavigationLink(value: ChatRoute.newChat) {
                            ChatOptionRow(
                                icon: "plus.bubble",
                                title: "New Chat",
                                subtitle: "Start a fresh conversation"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(value: ChatRoute.history) {
                            ChatOptionRow(
                                icon: "clock.arrow.circlepath",
                                title: "Message History",
                                subtitle: "View past conversations"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Chat")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: ChatRoute.self) { route in
            switch route {
            case .newChat:
                ChatConversationView()
            case .history:
                ChatHistoryView()
            }
        }
    }
}

enum ChatRoute: Hashable {
    case newChat, history
}

// MARK: - Chat Option Row (matches ToolCard style)

private struct ChatOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Molten.Accent.primary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Molten.Accent.primary.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Molten.Text.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Molten.Text.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Molten.Text.tertiary)
        }
        .glassCard(radius: Molten.Radius.xl, padding: 16)
    }
}

// MARK: - Chat History Placeholder

struct ChatHistoryView: View {
    var body: some View {
        ZStack {
            BlobBackground()
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 36))
                    .foregroundStyle(Molten.Text.tertiary)
                Text("No conversations yet")
                    .font(.moltenBody(14))
                    .foregroundStyle(Molten.Text.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("History")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Chat Conversation

/// Full chat view for Leah (remote LLM agent via Tailscale)
struct ChatConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(RemoteLLMService.self) private var llm
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var error: String?

    private let green = Color(hex: 0x4ADE80)

    var body: some View {
        ZStack {
            BlobBackground()

            VStack(spacing: 0) {
                // MARK: - Top Bar
                chatTopBar

                // MARK: - Messages
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            // Error banner
                            if let error {
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: 0xF87171))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(hex: 0xF87171).opacity(0.1))
                                    )
                                    .padding(.horizontal, 20)
                            }

                            // Empty state
                            if messages.isEmpty && !isStreaming {
                                VStack(spacing: 12) {
                                    Spacer().frame(height: 100)
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Molten.Text.tertiary)
                                    Text("Start a conversation with Leah")
                                        .font(.moltenBody(14))
                                        .foregroundStyle(Molten.Text.tertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }

                            ForEach(messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }

                            // Thinking indicator
                            if isStreaming, let last = messages.last, last.role == "assistant", last.content.isEmpty {
                                ThinkingDots()
                                    .id("thinking")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 80)
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: messages.last?.content) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }

                // MARK: - Input Bar
                chatInputBar
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .hidesTabBar()
    }

    // MARK: - Top Bar

    private var chatTopBar: some View {
        HStack(spacing: 12) {
            // Back button
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Molten.Text.primary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Molten.Glass.bg)
                            .overlay(Circle().stroke(Molten.Glass.border, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            // Connection dot
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
                .shadow(color: connectionColor.opacity(0.4), radius: 4)

            Text("Leah")
                .font(.custom("Georgia", size: 22).weight(.regular))
                .foregroundStyle(Molten.Text.primary)

            Spacer()

            // Clear button
            if !messages.isEmpty {
                Button {
                    withAnimation { clearConversation() }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Molten.Text.tertiary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Molten.BG.deep.opacity(0.8), Color.clear],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: - Input Bar

    private var chatInputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask Leah anything...", text: $inputText, axis: .vertical)
                .font(.moltenBody(14))
                .foregroundStyle(Molten.Text.primary)
                .tint(Molten.Accent.primary)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit { send() }

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canSend ? Molten.Text.primary : Molten.Text.tertiary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(canSend ? Molten.Accent.primary : Color.white.opacity(0.06))
                    )
                    .shadow(color: canSend ? Molten.Shadow.fab : .clear, radius: 8, y: 4)
            }
            .disabled(!canSend)
        }
        .padding(.leading, 22)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Molten.Card.bg))
                .overlay(Capsule().stroke(Molten.Card.border, lineWidth: 1))
        )
        .shadow(color: Molten.Shadow.deep, radius: 16, y: -4)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Helpers

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    private var connectionColor: Color {
        switch llm.connectionState {
        case .connected: green
        case .connecting: Color(hex: 0xFACC15)
        case .error: Color(hex: 0xF87171)
        case .disconnected: llm.isConfigured ? Color.white.opacity(0.25) : Color(hex: 0xF87171)
        }
    }

    // MARK: - Send Message

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        inputText = ""
        error = nil

        // Append user message
        messages.append(ChatMessage(role: "user", content: text))

        // Append empty assistant message (will be streamed into)
        messages.append(ChatMessage(role: "assistant", content: ""))

        isStreaming = true

        guard let token = auth.accessToken else {
            error = "Not logged in"
            messages.removeLast()
            isStreaming = false
            return
        }

        let history = messages.dropLast().map { (role: $0.role, content: $0.content) }

        Task {
            do {
                let stream = llm.chat(messages: history, token: token)
                for try await chunk in stream {
                    if let idx = messages.indices.last {
                        messages[idx].content += chunk
                    }
                }
            } catch {
                self.error = error.localizedDescription
                // Remove empty assistant message on failure
                if let last = messages.last, last.role == "assistant", last.content.isEmpty {
                    messages.removeLast()
                }
            }
            isStreaming = false
        }
    }

    private func clearConversation() {
        messages.removeAll()
        error = nil
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 50) }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(Molten.Text.primary)

                Text(timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(Molten.Text.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(bubbleBackground)
            .clipShape(bubbleShape)
            .overlay(bubbleShape.stroke(bubbleBorder, lineWidth: 1))

            if message.role == "assistant" { Spacer(minLength: 50) }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        message.role == "user"
            ? AnyShapeStyle(Molten.Accent.primary.opacity(0.18))
            : AnyShapeStyle(Molten.Card.bg)
    }

    private var bubbleBorder: Color {
        message.role == "user"
            ? Molten.Accent.primary.opacity(0.25)
            : Molten.Card.border
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if message.role == "user" {
            UnevenRoundedRectangle(
                topLeadingRadius: 22, bottomLeadingRadius: 22,
                bottomTrailingRadius: 6, topTrailingRadius: 22
            )
        } else {
            UnevenRoundedRectangle(
                topLeadingRadius: 22, bottomLeadingRadius: 6,
                bottomTrailingRadius: 22, topTrailingRadius: 22
            )
        }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: message.timestamp)
    }
}

// MARK: - Thinking Dots

private struct ThinkingDots: View {
    @State private var active = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Molten.Text.tertiary)
                        .frame(width: 7, height: 7)
                        .offset(y: active ? -6 : 0)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: active
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 22, bottomLeadingRadius: 6,
                    bottomTrailingRadius: 22, topTrailingRadius: 22
                )
                .fill(Molten.Card.bg)
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 22, bottomLeadingRadius: 6,
                    bottomTrailingRadius: 22, topTrailingRadius: 22
                )
                .stroke(Molten.Card.border, lineWidth: 1)
            )

            Spacer(minLength: 50)
        }
        .onAppear { active = true }
    }
}
