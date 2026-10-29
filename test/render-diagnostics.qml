import QtQuick
import qs.Commons as Host
import ".." as Plugin
import "mock-data.js" as MockData

Rectangle {
  id:canvas
  color:Host.Color.popups.background
  property bool ready:false
  property string language:"ru"
  property bool expanded:false
  property bool populated:false
  property bool agent:false
  property bool light:false
  function nodes(item) {
    var out=[item]
    if(item.children)for(var i=0;i<item.children.length;i++)out=out.concat(nodes(item.children[i]))
    return out
  }
  Timer {id:settle;interval:300;onTriggered:canvas.ready=true}
  Plugin.Panel {
    id:plugin
    anchors.fill:parent
    settings:({locale:canvas.language,iconIndicator:false,iconMotion:false})
    Component.onCompleted:{
      if(canvas.light) {
        Host.Color.background="#eee3cf";Host.Color.foreground="#302b3a"
        Host.Color.accent="#aa4d0e";Host.Color.urgent="#a12b30"
      }
      plugin.open();plugin.setExpanded(canvas.expanded);plugin.setSettingsOpen(true);plugin.settingsSection="diagnostics"
      Qt.callLater(function(){
        plugin.activityController.stop();MockData.populate(plugin.activityController)
        var all=canvas.nodes(plugin),view=all.find(function(n){return n.objectName==="fastDiagnostics"})
        var viewport=all.find(function(n){return n.objectName==="settingsViewport"})
        if(canvas.populated) {
          var end=1800000000,points=[],cpu=[]
          for(var i=0;i<120;i++) {
            points.push({time:end-60+i*.5,value:65+Math.sin(i/6)*5+(i===70?20:0),session:"demo"})
            cpu.push({time:end-60+i*.5,value:30+Math.sin(i/8)*20,session:"demo"})
          }
          view.periodSeconds=60
          view.report={schema:2,records:420,requested_range:[end-60,end],available_range:[end-60,end],resolution_seconds:.25,
            sessions:[{id:"demo",start:end-60,end:end}],gaps:[],events:[{type:"marker",time:end-25}],invalid_records:0,omitted_by_capacity:0,
            series:[{id:"temp",label:"Tctl",unit:"°C",points:points},{id:"cpu",label:"CPU",unit:"%",points:cpu}],
            process_frames:[{time:end-25,session:"demo",processes:[{name:"demo-game",pid:142,cpu:180,rss_kib:1000}]}]}
          if(canvas.agent)view.reportPath="/demo/exports/diagnostics-demo"
          Qt.callLater(function(){
            if(canvas.agent)viewport.contentY=Math.min(view.y+view.height-viewport.height,viewport.contentHeight-viewport.height)
            else viewport.contentY=300
            var plot=all.find(function(n){return n.objectName==="captureThermalPlot"});plot.selectIndex(70)
            settle.restart()
          })
        } else settle.restart()
      })
    }
  }
}
