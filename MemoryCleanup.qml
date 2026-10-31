import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import Quickshell.Io
import qs.Commons
import qs.Commons as Host
import qs.Ui
import "Model.js" as Model

// Persistent panel-owned operation; navigating away only dismisses confirmation.
Item {
  id: root
  objectName: "memoryCleanup"
  property var locale: null
  property alias watch: memoryWatch
  property bool cleanupExpanded: false
  property bool active: false
  property var memory: ({})
  property bool memoryReady: false
  property bool confirming: false
  property string statusKey: ""
  property var result: null
  property double finishedAt: 0
  property string captured: ""
  property bool timedOut: false
  readonly property bool running: cleaner.running
  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("memory-clean")).replace(/^file:\/\//, ""))
  signal completed()
  signal processesRequested()
  LayoutMirroring.enabled: locale ? locale.rightToLeft : Host.I18n.rightToLeft
  LayoutMirroring.childrenInherit: true

  function t(key, a, b, c) { return locale ? locale.t(key, a, b, c) : key }
  function number(value, decimals) { return locale ? locale.number(value, decimals) : Host.I18n.formatNumber(value, decimals) }
  function bytes(value) {
    return typeof value === "number" && isFinite(value) && value >= 0
      ? Model.formatBytes(value, "", root.number) : "—"
  }
  function validSnapshot(value) {
    return value && ["total", "free", "cache"].every(function(key) {
      return typeof value[key] === "number" && isFinite(value[key]) && value[key] >= 0
    }) && (value.available === null || (typeof value.available === "number"
      && isFinite(value.available) && value.available >= 0))
  }
  function request() {
    if (!active || running || !confirming || memoryWatch.running) return
    confirming = false; result = null; captured = ""; timedOut = false; finishedAt = 0
    statusKey = "memory_clean_running"
    deadline.restart()
    cleaner.running = true
  }
  onActiveChanged: if (!active) confirming = false
  onConfirmingChanged: Qt.callLater(function() {
    if (root.active && root.cleanupExpanded) {
      (root.confirming ? cancelButton : cleanButton).forceActiveFocus()
      if (root.confirming) viewport.contentY = Math.max(0, viewport.contentHeight - viewport.height)
    }
  })
  Keys.onEscapePressed: function(event) {
    if (confirming) confirming = false
    else event.accepted = false
  }

  Process {
    id: cleaner
    command: ["/usr/bin/python3", "-I", root.helper, "--clear"]
    stdout: SplitParser {
      onRead: function(line) {
        if (root.captured.length + line.length <= 8192) root.captured += line
        else { root.timedOut = true; root.statusKey = "memory_clean_unknown"; cleaner.signal(15); killDeadline.restart() }
      }
    }
    onStarted: root.statusKey = "memory_clean_running"
    onExited: function(code) {
      deadline.stop(); killDeadline.stop()
      root.finishedAt = Date.now() / 1000
      if (!root.timedOut) {
        root.statusKey = code === 126 || code === 127 ? "memory_clean_denied" : "memory_clean_failed"
        try {
          var data = JSON.parse(root.captured)
          if (data.schema === 1 && data.ok === true && code === 0) {
            root.statusKey = "memory_clean_done"
            if (root.validSnapshot(data.before) && root.validSnapshot(data.after)) root.result = data
            else root.statusKey = "memory_clean_unmeasured"
          } else if (data.schema === 1 && data.error === "busy") root.statusKey = "memory_clean_busy"
        } catch (error) {}
        if (code === 124 || code === 137) root.statusKey = "memory_clean_unknown"
      }
      root.completed()
    }
  }
  Timer {
    id: deadline; interval: 130000
    onTriggered: {
      root.timedOut = true; root.statusKey = "memory_clean_unknown"
      if (cleaner.running) { cleaner.signal(15); killDeadline.restart() }
    }
  }
  Timer { id: killDeadline; interval: 3000; onTriggered: if (cleaner.running) cleaner.signal(9) }
  Component.onDestruction: if (cleaner.running) cleaner.signal(15)

  Flickable {
    id: viewport
    objectName: "memoryCleanupViewport"
    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
    anchors.bottom: actions.top; anchors.bottomMargin: Style.spacing.sm
    contentWidth: width; contentHeight: body.implicitHeight
    clip: true; boundsBehavior: Flickable.StopAtBounds
    QQC.ScrollBar.vertical: QQC.ScrollBar {
      policy: QQC.ScrollBar.AsNeeded
      parent: root
      anchors.left: viewport.right
      anchors.top: viewport.top; anchors.bottom: viewport.bottom
    }
    Connections {
      target: viewport.Window.window
      function onActiveFocusItemChanged() {
        var window = viewport.Window.window
        if (!window || !root.active) return
        var item = window.activeFocusItem, ancestor = item
        while (ancestor && ancestor !== viewport.contentItem) ancestor = ancestor.parent
        if (!ancestor) return
        var top = item.mapToItem(viewport.contentItem,0,0).y
        if (top < viewport.contentY) viewport.contentY = Math.max(0,top)
        else if (top + item.height > viewport.contentY + viewport.height)
          viewport.contentY = Math.max(0,Math.min(viewport.contentHeight-viewport.height,top+item.height-viewport.height))
      }
    }
    Column {
      id: body
      width: viewport.width
      spacing: Style.spacing.sm
      MemoryWatch { id: memoryWatch; width: parent.width; locale: root.locale }
      Button {
        width: parent.width
        text: root.t("memory_watch_cache_tools")
        foreground: Host.Color.popups.text; accent: Host.Color.accent; focusable: true
        onClicked: { root.cleanupExpanded = !root.cleanupExpanded; root.confirming = false }
      }
      Column {
        width: parent.width; spacing: Style.spacing.sm; visible: root.cleanupExpanded
      Row {
        width: parent.width; spacing: Style.spacing.sm
        SvgIcon { name: "ram"; tint: Host.Color.popups.text }
        Text {
          width: parent.width - Style.space(16) - parent.spacing
          text: root.t("memory_clean_title"); textFormat: Text.PlainText; wrapMode: Text.Wrap
          color: Host.Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.heading
        }
      }
      Text {
        width: parent.width
        text: root.t("memory_clean_stats", root.bytes(root.memoryReady ? root.memory.available : null),
          root.bytes(root.memoryReady ? root.memory.cached : null))
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: Host.Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
      }
      Text {
        width: parent.width
        text: root.t("memory_clean_hint")
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: Host.Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption
      }
      Text {
        objectName: "memoryCleanupStatus"
        visible: root.statusKey !== ""
        width: parent.width
        text: root.t(root.statusKey)
          + (root.finishedAt > 0 && !root.running && root.locale ? " · " + root.locale.dateTime(root.finishedAt, true, false) : "")
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: ["memory_clean_failed", "memory_clean_unknown"].indexOf(root.statusKey) >= 0 ? Host.Color.urgent : Host.Color.popups.text
        font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
      }
      Text {
        visible: root.confirming
        width: parent.width
        text: root.t("memory_clean_confirm")
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: Host.Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption
      }
      Text {
        objectName: "memoryCleanupResult"
        visible: root.result !== null && !root.confirming
        width: parent.width
        text: root.result ? root.t("memory_clean_cache_result", root.bytes(root.result.before.cache), root.bytes(root.result.after.cache))
          + "\n" + root.t("memory_clean_available_result", root.bytes(root.result.before.available), root.bytes(root.result.after.available))
          + "\n" + root.t("memory_clean_result_hint") : ""
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: Host.Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption
      }
      }
    }
  }
  Column {
    id: actions
    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
    spacing: Style.spacing.sm
    Row {
      width: parent.width; spacing: Style.spacing.sm
      Button {
        objectName: "memoryWatchStart"
        width: (parent.width-parent.spacing)/2
        text: root.t(memoryWatch.running ? "memory_watch_stop" : "memory_watch_start")
        enabled: root.active && !root.running
        foreground: Host.Color.popups.text; accent: Host.Color.accent; bordered: true; focusable: true
        Accessible.role: Accessible.Button; Accessible.name: text
        onClicked: {
          root.confirming = false
          if (memoryWatch.running) memoryWatch.stop()
          else memoryWatch.begin()
        }
      }
      Button {
        width: (parent.width-parent.spacing)/2
        text: root.t("memory_watch_copy"); enabled: memoryWatch.frames.length > 0
        foreground: Host.Color.popups.text; accent: Host.Color.accent; bordered: true; focusable: true
        Accessible.role: Accessible.Button; Accessible.name: text
        onClicked: memoryWatch.copyReport()
      }
    }
    Button {
      objectName: "memoryProcesses"
      width: parent.width
      text: root.t("memory_processes")
      foreground: Host.Color.popups.text; accent: Host.Color.accent
      bordered: true; focusable: true
      Accessible.role: Accessible.Button; Accessible.name: text
      onClicked: root.processesRequested()
    }
    Row {
      visible: root.cleanupExpanded
      width: parent.width; spacing: Style.spacing.sm
      Button {
        id: cancelButton
        objectName: "memoryCleanupCancel"
        visible: root.confirming
        width: (parent.width - parent.spacing) / 2
        text: root.t("cancel")
        foreground: Host.Color.popups.text; accent: Host.Color.accent
        bordered: true; focusable: true
        Accessible.role: Accessible.Button; Accessible.name: text
        onClicked: root.confirming = false
      }
      Button {
        id: cleanButton
        objectName: "memoryCleanupRun"
        width: root.confirming ? (parent.width - parent.spacing) / 2 : parent.width
        text: root.t(root.confirming ? "memory_clean_authorize" : "memory_clean_action")
        foreground: Host.Color.popups.text; accent: Host.Color.accent
        bordered: true; focusable: true
        Accessible.role: Accessible.Button; Accessible.name: text
        enabled: root.active && !root.running && !memoryWatch.running
        onClicked: {
          if (root.confirming) root.request()
          else root.confirming = true
        }
      }
    }
  }
}
