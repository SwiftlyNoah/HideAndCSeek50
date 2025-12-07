//
//  TrainLinesView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import SwiftUI

struct TrainLinesToggleView: View {
    @ObservedObject var viewModel: MapToolsViewModel
    var body: some View {
        HStack {
            Image(systemName: "tram.fill")
                .foregroundColor(.primary.opacity(0.8))
            Text("Train Lines")
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: $viewModel.showTrainLines)
                .toggleStyle(SwitchToggleStyle(tint: .green))
        }
    }
}
