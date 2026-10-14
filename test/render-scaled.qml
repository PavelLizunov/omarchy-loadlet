import QtQuick
import ".." as Plugin
import "mock-data.js" as MockData
import qs.Commons

Item {
  id: host
  // Host fitting includes padding/borders in the outer card height.
  width: Style.space(480)
  height: Style.space(390) + Style.spacing.popupPadding * 2 + Style.space(2) * 2

  Plugin.Panel {
    id: plugin
    anchors.fill: parent
    Component.onCompleted: {
      Style.fontBaseSize = 16
      plugin.open()
      plugin.setExpanded(false)
      plugin.setSettingsOpen(false)
      plugin.languageExpanded = false
      MockData.populate(plugin.activityController)
      plugin.selectProcess(0)
      plugin.hintsVisible = true
    }
  }
}
