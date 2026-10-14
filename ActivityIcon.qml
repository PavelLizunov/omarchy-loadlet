import QtQuick
import qs.Commons
import qs.Commons as Host
import "ActivityIconSvg.js" as Vector
import "HeatPolicy.js" as Heat

Image {
  id: root
  property real cpu: -1
  property real ram: -1
  property bool fresh: false
  property real loadThreshold: 50
  readonly property int effectiveLoadThreshold: Vector.loadThreshold(loadThreshold)
  readonly property real gaugeCpu: Vector.gaugeValue(cpu, fresh, effectiveLoadThreshold)
  readonly property real gaugeRam: Vector.gaugeValue(ram, fresh, effectiveLoadThreshold)
  property int shape: Vector.defaultShape
  property bool hot: false
  property bool temperatureFresh: false
  property int heatLevel: 1
  readonly property int motionInterval: Heat.interval(effectiveHeatLevel)
  readonly property int effectiveHeatLevel: thermalAlert ? Math.max(1,Math.min(4,heatLevel)) : 0
  property color foreground: Host.Color.foreground
  property color background: Host.Color.background
  property color heatColor: Host.Color.urgent
  property color accent: Host.Color.accent
  property bool motionEnabled: true
  property double thermalSampleAt: 0
  property double lastMotionAt: 0
  readonly property int shapeIndex: Vector.shapeIndex(shape)
  readonly property bool thermalAlert: hot && temperatureFresh
  readonly property color cpuColor: Vector.pressureColor(fresh ? cpu : -1, foreground, accent, heatColor)
  readonly property color ramColor: Vector.pressureColor(fresh ? ram : -1, foreground, accent, heatColor)
  readonly property bool motionAllowed: motionEnabled && thermalAlert && visible && opacity > 0
  readonly property bool motionRunning: wiggle.running

  function requestWiggle() {
    if (!motionAllowed || wiggle.running) return
    var now = Date.now()
    if (thermalSampleAt>0 && (now<thermalSampleAt || now-thermalSampleAt>=35000)) {cancelWiggle();return}
    if (lastMotionAt > 0 && now >= lastMotionAt && now - lastMotionAt < motionInterval) return
    lastMotionAt = now
    wiggle.start()
  }
  function cancelWiggle() { wiggle.stop(); rotation = 0 }
  onThermalAlertChanged: if (thermalAlert) Qt.callLater(requestWiggle)
  onThermalSampleAtChanged: if (thermalAlert) Qt.callLater(requestWiggle)
  onMotionAllowedChanged: if (!motionAllowed) cancelWiggle()
  onEffectiveHeatLevelChanged: if (motionAllowed) Qt.callLater(requestWiggle)
  Component.onDestruction: cancelWiggle()

  // Visual replay only: severity cadence 15/10/5/3s, no sensor requests.
  Timer {
    interval: Math.max(3000,root.motionInterval)
    running: root.motionAllowed
    repeat: true
    onTriggered: root.requestWiggle()
  }
  // One 2000ms native transform per admitted replay.
  // Rotation is independent of source: no SVG regeneration on animation frames.
  SequentialAnimation {
    id: wiggle
    NumberAnimation { target: root; property: "rotation"; to: -6; duration: 200; easing.type: Easing.InOutSine }
    SequentialAnimation {
      loops: 4
      NumberAnimation { target: root; property: "rotation"; to: 6; duration: 200; easing.type: Easing.InOutSine }
      NumberAnimation { target: root; property: "rotation"; to: -6; duration: 200; easing.type: Easing.InOutSine }
    }
    NumberAnimation { target: root; property: "rotation"; to: 0; duration: 200; easing.type: Easing.InOutSine }
  }
  readonly property real rasterDpr: Math.max(1, Screen.devicePixelRatio)
  source: "data:image/svg+xml;utf8," + encodeURIComponent(Vector.svg(
    shapeIndex, gaugeCpu, gaugeRam, fresh, effectiveHeatLevel, foreground, background, heatColor, cpuColor, ramColor,
    sourceSize.width, sourceSize.height, accent))
  sourceSize.width: Math.max(1, Math.ceil(width * rasterDpr))
  sourceSize.height: Math.max(1, Math.ceil(height * rasterDpr))
  asynchronous: false
  cache: false
}
