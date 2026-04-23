//
//  DiceRollerView.swift
//  HideAndCSeek50
//

import SwiftUI

struct DiceRollerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var die1: Int = 1
    @State private var die2: Int = 1
    @State private var numberOfDice: Int = 1
    @State private var isRolling = false
    @State private var rollCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.red.opacity(0.08),
                        Color.orange.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Dice count picker
                    VStack(spacing: 8) {
                        Text("Number of Dice")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Picker("Number of Dice", selection: $numberOfDice) {
                            Text("1 Die").tag(1)
                            Text("2 Dice").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 40)
                    }

                    // Dice display
                    HStack(spacing: 32) {
                        DiceFaceView(value: die1, isRolling: isRolling)

                        if numberOfDice == 2 {
                            DiceFaceView(value: die2, isRolling: isRolling)
                        }
                    }
                    .animation(.spring(response: 0.3), value: numberOfDice)

                    // Total (only shown when 2 dice)
                    if numberOfDice == 2 {
                        VStack(spacing: 4) {
                            Text("Total")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(die1 + die2)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Roll button
                    Button(action: rollDice) {
                        HStack(spacing: 10) {
                            Image(systemName: "dice.fill")
                                .font(.title3)
                            Text("Roll")
                                .font(.title3.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.red.opacity(0.85))
                        )
                        .padding(.horizontal, 40)
                    }
                    .disabled(isRolling)
                    .scaleEffect(isRolling ? 0.96 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isRolling)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Dice Roller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func rollDice() {
        guard !isRolling else { return }
        isRolling = true

        // Animate through several random values before settling
        let totalSteps = 10
        for step in 0..<totalSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.06) {
                die1 = Int.random(in: 1...6)
                die2 = Int.random(in: 1...6)
                if step == totalSteps - 1 {
                    isRolling = false
                }
            }
        }
    }
}

// MARK: - Single die face

private struct DiceFaceView: View {
    let value: Int
    let isRolling: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .frame(width: 110, height: 110)

            DicePipsView(value: value)
                .frame(width: 80, height: 80)
        }
        .rotationEffect(.degrees(isRolling ? Double.random(in: -12...12) : 0))
        .animation(isRolling ? .easeInOut(duration: 0.06).repeatForever(autoreverses: true) : .spring(), value: isRolling)
        .contentTransition(.identity)
    }
}

// MARK: - Pip layout

private struct DicePipsView: View {
    let value: Int

    var body: some View {
        GeometryReader { geo in
            let pipSize: CGFloat = geo.size.width * 0.18
            ZStack {
                switch value {
                case 1:
                    pip(at: .center, in: geo.size, pipSize: pipSize)
                case 2:
                    pip(at: .topTrailing, in: geo.size, pipSize: pipSize)
                    pip(at: .bottomLeading, in: geo.size, pipSize: pipSize)
                case 3:
                    pip(at: .topTrailing, in: geo.size, pipSize: pipSize)
                    pip(at: .center, in: geo.size, pipSize: pipSize)
                    pip(at: .bottomLeading, in: geo.size, pipSize: pipSize)
                case 4:
                    pip(at: .topLeading, in: geo.size, pipSize: pipSize)
                    pip(at: .topTrailing, in: geo.size, pipSize: pipSize)
                    pip(at: .bottomLeading, in: geo.size, pipSize: pipSize)
                    pip(at: .bottomTrailing, in: geo.size, pipSize: pipSize)
                case 5:
                    pip(at: .topLeading, in: geo.size, pipSize: pipSize)
                    pip(at: .topTrailing, in: geo.size, pipSize: pipSize)
                    pip(at: .center, in: geo.size, pipSize: pipSize)
                    pip(at: .bottomLeading, in: geo.size, pipSize: pipSize)
                    pip(at: .bottomTrailing, in: geo.size, pipSize: pipSize)
                case 6:
                    pip(at: .topLeading, in: geo.size, pipSize: pipSize)
                    pip(at: .topTrailing, in: geo.size, pipSize: pipSize)
                    pip(at: .middleLeading, in: geo.size, pipSize: pipSize)
                    pip(at: .middleTrailing, in: geo.size, pipSize: pipSize)
                    pip(at: .bottomLeading, in: geo.size, pipSize: pipSize)
                    pip(at: .bottomTrailing, in: geo.size, pipSize: pipSize)
                default:
                    EmptyView()
                }
            }
        }
    }

    private enum PipPosition {
        case topLeading, topTrailing
        case middleLeading, middleTrailing
        case bottomLeading, bottomTrailing
        case center
    }

    @ViewBuilder
    private func pip(at position: PipPosition, in size: CGSize, pipSize: CGFloat) -> some View {
        let margin = size.width * 0.18
        let (x, y): (CGFloat, CGFloat) = {
            switch position {
            case .topLeading:     return (margin, margin)
            case .topTrailing:    return (size.width - margin, margin)
            case .middleLeading:  return (margin, size.height / 2)
            case .middleTrailing: return (size.width - margin, size.height / 2)
            case .bottomLeading:  return (margin, size.height - margin)
            case .bottomTrailing: return (size.width - margin, size.height - margin)
            case .center:         return (size.width / 2, size.height / 2)
            }
        }()

        Circle()
            .fill(Color.primary)
            .frame(width: pipSize, height: pipSize)
            .position(x: x, y: y)
    }
}

#Preview {
    DiceRollerView()
}
