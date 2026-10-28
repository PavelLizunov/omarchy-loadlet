import QtQuick
import qs.Commons as Host
import ".." as Plugin
import "mock-data.js" as MockData
Rectangle {
 id:canvas
 color:Host.Color.popups.background
 property string page:"fans"
 property bool editor:false
 property bool expanded:true
 property bool ready:false
 Plugin.Panel {
  id:plugin;anchors.fill:parent
  settings:({locale:"ru",iconMotion:false,iconIndicator:false})
  function nodes(item){var a=[item];for(var child of (item.children||[]))a=a.concat(nodes(child));return a}
  Component.onCompleted:{
   plugin.open();plugin.setExpanded(canvas.expanded);MockData.populate(plugin.activityController)
   plugin.activityController._gpus=[{id:"0000:01:00.0",vendor:"NVIDIA",name:"NVIDIA GeForce RTX 5060 Ti",usage:0,memoryUsed:0,memoryTotal:16000000000,memoryKind:"vram",frequencyMHz:200}]
   plugin.sensorsOpen=true;plugin.fansOpen=canvas.page==="fans"
   Qt.callLater(function(){
    plugin.activityController.stop();MockData.populate(plugin.activityController)
    plugin.activityController._gpus=[{id:"0000:01:00.0",vendor:"NVIDIA",name:"NVIDIA GeForce RTX 5060 Ti",usage:0,memoryUsed:0,memoryTotal:16000000000,memoryKind:"vram",frequencyMHz:200}]
    if(canvas.page==="cooling") {plugin.selectPart("motherboard");plugin.sensorOptionsOpen=true}
    if(canvas.editor){var p=nodes(plugin).filter(function(n){return n.objectName==="powerProfiles"})[0];p.editorOpen=true;p.selectProfile("idle")}
    Qt.callLater(function(){canvas.ready=true})
   })
  }
 }
}
