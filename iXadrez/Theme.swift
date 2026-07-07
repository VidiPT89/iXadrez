import SwiftUI

enum Theme {
    static let bg = Color(red: 0.043, green: 0.039, blue: 0.031)
    static let bgSoft = Color(red: 0.078, green: 0.071, blue: 0.055)
    static let panel = Color(red: 0.106, green: 0.094, blue: 0.071)
    static let panelBorder = Color(red: 0.184, green: 0.165, blue: 0.122)
    static let ink = Color(red: 0.953, green: 0.929, blue: 0.882)
    static let inkDim = Color(red: 0.722, green: 0.682, blue: 0.596)
    static let gold = Color(red: 0.831, green: 0.686, blue: 0.216)
    static let goldSoft = Color(red: 0.910, green: 0.780, blue: 0.396)
    static let danger = Color(red: 0.753, green: 0.314, blue: 0.247)
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(Theme.ink)
            .background(
                Capsule()
                    .fill(configuration.isPressed ? Theme.gold.opacity(0.12) : Color.clear)
                    .overlay(Capsule().stroke(configuration.isPressed ? Theme.gold : Theme.panelBorder, lineWidth: 1))
            )
    }
}
