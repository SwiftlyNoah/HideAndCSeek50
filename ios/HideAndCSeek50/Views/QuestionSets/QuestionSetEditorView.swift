//
//  QuestionSetEditorView.swift
//  HideAndCSeek50
//
//  Single-set editor. Works on a local `draft` copy; Save commits the full
//  set back through the view model. Default sets open read-only — the banner
//  offers Duplicate, which creates an editable copy and swaps the editor
//  into that copy in place.
//

import SwiftUI

struct QuestionSetEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: QuestionSetsViewModel

    @State private var draft: QuestionSet
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingAddCategorySheet = false
    @State private var newCategoryName: String = ""
    @State private var showingDuplicatePrompt = false
    @State private var duplicateName: String = ""

    init(set: QuestionSet, viewModel: QuestionSetsViewModel) {
        self.viewModel = viewModel
        self._draft = State(initialValue: set)
    }

    private var isLocked: Bool { draft.isDefault }

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle(draft.name.isEmpty ? "Question Set" : draft.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        saveButton
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        editButton
                    }
                }
                .alert("Add Category", isPresented: $showingAddCategorySheet) {
                    TextField("Category name", text: $newCategoryName)
                    Button("Cancel", role: .cancel) {}
                    Button("Add") {
                        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        addCategory(named: trimmed)
                    }
                }
                .alert("Duplicate Set", isPresented: $showingDuplicatePrompt) {
                    TextField("New set name", text: $duplicateName)
                    Button("Duplicate") {
                        let trimmed = duplicateName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        duplicateIntoEditableCopy(name: trimmed)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Name your duplicate set:")
                }
        }
    }

    // MARK: - Form content

    private var formContent: some View {
        Form {
            if isLocked {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Set — Read Only")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Duplicate to create an editable copy.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Duplicate") {
                            duplicateName = "\(draft.name) Copy"
                            showingDuplicatePrompt = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Name") {
                TextField("Set name", text: $draft.name)
                    .disabled(isLocked)
            }

            categoriesSection

            errorSection
        }
    }

    private var categoriesSection: some View {
        Section {
            ForEach($draft.categories) { $category in
                NavigationLink {
                    CategoryEditorView(category: $category, isLocked: isLocked)
                } label: {
                    CategoryRow(category: category)
                }
            }
            .onDelete { offsets in
                if !isLocked { deleteCategories(at: offsets) }
            }
            .onMove { source, destination in
                if !isLocked { moveCategories(from: source, to: destination) }
            }
            .deleteDisabled(isLocked)
            .moveDisabled(isLocked)

            if !isLocked {
                Button {
                    newCategoryName = ""
                    showingAddCategorySheet = true
                } label: {
                    Label("Add Category", systemImage: "plus.circle.fill")
                }
            }
        } header: {
            Text("Categories")
        } footer: {
            if draft.categories.isEmpty {
                Text("A set needs at least one category with one question before you can use it in a game.")
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage {
            Section {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
    }

    // MARK: - Toolbar views

    @ViewBuilder
    private var saveButton: some View {
        if isLocked {
            EmptyView()
        } else if isSaving {
            ProgressView()
        } else {
            Button("Save") { save() }
                .fontWeight(.semibold)
                .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private var editButton: some View {
        if !isLocked {
            EditButton()
        }
    }

    // MARK: - Mutations

    private func addCategory(named name: String) {
        let newCategory = QuestionCategoryDef(
            id: UUID().uuidString,
            name: name,
            iconName: CategoryIcon.fallback,
            drawCount: 2,
            keepCount: 1,
            timeLimitSeconds: 300,
            questions: []
        )
        draft.categories.append(newCategory)
    }

    private func deleteCategories(at offsets: IndexSet) {
        draft.categories.remove(atOffsets: offsets)
    }

    private func moveCategories(from: IndexSet, to: Int) {
        draft.categories.move(fromOffsets: from, toOffset: to)
    }

    // MARK: - Persistence

    private func save() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await viewModel.updateSet(draft)
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = "Couldn't save: \(error.localizedDescription)"
            }
        }
    }

    private func duplicateIntoEditableCopy(name: String) {
        Task {
            do {
                let _ = try await viewModel.duplicateSet(draft, newName: name)
                dismiss()
            } catch {
                errorMessage = "Couldn't duplicate: \(error.localizedDescription)"
            }
        }
    }
}

private struct CategoryRow: View {
    let category: QuestionCategoryDef

    private var timeText: String {
        let m = category.timeLimitSeconds / 60
        let s = category.timeLimitSeconds % 60
        if m > 0 && s > 0 { return "\(m)m \(s)s" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: category.iconName)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: 6) {
                    Text(category.rewardPreview)
                    Text("•")
                    Text(timeText)
                    Text("•")
                    Text("\(category.questions.count) q")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
