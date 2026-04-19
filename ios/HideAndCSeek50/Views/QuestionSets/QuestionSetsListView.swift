//
//  QuestionSetsListView.swift
//  HideAndCSeek50
//
//  Lists the signed-in user's question sets. Default set is locked from
//  rename/delete; everything else supports rename, duplicate, delete.
//

import SwiftUI
import FirebaseAuth

struct QuestionSetsListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QuestionSetsViewModel()

    @State private var setToRename: QuestionSet?
    @State private var renameText: String = ""

    @State private var setToDuplicate: QuestionSet?
    @State private var duplicateText: String = ""

    @State private var showingCreateSheet = false
    @State private var newSetName: String = ""

    @State private var setPendingDelete: QuestionSet?

    @State private var editorTarget: QuestionSet?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Question Sets")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            newSetName = ""
                            showingCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .onAppear {
                    if let uid = Auth.auth().currentUser?.uid {
                        viewModel.startListening(uid: uid)
                    }
                }
                .onDisappear {
                    viewModel.stopListening()
                }
                .sheet(item: $editorTarget) { set in
                    QuestionSetEditorView(set: set, viewModel: viewModel)
                }
                .alert("New Question Set", isPresented: $showingCreateSheet) {
                    TextField("Name", text: $newSetName)
                    Button("Cancel", role: .cancel) {}
                    Button("Create") {
                        let trimmed = newSetName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        Task {
                            if let created = try? await viewModel.createSet(name: trimmed) {
                                editorTarget = created
                            }
                        }
                    }
                } message: {
                    Text("Give your set a name. You can add categories and questions next.")
                }
                .alert("Rename Set", isPresented: Binding(
                    get: { setToRename != nil },
                    set: { if !$0 { setToRename = nil } }
                )) {
                    TextField("Name", text: $renameText)
                    Button("Cancel", role: .cancel) { setToRename = nil }
                    Button("Save") {
                        guard let target = setToRename else { return }
                        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        setToRename = nil
                        guard !trimmed.isEmpty else { return }
                        Task { try? await viewModel.renameSet(id: target.id, to: trimmed) }
                    }
                }
                .alert("Duplicate Set", isPresented: Binding(
                    get: { setToDuplicate != nil },
                    set: { if !$0 { setToDuplicate = nil } }
                )) {
                    TextField("Name", text: $duplicateText)
                    Button("Cancel", role: .cancel) { setToDuplicate = nil }
                    Button("Duplicate") {
                        guard let source = setToDuplicate else { return }
                        let trimmed = duplicateText.trimmingCharacters(in: .whitespacesAndNewlines)
                        setToDuplicate = nil
                        guard !trimmed.isEmpty else { return }
                        Task {
                            if let copy = try? await viewModel.duplicateSet(source, newName: trimmed) {
                                editorTarget = copy
                            }
                        }
                    }
                }
                .confirmationDialog(
                    "Delete \"\(setPendingDelete?.name ?? "")\"?",
                    isPresented: Binding(
                        get: { setPendingDelete != nil },
                        set: { if !$0 { setPendingDelete = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        guard let target = setPendingDelete else { return }
                        setPendingDelete = nil
                        Task { try? await viewModel.deleteSet(id: target.id) }
                    }
                    Button("Cancel", role: .cancel) { setPendingDelete = nil }
                } message: {
                    Text("This cannot be undone.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.sets.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.sets.isEmpty {
            ContentUnavailableView(
                "No Question Sets",
                systemImage: "list.bullet.rectangle",
                description: Text("Tap + to create your first set.")
            )
        } else {
            List {
                ForEach(viewModel.sets) { set in
                    Button {
                        if !set.isDefault { editorTarget = set }
                    } label: {
                        QuestionSetRow(set: set)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !set.isDefault {
                            Button(role: .destructive) {
                                setPendingDelete = set
                            } label: { Label("Delete", systemImage: "trash") }

                            Button {
                                renameText = set.name
                                setToRename = set
                            } label: { Label("Rename", systemImage: "pencil") }
                            .tint(.blue)
                        }

                        Button {
                            duplicateText = "\(set.name) Copy"
                            setToDuplicate = set
                        } label: { Label("Duplicate", systemImage: "doc.on.doc") }
                        .tint(.purple)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct QuestionSetRow: View {
    let set: QuestionSet

    private var lastEditedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: set.updatedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "list.bullet.rectangle.fill")
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(set.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if set.isDefault {
                        Text("DEFAULT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Label("\(set.categories.count) categories", systemImage: "folder.fill")
                    Text("•")
                    Label("\(set.questionCount) questions", systemImage: "questionmark.bubble.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text("Edited \(lastEditedText)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !set.isDefault {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    QuestionSetsListView()
}
