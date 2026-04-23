//
//  CardDecksListView.swift
//  HideAndCSeek50
//

import SwiftUI
import FirebaseAuth

struct CardDecksListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CardDecksViewModel()

    @State private var showingCreatePrompt = false
    @State private var newDeckName = ""
    @State private var selectedDeck: CardDeck?
    @State private var renamingDeck: CardDeck?
    @State private var renameText = ""
    @State private var deletingDeckId: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading decks…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.decks.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.draw")
                                    .foregroundColor(.secondary)
                                Text("Swipe left to delete or rename. Swipe right to duplicate.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                            .listRowBackground(Color(.systemGroupedBackground))
                        }

                        ForEach(viewModel.decks) { deck in
                            deckRow(deck)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedDeck = deck }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if !deck.isDefault {
                                        Button(role: .destructive) {
                                            deletingDeckId = deck.id
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }

                                        Button {
                                            renamingDeck = deck
                                            renameText = deck.name
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        Task { await duplicateDeck(deck) }
                                    } label: {
                                        Label("Duplicate", systemImage: "doc.on.doc")
                                    }
                                    .tint(.green)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Card Decks")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newDeckName = ""
                        showingCreatePrompt = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedDeck) { deck in
                CardDeckEditorView(deck: deck)
                    .environmentObject(viewModel)
            }
            .alert("New Deck", isPresented: $showingCreatePrompt) {
                TextField("Deck name", text: $newDeckName)
                Button("Create") { Task { await createDeck() } }
                    .disabled(newDeckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for your new card deck.")
            }
            .alert("Rename Deck", isPresented: .constant(renamingDeck != nil)) {
                TextField("New name", text: $renameText)
                Button("Save") { Task { await renameDeck() } }
                Button("Cancel", role: .cancel) { renamingDeck = nil }
            } message: {
                Text("Enter a new name for \"\(renamingDeck?.name ?? "")\".")
            }
            .alert("Delete Deck?", isPresented: .constant(deletingDeckId != nil)) {
                Button("Delete", role: .destructive) { Task { await deleteDeck() } }
                Button("Cancel", role: .cancel) { deletingDeckId = nil }
            } message: {
                Text("This cannot be undone.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage { Text(errorMessage) }
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
    }

    // MARK: - Deck Row

    private func deckRow(_ deck: CardDeck) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(deck.isDefault ? Color.indigo.opacity(0.15) : Color(.systemGray6))
                    .frame(width: 44, height: 44)
                Image(systemName: deck.isDefault ? "rectangle.stack.fill" : "rectangle.stack")
                    .font(.title3)
                    .foregroundColor(deck.isDefault ? .indigo : .primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(deck.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    if deck.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.15))
                            .foregroundColor(.indigo)
                            .cornerRadius(4)
                    }
                }
                Text("\(deck.cardCount) cards, \(deck.uniqueCardCount) unique")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Updated \(deck.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Card Decks")
                .font(.headline)
            Text("Create your first deck to customize the cards used during a game.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Create Deck") {
                newDeckName = ""
                showingCreatePrompt = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func createDeck() async {
        let trimmed = newDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let newDeck = try await viewModel.createDeck(name: trimmed)
            await MainActor.run { selectedDeck = newDeck }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func renameDeck() async {
        guard let deck = renamingDeck else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { renamingDeck = nil; return }
        do {
            try await viewModel.renameDeck(id: deck.id, to: trimmed)
            await MainActor.run { renamingDeck = nil }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func deleteDeck() async {
        guard let id = deletingDeckId else { return }
        do {
            try await viewModel.deleteDeck(id: id)
            await MainActor.run { deletingDeckId = nil }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                deletingDeckId = nil
            }
        }
    }

    private func duplicateDeck(_ deck: CardDeck) async {
        do {
            let _ = try await viewModel.duplicateDeck(deck, newName: "\(deck.name) Copy")
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

#Preview {
    CardDecksListView()
}
