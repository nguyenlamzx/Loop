//
//  LayoutPickerView.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import Defaults
import SwiftUI

/// A centered HUD showing all saved layouts as cards.
/// User clicks one to assign it to the current screen.
/// Triggered via Trigger + W (restoreWorkspace action).
struct LayoutPickerView: View {
    let layouts: [SavedLayout]
    let currentScreenName: String
    let onSelect: (SavedLayout) -> Void
    let onRemove: () -> Void
    let onDismiss: () -> Void

    @State private var hoveredLayoutID: UUID?

    private var activeLayoutID: String? {
        Defaults[.activeLayoutPerScreen][currentScreenName]
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .onTapGesture { onDismiss() }

            // Picker card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Select Layout")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Text(currentScreenName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.1), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                    .overlay(Color.white.opacity(0.1))

                if layouts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.dashed")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.3))

                        Text("No layouts saved yet")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))

                        Text("Use \"Save Layout\" from menubar")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(.vertical, 30)
                } else {
                    // Layout grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(layouts) { layout in
                            let isActive = activeLayoutID == layout.id.uuidString
                            let isHovered = hoveredLayoutID == layout.id

                            LayoutCard(
                                layout: layout,
                                isActive: isActive,
                                isHovered: isHovered
                            )
                            .onTapGesture {
                                onSelect(layout)
                            }
                            .onHover { hovering in
                                hoveredLayoutID = hovering ? layout.id : nil
                            }
                        }
                    }
                    .padding(16)
                }

                // Footer
                if activeLayoutID != nil {
                    Divider()
                        .overlay(Color.white.opacity(0.1))

                    Button {
                        onRemove()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Remove Layout from Screen")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }

                // ESC hint
                Text("ESC to close")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 10)
            }
            .frame(width: 360)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

/// A card representing a saved layout with a mini zone preview
struct LayoutCard: View {
    let layout: SavedLayout
    let isActive: Bool
    let isHovered: Bool

    private var fillColor: Color {
        if isActive {
            return Color.blue.opacity(0.1)
        } else if isHovered {
            return Color.white.opacity(0.08)
        } else {
            return Color.white.opacity(0.04)
        }
    }

    private var borderColor: Color {
        if isActive {
            return Color.blue.opacity(0.4)
        } else if isHovered {
            return Color.white.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            zonePreview
            nameRow
            descriptionRow
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(fillColor))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(borderColor, lineWidth: 1))
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var zonePreview: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(layout.zones) { zone in
                    zoneRect(zone, in: geometry.size)
                }
            }
        }
        .frame(height: 60)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private func zoneRect(_ zone: LayoutZone, in size: CGSize) -> some View {
        let rect = CGRect(
            x: zone.frame.minX * size.width,
            y: zone.frame.minY * size.height,
            width: zone.frame.width * size.width,
            height: zone.frame.height * size.height
        )
        let zoneFill = isActive ? Color.blue.opacity(0.3) : Color.white.opacity(0.1)
        let zoneBorder = isActive ? Color.blue.opacity(0.6) : Color.white.opacity(0.2)

        return RoundedRectangle(cornerRadius: 4)
            .fill(zoneFill)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(zoneBorder, lineWidth: 1))
            .frame(width: max(rect.width - 2, 0), height: max(rect.height - 2, 0))
            .position(x: rect.midX, y: rect.midY)
    }

    private var nameRow: some View {
        HStack {
            Text(layout.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
        }
    }

    private var descriptionRow: some View {
        Text(layout.zoneDescription)
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
