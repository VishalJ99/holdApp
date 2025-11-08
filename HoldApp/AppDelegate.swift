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
    var debugMenuManager: DebugMenuManager!

    // UI components (legacy - will be replaced in Phase 1)
    private var spotlightPanel: SpotlightPanel!
    private var spotlightViewController: SpotlightViewController!
    private var hotkeyManager: HotkeyManager!

    // Legacy components (will be removed)
    private var logManager: LogManager!


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

        // Setup Debug menu
        debugMenuManager = DebugMenuManager(taskManager: taskManager, appState: appState)
        debugMenuManager.setupDebugMenu()

        // Initialize legacy components (for now)
        logManager = LogManager()

        // Create Spotlight UI
        spotlightViewController = SpotlightViewController()
        spotlightPanel = SpotlightPanel()
        spotlightPanel.contentViewController = spotlightViewController

        // Setup callbacks - now using SwiftData TaskManager
        spotlightViewController.onEnterPressed = { [weak self] text in
            guard let self = self else { return }

            // Create task using TaskManager (saves to SwiftData + CloudKit automatically)
            let task = self.taskManager.createTask(text: text, parent: nil, setCurrent: true)

            // Legacy: Also save to old CloudKit for backward compatibility (will remove later)
            CloudKitManager.shared.saveTask(text: text) { result in
                switch result {
                case .success:
                    print("✅ Legacy CloudKit save successful")
                case .failure(let error):
                    print("⚠️ Legacy CloudKit save failed: \(error)")
                }
            }

            // Legacy logging (will remove later)
            self.logManager.log(text: text)
            self.spotlightPanel.hide()

            // Update app state
            self.appState.isSpotlightOpen = false
        }

        spotlightViewController.onEscapePressed = { [weak self] in
            self?.spotlightPanel.hide()
            self?.appState.isSpotlightOpen = false
        }

        // Setup hotkeys
        hotkeyManager = HotkeyManager()
        hotkeyManager.onShowHotkey = { [weak self] in
            self?.spotlightPanel.show()
            self?.appState.isSpotlightOpen = true
        }
        hotkeyManager.onHideHotkey = { [weak self] in
            self?.spotlightPanel.hide()
            self?.appState.isSpotlightOpen = false
        }
        hotkeyManager.registerHotkeys()

        print("✅ Phase 0 initialization complete")
        print("💡 Use Debug menu to verify task tree and state")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

