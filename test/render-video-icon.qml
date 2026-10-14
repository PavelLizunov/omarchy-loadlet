import QtQuick
import qs.Commons as Host
import "plugin" as Plugin

Rectangle {
  id: fixture
  color: Host.Color.background
  property bool previewReady: false
  property real cpu: 85
  property real ram: 55
  Component.onCompleted: Host.Color.loadColors('foreground="#d8dee9"\nbackground="#2e3440"\naccent="#81a1c1"\nred="#bf616a"')
  Plugin.ActivityIcon {
    id: icon
    objectName: "videoIcon"
    anchors.fill: parent
    cpu: fixture.cpu
    ram: fixture.ram
    fresh: true
    shape: 10
    loadThreshold: 50
    hot: false
    temperatureFresh: true
    motionEnabled: false
  }
  Timer {
    interval: 40
    running: true
    repeat: true
    onTriggered: if (icon.status === Image.Ready) { fixture.previewReady = true; stop() }
  }
}
