//
//  ViewController.swift
//  HoldApp
//
//  Created by Vishal Jain on 03/11/2025.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Show Hello World popup after view loads
        DispatchQueue.main.async {
            self.showHelloWorldAlert()
        }
    }

    func showHelloWorldAlert() {
        let alert = NSAlert()
        alert.messageText = "Hello World"
        alert.informativeText = "Welcome to your macOS app!"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

