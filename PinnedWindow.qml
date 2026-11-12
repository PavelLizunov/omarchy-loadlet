import QtQuick
import Quickshell
import Quickshell.Wayland

// A card-sized surface leaves all other desktop input with its original owner.
PanelWindow {
  property point origin: Qt.point(0, 0)

  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; left: true }
  margins { top: origin.y; left: origin.x }

  WlrLayershell.namespace: "loadlet-pinned-panel"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
}
