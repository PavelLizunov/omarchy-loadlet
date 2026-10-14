import QtQuick
import ".." as Plugin
import "mock-data.js" as MockData

Item {
  id: host
  width: 480
  height: 422

  Plugin.Panel {
    id: plugin
    anchors.fill: parent
    Component.onCompleted: {
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
