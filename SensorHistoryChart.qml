import QtQuick
import qs.Commons
import qs.Commons as Host
import qs.Ui

Item {
  id: root
  objectName: "sensorHistoryChart"
  property var points: []
  property color lineColor: Host.Color.accent
  property real ceiling: 120
  property string unit: "°C"
  property string hint: ""
  property string emptyText: ""
  property string gapText: ""
  property string liveText: ""
  property bool subsecond: false
  property int windowSeconds: 0
  property double referenceTime: 0
  property int selectedIndex: -1
  property double selectedTime: -1
  property bool pinned: false
  property bool cursorInGap: false
  readonly property var selectedPoint: selectedIndex >= 0 && selectedIndex < points.length ? points[selectedIndex] : null
  readonly property real endTime: referenceTime > 0 ? referenceTime : points.length ? points[points.length - 1].time : 0
  readonly property real startTime: windowSeconds > 0 ? endTime - windowSeconds : points.length ? points[0].time : 0
  readonly property real maximum: {
    var high = Math.max(1, ceiling)
    points.forEach(function(point) { high = Math.max(high, point.value) })
    if (ceiling > 0) return Math.ceil(high)
    var step = Math.pow(10, Math.floor(Math.log(high) / Math.LN10)) / 2
    return Math.ceil(high * 1.1 / step) * step
  }
  readonly property real axisWidth: Math.ceil(axisMetrics.width) + Style.spacing.sm
  function formatValue(value) { return Number(value).toFixed(unit === "°C" || unit === "°F" ? 1 : 0) }
  function xFor(point) {
    var ratio = endTime > startTime ? (point.time - startTime) / (endTime - startTime) : 0.5
    return 1 + Math.max(0, Math.min(1, ratio)) * Math.max(1, plot.width - 2)
  }
  function yFor(value) { return 1 + (1 - Math.max(0, Math.min(1, value / maximum))) * Math.max(1, plot.height - 2) }
  function breakBefore(index) {
    return index > 0 && (points[index].breakBefore === true
      || (points[index].breakBefore === undefined && points[index].time - points[index - 1].time > 60))
  }
  function clearSelection() { selectedIndex = -1; selectedTime = -1; pinned = false; cursorInGap = false }
  function selectIndex(index) {
    selectedIndex = Math.max(-1, Math.min(points.length - 1, index))
    selectedTime = selectedPoint ? selectedPoint.time : -1
    cursorInGap = false
  }
  function selectAt(x) {
    if (!points.length) { clearSelection(); return }
    var target = startTime + Math.max(0, Math.min(1, x / Math.max(1, plot.width))) * (endTime - startTime)
    var nearest = 0, gap = target < points[0].time || target > points[points.length - 1].time
    for (var i = 1; i < points.length; i++) {
      if (Math.abs(points[i].time - target) < Math.abs(points[nearest].time - target)) nearest = i
      if (breakBefore(i) && target > points[i - 1].time && target < points[i].time) gap = true
    }
    if (gap && Math.abs(xFor(points[nearest]) - x) > Style.space(8)) {
      selectIndex(-1); cursorInGap = true
    } else selectIndex(nearest)
  }
  onSelectedIndexChanged: selectedTime = selectedPoint ? selectedPoint.time : -1
  onPointsChanged: {
    var time = selectedTime
    var index = time < 0 ? -1 : points.findIndex(function(point) { return point.time === time })
    selectIndex(index)
    if (index < 0) pinned = false
    plot.requestPaint()
  }
  onMaximumChanged: plot.requestPaint()
  onStartTimeChanged: plot.requestPaint()
  onEndTimeChanged: plot.requestPaint()
  onLineColorChanged: plot.requestPaint()

  TextMetrics {
    id: axisMetrics
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    text: root.formatValue(root.maximum) + " " + root.unit
  }
  Text {
    id: reading
    objectName: "chartReading"
    anchors.left: parent.left
    anchors.right: liveButton.left
    anchors.rightMargin: Style.spacing.sm
    anchors.verticalCenter: liveButton.verticalCenter
    text: root.selectedPoint ? Qt.formatDateTime(new Date(root.selectedPoint.time * 1000), root.subsecond ? "dd.MM HH:mm:ss.zzz" : "dd.MM HH:mm:ss")
      + " · " + root.formatValue(root.selectedPoint.value) + " " + root.unit : root.cursorInGap ? root.gapText : root.hint
    textFormat: Text.PlainText
    color: root.selectedPoint ? root.lineColor : Host.Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }
  Button {
    id: liveButton
    objectName: "chartLiveButton"
    anchors.top: parent.top; anchors.right: parent.right
    height: Style.space(22)
    text: root.liveText
    fontFamily: Style.font.family; fontSize: Style.font.caption
    foreground: Host.Color.popups.text; accent: root.lineColor
    enabled: root.selectedIndex >= 0 || root.cursorInGap
    bordered: true; focusable: true
    onClicked: root.clearSelection()
  }
  Item {
    id: graphArea
    anchors.top: liveButton.bottom; anchors.topMargin: Style.spacing.xs
    anchors.left: parent.left; anchors.right: parent.right
    anchors.bottom: timeLabels.top; anchors.bottomMargin: Style.spacing.xs
    Repeater {
      model: [1, 0.5, 0]
      Text {
        required property real modelData
        width: root.axisWidth - Style.spacing.sm
        y: (1 - modelData) * (graphArea.height - height)
        text: root.formatValue(root.maximum * modelData) + (modelData === 1 ? " " + root.unit : "")
        horizontalAlignment: Text.AlignRight
        textFormat: Text.PlainText; color: Host.Color.popups.text
        font.family: Style.font.family; font.pixelSize: Style.font.caption
      }
    }
    Canvas {
      id: plot
      objectName: "chartPlot"
      anchors.top: parent.top; anchors.bottom: parent.bottom
      anchors.left: parent.left; anchors.leftMargin: root.axisWidth
      anchors.right: parent.right
      antialiasing: true
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var context = getContext("2d")
        context.clearRect(0, 0, width, height)
        context.beginPath()
        ;[1, 0.5, 0].forEach(function(level) {
          var y = root.yFor(root.maximum * level)
          context.moveTo(0, y); context.lineTo(width, y)
        })
        context.strokeStyle = Util.alpha(Host.Color.popups.text, 0.16)
        context.lineWidth = 1; context.stroke()
        context.beginPath()
        root.points.forEach(function(point, index) {
          var x = root.xFor(point), y = root.yFor(point.value)
          if (index === 0 || root.breakBefore(index)) context.moveTo(x, y)
          else context.lineTo(x, y)
        })
        context.strokeStyle = root.lineColor
        context.lineWidth = Math.max(1, Style.spaceReal(1.5)); context.stroke()
        root.points.forEach(function(point, index) {
          if ((index === 0 || root.breakBefore(index))
              && (index === root.points.length - 1 || root.breakBefore(index + 1))) {
            context.beginPath(); context.arc(root.xFor(point), root.yFor(point.value), 2, 0, Math.PI * 2)
            context.fillStyle = root.lineColor; context.fill()
          }
        })
      }
      Rectangle {
        visible: !!root.selectedPoint
        x: root.selectedPoint ? root.xFor(root.selectedPoint) : 0
        width: 1; height: parent.height
        color: root.lineColor; opacity: 0.65
      }
      Rectangle {
        visible: !!root.selectedPoint
        x: root.selectedPoint ? root.xFor(root.selectedPoint) - width / 2 : 0
        y: root.selectedPoint ? root.yFor(root.selectedPoint.value) - height / 2 : 0
        width: Style.space(5); height: width; radius: width / 2
        color: root.lineColor
      }
      Text {
        anchors.centerIn: parent
        width: parent.width
        visible: !root.points.length
        text: root.emptyText
        textFormat: Text.PlainText; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
        color: Host.Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption
      }
      MouseArea {
        objectName: "chartPointer"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.CrossCursor
        onPositionChanged: function(mouse) { if (!root.pinned || pressed) root.selectAt(mouse.x) }
        onPressed: function(mouse) { root.selectAt(mouse.x); root.pinned = true; root.forceActiveFocus() }
        onExited: if (!root.pinned) root.clearSelection()
        onDoubleClicked: root.clearSelection()
      }
    }
  }
  Item {
    id: timeLabels
    anchors.bottom: parent.bottom
    anchors.left: parent.left; anchors.leftMargin: root.axisWidth
    anchors.right: parent.right
    height: Style.font.caption + Style.spacing.xs
    Text {
      text: root.endTime > 0 ? Qt.formatDateTime(new Date(root.startTime * 1000), "HH:mm:ss") : "—"
      textFormat: Text.PlainText
      color: Host.Color.popups.text; font.pixelSize: Style.font.caption; font.family: Style.font.family
    }
    Text {
      anchors.right: parent.right
      text: root.endTime > 0 ? Qt.formatDateTime(new Date(root.endTime * 1000), "HH:mm:ss") : "—"
      textFormat: Text.PlainText
      color: Host.Color.popups.text; font.pixelSize: Style.font.caption; font.family: Style.font.family
    }
  }
  activeFocusOnTab: true
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape && (selectedIndex >= 0 || cursorInGap)) clearSelection()
    else if (event.key === Qt.Key_Left) { selectIndex(points.length ? (selectedIndex < 0 ? points.length - 1 : Math.max(0, selectedIndex - 1)) : -1); pinned = selectedIndex >= 0 }
    else if (event.key === Qt.Key_Right) { selectIndex(Math.min(points.length - 1, selectedIndex + 1)); pinned = selectedIndex >= 0 }
    else if (event.key === Qt.Key_Home) { selectIndex(points.length ? 0 : -1); pinned = selectedIndex >= 0 }
    else if (event.key === Qt.Key_End) { selectIndex(points.length - 1); pinned = selectedIndex >= 0 }
    else return
    event.accepted = true
  }
}
