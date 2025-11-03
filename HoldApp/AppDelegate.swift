//
//  AppDelegate.swift
//  HoldApp
//
//  Created by Vishal Jain on 03/11/2025.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var spotlightPanel: SpotlightPanel!
    private var spotlightViewController: SpotlightViewController!
    private var hotkeyManager: HotkeyManager!
    private var logManager: LogManager!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize components
        logManager = LogManager()

        // Create Spotlight UI
        spotlightViewController = SpotlightViewController()
        spotlightPanel = SpotlightPanel()
        spotlightPanel.contentViewController = spotlightViewController

        // Setup callbacks
        spotlightViewController.onEnterPressed = { [weak self] text in
            self?.logManager.log(text: text)
            self?.spotlightPanel.hide()
        }

        spotlightViewController.onEscapePressed = { [weak self] in
            self?.spotlightPanel.hide()
        }

        // Setup hotkeys
        hotkeyManager = HotkeyManager()
        hotkeyManager.onShowHotkey = { [weak self] in
            self?.spotlightPanel.show()
        }
        hotkeyManager.onHideHotkey = { [weak self] in
            self?.spotlightPanel.hide()
        }
        hotkeyManager.registerHotkeys()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

