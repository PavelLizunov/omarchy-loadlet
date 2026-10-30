import QtQuick
import Quickshell
import Quickshell.Io

// One bounded, user-requested local export; never starts an AI or applies advice.
Item {
  id: root
  function t(key, a, b, c) { return locale ? locale.t(key, a, b, c) : key }
  visible: false
  property var locale: null
  property string language: locale ? locale.language : "en"
  property int hours: 2
  property string resultPath: ""
  property string error: ""
  property bool timedOut: false
  readonly property bool running: exporter.running
  readonly property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("activity-report")).replace(/^file:\/\//,""))
  function request() {
    if (running) return
    error="";resultPath="";timedOut=false
    exporter.command=["/usr/bin/python3","-I",helperPath,"--hours",String(hours)]
    deadline.restart();exporter.running=true
  }
  function copyPrompt() {
    if (resultPath) Quickshell.clipboardText=root.t("diagnostic_prompt",resultPath)
  }
  Process {
    id: exporter
    clearEnvironment: true
    environment: ({"PATH":"/usr/bin","LC_ALL":"C.UTF-8","HOME":Quickshell.env("HOME"),"XDG_STATE_HOME":Quickshell.env("XDG_STATE_HOME")})
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: function(code) {
      deadline.stop()
      if(root.timedOut) return
      if(code!==0) {root.error=root.t("diagnostic_export_failed");return}
      try {
        var data=JSON.parse(output.text)
        if(typeof data.path!=='string' || data.path[0]!=='/') throw new Error('path')
        root.resultPath=data.path
      } catch(e) { root.error=root.t("diagnostic_export_failed") }
    }
  }
  Timer {
    id: deadline; interval: 10000
    onTriggered: { root.timedOut=true;exporter.signal(9);root.error=root.t("diagnostic_export_failed") }
  }
  Component.onDestruction: if(exporter.running) exporter.signal(9)
}
