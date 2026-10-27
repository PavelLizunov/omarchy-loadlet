import QtQuick
import qs.Commons as Host
import ".." as Plugin
import "mock-data.js" as MockData

Rectangle {
  id: canvas
  color: Host.Color.popups.background
  property bool compact: false
  property bool ready: false
  Plugin.Panel {
    id: plugin
    anchors.fill: parent
    settings: ({locale:"ru",iconMotion:false})
    Component.onCompleted: {
      plugin.open()
      plugin.setExpanded(!canvas.compact)
      MockData.populate(plugin.activityController)
      var ctrl = plugin.activityController
      ctrl._gpus = [
        {id:"0000:01:00.0",name:"NVIDIA GeForce RTX 5060 Ti",usage:42,memoryUsed:2000000000,memoryTotal:16000000000,memoryKind:"vram",frequencyMHz:2200},
        {id:"0000:06:00.0",name:"Advanced Micro Devices, Inc. [AMD/ATI] Raphael [Radeon 610M]",usage:12,memoryUsed:100000000,memoryTotal:1000000000,memoryKind:"shared",frequencyMHz:400}
      ]
      var readings = {}
      ctrl._processes.forEach(function(p,i) {
        readings[p.pid+":"+p.startTicks] = {usage:42-i,byGpu:{"0000:01:00.0":42-i,"0000:06:00.0":i===0?12:0}}
      })
      ctrl.processGpus = readings
      ctrl.processGpusUpdatedAt = Date.now()
      ctrl.freshnessClock = Date.now()
      plugin.setSort("gpu:0000:01:00.0")
      Qt.callLater(function(){canvas.ready=true})
    }
  }
}
