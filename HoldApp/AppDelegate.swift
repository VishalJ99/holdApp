//
//  AppDelegate.swift
//  HoldApp
//
//  Created by Vishal Jain on 03/11/2025.
//

import Cocoa
import SwiftData

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // SwiftData components
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    // State management
    var appState: AppState!
    var taskManager: TaskManager!

    // Managers
    var debugMenuManager: DebugMenuManager!
    var globalActionsManager: GlobalActionsManager!
    var menuBarManager: MenuBarManager!
    var hotkeyManager: HotkeyManager!

    // Windows & Panels
    private var spotlightPanel: SpotlightPanel!
    private var editorWindow: EditorWindow!
    private var settingsWindow: SettingsWindow!
    private var cheatSheetWindow: CheatSheetWindow?
    private var toastWindow: ToastWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize SwiftData with CloudKit sync
        do {
            let schema = Schema([Task.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.vishaljain.HoldApp")
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            modelContext = ModelContext(modelContainer)

            print("✅ SwiftData + CloudKit initialized (private database)")
        } catch {
            fatalError("Failed to initialize SwiftData: \(error)")
        }

        // Initialize state management
        appState = AppState.shared
        taskManager = TaskManager(modelContext: modelContext, appState: appState)

        // Setup managers
        debugMenuManager = DebugMenuManager(taskManager: taskManager, appState: appState)
        debugMenuManager.setupDebugMenu()

        globalActionsManager = GlobalActionsManager(taskManager: taskManager, appState: appState)
        globalActionsManager.setupGlobalActions()

        menuBarManager = MenuBarManager()
        menuBarManager.setupMenuBar(
            onShowSpotlight: { [weak self] in self?.showSpotlight() },
            onShowEditor: { [weak self] in self?.showEditor() },
            onShowSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) }
        )

        // Create UI components
        spotlightPanel = SpotlightPanel(appState: appState, taskManager: taskManager)
        editorWindow = EditorWindow(appState: appState, taskManager: taskManager)
        settingsWindow = SettingsWindow()
        toastWindow = ToastWindow()

        // Setup hotkeys
        hotkeyManager = HotkeyManager()
        hotkeyManager.onShowSpotlight = { [weak self] in self?.showSpotlight() }
        hotkeyManager.onShowEditor = { [weak self] in self?.showEditor() }
        hotkeyManager.onCompleteTask = { [weak self] in
            self?.globalActionsManager.handleCompleteCurrentTask()
        }
        hotkeyManager.onDismissTask = { [weak self] in
            self?.globalActionsManager.handleDismissCurrentTask()
        }
        hotkeyManager.onShowCheatSheet = { [weak self] in self?.showCheatSheet() }
        hotkeyManager.registerHotkeys()

        // Track window state changes
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: spotlightPanel,
            queue: .main
        ) { [weak self] _ in
            self?.appState.isSpotlightOpen = true
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: spotlightPanel,
            queue: .main
        ) { [weak self] _ in
            self?.appState.isSpotlightOpen = false
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: editorWindow,
            queue: .main
        ) { [weak self] _ in
            self?.appState.isEditorOpen = true
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: editorWindow,
            queue: .main
        ) { [weak self] _ in
            self?.appState.isEditorOpen = false
        }

        print("✅ All phases initialized")
        print("💡 Press Cmd+Shift+Space for Spotlight")
        print("💡 Press Cmd+Shift+\\ for Editor")
        print("💡 Press Cmd+? for Cheat Sheet")
    }

    // MARK: - Window Management

    func showSpotlight() {
        if appState.isSpotlightOpen {
            // Already open, bring to front
            spotlightPanel.orderFrontRegardless()
        } else {
            spotlightPanel.show()
            appState.isSpotlightOpen = true
        }
    }

    func showEditor() {
        if appState.isEditorOpen {
            // Already open, bring to front
            editorWindow.makeKeyAndOrderFront(nil)
        } else {
            editorWindow.makeKeyAndOrderFront(nil)
            appState.isEditorOpen = true
        }
    }

    func showSettings() {
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    func showCheatSheet() {
        if cheatSheetWindow == nil {
            cheatSheetWindow = CheatSheetWindow(onClose: { [weak self] in
                self?.cheatSheetWindow?.close()
                self?.cheatSheetWindow = nil
            })
        }
        cheatSheetWindow?.show()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Cleanup
        hotkeyManager.unregisterHotkeys()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
