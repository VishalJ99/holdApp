import SwiftUI
import Observation

@Observable
final class ToastManager {
    static let shared = ToastManager()

    var currentToast: ToastMessage?

    private init() {}

    func showSuccess(_ message: String) {
        show(.success(message))
    }

    func showError(_ message: String) {
        show(.error(message))
    }

    private func show(_ toast: ToastMessage) {
        currentToast = toast

        // Auto-dismiss after timing
        DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
            if self.currentToast == toast {
                self.currentToast = nil
            }
        }
    }

    enum ToastMessage: Equatable {
        case success(String)
        case error(String)

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .success: return UIConstants.successGreen
            case .error: return UIConstants.warningOrange
            }
        }

        var message: String {
            switch self {
            case .success(let msg), .error(let msg): return msg
            }
        }

        var duration: Double {
            UIConstants.toastFadeIn + UIConstants.toastHold + UIConstants.toastFadeOut
        }
    }
}

// Toast View
struct ToastView: View {
    let toast: ToastManager.ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.icon)
                .foregroundColor(toast.iconColor)

            Text(toast.message)
                .font(.system(size: UIConstants.toastFontSize, weight: .medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
