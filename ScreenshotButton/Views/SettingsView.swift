import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: HotkeySettingsViewModel

    var body: some View {
        Form {
            Section("Capture Hotkeys") {
                Picker("Area to Clipboard", selection: bindingForPicker) {
                    Text("None").tag(HotkeyBinding?.none)
                    ForEach(HotkeyBinding.allFKeys, id: \.self) { key in
                        Text(key.label).tag(HotkeyBinding?.some(key))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Area-to-Clipboard hotkey")

                if viewModel.permissionDenied {
                    LabeledContent {
                        Button("Open Settings") {
                            viewModel.openAccessibilitySettings()
                        }
                    } label: {
                        Text("Accessibility is required for global hotkeys.")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("Tip: macOS may map F1–F12 to media keys. Hold Fn or enable F-keys-as-standard-keys in System Settings → Keyboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 260)
    }

    private var bindingForPicker: Binding<HotkeyBinding?> {
        Binding(
            get: { viewModel.binding },
            set: { viewModel.setBinding($0) }
        )
    }
}
