import SwiftUI

struct CRTLoadingView: View {
    let message: String
    @State private var dotCount = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(CRT.orangeBright)
                .scaleEffect(1.2)

            Text(message + String(repeating: ".", count: dotCount))
                .font(CRT.monoText(14))
                .foregroundStyle(CRT.orangeBright)
                .crtGlow()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CRT.bgDeep)
        .onAppear {
            animationTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    dotCount = (dotCount + 1) % 4
                }
            }
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }
}

struct CRTErrorView: View {
    let message: String
    var retryAction: (() async -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(CRT.redAccent)
                .crtGlow(color: CRT.redAccent)

            Text("ERROR")
                .font(CRT.monoBold(16))
                .foregroundStyle(CRT.redAccent)

            Text(message)
                .font(CRT.monoText(13))
                .foregroundStyle(CRT.orangeDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let retryAction = retryAction {
                CRTButton(title: "RETRY", icon: "arrow.clockwise", color: CRT.amber) {
                    Task { await retryAction() }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CRT.bgDeep)
    }
}

struct CRTEmptyView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(CRT.orangeDim)

            Text(title)
                .font(CRT.monoBold(16))
                .foregroundStyle(CRT.orangeBright)

            Text(message)
                .font(CRT.monoText(13))
                .foregroundStyle(CRT.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let actionTitle = actionTitle, let action = action {
                CRTButton(title: actionTitle, color: CRT.orangeBright, action: action)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CRT.bgDeep)
    }
}
