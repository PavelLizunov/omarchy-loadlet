import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "I18n.js" as I18n

// Owns the guarded process-action lifecycle.
Item {
  id: root

  width: 0
  height: 0
  visible: false

  property bool active: false
  property string language: "ru"

  readonly property string signalHelperPath: decodeURIComponent(
    String(Qt.resolvedUrl("process-signal")).replace(/^file:\/\//, ""))

  readonly property string currentUser: Quickshell.env("USER") || Quickshell.env("LOGNAME")
  readonly property bool confirmationOpen: _pendingAction !== null
  readonly property var pendingAction: _pendingAction
  readonly property bool running: signalProc.running
  readonly property string status: _status
  readonly property bool failed: _failed

  property var _pendingAction: null
  property var _activeAction: null
  property string _status: ""
  property bool _failed: false

  signal confirmationRequested()
  signal focusRequested()
  signal refreshRequested()

  function blockReason(process) {
    var reason = Model.processActionBlockReason(process, currentUser)
    var keys = {
      "Protected system process": "blocked_system",
      "Process identity is unavailable": "blocked_identity",
      "Process has already stopped": "blocked_stopped",
      "Only your own processes can be ended": "blocked_owner",
      "Desktop session is protected": "blocked_desktop"
    }
    return reason ? I18n.t(keys[reason] || "status_error", language) : ""
  }

  function request(process, force) {
    if (!active || !enabled || running || !process) return false

    var reason = blockReason(process)
    if (reason !== "") {
      _pendingAction = null
      _failed = true
      _status = reason
      clearStatus.restart()
      focusRequested()
      return false
    }

    _failed = false
    _status = ""
    clearStatus.stop()
    _pendingAction = {
      pid: Number(process.pid),
      startTicks: Number(process.startTicks),
      name: String(process.name || "process"),
      user: String(process.user || ""),
      action: force === true ? "KILL" : "TERM"
    }
    confirmationRequested()
    focusRequested()
    return true
  }

  function cancel() {
    _pendingAction = null
    focusRequested()
  }

  function confirm() {
    if (!active || !enabled || !_pendingAction || running) {
      cancel()
      return
    }

    _activeAction = _pendingAction
    _pendingAction = null
    _failed = false
    _status = I18n.t("status_sending", root.language, _activeAction.name)
    signalProc.command = [
      "/usr/bin/python3", "-I", signalHelperPath,
      _activeAction.action,
      String(_activeAction.pid),
      String(_activeAction.startTicks)
    ]
    signalProc.running = true
    actionDeadline.restart()
  }

  function finish(exitCode) {
    if (_activeAction === null) return
    actionDeadline.stop()
    var action = _activeAction

    if (active) {
      if (exitCode === 0) {
        _failed = false
        _status = I18n.t("status_sent", root.language, action ? action.name : "process", action ? action.pid : "")
      } else {
        _failed = true
        // Helper stderr remains a machine diagnostic, never bypasses the UI locale.
        _status = I18n.t("status_error", root.language)
      }
    }

    _activeAction = null
    if (!active) return
    refreshRequested()
    clearStatus.restart()
    focusRequested()
  }

  function clearSessionState() {
    _pendingAction = null
    _status = ""
    _failed = false
    clearStatus.stop()
  }

  Component.onDestruction: {
    actionDeadline.stop()
    if (signalProc.running) signalProc.signal(9)
  }

  onActiveChanged: if (!active) clearSessionState()
  onEnabledChanged: if (!enabled) _pendingAction = null

  Process {
    id: signalProc
    clearEnvironment: true
    environment: ({ "PATH": "/usr/bin", "LC_ALL": "C" })
    stdout: StdioCollector {
      id: signalStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: signalStderr
      waitForEnd: true
    }
    onExited: function(exitCode) { root.finish(exitCode) }
  }

  Timer {
    id: actionDeadline
    interval: 3000
    repeat: false
    onTriggered: {
      if (signalProc.running) signalProc.signal(9)
      root.finish(1)
    }
  }

  Timer {
    id: clearStatus
    interval: 5000
    repeat: false
    onTriggered: {
      root._status = ""
      root._failed = false
    }
  }
}
