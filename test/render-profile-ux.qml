import QtQuick
import qs.Commons as Host
import ".." as Plugin
import "mock-data.js" as MockData

Rectangle {
  id: canvas
  color: Host.Color.popups.background
  property string page: "overview"
  property string language: "en"
  property bool editor: false
  property bool expanded: true
  property bool ready: false
  property bool gaming: false
  property bool showMap: false
  property bool autoOptions: false
  function nodes(item) {
    var result = [item]
    for (var child of (item.children || [])) result = result.concat(nodes(child))
    return result
  }
  Timer { id:settle;interval:250;onTriggered:canvas.ready=true }
  Plugin.Panel {
    id: plugin
    anchors.fill: parent
    settings: ({locale:canvas.language,iconMotion:false,iconIndicator:false,autoGameBaseProfile:"idle",fanPlace_pwm2:"fan_cpu",fanPlace_pwm3:"fan_front",fanPlace_pwm4:"fan_bottom"})
    Component.onCompleted: {
      plugin.open(); plugin.setExpanded(canvas.expanded)
      MockData.populate(plugin.activityController)
      plugin.sensorsOpen=canvas.page==="fans" || canvas.page==="cooling"
      plugin.fansOpen=canvas.page==="fans"
      plugin.settingsOpen=canvas.page==="settings"
      Qt.callLater(function() {
        plugin.activityController.stop(); MockData.populate(plugin.activityController)
        plugin.activityController.iconTemperature=54
        plugin.activityController.thermalUpdatedAt=Date.now()
        plugin.activityController.freshnessClock=Date.now()
        plugin.activityController.processGpus={"41820:1000":{usage:12,byGpu:{"0000:01:00.0":12}},"44910:8000":{usage:4,byGpu:{"0000:01:00.0":4}}}
        plugin.activityController.processGpusUpdatedAt=Date.now()
        plugin.activityController._gpus=[{id:"0000:01:00.0",vendor:"NVIDIA",name:"NVIDIA GeForce RTX 5060 Ti",usage:26,memoryUsed:4200000000,memoryTotal:16000000000,memoryKind:"vram",frequencyMHz:1200}]
        var profiles=canvas.nodes(plugin).filter(function(n){return n.objectName==="powerProfiles"})[0]
        if(profiles) {
          profiles.cpuCapabilities={boost:"1",noTurbo:null,policies:[{scaling_governor:"powersave",energy_performance_preference:"power",scaling_max_freq:"5400000"}],automatic:{enabled:false,gaming:canvas.gaming,error:""}}
          profiles.capabilitiesReady=true;profiles.automationOptionsOpen=canvas.autoOptions
          if(canvas.editor){profiles.editorOpen=true;profiles.selectProfile("idle")}
        }
        if(canvas.page==="cooling"){plugin.selectPart("motherboard");plugin.sensorOptionsOpen=true}
        plugin.computerMapVisible=canvas.showMap;settle.restart()
      })
    }
  }
}
