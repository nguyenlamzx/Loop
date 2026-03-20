//
//  LayoutOverlayView.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import SwiftUI

/// The overlay view that displays all layout zones on screen.
/// User clicks a zone → frontmost window snaps to that zone.
struct LayoutOverlayView: View {
    let layout: SavedLayout
    let screenFrame: CGRect // cgSafeScreenFrame of target screen
    let onZoneClicked: (LayoutZone) -> Void
    let onDismiss: () -> Void

    @State private var filledZoneIDs: Set<UUID> = []
    @State private var hoveredZoneID: UUID?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.3)
                    .onTapGesture {
                        onDismiss()
                    }

                // Zone rectangles
                ForEach(layout.zones) { zone in
                    let rect = zoneRect(zone, in: geometry.size)
                    let isFilled = filledZoneIDs.contains(zone.id)
                    let isHovered = hoveredZoneID == zone.id

                    ZoneView(
                        zone: zone,
                        index: layout.zones.firstIndex(where: { $0.id == zone.id })! + 1,
                        isFilled: isFilled,
                        isHovered: isHovered
                    )
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .onHover { hovering in
                        hoveredZoneID = hovering ? zone.id : nil
                    }
                    .onTapGesture {
                        guard !isFilled else { return }
                        withAnimation(.spring(response: 0.3)) {
                            filledZoneIDs.insert(zone.id)
                        }
                        onZoneClicked(zone)

                        // Auto-dismiss when all zones are filled
                        if filledZoneIDs.count == layout.zones.count {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                onDismiss()
                            }
                        }
                    }
                }

                // Layout name + instructions
                VStack(spacing: 8) {
                    Text(layout.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Click a zone to snap the frontmost window")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Press ESC to dismiss")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .position(x: geometry.size.width / 2, y: 50)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    private func zoneRect(_ zone: LayoutZone, in size: CGSize) -> CGRect {
        CGRect(
            x: zone.frame.minX * size.width,
            y: zone.frame.minY * size.height,
            width: zone.frame.width * size.width,
            height: zone.frame.height * size.height
        )
    }
}

/// Individual zone visual
struct ZoneView: View {
    let zone: LayoutZone
    let index: Int
    let isFilled: Bool
    let isHovered: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(fillColor)

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: isFilled ? 3 : 2)

            VStack(spacing: 4) {
                Text("Zone \(index)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                if isFilled {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(4)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.3), value: isFilled)
    }

    private var fillColor: Color {
        if isFilled {
            return .green.opacity(0.15)
        } else if isHovered {
            return .blue.opacity(0.3)
        } else {
            return .white.opacity(0.08)
        }
    }

    private var borderColor: Color {
        if isFilled {
            return .green.opacity(0.6)
        } else if isHovered {
            return .blue.opacity(0.8)
        } else {
            return .white.opacity(0.3)
        }
    }
}
