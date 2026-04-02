import SwiftUI

struct TopologyView: View {
    @EnvironmentObject var device: DeviceManager
    let expandedKey: String?
    let onSelectButton: (String) -> Void

    private let k: CGFloat = 44
    private let g: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: XPSpacing.s4) {
            XPCategoryHeader(title: "Visual Topology Reference")

            let col = { (c: Int) -> CGFloat in CGFloat(c) * (k + g) }
            let row = { (r: Int) -> CGFloat in CGFloat(r) * (k + g) }

            let swDiameter: CGFloat = k * 2 + g  // circle spanning 2 rows
            let swGap: CGFloat = g * 3
            let ox = swDiameter + swGap            // grid X offset
            let gridW = k * 4 + g * 3
            let totalW = ox + gridW
            let gridH = k * 3 + g * 2

            ZStack(alignment: .topLeading) {
                // Scroll wheel — outer ring (selects scroll wheel card)
                Button { onSelectButton("scroll_wheel") } label: {
                    Circle()
                        .fill(scrollActive ? Color.xpPrimary.opacity(0.10) : Color.xpSurfaceContainerHighest.opacity(0.5))
                        .frame(width: swDiameter, height: swDiameter)
                        .overlay(
                            Circle()
                                .stroke(scrollActive ? Color.xpPrimary : Color.xpOutlineVariant.opacity(0.2), lineWidth: scrollActive ? 2.5 : 1)
                        )
                }
                .buttonStyle(.plain)

                // Scroll button — inner circle (selects scroll button card)
                Button { onSelectButton("000400000000") } label: {
                    Circle()
                        .fill(isActive("000400000000") ? Color.xpPrimary.opacity(0.18) : Color.xpSurfaceContainerHigh)
                        .frame(width: swDiameter * 0.38, height: swDiameter * 0.38)
                        .overlay(
                            Circle()
                                .stroke(isActive("000400000000") ? Color.xpPrimary.opacity(0.5) : Color.xpOutlineVariant.opacity(0.15), lineWidth: isActive("000400000000") ? 2 : 1)
                        )
                }
                .buttonStyle(.plain)
                .offset(x: swDiameter * 0.31, y: swDiameter * 0.31)

                // Grid keys
                tKey("010000000000", "TL", w: k, h: k).offset(x: ox + col(0), y: row(0))
                tKey("020000000000", "TM", w: k, h: k).offset(x: ox + col(1), y: row(0))
                tKey("040000000000", "TR", w: k, h: k).offset(x: ox + col(2), y: row(0))
                tKey("400000000000", "R",  w: k, h: k * 2 + g).offset(x: ox + col(3), y: row(0))

                tKey("080000000000", "ML", w: k, h: k).offset(x: ox + col(0), y: row(1))
                tKey("100000000000", "MC", w: k, h: k).offset(x: ox + col(1), y: row(1))
                tKey("200000000000", "MR", w: k, h: k).offset(x: ox + col(2), y: row(1))

                tKey("800000000000", "BL", w: k, h: k).offset(x: ox + col(0), y: row(2))
                tKey("000100000000", "BC", w: k * 2 + g, h: k).offset(x: ox + col(1), y: row(2))
                tKey("000200000000", "BR", w: k, h: k).offset(x: ox + col(3), y: row(2))
            }
            .frame(width: totalW, height: gridH)
            .frame(maxWidth: .infinity)

            HStack(spacing: XPSpacing.s4) {
                legendItem(Circle().stroke(Color.xpPrimary, lineWidth: 2).frame(width: 8, height: 8), "Active Selection")
                legendItem(RoundedRectangle(cornerRadius: 2).fill(Color.xpSurfaceContainerHighest.opacity(0.5)).frame(width: 8, height: 8), "Available Inputs")
            }
            .padding(.top, XPSpacing.s2)
        }
        .padding(XPSpacing.s6)
        .frame(maxWidth: .infinity)
        .background(Color.xpSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: XPRadius.xl))
    }

    private var scrollActive: Bool {
        isActive("scroll_wheel") || isActive("000400000000") || isActive("scroll_cw") || isActive("scroll_ccw")
    }

    private func isActive(_ key: String) -> Bool {
        if device.activeKey == key { return true }
        // Highlight if this key's card is the expanded accordion item
        if let ex = expandedKey {
            if key == "scroll_wheel" && ex == "scroll_wheel" { return true }
            if key == "000400000000" && ex == "000400000000" { return true }
            if ex == key { return true }
        }
        return false
    }

    @ViewBuilder
    private func tKey(_ key: String, _ label: String, w: CGFloat, h: CGFloat) -> some View {
        let active = isActive(key)
        Button { onSelectButton(key) } label: {
            RoundedRectangle(cornerRadius: 6)
                .fill(active ? Color.xpPrimary.opacity(0.12) : Color.xpSurfaceContainerHighest.opacity(0.5))
                .frame(width: w, height: h)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(active ? Color.xpPrimary : Color.xpOutlineVariant.opacity(0.2), lineWidth: active ? 2.5 : 1)
                )
                .overlay(
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(active ? .xpPrimary : .xpOnSurfaceVariant.opacity(0.6))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func legendItem<S: View>(_ icon: S, _ text: String) -> some View {
        HStack(spacing: XPSpacing.s1) {
            icon
            Text(text).font(XPFont.labelSm()).foregroundColor(.xpOnSurfaceVariant)
        }
    }
}
