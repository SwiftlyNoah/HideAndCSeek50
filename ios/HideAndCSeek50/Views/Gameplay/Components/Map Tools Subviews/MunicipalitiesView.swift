//
//  MunicipalitiesView.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/7/25.
//

import SwiftUI

struct MunicipalitiesSectionView: View {
    @ObservedObject var viewModel: MapToolsViewModel
    var body: some View {
        DisclosureGroup(isExpanded: $viewModel.municipalitiesExpanded) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button(action: viewModel.showAllGreen) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("All Green")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    Button(action: viewModel.hideAll) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.slash.fill")
                                .font(.caption)
                            Text("Clear All")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(8)
                    }
                    Button(action: viewModel.showAllRed) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                            Text("All Red")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                }
                if viewModel.allRegionNames.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map")
                            .font(.title)
                            .foregroundColor(.primary.opacity(0.6))
                        Text("No regions available")
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.allRegionNames, id: \.self) { regionName in
                                regionToggleButton(regionName)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(16)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(12)
        } label: {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.primary.opacity(0.8))
                Text("Municipalities")
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .accentColor(.clear)
    }
    private func regionToggleButton(_ regionName: String) -> some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.toggleGreen(regionName) }) {
                Image(systemName: viewModel.greenRegions.contains(regionName) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)
            Text(regionName)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: { viewModel.toggleRed(regionName) }) {
                Image(systemName: viewModel.redRegions.contains(regionName) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}
