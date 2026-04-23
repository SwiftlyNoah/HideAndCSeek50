//
//  CardDeckEditorView.swift
//  HideAndCSeek50
//

import SwiftUI

struct CardDeckEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CardDecksViewModel

    let sourceDeck: CardDeck

    @State private var name: String
    @State private var entries: [CardDeckEntry]
    @State private var showingAddCard = false
    @State private var editingEntry: CardDeckEntry?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingDeleteConfirm = false
    @State private var showingDuplicatePrompt = false
    @State private var duplicateName: String = ""

    private let maxTotalCards = 500

    init(deck: CardDeck) {
        self.sourceDeck = deck
        _name = State(initialValue: deck.name)
        _entries = State(initialValue: deck.entries)
    }

    private var totalCardCount: Int {
        entries.reduce(0) { $0 + $1.multiplier }
    }

    private var hasChanges: Bool {
        name != sourceDeck.name || entries != sourceDeck.entries
    }

    private var isDefault: Bool { sourceDeck.isDefault }

    var body: some View {
        NavigationStack {
            Form {
                if isDefault {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Default Deck — Read Only")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Duplicate to create an editable copy.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Duplicate") {
                                duplicateName = "\(sourceDeck.name) Copy"
                                showingDuplicatePrompt = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Name") {
                    TextField("Deck Name", text: $name)
                        .disabled(isDefault)
                }

                Section {
                    if entries.isEmpty {
                        Text("No cards yet. Tap + to add cards.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(entries) { entry in
                            entryRow(entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !isDefault { editingEntry = entry }
                                }
                        }
                        .onDelete { offsets in
                            if !isDefault { entries.remove(atOffsets: offsets) }
                        }
                        .onMove { from, to in
                            if !isDefault { entries.move(fromOffsets: from, toOffset: to) }
                        }
                        .deleteDisabled(isDefault)
                        .moveDisabled(isDefault)
                    }
                } header: {
                    HStack {
                        Text("Cards")
                        Spacer()
                        Text("\(totalCardCount) total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !isDefault {
                    Section {
                        Button {
                            showingAddCard = true
                        } label: {
                            Label("Add Card", systemImage: "plus.circle.fill")
                        }
                        .disabled(totalCardCount >= maxTotalCards)
                    }

                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete Deck", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                #if DEBUG
                Section("Debug") {
                    Text("Deck id: \(sourceDeck.id.prefix(8))…  Unique: \(entries.count)  Total: \(totalCardCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                #endif
            }
            .navigationTitle(isDefault ? CardDeck.defaultName : (name.isEmpty ? "New Deck" : name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }

                if !isDefault {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { Task { await saveDeck() } }
                            .fontWeight(.semibold)
                            .disabled(!hasChanges || isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showingAddCard) {
                CardEditorView { card, multiplier in
                    let entry = CardDeckEntry(id: UUID().uuidString, card: card, multiplier: multiplier)
                    entries.append(entry)
                }
            }
            .sheet(item: $editingEntry) { entry in
                CardEditorView(entry: entry) { updatedCard, updatedMultiplier in
                    if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                        entries[idx] = CardDeckEntry(id: entry.id, card: updatedCard, multiplier: updatedMultiplier)
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage { Text(errorMessage) }
            }
            .alert("Duplicate Deck", isPresented: $showingDuplicatePrompt) {
                TextField("New deck name", text: $duplicateName)
                Button("Duplicate") { Task { await duplicateDeck() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Name your duplicate deck:")
            }
            .alert("Delete Deck?", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) { Task { await deleteDeck() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\"\(name)\" will be permanently deleted. This cannot be undone.")
            }
        }
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: CardDeckEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.card.type.iconName)
                .foregroundColor(entry.card.type.themeColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.card.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(entry.card.displaySubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if entry.card.type == .curse, let cost = entry.card.castingCost {
                    Text("Cost: \(cost)")
                        .font(.caption2)
                        .foregroundColor(CardType.curse.themeColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("×\(entry.multiplier)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func removeEntry(id: String) {
        entries.removeAll { $0.id == id }
    }

    private func saveDeck() async {
        isSaving = true
        var updated = sourceDeck
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.entries = entries
        do {
            try await viewModel.updateDeck(updated)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func deleteDeck() async {
        isSaving = true
        do {
            try await viewModel.deleteDeck(id: sourceDeck.id)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func duplicateDeck() async {
        let trimmed = duplicateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let _ = try await viewModel.duplicateDeck(sourceDeck, newName: trimmed)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
