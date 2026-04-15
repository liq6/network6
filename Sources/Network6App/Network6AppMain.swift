import SwiftUI

@main
struct Network6AppMain: App {
    @StateObject private var viewModel = NetworkViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1100, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1400, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Export CSV…") {
                    viewModel.exportCSV()
                }
                .keyboardShortcut("e", modifiers: [.command])

                Button("Export JSON…") {
                    viewModel.exportJSON()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
