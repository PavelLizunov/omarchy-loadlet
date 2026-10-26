import QtQuick
import qs.Commons
import qs.Commons as Host

Item {
  id: root
  property var points: []
  property color lineColor: Host.Color.accent
  property real ceiling: 120
  property string unit: "°C"
  property string hint: ""
  property int selectedIndex: -1
  readonly property var selectedPoint: selectedIndex >= 0 && selectedIndex < points.length ? points[selectedIndex] : null
  readonly property real startTime: points.length ? points[0].time : 0
  readonly property real endTime: points.length ? points[points.length - 1].time : 0
  function xFor(point) { return endTime > startTime ? (point.time - startTime) / (endTime - startTime) * plot.width : plot.width / 2 }
  function selectAt(x) {
    if (!points.length) { selectedIndex = -1; return }
    var target = startTime + Math.max(0, Math.min(1, x / Math.max(1, plot.width))) * (endTime - startTime)
    var nearest = 0
    for (var i = 1; i < points.length; i++)
      if (Math.abs(points[i].time - target) < Math.abs(points[nearest].time - target)) nearest = i
    selectedIndex = nearest
  }
  onPointsChanged: { selectedIndex = Math.min(selectedIndex, points.length - 1); plot.requestPaint() }
  onCeilingChanged: plot.requestPaint()
  onLineColorChanged: plot.requestPaint()
  Text {
    id: reading
    width: parent.width
    text: root.selectedPoint ? Qt.formatDateTime(new Date(root.selectedPoint.time * 1000), "dd.MM HH:mm:ss")
      + " · " + Number(root.selectedPoint.value).toFixed(1) + " " + root.unit : root.hint
    textFormat: Text.PlainText
    color: root.selectedPoint ? root.lineColor : Qt.darker(Host.Color.popups.text, 1.25)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }
  Canvas {
    id: plot
    anchors.top: reading.bottom
    anchors.topMargin: Style.spacing.sm
    anchors.left: parent.left; anchors.right: parent.right
    anchors.bottom: timeLabels.top
    anchors.bottomMargin: Style.spacing.xs
    antialiasing: true
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var context = getContext("2d")
      context.clearRect(0, 0, width, height)
      if (!root.points.length) return
      var maximum = root.ceiling > 0 ? root.ceiling : 1
      if (root.ceiling <= 0) root.points.forEach(function(point) { maximum = Math.max(maximum, point.value * 1.12) })
      context.beginPath()
      root.points.forEach(function(point, index) {
        var x = root.xFor(point), y = height - Math.max(0, Math.min(1, point.value / maximum)) * (height - 1)
        if (index === 0 || point.time - root.points[index - 1].time > 60) context.moveTo(x, y)
        else context.lineTo(x, y)
      })
      context.strokeStyle = root.lineColor
      context.lineWidth = Math.max(1, Style.spaceReal(1.5))
      context.stroke()
    }
    Rectangle {
      visible: !!root.selectedPoint
      x: root.selectedPoint ? root.xFor(root.selectedPoint) : 0
      width: 1; height: parent.height
      color: root.lineColor
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.CrossCursor
      onPositionChanged: function(mouse) { root.selectAt(mouse.x) }
      onPressed: function(mouse) { root.selectAt(mouse.x); root.forceActiveFocus() }
    }
  }
  Item {
    id: timeLabels
    anchors.bottom: parent.bottom
    width: parent.width
    height: Style.font.caption + Style.spacing.xs
    Text {
      text: root.points.length ? Qt.formatDateTime(new Date(root.startTime * 1000), "HH:mm:ss") : "—"
      textFormat: Text.PlainText
      color: Host.Color.popups.text; font.pixelSize: Style.font.caption; font.family: Style.font.family
    }
    Text {
      anchors.right: parent.right
      text: root.points.length ? Qt.formatDateTime(new Date(root.endTime * 1000), "HH:mm:ss") : "—"
      textFormat: Text.PlainText
      color: Host.Color.popups.text; font.pixelSize: Style.font.caption; font.family: Style.font.family
    }
  }
  activeFocusOnTab: true
  Keys.onLeftPressed: selectedIndex = Math.max(0, selectedIndex - 1)
  Keys.onRightPressed: selectedIndex = Math.min(points.length - 1, selectedIndex + 1)
}
