import QtQuick
import qs.Commons as Host
import "imports/ActivityHost/Ui" as NativeHost
import "plugin" as Plugin

Rectangle {
  id: fixture
  color: Host.Color.background
  property string language: "en"
  property int fontSize: 12
  property bool stale: false
  property bool hot: false
  property bool previewReady: false
  property string tooltipText: ""
  Component.onCompleted: {
    Host.Color.loadColors('foreground="#d8dee9"\nbackground="#2e3440"\naccent="#81a1c1"\nred="#bf616a"')
    Host.Style.fontBaseSize=fontSize
  }
  Plugin.Panel {
    id: plugin
    visible: false
    width: Host.Style.bar.iconSlot
    height: Host.Style.bar.sizeHorizontal
    settings: ({locale:fixture.language,iconIndicator:false,iconShape:10,iconLoadThreshold:50})
  }
  NativeHost.ActivityTooltipBubble {
    id: bubble
    objectName: "tooltipRoot"
    x: 12; y: 12
    width: implicitWidth
    height: implicitHeight
    tooltipText: fixture.tooltipText
  }
  Timer {
    interval: 40; repeat: true; running: true
    onTriggered: {
      var ctrl=plugin.activityController
      ctrl.stop()
      ctrl.glanceCpu=27;ctrl.glanceMemory=61
      ctrl.glanceMemoryUsed=9.11*1024*1024*1024;ctrl.glanceMemoryTotal=14.9*1024*1024*1024
      ctrl.glanceUpdatedAt=100000;ctrl.thermalUpdatedAt=100000
      ctrl.iconTemperature=fixture.hot?85:72;ctrl.freshnessClock=fixture.stale?135000:115000
      ctrl.updateHeatAlert()
      function nodes(item) {
        var result=[item]
        if(item.children) for(var i=0;i<item.children.length;i++) result=result.concat(nodes(item.children[i]))
        return result
      }
      var button=nodes(plugin).filter(function(n){return n.iconComponent!==undefined})[0]
      if(!button) return
      fixture.tooltipText=button.tooltipText
      fixture.previewReady=true
      stop()
    }
  }
}
