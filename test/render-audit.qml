import QtQuick
import qs.Commons as Host
import ".." as Plugin
import "mock-data.js" as MockData

Rectangle {
  id: canvas
  color: Host.Color.popups.background
  property string page: "overview"
  property string language: "ru"
  property bool expanded: false
  property bool light: true
  property bool editor: false
  property bool showMap: false
  property bool agent: false
  property string section: "tiles"
  property int fontSize: 12
  property bool ready: false
  function nodes(item) {
    var result = [item]
    for (var child of (item.children || [])) result = result.concat(nodes(child))
    return result
  }
  function named(name) { return nodes(plugin).find(function(n) { return n.objectName === name }) }
  Timer { interval: 250; id: settle; onTriggered: canvas.ready = true }
  Plugin.Panel {
    id: plugin
    anchors.fill: parent
    settings: ({locale:canvas.language,iconMotion:false,iconIndicator:false,
      compactTile0:"cpu",compactTile1:"gpu",compactRamStrip:true,
      activePowerProfile:"idle",fanPlace_pwm2:"fan_cpu",fanPlace_pwm3:"fan_front"})
    Component.onCompleted: {
      Host.Style.fontBaseSize = canvas.fontSize
      if (canvas.light) {
        Host.Color.background="#eee3cf";Host.Color.foreground="#302b3a"
        Host.Color.accent="#aa4d0e";Host.Color.urgent="#a12b30"
      }
      plugin.open();plugin.setExpanded(canvas.expanded)
      plugin.showPage(canvas.page === "settings" ? "overview" : canvas.page)
      if (canvas.page === "settings") { plugin.setSettingsOpen(true);plugin.settingsSection=canvas.section }
      Qt.callLater(function() {
        var ctrl=plugin.activityController
        ctrl.stop();MockData.populate(ctrl)
        ctrl.iconTemperature=54;ctrl.thermalUpdatedAt=Date.now();ctrl.freshnessClock=Date.now()
        ctrl._gpus=[{id:"0000:01:00.0",vendor:"NVIDIA",name:"NVIDIA GeForce RTX 5060 Ti",
          usage:26,memoryUsed:4200000000,memoryTotal:16000000000,memoryKind:"vram",frequencyMHz:1200}]
        var profiles=canvas.named("powerProfiles")
        profiles.cpuCapabilities={boost:"1",noTurbo:null,policies:[{scaling_governor:"powersave",
          energy_performance_preference:"power",scaling_max_freq:"5400000"}],automatic:{enabled:false,gaming:false,error:""}}
        profiles.capabilitiesReady=true
        if (canvas.editor) profiles.beginEdit()
        plugin.computerMapVisible=canvas.showMap
        if (canvas.agent) {
          var view=canvas.named("fastDiagnostics")
          view.agentVisible=true;view.agents=[{value:"pi",label:"Pi",inline:true}]
          view.selectedAgent="pi";view.agentAvailable=true
          view.agentModels=[{value:"example/model",label:"Example model"}]
        }
        // Names only: baseline geometry is still supplied by the actual consumer.
        var all=canvas.nodes(plugin)
        all.find(function(n){return n.fittedContentWidth!==undefined}).objectName="auditPanel"
        var cards=all.filter(function(n){return n.tile!==undefined})
        cards.forEach(function(card,i) {
          card.objectName="auditTile"+i
          canvas.nodes(card).find(function(n){return n.text===card.value}).objectName="auditValue"+i
        })
        if(cards.length)cards[0].parent.objectName="auditGrid"
        settle.restart()
      })
    }
  }
}
