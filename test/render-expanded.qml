import QtQuick
import ".." as Plugin
import "mock-data.js" as MockData

Item {
  id: host
  width: 780
  height: 592

  Plugin.Panel {
    id: plugin
    anchors.fill: parent
    Component.onCompleted: {
      plugin.open()
      plugin.setExpanded(true)
      plugin.setSettingsOpen(false)
      plugin.languageExpanded = false
      MockData.populate(plugin.activityController)
      plugin.selectProcess(0)
      plugin.hintsVisible = true
    }
  }
}
