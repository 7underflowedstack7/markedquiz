import SwiftUI

struct CRTButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = CRT.orangeBright
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(CRT.bgDeep)
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(CRT.monoText(14))
                    }
                    Text(title)
                        .font(CRT.monoBold(14))
                }
            }
            .foregroundStyle(CRT.bgDeep)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
        }
        .disabled(isLoading)
        .accessibilityLabel(title)
    }
}

struct CRTSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = CRT.orangeBright
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(CRT.monoText(13))
                }
                Text(title)
                    .font(CRT.monoText(13))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityLabel(title)
    }
}
