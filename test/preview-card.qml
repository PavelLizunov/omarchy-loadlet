// Historical static mock: NOT the production Panel.qml and NOT acceptance evidence.
// Preserved at the user's request when development was paused.
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import ".." as Plugin

Rectangle {
  id: canvas
  width: 520
  height: 480
  color: "#181a1f"

  Rectangle {
    anchors.fill: parent
    color: Color.popups ? Color.popups.background : "#21252b"
    border.color: Color.popups ? Color.popups.border : "#3b4048"
    border.width: Style.space(2)
    radius: Style.cornerRadius

    Column {
      anchors.fill: parent
      anchors.margins: Style.spacing.xl
      spacing: Style.spacing.md

      // Header
      Row {
        width: parent.width
        spacing: Style.spacing.md

        Text {
          text: "\uf201"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }

        Column {
          width: parent.width - 120
          Text {
            text: "Активность"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
          }
          Text {
            text: "Аптайм 2 дня 16 ч"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      // Metric Cards Row
      Row {
        width: parent.width
        spacing: Style.spacing.md

        // CPU Card
        Rectangle {
          width: (parent.width - Style.spacing.md) / 2
          height: Style.space(110)
          color: "#282c34"
          border.color: "#3e4451"
          radius: Style.cornerRadius

          Column {
            anchors.fill: parent
            anchors.margins: Style.spacing.md
            spacing: Style.spacing.xs

            Row {
              width: parent.width
              Text { text: "Процессор · 3.1 GHz"; color: Color.foreground; font.bold: true; font.pixelSize: Style.font.bodySmall }
            }

            Row {
              width: parent.width
              Column {
                width: parent.width - 64
                Text { text: "34%"; color: Color.foreground; font.pixelSize: Style.font.title; font.bold: true }
                Text { text: "55°C"; color: Color.muted; font.pixelSize: Style.font.caption }
              }
              Rectangle {
                width: 56; height: 32; color: "transparent"; border.color: "#4b5263"; border.width: 1
                Text { text: "8 CORE"; color: Color.muted; font.pixelSize: 9; anchors.centerIn: parent }
              }
            }

            Rectangle {
              width: parent.width; height: 3; color: "#3e4451"
              Rectangle { width: parent.width * 0.34; height: parent.height; color: "#61afef" }
            }
          }
        }

        // RAM Card
        Rectangle {
          width: (parent.width - Style.spacing.md) / 2
          height: Style.space(110)
          color: "#282c34"
          border.color: "#3e4451"
          radius: Style.cornerRadius

          Column {
            anchors.fill: parent
            anchors.margins: Style.spacing.md
            spacing: Style.spacing.xs

            Row {
              width: parent.width
              Text { text: "ОЗУ · 5500 MT/s"; color: Color.foreground; font.bold: true; font.pixelSize: Style.font.bodySmall }
              Text { text: "Подк 0%"; color: Color.muted; font.pixelSize: Style.font.caption; anchors.right: parent.right }
            }

            Row {
              width: parent.width
              Column {
                width: parent.width
                Text { text: "56%"; color: Color.foreground; font.pixelSize: Style.font.title; font.bold: true }
                Text { text: "исп. 11.6G · кэш 3.8G"; color: Color.muted; font.pixelSize: Style.font.caption }
              }
            }

            Rectangle {
              width: parent.width; height: 3; color: "#3e4451"
              Rectangle { width: parent.width * 0.56; height: parent.height; color: "#98c379" }
            }
          }
        }
      }

      // Network & Disk Row
      Row {
        width: parent.width
        spacing: Style.spacing.md

        Rectangle {
          width: (parent.width - Style.spacing.md) / 2
          height: Style.space(56)
          color: "#282c34"
          border.color: "#3e4451"
          radius: Style.cornerRadius

          Row {
            anchors.centerIn: parent
            spacing: Style.spacing.md
            Text { text: "Сеть"; color: Color.muted; font.bold: true; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "↓ 750 B/s  ↑ 590 B/s"; color: Color.foreground; font.bold: true; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
          }
        }

        Rectangle {
          width: (parent.width - Style.spacing.md) / 2
          height: Style.space(56)
          color: "#282c34"
          border.color: "#3e4451"
          radius: Style.cornerRadius

          Row {
            anchors.centerIn: parent
            spacing: Style.spacing.md
            Text { text: "Диск"; color: Color.muted; font.bold: true; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Чт 0 B/s  Зап 110K/s"; color: Color.foreground; font.bold: true; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
          }
        }
      }

      // Busiest Section
      Text {
        text: "Активные процессы"
        color: Color.foreground
        font.bold: true
        font.pixelSize: Style.font.bodySmall
      }

      Column {
        width: parent.width
        spacing: Style.spacing.xs

        Rectangle {
          width: parent.width; height: 30; color: "#21252b"; radius: 4
          Row {
            anchors.fill: parent; anchors.margins: 6
            Text { text: "opencode"; color: Color.foreground; font.bold: true; width: 220; elide: Text.ElideRight }
            Text { text: "114.9%"; color: "#e06c75"; font.bold: true; width: 80; horizontalAlignment: Text.AlignRight }
            Text { text: "5.0%"; color: Color.foreground; width: 60; horizontalAlignment: Text.AlignRight }
          }
        }

        Rectangle {
          width: parent.width; height: 30; color: "#21252b"; radius: 4
          Row {
            anchors.fill: parent; anchors.margins: 6
            Text { text: "ghostty"; color: Color.foreground; font.bold: true; width: 220; elide: Text.ElideRight }
            Text { text: "21.2%"; color: Color.foreground; width: 80; horizontalAlignment: Text.AlignRight }
            Text { text: "0.6%"; color: Color.foreground; width: 60; horizontalAlignment: Text.AlignRight }
          }
        }
      }
    }
  }
}
