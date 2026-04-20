//
//  CardEditorView.swift
//  HideAndCSeek50
//

import SwiftUI

struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    let onSave: (CustomCard, Int) -> Void

    // Shared
    @State private var type: CardType

    // Curse
    @State private var curseTitle: String
    @State private var curseDescription: String
    @State private var castingCost: String

    // Powerup
    @State private var powerupTitle: String
    @State private var powerupDescription: String

    // Time Bonus
    @State private var timeBonusMinutes: Int

    // Multiplier
    @State private var multiplier: Int

    // Preserved original id so edits don't mint a new id
    private let existingCardId: String

    init(entry: CardDeckEntry? = nil, onSave: @escaping (CustomCard, Int) -> Void) {
        self.isNew = (entry == nil)
        self.onSave = onSave

        let card = entry?.card
        existingCardId = card?.id ?? UUID().uuidString

        _type = State(initialValue: card?.type ?? .powerup)
        _curseTitle = State(initialValue: card?.curseTitle ?? "")
        _curseDescription = State(initialValue: card?.curseDescription ?? "")
        _castingCost = State(initialValue: card?.castingCost ?? "")
        _powerupTitle = State(initialValue: card?.powerupTitle ?? "")
        _powerupDescription = State(initialValue: card?.powerupDescription ?? "")
        _timeBonusMinutes = State(initialValue: card?.timeBonusMinutes ?? 5)
        _multiplier = State(initialValue: entry?.multiplier ?? 1)
    }

    private var builtCard: CustomCard {
        CustomCard(
            id: existingCardId,
            type: type,
            curseTitle: type == .curse ? curseTitle : nil,
            curseDescription: type == .curse ? curseDescription : nil,
            castingCost: type == .curse ? castingCost : nil,
            powerupTitle: type == .powerup ? powerupTitle : nil,
            powerupDescription: type == .powerup ? powerupDescription : nil,
            timeBonusMinutes: type == .timeBonus ? timeBonusMinutes : nil
        )
    }

    private var canSave: Bool { builtCard.isValid() && multiplier >= 1 && multiplier <= 20 }

    private var curseFieldsError: String? {
        guard type == .curse else { return nil }
        if curseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Title is required" }
        if curseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Description is required" }
        if castingCost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Casting cost is required" }
        return nil
    }

    private var powerupFieldsError: String? {
        guard type == .powerup else { return nil }
        if powerupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Title is required" }
        if powerupDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Description is required" }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card Type") {
                    Picker("Type", selection: $type) {
                        ForEach(CardType.allCases, id: \.self) { t in
                            Label(t.displayName, systemImage: t.iconName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if type == .curse {
                    Section {
                        TextField("Title", text: $curseTitle)
                        TextField("Description", text: $curseDescription, axis: .vertical)
                            .lineLimit(3...6)
                        TextField("Casting Cost", text: $castingCost, axis: .vertical)
                            .lineLimit(2...4)
                        if let err = curseFieldsError {
                            Text(err).font(.caption).foregroundColor(.red)
                        }
                    } header: {
                        Label("Curse Details", systemImage: CardType.curse.iconName)
                            .foregroundColor(CardType.curse.themeColor)
                    } footer: {
                        Text("Casting cost is what the hider must do/pay to play this curse.")
                    }
                }

                if type == .powerup {
                    Section {
                        TextField("Title", text: $powerupTitle)
                        TextField("Description", text: $powerupDescription, axis: .vertical)
                            .lineLimit(3...6)
                        if let err = powerupFieldsError {
                            Text(err).font(.caption).foregroundColor(.red)
                        }
                    } header: {
                        Label("Powerup Details", systemImage: CardType.powerup.iconName)
                            .foregroundColor(CardType.powerup.themeColor)
                    }
                }

                if type == .timeBonus {
                    Section {
                        Stepper(value: $timeBonusMinutes, in: 1...120) {
                            HStack {
                                Text("Bonus Time")
                                Spacer()
                                Text("\(timeBonusMinutes) min")
                                    .foregroundColor(.secondary)
                                    .fontWeight(.semibold)
                            }
                        }
                    } header: {
                        Label("Time Bonus Details", systemImage: CardType.timeBonus.iconName)
                            .foregroundColor(CardType.timeBonus.themeColor)
                    } footer: {
                        Text("Minutes added to the hiders' hiding time when this card is drawn.")
                    }
                }

                Section {
                    Stepper(value: $multiplier, in: 1...20) {
                        HStack {
                            Text("Copies in Deck")
                            Spacer()
                            Text("×\(multiplier)")
                                .foregroundColor(.secondary)
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Deck Count")
                } footer: {
                    Text("How many copies of this card appear in the deck.")
                }

                // Debug info in DEBUG builds
                #if DEBUG
                Section("Debug") {
                    Text("Card id: \(existingCardId.prefix(8))…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                #endif
            }
            .navigationTitle(isNew ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(builtCard, multiplier)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    CardEditorView { _, _ in }
}
