import Foundation
import Observation

@Observable
final class AppState {
    // Current task
    var currentTaskId: UUID?

    // Window states
    var isSpotlightOpen: Bool = false
    var isEditorOpen: Bool = false
    var isParentSelectorOpen: Bool = false

    // Editor state
    var filterText: String = ""
    var selectedTaskId: UUID?
    var editorMode: EditorMode = .treeView

    enum EditorMode {
        case treeView      // State 1
        case filterFocused // State 2
        case taskSelected  // State 3
    }

    // Singleton (or inject via environment)
    static let shared = AppState()
    private init() {}
}
