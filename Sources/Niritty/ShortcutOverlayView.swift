import NirittyWorkspaceModel
import SwiftUI

struct ShortcutOverlayView: View {
    let model: ShortcutOverlayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Shortcut Overlay")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.rows, id: \.commandTitle) { row in
                    HStack {
                        Text(row.commandTitle)
                            .frame(minWidth: 180, alignment: .leading)

                        Text(row.shortcutText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
