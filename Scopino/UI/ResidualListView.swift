//
//  ResidualListView.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import SwiftUI

struct ResidualListView: View {

    @Binding var residuals: [ResidualItem]

    // Raggruppa per categoria
    private var grouped: [(category: ResidualCategory, items: [Binding<ResidualItem>])] {
        ResidualCategory.allCases.compactMap { category in
            let indices = residuals.indices.filter { residuals[$0].category == category }
            guard !indices.isEmpty else { return nil }
            let bindings = indices.map { $residuals[$0] }
            return (category, bindings)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(grouped, id: \.category) { group in
                    Section {
                        ForEach(group.items, id: \.id) { $item in
                            ResidualRowView(item: $item)
                            Divider()
                                .padding(.leading, 44)
                        }
                    } header: {
                        categoryHeader(group.category, items: group.items)
                    }
                }
            }
        }
        .frame(maxHeight: 320)
    }

    // MARK: - Category header

    private func categoryHeader(
        _ category: ResidualCategory,
        items: [Binding<ResidualItem>]
    ) -> some View {
        let allSelected = items.allSatisfy { $0.isSelected.wrappedValue }
        let totalSize = items.reduce(Int64(0)) { $0 + $1.sizeBytes.wrappedValue }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        return HStack {
            Image(systemName: category.systemIcon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(category.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()

            Text(formatter.string(fromByteCount: totalSize))
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Toggle seleziona tutto nella categoria
            Toggle("", isOn: Binding(
                get: { allSelected },
                set: { newValue in
                    for item in items { item.isSelected.wrappedValue = newValue }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Row

struct ResidualRowView: View {
    @Binding var item: ResidualItem

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Toggle("", isOn: $item.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()

            // Icona file/cartella
            Image(systemName: iconForItem)
                .foregroundStyle(item.requiresPrivileges ? .orange : .secondary)
                .frame(width: 16)

            // Path
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Dimensione
            Text(item.displaySize)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            // Badge privilegi
            if item.requiresPrivileges {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            item.isSelected.toggle()
        }
    }

    private var iconForItem: String {
        let path = item.path
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue ? "folder.fill" : "doc.fill"
    }
}
