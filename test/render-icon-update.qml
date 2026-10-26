import QtQuick
import qs.Commons
import qs.Commons as Host
import "plugin" as Plugin
import "mock-data.js" as MockData

// Runs only inside the reviewed inert copy prepared by ui-checks.py.
Rectangle {
  id: fixture
  color: Host.Color.background
  property string mode: "icons"
  property string language: "ru"
  property int fontSize: 12
  property bool previewReady: false
  property bool dropdownOpen: false
  property bool dataReady: false
  property string sampleState: "normal"
  property int selectedShape: 10
  property int loadThreshold: 50
  property bool motionPreview: false
  property bool settingsBottom: false
  property bool expandedView: false
  property bool mapOpen: false
  property string settingsCategory: "tiles"
  property string part: ""
  property bool optionsOpen: false
  property bool pageBottom: false
  property bool sensorDropdown: false
  property bool languageOpen: false
  property int tileCount: 2
  property int shapePage: 0
  property int demoHeatLevel: 1
  property string diagnosticDemo: ""
  property real previewRotation: 0

  function nodes(item) {
    var result = [item]
    if (item.children) for (var i=0; i<item.children.length; i++) result=result.concat(nodes(item.children[i]))
    return result
  }
  Component.onCompleted: {
    Host.Color.loadColors('foreground="#d8dee9"\nbackground="#2e3440"\naccent="#81a1c1"\nred="#bf616a"')
    Style.fontBaseSize = fontSize
  }

  Loader {
    anchors.fill: parent
    sourceComponent: ["icons","shapes","cpu","heat","threshold"].indexOf(fixture.mode)>=0 ? iconSheet : panelView
  }
  Timer {
    interval: 40; running: true; repeat: true
    onTriggered: {
      var all=fixture.nodes(fixture), icons=all.filter(function(n){return n.shapeIndex!==undefined})
      if (["icons","shapes","cpu","heat","threshold"].indexOf(fixture.mode)<0 && !fixture.dataReady) {
        var p=all.filter(function(n){return n.objectName==='previewPanel'})[0]
        if (!p) return
        p.activityController.stop()
        if (fixture.sampleState!=='loading' && fixture.sampleState!=='error') MockData.populate(p.activityController)
        var ctrl=p.activityController, high=fixture.sampleState==='hot'
        p.sensorsOpen=fixture.mode==='cooling' || fixture.mode==='fans'
        p.fansOpen=fixture.mode==='fans'
        p.computerMapVisible=fixture.mapOpen
        p.settingsSection=fixture.settingsCategory
        p.sensorOptionsOpen=fixture.optionsOpen
        if(fixture.part) p.selectPart(fixture.part)
        if (fixture.sampleState==='empty' || fixture.sampleState==='loading' || fixture.sampleState==='error') {
          ctrl._sensorSnapshot={schema:1,sample:270000,temperatures:[],fans:[],controls:[]}
          ctrl.sensorHistory={}
        }
        if (fixture.sampleState==='error') p.historyReadError=true
        p.historyPending=fixture.sampleState==='loading'
        p.languageExpanded=fixture.languageOpen
        if (high) ctrl._metrics=Object.assign({},ctrl.metrics,{cpu:85,memory:92})
        ctrl.glanceCpu=ctrl.cpuReady ? ctrl.metrics.cpu : -1
        ctrl.glanceMemory=ctrl.snapshot.memory.total ? ctrl.metrics.memory : -1
        ctrl.glanceUpdatedAt=Date.now()
        var temp=high ? 80+(fixture.demoHeatLevel-1)*5 : 54
        ctrl._thermalSnapshot={schema:1,sample:270000,temperatures:[{chip:'coretemp',label:'Package id 0',value:temp}]}
        ctrl.iconTemperature=temp
        ctrl.thermalUpdatedAt=Date.now()
        ctrl.freshnessClock=Date.now()
        if (fixture.sampleState==='empty') ctrl._processes=[]
        if (fixture.sampleState==='error') { ctrl.resetData();ctrl.clearGlance();ctrl.errorText='Не удалось прочитать системные показатели. Повторная попытка…' }
        if (fixture.sampleState==='loading') { ctrl.resetData();ctrl.clearGlance() }
        ctrl.updateHeatAlert()
        var exporter=all.filter(function(n){return n.resultPath!==undefined && n.helperPath!==undefined})[0]
        if(exporter && fixture.diagnosticDemo==='success') exporter.resultPath='/home/demo/.local/state/omarchy/activity-lite/exports/20261001T120000Z'
        if(exporter && fixture.diagnosticDemo==='error') exporter.error='Не удалось экспортировать историю.'
        if(fixture.diagnosticDemo==='writer-error') ctrl.journalError='journal_write_failed'
        fixture.dataReady=true
        return
      }
      if (icons.length === 0 || icons.some(function(n){return n.status !== Image.Ready})) return
      if (icons.some(function(n){return n.motionRunning})) return
      if (fixture.settingsBottom) {
        var scroll=all.filter(function(n){return n.objectName==='settingsViewport'})[0]
        if (!scroll) return
        scroll.contentY=Math.max(0,scroll.contentHeight-scroll.height)
        fixture.settingsBottom=false
        return
      }
      if (fixture.pageBottom) {
        var viewport=all.filter(function(n){return n.objectName==='fansViewport' || n.objectName==='coolingViewport'})[0]
        if (!viewport) return
        viewport.contentY=Math.max(0,viewport.contentHeight-viewport.height)
        fixture.pageBottom=false
        return
      }
      if (fixture.sensorDropdown) {
        var selector=all.filter(function(n){return n.objectName==='sensorDropdown'})[0]
        if (!selector) return
        selector.open();fixture.sensorDropdown=false
        return
      }
      if (fixture.dropdownOpen) {
        var dropdown=all.filter(function(n){return n.objectName==='iconShapeDropdown'})[0]
        if (!dropdown) return
        dropdown.open()
        fixture.dropdownOpen=false
        return
      }
      fixture.previewReady=true
      stop()
    }
  }

  Component {
    id: panelView
    Item {
      Plugin.Panel {
        id: plugin
        objectName: "previewPanel"
        anchors.fill: parent
        settings: ({locale:fixture.language, iconIndicator:false, iconShape:fixture.selectedShape, iconLoadThreshold:fixture.loadThreshold,iconHeatThreshold:80,iconMotion:fixture.motionPreview,compactTile0:'cpu',compactTile1:'gpu',compactTileCount:fixture.tileCount})
        Component.onCompleted: {
          open()
          activityController.stop()
          MockData.populate(activityController)
          setSettingsOpen(fixture.mode==='settings')
          setExpanded(fixture.mode==='expanded' || fixture.mode==='settings' || fixture.expandedView)
          activityController.glanceCpu=30
          activityController.glanceMemory=44
          activityController.glanceUpdatedAt=Date.now()
          activityController.freshnessClock=Date.now()
          activityController.iconTemperature=83
          activityController.thermalUpdatedAt=Date.now()
          activityController.freshnessClock=activityController.thermalUpdatedAt
          activityController.updateHeatAlert()
        }
      }
    }
  }
  Component {
    id: iconSheet
    Item {
      Text { x:24; y:18; text:"Loadlet / actual Panel consumer"; color:Host.Color.foreground; font.pixelSize:18 }
      Row {
        x:24; y:70; spacing:12
        Repeater {
          model: fixture.mode==='heat' ? [76,80,85,90,95].map(function(t){return {
            title:'CPU temperature '+t+' C',cpu:85,ram:92,temp:t,fresh:true
          }}) : fixture.mode==='shapes' ? Array.from({length:5},function(_,i){return {
            title:'Shape '+(fixture.shapePage*5+i+1),shape:fixture.shapePage*5+i,
            cpu:85,ram:92,temp:80+(fixture.demoHeatLevel-1)*5,fresh:true
          }}) : fixture.mode==='threshold' ? [49.99,50,55,85,100].map(function(n){return {
            title:'CPU '+n+' / RAM 55',cpu:n,ram:55,temp:55,fresh:true
          }}) : fixture.mode==='cpu' ? [10,30,60,90,0].map(function(n){return {
            title:'CPU '+n+' / RAM 44',cpu:n,ram:44,temp:55,fresh:true
          }}) : [
            {title:"Unavailable",cpu:-1,ram:-1,temp:-1,fresh:false},
            {title:"CPU 70 / RAM 44",cpu:70,ram:44,temp:55,fresh:true},
            {title:"CPU 30 / RAM 70",cpu:30,ram:70,temp:55,fresh:true},
            {title:"CPU 85 / RAM 92",cpu:85,ram:92,temp:83,fresh:true},
            {title:"Stale temperature",cpu:85,ram:92,temp:83,fresh:true,stale:true}
          ]
          Column {
            id: sample
            required property var modelData
            width:170; spacing:18
            Text { text:sample.modelData.title; color:Host.Color.foreground; font.pixelSize:12 }
            Plugin.Panel {
              id: barPlugin
              width:Style.bar.iconSlot; height:Style.bar.sizeHorizontal
              settings: ({locale:'en',iconIndicator:false,iconShape:sample.modelData.shape===undefined?fixture.selectedShape:sample.modelData.shape,iconLoadThreshold:fixture.loadThreshold,iconHeatThreshold:80,iconMotion:fixture.motionPreview})
              Component.onCompleted: {
                var ctrl=activityController
                ctrl.glanceCpu=sample.modelData.cpu;ctrl.glanceMemory=sample.modelData.ram
                ctrl.glanceUpdatedAt=sample.modelData.fresh ? Date.now() : 0
                ctrl.freshnessClock=Date.now()
                ctrl.iconTemperature=sample.modelData.temp
                ctrl.thermalUpdatedAt=sample.modelData.stale ? Date.now()-40000 : Date.now()
                ctrl.freshnessClock=Date.now()
                ctrl.updateHeatAlert()
                if (fixture.previewRotation!==0) {
                  var icon=fixture.nodes(barPlugin).filter(function(n){return n.objectName==='activityBarIcon'})[0]
                  if (icon) icon.rotation=fixture.previewRotation
                }
              }
            }
            Plugin.ActivityIcon {
              width:112; height:112
              cpu:barPlugin.activityController.glanceCpu
              ram:barPlugin.activityController.glanceMemory
              fresh:barPlugin.activityController.glanceFresh
              shape:barPlugin.iconShapeSetting
              loadThreshold:barPlugin.iconLoadThresholdSetting
              hot:barPlugin.activityController.heatAlert
              temperatureFresh:barPlugin.activityController.thermalFresh
              heatLevel:barPlugin.activityController.heatLevel
              motionEnabled: fixture.motionPreview
              rotation: fixture.previewRotation
            }
          }
        }
      }
      Text { x:24; y:296; text:"Top: native icon slot. Below: actual ActivityIcon at 112px. Demo values; inert IO."; color:Host.Color.foreground; font.pixelSize:12 }
    }
  }
}
