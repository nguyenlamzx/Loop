//
//  WorkspaceConfigurationView.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import Defaults
import Luminare
import SwiftUI

/// Full workspace management view accessible from Settings.
/// Allows users to list, save, restore, rename, and delete workspaces.
struct WorkspaceConfigurationView: View {
    @Binding var isPresented: Bool
    @Default(.savedWorkspaces) var savedWorkspaces
    @State private var newWorkspaceName: String = ""
    @State private var editingWorkspaceID: UUID?
    @State private var editingName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Workspaces")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Save current workspace
            HStack(spacing: 8) {
                TextField("Workspace name…", text: $newWorkspaceName)
                    .textFieldStyle(.roundedBorder)

                Button("Save Current") {
                    saveCurrentWorkspace()
                }
                .disabled(newWorkspaceName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            // Workspace list
            if savedWorkspaces.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No saved workspaces")
                        .foregroundStyle(.secondary)
                    Text("Arrange your windows, then save the layout above.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(savedWorkspaces) { workspace in
                            WorkspaceRowView(
                                workspace: workspace,
                                isEditing: editingWorkspaceID == workspace.id,
                                editingName: $editingName,
                                onRestore: { restoreWorkspace(workspace) },
                                onRename: { startRenaming(workspace) },
                                onCommitRename: { commitRename(workspace) },
                                onDelete: { deleteWorkspace(workspace) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 420, height: 400)
    }

    private func saveCurrentWorkspace() {
        let name = newWorkspaceName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        WorkspaceManager.saveCurrentWorkspace(name: name)
        newWorkspaceName = ""
    }

    private func restoreWorkspace(_ workspace: SavedWorkspace) {
        WorkspaceManager.restoreWorkspace(workspace)
    }

    private func startRenaming(_ workspace: SavedWorkspace) {
        editingWorkspaceID = workspace.id
        editingName = workspace.name
    }

    private func commitRename(_ workspace: SavedWorkspace) {
        let name = editingName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            editingWorkspaceID = nil
            return
        }

        WorkspaceManager.renameWorkspace(id: workspace.id, to: name)
        editingWorkspaceID = nil
    }

    private func deleteWorkspace(_ workspace: SavedWorkspace) {
        WorkspaceManager.deleteWorkspace(id: workspace.id)
    }
}

struct WorkspaceRowView: View {
    let workspace: SavedWorkspace
    let isEditing: Bool
    @Binding var editingName: String

    let onRestore: () -> Void
    let onRename: () -> Void
    let onCommitRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: "rectangle.3.group.fill")
                .foregroundStyle(.blue)
                .frame(width: 20)

            // Name + info
            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Name", text: $editingName, onCommit: onCommitRename)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, weight: .medium))
                } else {
                    Text(workspace.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }

                Text("\(workspace.windows.count) windows • \(formattedDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
            HStack(spacing: 4) {
                Button {
                    onRestore()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .help("Restore this workspace")
                }
                .buttonStyle(.plain)

                Button {
                    if isEditing {
                        onCommitRename()
                    } else {
                        onRename()
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .help(isEditing ? "Save name" : "Rename")
                }
                .buttonStyle(.plain)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .help("Delete workspace")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: workspace.createdAt)
    }
}
