import AppKit

/// NSTableView that toggles the selected row's checkbox when the user presses
/// Space — a small keyboard affordance for the results list.
public final class CheckboxTableView: NSTableView {

    /// Invoked with the selected row when Space is pressed.
    var onToggleRow: ((Int) -> Void)?

    public override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " ", selectedRow >= 0 {
            onToggleRow?(selectedRow)
            return
        }
        super.keyDown(with: event)
    }
}
