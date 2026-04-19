//
//  QuestionEditorView.swift
//  HideAndCSeek50
//
//  Edits a single question inside the parent category's draft. For
//  multiple-choice, renders a reorderable list of choices with add/delete;
//  the answer UI in game chat reads these choices directly at runtime.
//

import SwiftUI

struct QuestionEditorView: View {
    @Binding var question: CustomQuestion
    let isLocked: Bool

    var body: some View {
        Form {
            Section("Question") {
                TextField("Ask something…", text: $question.text, axis: .vertical)
                    .lineLimit(2...6)
                    .disabled(isLocked)
            }

            Section("Type") {
                Picker("Type", selection: $question.questionType) {
                    ForEach(QuestionType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.iconName)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isLocked)
                .onChange(of: question.questionType) { _, newValue in
                    // Seed sensible defaults when switching types so the editor isn't empty.
                    if newValue == .multipleChoice && question.choices.count < 2 {
                        question.choices = ["Yes", "No"]
                    }
                    if newValue != .multipleChoice {
                        question.choices = []
                    }
                }
            }

            if question.questionType == .multipleChoice {
                Section {
                    ForEach(question.choices.indices, id: \.self) { index in
                        HStack {
                            TextField("Choice \(index + 1)", text: Binding(
                                get: { question.choices[index] },
                                set: { question.choices[index] = $0 }
                            ))
                            .disabled(isLocked)

                            if !isLocked && question.choices.count > 2 {
                                Button {
                                    question.choices.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .onMove(perform: isLocked ? nil : { from, to in
                        question.choices.move(fromOffsets: from, toOffset: to)
                    })

                    if !isLocked {
                        Button {
                            question.choices.append("")
                        } label: {
                            Label("Add Choice", systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text("Choices")
                } footer: {
                    Text("Hiders pick one of these. Minimum two.")
                }
            } else if question.questionType == .shortAnswer {
                Section {
                    Text("Hiders type a free-text answer.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else {
                Section {
                    Text("Hiders submit a photo.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Question")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isLocked && question.questionType == .multipleChoice {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}
