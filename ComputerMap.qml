import QtQuick
import qs.Commons
import qs.Commons as Host
import qs.Ui

Item {
  id: root
  function t(key, a, b, c) { return locale ? locale.t(key, a, b, c) : key }
  objectName: "computerMap"
  property var locale: null
  property string language: locale ? locale.language : "en"
  property string selectedPart: ""
  property var readings: ({})
  signal picked(string part)
  readonly property bool compact: width < Style.space(600)
  readonly property bool stacked: width < Style.space(436)
  readonly property real labelWidth: stacked ? (width-Style.spacing.sm)/2
    : compact ? Style.space(94) : Math.min(width * 0.32, Style.space(190))
  readonly property real rowHeight: compact ? Math.max(Style.space(44), Style.font.caption * 4 + Style.spacing.xs)
    : Math.max(Style.space(48), Style.font.caption * 4 + Style.spacing.sm * 2)
  implicitHeight: stacked ? drawing.height + Style.spacing.sm + rowHeight * 6
    : Math.max(width * 0.40, rowHeight * 6)
  readonly property color ink: Host.Color.popups.text
  readonly property color accent: Host.Color.accent
  function hex(color) {
    return "#" + [color.r,color.g,color.b].map(function(c){return Math.round(c*255).toString(16).padStart(2,"0")}).join("")
  }
  readonly property var parts: [
    {key:"fan_rear",x:0.15,y:0.25,side:0,row:0}, {key:"cpu",x:0.43,y:0.29,side:0,row:1},
    {key:"memory",x:0.65,y:0.29,side:1,row:1}, {key:"fan_cpu",x:0.43,y:0.43,side:0,row:2},
    {key:"gpu",x:0.43,y:0.64,side:0,row:4}, {key:"storage",x:0.65,y:0.48,side:1,row:2},
    {key:"motherboard",x:0.27,y:0.48,side:0,row:3}, {key:"fan_front",x:0.85,y:0.51,side:1,row:3},
    {key:"fan_top",x:0.44,y:0.09,side:1,row:0}, {key:"fan_ssd",x:0.65,y:0.80,side:1,row:5},
    {key:"fan_bottom",x:0.492,y:0.825,side:0,row:5}
  ]
  Item {
    id: drawing
    objectName: "computerMapDrawing"
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true
    x: (root.width-width)/2
    y: root.stacked ? 0 : (root.height-height)/2
    width: root.stacked ? parent.width : Math.max(0, parent.width - root.labelWidth * 2 - Style.spacing.sm * 2)
    height: width * 0.72
    Image {
      anchors.fill: parent
      readonly property int pixelWidth: Math.max(1,Math.ceil(width*Screen.devicePixelRatio))
      readonly property int pixelHeight: Math.max(1,Math.ceil(height*Screen.devicePixelRatio))
      sourceSize.width: pixelWidth
      sourceSize.height: pixelHeight
      // Original side cutaway. Tabler keyline principles: uniform strokes,
      // round joins, simple geometry and generous separation, not boxed labels.
      source: "data:image/svg+xml;utf8," + encodeURIComponent(
        '<svg xmlns="http://www.w3.org/2000/svg" width="'+pixelWidth+'" height="'+pixelHeight+'" viewBox="0 0 500 360" fill="none" stroke="'+root.hex(root.ink)+'" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
        +'<path d="M42 24H438L462 42V328H42Z M438 24V310H42m396 0 24 18M62 328v12h35v-12m299 0v12h35v-12"/>'
        +'<rect x="110" y="65" width="260" height="220" rx="5" stroke-opacity=".45"/>'
        +'<path d="M120 74h25m-25 7h25m-25 7h25m-25 7h25M130 161v28h33m123 4v15h50m-175-22v18m-7-18v18m-7-18v18" stroke-opacity=".5"/>'
        +'<rect x="165" y="76" width="102" height="104" rx="5"/>'
        +'<path d="M175 82v92m9-92v92m9-92v92m9-92v92m9-92v92m9-92v92m9-92v92m9-92v92m9-92v92m9-92v92" stroke-opacity=".4"/>'
        +'<circle cx="216" cy="127" r="34"/><circle cx="216" cy="127" r="8"/>'
        +'<path d="M211 120c-27-22-4-36 4-23l7 23m1 4c30-15 33 12 18 12l-17-4m-7 3c-2 34-27 21-20 8l13-15"/>'
        +'<rect x="299" y="76" width="15" height="87" rx="2"/><rect x="324" y="76" width="15" height="87" rx="2"/>'
        +'<path d="M303 87h7m-7 13h7m-7 13h7m-7 13h7m-7 13h7m18-52h7m-7 13h7m-7 13h7m-7 13h7m-7 13h7" stroke-opacity=".5"/>'
        +'<rect x="281" y="175" width="75" height="22" rx="3"/><circle cx="348" cy="186" r="2"/><path d="M290 181h33m-33 5h33m-33 5h33" stroke-opacity=".5"/>'
        +'<rect x="106" y="220" width="258" height="55" rx="5"/><path d="M107 230H96v49h13m12-4v10h97m14-10v10h56"/>'
        +'<circle cx="177" cy="247" r="20"/><circle cx="287" cy="247" r="20"/>'
        +'<path d="m164 234 26 26m-26 0 26-26m84 0 26 26m-26 0 26-26" stroke-opacity=".5"/>'
        +'<rect x="385" y="65" width="41" height="220" rx="3"/>'
        +'<circle cx="405" cy="105" r="17"/><circle cx="405" cy="175" r="17"/><circle cx="405" cy="245" r="17"/>'
        +'<path d="m394 94 22 22m-22 0 22-22m-22 70 22 22m-22 0 22-22m-22 70 22 22m-22 0 22-22" stroke-opacity=".5"/>'
        +'<rect x="57" y="65" width="38" height="63" rx="3"/><circle cx="76" cy="96" r="14"/><path d="m66 86 20 20m-20 0 20-20"/>'
        +'<path d="M151 40h161m-161 7h161m-161 7h161" stroke-opacity=".55"/>'
        +'<rect x="58" y="293" width="126" height="15" rx="2"/><path d="M69 296v9m8-9v9m8-9v9m8-9v9m8-9v9" stroke-opacity=".4"/>'
        +'<rect x="205" y="286" width="82" height="23" rx="3"/><ellipse cx="246" cy="297" rx="27" ry="9"/><path d="m225 292 42 10m-42 0 42-10" stroke-opacity=".5"/>'
        +'</svg>')
    }
    Repeater {
      model: root.parts
      Item {
        id: target
        required property var modelData
        required property int index
        x: modelData.x*drawing.width-width/2
        y: modelData.y*drawing.height-height/2
        objectName: "mapTarget-" + modelData.key
        width: Style.space(root.compact ? 24 : 30); height: width
        Rectangle {
          anchors.centerIn: parent
          width: Style.space(20); height: width; radius: width/2
          color: root.selectedPart===target.modelData.key || mouse.containsMouse || target.activeFocus ? root.accent : Host.Color.popups.background
          border.color: root.accent; border.width: Math.max(1,Style.space(1))
          Text {
            anchors.centerIn: parent
            text: target.index+1; textFormat: Text.PlainText
            color: root.selectedPart===target.modelData.key || mouse.containsMouse || target.activeFocus ? Host.Color.popups.background : root.accent
            font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true
          }
        }
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: root.t("map_"+modelData.key) + ": " + ((root.readings[modelData.key] || {}).text || root.t("map_no_data"))
        Keys.onReturnPressed: root.picked(modelData.key)
        Keys.onSpacePressed: root.picked(modelData.key)
        MouseArea {
          id: mouse; anchors.fill: parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor
          onClicked: root.picked(target.modelData.key)
        }
        PanelToolTip { visible:mouse.containsMouse || target.activeFocus; text:target.Accessible.name; fontFamily:Style.font.family }
      }
    }
  }
  Item {
    objectName: "mapLegend"
    anchors.fill: parent
    Repeater {
      model: root.parts
      Item {
        id: callout
        required property var modelData
        required property int index
        readonly property var reading: root.readings[modelData.key] || ({text:root.t("map_no_data")})
        readonly property real pointX: drawing.x + modelData.x * drawing.width
        readonly property real pointY: drawing.y + modelData.y * drawing.height
        x: modelData.side ? root.width - width : 0
        y: root.stacked ? drawing.height + Style.spacing.sm + modelData.row * root.rowHeight
          : modelData.row * (root.height-root.rowHeight) / 5
        width: root.labelWidth
        height: root.rowHeight - Style.spacing.xs
        Rectangle {
          visible: !root.stacked
          readonly property real dx: callout.pointX - callout.x - x
          readonly property real dy: callout.pointY - callout.y - y
          x: callout.modelData.side ? 0 : callout.width
          y: callout.height / 2
          width: Math.sqrt(dx*dx+dy*dy)
          height: 1
          rotation: Math.atan2(dy,dx)*180/Math.PI
          transformOrigin: Item.TopLeft
          color: root.accent
          opacity: root.selectedPart===callout.modelData.key ? 0.8 : 0.3
          z: -1
        }
        Button {
          objectName: "mapLegendPart" + callout.index
          anchors.fill: parent
          foreground: root.ink; accent: root.accent
          selected: root.selectedPart===callout.modelData.key
          bordered: true; focusable: true
          tooltipText: root.t("map_"+callout.modelData.key) + "\n" + (callout.reading.detail || root.t("map_no_data"))
          Accessible.name: title.text + ": " + value.text
          onClicked: root.picked(callout.modelData.key)
          Column {
            anchors.centerIn: parent
            width: parent.width - Style.spacing.sm * 2
            Text {
              id: title
              width: parent.width
              text: (callout.index+1) + " · " + root.t((root.compact ? "map_short_" : "map_")+callout.modelData.key)
              textFormat: Text.PlainText; wrapMode: Text.Wrap
              color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
            Text {
              id: value
              objectName: "mapReading-" + callout.modelData.key
              width: parent.width
              text: root.compact ? String(callout.reading.text).split(" · ").join("\n") : callout.reading.text
              textFormat: Text.PlainText; wrapMode: Text.Wrap
              color: callout.reading.hot ? Host.Color.urgent : root.accent
              font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true
            }
          }
        }
      }
    }
  }
}
