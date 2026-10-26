import QtQuick
import qs.Commons
import qs.Commons as Host
import qs.Ui
import "I18n.js" as I18n

Item {
  id: root
  property string language: "ru"
  property string selectedPart: ""
  signal picked(string part)
  implicitHeight: width * 0.76
  readonly property color ink: Host.Color.popups.text
  readonly property color accent: Host.Color.accent
  readonly property string outlineColor: "#" + [ink.r, ink.g, ink.b].map(function(channel) {
    return Math.round(channel * 255).toString(16).padStart(2, "0")
  }).join("")
  readonly property var parts: [
    {key:"fan_top",x:0.37,y:0.06,w:0.28,h:0.12,icon:"fans"},
    {key:"fan_rear",x:0.05,y:0.24,w:0.22,h:0.15,icon:"fans"},
    {key:"cpu",x:0.34,y:0.24,w:0.23,h:0.16,icon:"cpu"},
    {key:"memory",x:0.62,y:0.24,w:0.19,h:0.16,icon:"ram"},
    {key:"fan_cpu",x:0.34,y:0.43,w:0.23,h:0.13,icon:"fans"},
    {key:"fan_front",x:0.83,y:0.43,w:0.16,h:0.22,icon:"fans"},
    {key:"gpu",x:0.17,y:0.60,w:0.61,h:0.13,icon:"gpu"},
    {key:"motherboard",x:0.17,y:0.79,w:0.28,h:0.13,icon:"cpu"},
    {key:"storage",x:0.50,y:0.79,w:0.22,h:0.13,icon:"storage"},
    {key:"fan_ssd",x:0.75,y:0.79,w:0.23,h:0.13,icon:"fans"}
  ]
  Image {
    anchors.fill: parent
    sourceSize.width: Math.max(1, Math.ceil(width * Screen.devicePixelRatio))
    sourceSize.height: Math.max(1, Math.ceil(height * Screen.devicePixelRatio))
    source: "data:image/svg+xml;utf8," + encodeURIComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" width="' + sourceSize.width + '" height="' + sourceSize.height
      + '" viewBox="0 0 400 304" fill="none" stroke="' + root.outlineColor + '" stroke-opacity="0.35" stroke-width="2">'
      + '<rect x="8" y="8" width="384" height="288" rx="12"/><rect x="52" y="58" width="268" height="224" rx="5"/>'
      + '<path d="M24 18h65m-65 8h65M24 283h112M330 32h46v56h-46M92 126v42h-21m130-42v42h36M82 232h198M302 144h28v72h-16"/>'
      + '<circle cx="350" cy="43" r="3"/></svg>')
  }
  Repeater {
    model: root.parts
    Button {
      id: hotspot
      required property var modelData
      x: modelData.x * root.width
      y: modelData.y * root.height
      width: modelData.w * root.width
      height: modelData.h * root.height
      text: ""
      selected: root.selectedPart === modelData.key
      foreground: root.ink
      accent: root.accent
      background: Host.Color.popups.background
      bordered: true
      focusable: true
      tooltipText: I18n.t("map_" + modelData.key, root.language)
      Accessible.name: tooltipText
      onClicked: root.picked(modelData.key)
      Rectangle {
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: Style.space(3)
        width: Style.space(4); height: width; radius: width / 2
        color: hotspot.selected ? root.accent : root.ink
      }
      Column {
        anchors.centerIn: parent
        width: parent.width - Style.spacing.xs
        spacing: Style.space(1)
        SvgIcon {
          anchors.horizontalCenter: parent.horizontalCenter
          name: hotspot.modelData.icon
          width: Math.min(Style.space(16), hotspot.height * 0.36)
          height: width
          tint: hotspot.selected ? root.accent : root.ink
        }
        Text {
          width: parent.width
          text: I18n.t("map_" + hotspot.modelData.key, root.language)
          textFormat: Text.PlainText
          color: hotspot.selected ? root.accent : root.ink
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
      }
    }
  }
}
