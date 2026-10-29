import QtQuick
import qs.Commons as Host
import ".." as Plugin
import "mock-data.js" as MockData

Rectangle {
  id: canvas
  color: Host.Color.popups.background
  property bool expanded: false
  property bool light: true
  property string language: "ru"
  property bool ready: false
  Timer { id:settle;interval:250;onTriggered:canvas.ready=true }
  Plugin.Panel {
    id: plugin
    anchors.fill: parent
    settings: ({locale:canvas.language,iconMotion:false,iconIndicator:false,
      fanPlace_pwm2:"fan_cpu",fanPlace_pwm3:"fan_top"})
    Component.onCompleted: {
      if(canvas.light) {
        Host.Color.background="#eee3cf";Host.Color.foreground="#302b3a"
        Host.Color.accent="#aa4d0e";Host.Color.urgent="#a12b30"
      }
      plugin.open();plugin.setExpanded(canvas.expanded)
      plugin.sensorsOpen=true
      Qt.callLater(function() {
        plugin.activityController.stop();MockData.populate(plugin.activityController)
        var snapshot=plugin.activityController._sensorSnapshot
        var temperatures=snapshot.temperatures.concat([
          {id:"cpu-die",category:"cpu",value:42},
          {id:"gpu-hotspot",category:"gpu",value:50},
          {id:"ram",category:"memory",value:40},
          {id:"drive",category:"storage",value:34},
          {id:"board-other",category:"motherboard",value:52}])
        var fans=snapshot.fans.concat([
          {id:"fan3",chip:"it8613",label:"fan3",category:"motherboard",unit:"rpm",value:1125},
          {id:"fan4",chip:"it8613",label:"fan4",category:"motherboard",unit:"rpm",value:0},
          {id:"gpu-fan",category:"gpu",unit:"percent",value:30}])
        plugin.activityController._sensorSnapshot=Object.assign({},snapshot,{temperatures:temperatures,fans:fans})
        plugin.sensorPart="";plugin.computerMapVisible=true
        settle.restart()
      })
    }
  }
}
