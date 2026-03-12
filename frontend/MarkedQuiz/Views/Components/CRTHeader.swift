import SwiftUI

struct CRTHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CRT.monoBold(20))
                .foregroundStyle(CRT.orangeBright)
                .crtGlow()

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(CRT.monoText(12))
                    .foregroundStyle(CRT.textDim)
            }
        }
    }
}

struct CRTSeparator: View {
    var body: some View {
        Rectangle()
            .fill(CRT.orangeFaint)
            .frame(height: 1)
            .shadow(color: CRT.orangeBright.opacity(0.1), radius: 2)
    }
}

struct CRTStatusDot: View {
    enum Status {
        case online, warning, offline
    }

    let status: Status

    var color: Color {
        switch status {
        case .online: return CRT.greenAccent
        case .warning: return CRT.amber
        case .offline: return CRT.redAccent
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(0.5), radius: 3)
    }
}
