//
//  CategoryEditorView.swift
//  HideAndCSeek50
//
//  Edits a single category inside the parent set's draft. Binds directly to
//  the parent's `QuestionCategoryDef` so edits flow back without an
//  intermediate save step — the parent's Save button commits the whole set.
//

import SwiftUI

struct CategoryEditorView: View {
    @Binding var category: QuestionCategoryDef
    let isLocked: Bool

    @State private var showingAddQuestionSheet = false
    @State private var newQuestionText: String = ""

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private let timeRange: ClosedRange<Double> = 30...1800

    var body: some View {
        Form {
            nameSection
            iconSection
            rewardSection
            timerSection
            questionsSection
        }
        .navigationTitle(category.name.isEmpty ? "Category" : category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isLocked {
                    EditButton()
                }
            }
        }
        .alert("Add Question", isPresented: $showingAddQuestionSheet) {
            TextField("Question text", text: $newQuestionText)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let trimmed = newQuestionText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                addQuestion(text: trimmed)
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("Category name", text: $category.name)
                .disabled(isLocked)
        }
    }

    private var iconSection: some View {
        Section("Icon") {
            LazyVGrid(columns: iconColumns, spacing: 8) {
                ForEach(CategoryIcon.all, id: \.self) { symbol in
                    let isSelected = category.iconName == symbol
                    Button {
                        if !isLocked { category.iconName = symbol }
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 18))
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.blue.opacity(0.25) : Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            .foregroundColor(isSelected ? .blue : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var rewardSection: some View {
        Section {
            Stepper(value: $category.drawCount, in: 1...10) {
                HStack {
                    Text("Draw")
                    Spacer()
                    Text("\(category.drawCount)")
                        .foregroundColor(.secondary)
                }
            }
            .disabled(isLocked)
            .onChange(of: category.drawCount) { _, newValue in
                if category.keepCount > newValue {
                    category.keepCount = newValue
                }
            }

            Stepper(value: $category.keepCount, in: 1...max(1, category.drawCount)) {
                HStack {
                    Text("Keep")
                    Spacer()
                    Text("\(category.keepCount)")
                        .foregroundColor(.secondary)
                }
            }
            .disabled(isLocked)
        } header: {
            Text("Reward")
        } footer: {
            Text("Preview: \(category.rewardPreview)")
        }
    }

    private var timerSection: some View {
        Section {
            Slider(
                value: Binding(
                    get: { Double(category.timeLimitSeconds) },
                    set: { category.timeLimitSeconds = Int($0) }
                ),
                in: timeRange,
                step: 15
            )
            .disabled(isLocked)

            HStack {
                Text("Time limit")
                Spacer()
                Text(formattedTime(category.timeLimitSeconds))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Timer")
        } footer: {
            Text("Hiders have this long to answer any question in this category.")
        }
    }

    private var questionsSection: some View {
        Section {
            ForEach($category.questions) { $question in
                NavigationLink {
                    QuestionEditorView(question: $question, isLocked: isLocked)
                } label: {
                    QuestionRow(question: question)
                }
            }
            .onDelete { offsets in
                if !isLocked { deleteQuestions(at: offsets) }
            }
            .onMove { source, destination in
                if !isLocked { moveQuestions(from: source, to: destination) }
            }
            .deleteDisabled(isLocked)
            .moveDisabled(isLocked)

            if !isLocked {
                Button {
                    newQuestionText = ""
                    showingAddQuestionSheet = true
                } label: {
                    Label("Add Question", systemImage: "plus.circle.fill")
                }
            }
        } header: {
            Text("Questions (\(category.questions.count))")
        } footer: {
            if category.questions.isEmpty {
                Text("A category needs at least one question.")
            }
        }
    }

    private func addQuestion(text: String) {
        let question = CustomQuestion(
            id: UUID().uuidString,
            text: text,
            questionType: .multipleChoice,
            choices: ["Yes", "No"]
        )
        category.questions.append(question)
    }

    private func deleteQuestions(at offsets: IndexSet) {
        category.questions.remove(atOffsets: offsets)
    }

    private func moveQuestions(from: IndexSet, to: Int) {
        category.questions.move(fromOffsets: from, toOffset: to)
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 && s > 0 { return "\(m)m \(s)s" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
}

private struct QuestionRow: View {
    let question: CustomQuestion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: question.questionType.iconName)
                .foregroundColor(.purple)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(question.text)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(question.questionType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
