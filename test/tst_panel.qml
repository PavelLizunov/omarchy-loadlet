import QtQuick
import QtTest
import Quickshell
import qs.Commons
import "imports/ActivityHost/Ui" as NativeHost
import "plugin" as Plugin
import "mock-data.js" as MockData
import "plugin/ProfileCodec.js" as ProfileCodec

Item {
  id: host
  width: 1600
  height: 1200
  Plugin.Panel { id: plugin; anchors.fill: parent }
  Component { id: controllerComponent; Plugin.ActivityController {} }
  Component {
    id: symmetryIconComponent
    Rectangle {
      width:16;height:16;x:1200;y:900;z:200;color:'#2e3440'
      property alias icon: symmetricIcon
      Plugin.ActivityIcon {
        id:symmetricIcon
        anchors.fill:parent;motionEnabled:false
        foreground:'#d8dee9';background:'#2e3440';accent:'#81a1c1'
      }
    }
  }
  NativeHost.ActivityTooltipBubble { id: tooltipBubble; visible: false }
  QtObject {
    id: inertBar
    property string fontFamily: Style.font.family
    property color barForeground: Color.foreground
    property color urgent: Color.urgent
    property color background: Color.background
    property bool vertical: false
    property int barSize: Style.bar.sizeHorizontal
    property bool foregroundAnimationEnabled: false
    property string shownTooltip: ""
    property string requestedCommand: ""
    function showTooltip(item, text) { shownTooltip=text }
    function hideTooltip(item) { shownTooltip="" }
    function registerClickTarget(item) {}
    function unregisterClickTarget(item) {}
    function run(command) { requestedCommand=command }
  }
  TestCase {
    name: "ActivityPanel"
    when: windowShown
    function nodes(item) {
      var out = [item]
      if (item.children) for (var i=0;i<item.children.length;i++) out=out.concat(nodes(item.children[i]))
      return out
    }
    function pick(prop) {
      var all=nodes(plugin)
      for(var i=0;i<all.length;i++) if(all[i][prop] !== undefined) return all[i]
      fail("Missing property " + prop)
    }
    function init() {
      plugin.close(); host.width=1600; host.height=1200
      Style.fontBaseSize=12; Style.spacingScaleWithFont=true
      plugin.settings={locale:"ru",iconIndicator:false}; plugin.sortKey="cpu";plugin.sortAscending=false
      plugin.open();plugin.activityController.stop();plugin.computerMapVisible=false;plugin.settingsSection="tiles";plugin.fanStatusKey=""
      plugin.sensorPart="";plugin.selectedSensorId="";plugin.savedSensors=[];plugin.focusedFanChannel="";plugin.historyFanChannel=""
      plugin.sensorOptionsOpen=false;plugin.fanAssignmentOpen=false;plugin.fanIdentificationOpen=false
      var fan=nodes(plugin).filter(function(n){return n.command&&n.command[0]==='/usr/local/lib/loadlet/fan-control'})[0]
      fan.running=false;plugin.historyPending=false;plugin.historyReadError=false
      // Previous icon tests may replace bindings on this persistent consumer.
      var ctrl=plugin.activityController
      var icons=nodes(plugin).filter(function(n){return n.shapeIndex!==undefined})
      for(var i=0;i<icons.length;i++) {
        var icon=icons[i]
        icon.cancelWiggle();icon.lastMotionAt=0;icon.visible=true
        icon.cpu=Qt.binding(function(){return ctrl.glanceCpu})
        icon.ram=Qt.binding(function(){return ctrl.glanceMemory})
        icon.fresh=Qt.binding(function(){return ctrl.glanceFresh})
        icon.shape=Qt.binding(function(){return plugin.iconShapeSetting})
        icon.hot=Qt.binding(function(){return ctrl.heatAlert})
        icon.temperatureFresh=Qt.binding(function(){return ctrl.thermalFresh})
        icon.thermalSampleAt=Qt.binding(function(){return ctrl.thermalUpdatedAt})
        icon.heatLevel=Qt.binding(function(){return ctrl.heatLevel})
        icon.motionEnabled=Qt.binding(function(){return plugin.booleanSetting('iconMotion',true)})
      }
      plugin.activityController.resetData();plugin.activityController.lastTick=Date.now()
      MockData.populate(plugin.activityController); plugin.hintsVisible=true
      wait(60)
    }
    function cleanup() { plugin.close(); plugin.bar=null; wait(60) }
    function named(name) {
      var item=nodes(plugin).filter(function(n){return n.objectName===name})[0]
      verify(!!item,'Missing '+name)
      return item
    }
    function test_all_pages_expand_data() {
      return ['overview','cooling','fans','settings'].map(function(page){return {tag:page,page:page}})
    }
    function test_all_pages_expand(data) {
      plugin.hintsVisible=false
      plugin.sensorsOpen=data.page==='cooling'||data.page==='fans'
      plugin.fansOpen=data.page==='fans'
      plugin.setSettingsOpen(data.page==='settings');wait(20)
      var button=named('expandButton'), panel=pick('fittedContentWidth')
      verify(button.visible);var small=panel.width;var before=plugin.expanded
      mouseClick(button,button.width/2,button.height/2);wait(30)
      compare(plugin.expanded,!before);verify(before ? panel.width<small : panel.width>small)
      compare(plugin.settingsOpen,data.page==='settings')
      compare(plugin.sensorsOpen,data.page==='cooling'||data.page==='fans')
      pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_E);wait(30)
      compare(plugin.expanded,before,'E works on every page')
    }
    function test_page_geometry_data() {
      var result=[]
      ;['cooling','fans','settings'].forEach(function(page){
        ;[{font:12,width:340,height:360},{font:16,width:760,height:680},{font:24,width:960,height:660}].forEach(function(size){
          result.push({tag:page+'-'+size.font,page:page,font:size.font,width:size.width,height:size.height})
        })
      })
      return result
    }
    function test_page_geometry(data) {
      host.width=data.width;host.height=data.height;Style.fontBaseSize=data.font
      plugin.hintsVisible=false;plugin.sensorsOpen=data.page!=='settings';plugin.fansOpen=data.page==='fans'
      plugin.setSettingsOpen(data.page==='settings');wait(30)
      var panel=pick('fittedContentWidth'),button=named('expandButton')
      verify(button.mapToItem(panel,button.width,button.height).x<=panel.width+1)
      var viewport=named(data.page==='settings'?'settingsViewport':data.page==='fans'?'fansViewport':'coolingViewport')
      verify(viewport.height>0);verify(viewport.contentHeight>0)
      viewport.contentY=Math.max(0,viewport.contentHeight-viewport.height);wait(10)
      if(data.page==='cooling') {
        var chart=named('sensorHistoryChart')
        verify(chart.mapToItem(viewport,0,chart.height).y<=viewport.height+1)
      }
    }
    function test_cooling_navigation_and_scroll() {
      plugin.hintsVisible=false;pick('moveRequested').forceActiveFocus()
      keyClick(Qt.Key_H);wait(30);compare(plugin.sensorsOpen,true)
      var viewport=named('coolingViewport')
      compare(plugin.expanded,false,'Cooling navigation preserves compact size')
      verify(viewport.contentHeight<=viewport.height+1,'Default compact chart fits without extra scrolling')
      viewport.contentY=Math.max(0,viewport.contentHeight-viewport.height);wait(10)
      var chart=named('sensorHistoryChart')
      verify(chart.mapToItem(viewport,0,chart.height).y<=viewport.height+1,'Chart reachable by scrolling')
      var dropdown=named('sensorDropdown');dropdown.open();wait(10)
      keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(20)
      verify(plugin.selectedSensorId!=='')
      plugin.fansOpen=true;pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_Escape);wait(10)
      compare(plugin.sensorsOpen,false);compare(plugin.fansOpen,false)
      var overview=nodes(plugin).filter(function(n){return n.modelData&&n.modelData.key==='overview'})[0]
      compare(overview.selected,true)
      plugin.sensorsOpen=true;plugin.fansOpen=true;plugin.openDetails();wait(20)
      compare(plugin.sensorsOpen,false);compare(plugin.expanded,true)
    }
    function clickVisible(item, viewport) {
      verify(item.visible, 'Target must be visible')
      if (viewport) {
        var y=item.mapToItem(viewport,0,0).y
        viewport.contentY=Math.max(0,Math.min(viewport.contentHeight-viewport.height,
          viewport.contentY+y-Math.max(0,(viewport.height-item.height)/2)))
        wait(20)
        verify(item.mapToItem(viewport,0,0).y>=-1,'Target top inside viewport')
        verify(item.mapToItem(viewport,0,item.height).y<=viewport.height+1,'Target bottom inside viewport')
      }
      mouseClick(item,item.width/2,item.height/2);wait(30)
    }
    function tab(key) {
      return nodes(plugin).filter(function(n){return n.modelData&&n.modelData.key===key&&n.text!==undefined})[0]
    }
    function test_navigation_frame_and_recovery_data() {
      return [false,true].map(function(expanded){return {tag:expanded?'large':'compact',expanded:expanded}})
    }
    function test_navigation_frame_and_recovery(data) {
      plugin.hintsVisible=false;plugin.setExpanded(data.expanded);wait(20)
      var panel=pick('fittedContentWidth'), width=panel.width,height=panel.height
      function stable() { compare(panel.width,width);compare(panel.height,height);compare(plugin.expanded,data.expanded) }
      clickVisible(tab('fans'));stable()
      var viewport=named('fansViewport')
      clickVisible(named('computerMapToggle'),viewport);stable();compare(plugin.computerMapVisible,true)
      clickVisible(tab('sensors'));stable();compare(plugin.computerMapVisible,false)
      verify(named('sensorDropdown').visible,'Switching pages restores readings, not the diagram')
      viewport=named('coolingViewport')
      clickVisible(named('sensorOptionsToggle'),viewport);stable()
      verify(named('sensorAssignmentDropdown').visible,'One disclosure exposes the category editor')
      clickVisible(named('sensorOptionsToggle'),viewport);stable()
      clickVisible(named('computerMapToggle'),viewport);stable()
      pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_Escape);wait(20)
      compare(plugin.computerMapVisible,false);compare(plugin.sensorsOpen,true);stable()
      plugin.setSettingsOpen(true);wait(20);stable()
      plugin.setSettingsOpen(false);wait(20);stable()
      clickVisible(tab('overview'));stable()
    }
    function test_filter_assignment_keeps_reading() {
      plugin.hintsVisible=false;plugin.selectPart('cpu');wait(20)
      var sensor=plugin.selectedSensor;verify(!!sensor)
      plugin.sensorOptionsOpen=true;wait(20)
      var viewport=named('coolingViewport'),dropdown=named('sensorAssignmentDropdown')
      clickVisible(dropdown,viewport);keyClick(Qt.Key_Down);keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(30)
      compare(plugin.sensorPart,'gpu','Category assignment follows the selected category')
      compare(plugin.selectedSensor.id,sensor.id,'The edited sensor remains selected')
      compare(plugin.expanded,false)
    }
    function test_category_sensor_identity_and_click() {
      plugin.hintsVisible=false;plugin.setExpanded(true);plugin.selectPart('cpu');wait(20)
      var original=plugin.selectedSensor
      plugin.assignSensor(original,'gpu');wait(20)
      compare(plugin.sensorPart,'gpu');compare(plugin.selectedSensor.id,original.id)
      verify(plugin.filteredSensors.every(function(s){return plugin.sensorMatches(s,'gpu')}))
      plugin.selectPart('motherboard');wait(20)
      compare(plugin.selectedSensor.id,'board-temp1')
      plugin.selectPart('gpu');wait(20)
      var dropdown=named('sensorDropdown');dropdown.open();wait(20)
      var list=dropdown.optionView
      verify(!!list);compare(list.currentIndex,0)
      var second=list.contentItem.children.filter(function(n){return n.index===1})[0]
      verify(!!second)
      mouseClick(second,second.width/2,second.height/2);wait(20)
      compare(plugin.selectedSensor.id,dropdown.options[1].value,'Click picks its row without a hover event')
      plugin.selectPart('motherboard');wait(20)
      compare(dropdown.value,'board-temp1','Choice preserves its controlled value binding')
      plugin.sensorOptionsOpen=true;wait(10)
      plugin.assignSensor(plugin.selectedSensor,'storage');wait(20)
      compare(plugin.sensorPart,'storage');compare(plugin.selectedSensor.id,'board-temp1')
      verify(plugin.sensorOwner(plugin.selectedSensor).indexOf('ITE IT8613E')>=0,'Manual label retains model')
    }
    function test_missing_sensor_metadata_assignment_isolation() {
      var a={id:'offline-a',chip:'chip',label:'temp',location:''}
      var b={id:'offline-b',chip:'chip',label:'temp',location:''}
      plugin.assignSensor(a,'storage')
      compare(plugin.sensorPlace(a),'storage');compare(plugin.sensorPlace(b),'automatic')
    }
    function test_profile_timeout_retains_failure() {
      plugin.setExpanded(true);plugin.sensorsOpen=true;plugin.fansOpen=true
      plugin.activityController.stop();MockData.populate(plugin.activityController);wait(20)
      var profiles=named('powerProfiles')
      profiles.applyProfile(profiles.profiles[1])
      var proc=nodes(profiles).filter(function(n){return n.command&&n.command.indexOf('apply')>=0})[0]
      profiles.operationExpired=true
      proc.running=false;proc.exited(0)
      compare(profiles.statusKey,'profile_failed')
      profiles.operationExpired=false
    }
    function test_power_profiles_create_save_apply_inert() {
      plugin.setExpanded(true);plugin.sensorsOpen=true;plugin.fansOpen=true
      plugin.activityController.stop();MockData.populate(plugin.activityController);wait(20)
      var profiles=named('powerProfiles')
      compare(profiles.profiles.length,3)
      profiles.selectProfile('idle');profiles.changeCpu('maxMHz',1800);profiles.saveDraft();wait(10)
      var saved=JSON.parse(plugin.settings.powerProfiles)
      compare(saved.filter(function(p){return p.id==='idle'})[0].config.cpu.maxMHz,1800)
      profiles.applyProfile(profiles.profiles.filter(function(p){return p.id==='idle'})[0]);wait(10)
      var proc=nodes(profiles).filter(function(n){return n.command&&n.command.indexOf('apply')>=0})[0]
      verify(!!proc);compare(proc.running,true)
      var config=profiles.profiles.filter(function(p){return p.id==='idle'})[0].config
      compare(proc.command[3],ProfileCodec.encode(config))
      compare(ProfileCodec.encode({cpu:{boost:false}}),'eyJjcHUiOnsiYm9vc3QiOmZhbHNlfX0=')
      compare(config.cpu.boost,false);compare(config.cpu.maxMHz,1800)
      proc.running=false;proc.exited(0);wait(10)
      compare(plugin.settings.activePowerProfile,'idle')
      profiles.selectProfile('games');profiles.saveDraft();wait(10)
      verify(JSON.parse(plugin.settings.powerProfiles).some(function(p){return p.id==='games'}))
      profiles.editorOpen=true;wait(10)
      clickVisible(named('newPowerProfileButton'),named('fansViewport'))
      var created=profiles.draft.id
      verify(created.indexOf('custom-')===0)
      compare(named('powerProfileName').text,profiles.draft.name,'New profile replaces the visible name binding')
      profiles.saveDraft();wait(10)
      verify(JSON.parse(plugin.settings.powerProfiles).some(function(p){return p.id===created}))
      clickVisible(named('deletePowerProfileButton'),named('fansViewport'));wait(10)
      verify(JSON.parse(plugin.settings.powerProfiles).some(function(p){return p.id===created}),'Deletion needs confirmation')
      clickVisible(named('deletePowerProfileButton'),named('fansViewport'));wait(10)
      verify(!JSON.parse(plugin.settings.powerProfiles).some(function(p){return p.id===created}))
    }
    function test_profile_browse_edit_cancel_and_apply() {
      plugin.hintsVisible=false;plugin.setExpanded(true);clickVisible(tab('fans'))
      var profiles=named('powerProfiles'),viewport=named('fansViewport')
      profiles.capabilitiesReady=true
      var before=JSON.stringify(plugin.settings),panel=pick('fittedContentWidth'),height=panel.height,width=panel.width
      named('powerProfileDropdown').changed('games');wait(10)
      compare(profiles.selectedId,'games');compare(profiles.running,false)
      compare(JSON.stringify(plugin.settings),before,'Browsing is inert')
      clickVisible(named('profileEditorToggle'),viewport)
      compare(profiles.draft.id,'games');verify(!named('computerMapToggle').visible)
      profiles.changeCpu('boost',false)
      clickVisible(named('cancelPowerProfileButton'),viewport)
      compare(JSON.stringify(plugin.settings),before);compare(profiles.draft.config.cpu.boost,true)
      compare(panel.height,height);compare(panel.width,width)
      clickVisible(named('profileEditorToggle'),viewport)
      named('powerProfileName').forceActiveFocus();keyClick(Qt.Key_Escape);wait(10)
      compare(profiles.editorOpen,false);compare(plugin.fansOpen,true)
      clickVisible(named('profileEditorToggle'),viewport)
      pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_Escape);wait(10)
      compare(profiles.editorOpen,false);compare(plugin.fansOpen,true)
      clickVisible(named('profileEditorToggle'),viewport)
      profiles.changeCpu('maxMHz',2000)
      clickVisible(named('saveApplyPowerProfileButton'),viewport)
      compare(profiles.running,true);compare(profiles.editorOpen,false)
      compare(JSON.parse(plugin.settings.powerProfiles).filter(function(p){return p.id==='games'})[0].config.cpu.maxMHz,2000)
      var proc=nodes(profiles).filter(function(n){return n.command&&n.command.indexOf('apply')>=0})[0]
      compare(proc.command[3],ProfileCodec.encode(profiles.selectedProfile.config))
      proc.running=false;proc.exited(0)
      compare(plugin.settings.activePowerProfile,'games');compare(plugin.settings.autoGameProfiles,false)
      compare(panel.height,height);compare(panel.width,width)
    }
    function test_profile_auto_base_and_invalid_draft() {
      plugin.hintsVisible=false;clickVisible(tab('fans'))
      var profiles=named('powerProfiles'),viewport=named('fansViewport')
      profiles.capabilitiesReady=true
      clickVisible(named('automationOptionsToggle'),viewport)
      named('automaticBaseProfile').changed('current')
      clickVisible(named('autoGameProfilesToggle'),viewport)
      compare(profiles.pendingBaseId,'current');compare(profiles.operation,'auto-config')
      var proc=nodes(profiles).filter(function(n){return n.command&&n.command.indexOf('auto-config')>=0})[0]
      compare(proc.command[3],ProfileCodec.encode({game:profiles.profiles[2].config,base:profiles.profiles[0].config}))
      proc.running=false;proc.exited(126)
      profiles.selectProfile('idle');profiles.changeFan('pwm2','101',false)
      var before=JSON.stringify(plugin.settings)
      compare(profiles.saveDraft(),false);compare(profiles.statusKey,'profile_invalid');compare(JSON.stringify(plugin.settings),before)
    }
    function test_map_live_readings_assignments_and_stale() {
      plugin.hintsVisible=false;plugin.sensorsOpen=true
      plugin.persistSettings({fanPlace_pwm2:'fan_cpu',fanPlace_pwm3:'fan_front'})
      plugin.computerMapVisible=true;wait(20)
      compare(named('mapReading-cpu').text,'54°C')
      compare(named('mapReading-fan_cpu').text,'700 RPM')
      compare(named('mapReading-fan_front').text,'850 RPM')
      compare(named('mapReading-memory').text,'Нет данных')
      var ctrl=plugin.activityController,snap=ctrl._sensorSnapshot
      ctrl._sensorSnapshot=Object.assign({},snap,{temperatures:snap.temperatures.concat([{id:'cpu-die',category:'cpu',value:62}]),fans:snap.fans.concat([{id:'gpu-fan',category:'gpu',fan:true,value:30,unit:'percent'}])})
      compare(named('mapReading-cpu').text,'54–62°C')
      compare(named('mapReading-gpu').text,'48°C\n30%')
      plugin.assignSensor(ctrl._sensorSnapshot.temperatures[0],'storage')
      compare(plugin.mapReadings.cpu.text,'62°C');compare(plugin.mapReadings.storage.text,'54°C')
      ctrl.sensorsUpdatedAt=0
      compare(plugin.mapReadings.cpu.text,'Нет данных');compare(plugin.mapReadings.fan_front.text,'Нет данных')
    }
    function test_settings_choice_reset_remains_reactive() {
      plugin.setSettingsOpen(true);plugin.settingsSection='icon';wait(20)
      var dropdown=named('iconShapeDropdown')
      dropdown.open();wait(10)
      var list=dropdown.optionView
      list.currentIndex=2;list.selectCurrent();wait(10)
      compare(plugin.iconShapeSetting,2)
      plugin.resetPreferences();wait(10)
      compare(dropdown.value,'10')
    }
    function test_multi_gpu_columns_sort_and_missing() {
      plugin.setExpanded(true);var ctrl=plugin.activityController
      ctrl._gpus=[{id:"0000:01:00.0",name:"NVIDIA GeForce RTX 5060 Ti"},{id:"0000:06:00.0",name:"Radeon 610M"}]
      var samples={}
      samples[ctrl._processes[0].pid+":"+ctrl._processes[0].startTicks]={usage:40,byGpu:{"0000:01:00.0":40,"0000:06:00.0":0}}
      samples[ctrl._processes[1].pid+":"+ctrl._processes[1].startTicks]={usage:60,byGpu:{"0000:06:00.0":60}}
      ctrl.processGpus=samples;ctrl.processGpusUpdatedAt=Date.now();ctrl.freshnessClock=Date.now();wait(20)
      var heading=named("processHeader-gpu:0000:06:00.0")
      mouseClick(heading,heading.width/2,heading.height/2);wait(10)
      compare(plugin.sortedProcesses[0].pid,ctrl._processes[1].pid)
      compare(plugin.sortedProcesses[plugin.sortedProcesses.length-1].gpu,-1)
      mouseClick(heading,heading.width/2,heading.height/2);wait(10)
      compare(plugin.sortedProcesses[0].pid,ctrl._processes[0].pid)
      compare(plugin.sortedProcesses[plugin.sortedProcesses.length-1].gpu,-1)
      compare(plugin.processGpuHeading(ctrl._gpus[0]),"RTX 5060 Ti")
    }
    function test_action_finish_is_idempotent() {
      var action=pick('_activeAction')
      action._activeAction={pid:123,startTicks:1,name:'demo'}
      action.finish(1);verify(action.failed)
      var status=action.status
      action.finish(0);verify(action.failed);compare(action.status,status)
    }
    function test_compact_fans_disclosures_and_history() {
      plugin.hintsVisible=false;clickVisible(tab('fans'))
      var viewport=named('fansViewport')
      verify(!named('identifyFanButton').visible,'Trials are separated from everyday controls')
      clickVisible(named('fanAssignmentToggle'),viewport)
      verify(named('fanAssignmentDropdown').visible)
      clickVisible(named('fanAssignmentToggle'),viewport)
      clickVisible(named('fanIdentificationToggle'),viewport)
      verify(named('identifyFanButton').visible)
      clickVisible(named('fanIdentificationToggle'),viewport)
      var restore=nodes(plugin).filter(function(n){return n.iconName==='restore'&&n.text&&n.text.indexOf('Вернуть')>=0})[0]
      verify(restore.visible,'Recovery control is retained')
      verify(viewport.contentHeight>0,'Fan controls retain a scrollable content surface')
      clickVisible(restore,viewport)
      var fan=nodes(plugin).filter(function(n){return n.command&&n.command[0]==='/usr/local/lib/loadlet/fan-control'})[0]
      fan.running=false;fan.exited(0);plugin.activityController.stop();MockData.populate(plugin.activityController);wait(20)
      var history=named('fanHistoryButton');clickVisible(history,viewport)
      compare(plugin.fansOpen,false);compare(plugin.selectedSensor.label,'fan2');compare(plugin.expanded,false)
      plugin.close();plugin.open();plugin.activityController.stop();MockData.populate(plugin.activityController);wait(20)
      compare(plugin.computerMapVisible,false);compare(plugin.fanIdentificationOpen,false)
    }
    function test_chart_timestamp_selection() {
      plugin.sensorsOpen=true;wait(20)
      var chart=named('sensorHistoryChart')
      chart.referenceTime=200;chart.windowSeconds=100
      chart.points=[{time:100,value:40},{time:110,value:50},{time:200,value:60}]
      chart.selectAt(chart.xFor(chart.points[1]));compare(chart.selectedIndex,1)
      chart.forceActiveFocus();keyClick(Qt.Key_Right);compare(chart.selectedIndex,2)
      keyClick(Qt.Key_Left);compare(chart.selectedIndex,1)
      chart.points=[{time:110,value:50},{time:200,value:60},{time:210,value:61}]
      compare(chart.selectedPoint.time,110,'Selection follows the timestamp, not a shifting index')
      chart.points=[];keyClick(Qt.Key_Left);compare(chart.selectedIndex,-1)
      chart.points=[{time:110,value:50},{time:200,value:60}];keyClick(Qt.Key_Left);compare(chart.selectedIndex,1,'Left enters from newest sample')
    }
    function test_symmetric_page_margins_data() {
      return ['fans','cooling','settings'].map(function(page){return {tag:page,page:page}})
    }
    function test_symmetric_page_margins(data) {
      plugin.hintsVisible=false
      if(data.page==='settings')plugin.setSettingsOpen(true)
      else { clickVisible(tab(data.page==='fans'?'fans':'sensors')) }
      var viewport=named(data.page==='fans'?'fansViewport':data.page==='cooling'?'coolingViewport':'settingsViewport')
      var body=named(data.page==='fans'?'fanBody':data.page==='cooling'?'coolingBody':'settingsBody')
      compare(body.width,viewport.width,'Content does not reserve an asymmetric scrollbar gutter')
      var tabs=named(data.page==='settings'?'settingsTabs':'pageTabs')
      compare(viewport.mapToItem(plugin,0,0).x,tabs.mapToItem(plugin,0,0).x)
      compare(viewport.width,tabs.width,'Scrolling content and navigation share both edges')
      if(data.page==='fans') {
        var duration=named('fanDurationDropdown'),history=named('fanHistoryButton')
        compare(history.height,duration.rowHeight,'Adjacent action matches the input height')
        compare(history.mapToItem(viewport,0,history.height).y,duration.mapToItem(viewport,0,duration.height).y)
      }
      var scroll=named(data.page==='fans'?'fansScrollBar':data.page==='cooling'?'coolingScrollBar':'settingsScrollBar')
      verify(scroll.mapToItem(viewport,0,0).x>=viewport.width,'Scroll thumb stays outside content')
      host.width=350;wait(20);compare(body.width,viewport.width)
      viewport.contentY=Math.max(0,viewport.contentHeight-viewport.height);wait(10)
      compare(body.width,viewport.width)
    }
    function test_chart_axes_pin_gaps_and_live() {
      plugin.hintsVisible=false;plugin.setExpanded(true);clickVisible(tab('sensors'))
      var chart=named('sensorHistoryChart')
      chart.referenceTime=1000;chart.windowSeconds=600
      chart.points=[{time:410,value:50},{time:420,value:55},{time:900,value:60,breakBefore:true}]
      compare(chart.startTime,400);compare(chart.endTime,1000)
      verify(named('coolingViewport').contentHeight<=named('coolingViewport').height+1,'Expanded chart page fits')
      compare(chart.maximum,120)
      chart.points=[{time:410,value:50,breakBefore:false},{time:900,value:60,breakBefore:false}]
      compare(chart.breakBefore(1),false,'Downsampled continuous samples are not gaps')
      chart.points=[{time:410,value:50},{time:420,value:55},{time:900,value:60,breakBefore:true}]
      chart.selectAt((600-400)/600*named('chartPlot').width)
      compare(chart.selectedIndex,-1);compare(chart.cursorInGap,true)
      var pointer=named('chartPointer')
      mouseClick(pointer,chart.xFor(chart.points[0]),pointer.height/2);wait(10)
      compare(chart.pinned,true);compare(chart.selectedPoint.time,410)
      mouseMove(pointer,pointer.width-2,pointer.height/2);wait(10)
      compare(chart.selectedPoint.time,410,'Pinned reading does not follow hover')
      clickVisible(named('chartLiveButton'));compare(chart.selectedIndex,-1);compare(chart.pinned,false)
      chart.forceActiveFocus();keyClick(Qt.Key_End);compare(chart.selectedPoint.time,900)
      keyClick(Qt.Key_Escape);compare(chart.selectedIndex,-1);compare(plugin.sensorsOpen,true)
      chart.ceiling=0;chart.unit='RPM';chart.points=[{time:420,value:1800}]
      verify(chart.maximum>1800);compare(chart.formatValue(1800),'1800')
      chart.points=[{time:420,value:0}];verify(chart.maximum>0)
      chart.points=[];compare(chart.selectedIndex,-1)
    }
    function test_compact_map_preserves_drawing() {
      host.width=471;host.height=405;plugin.hintsVisible=false;clickVisible(tab('sensors'))
      plugin.computerMapVisible=true;wait(20)
      var drawing=named('computerMapDrawing'),map=named('computerMap')
      verify(drawing.width>=240,'Callouts must not squeeze the diagram again')
      var cpu=named('mapTarget-cpu'),fan=named('mapTarget-fan_cpu')
      verify(cpu.y+cpu.height<=fan.y,'CPU hit targets do not overlap')
      var bottom=named('mapTarget-fan_bottom'),ssd=named('mapTarget-fan_ssd')
      verify(bottom.x+bottom.width<=ssd.x,'Bottom fan hit targets do not overlap')
      host.width=380;wait(20)
      verify(map.stacked);compare(drawing.width,map.width)
      verify(named('mapLegendPart0').mapToItem(map,0,0).y>=drawing.height,'Narrow labels stack below, not over the drawing')
      clickVisible(named('mapLegendPart1'),named('coolingViewport'))
      compare(plugin.sensorPart,'cpu');compare(plugin.computerMapVisible,false)
    }
    function test_map_legend_cells_stay_inside() {
      plugin.hintsVisible=false;plugin.setExpanded(true);clickVisible(tab('sensors'))
      clickVisible(named('computerMapToggle'),named('coolingViewport'))
      var legend=named('mapLegend')
      for(var i=0;i<10;i++) {
        var cell=named('mapLegendPart'+i)
        verify(cell.mapToItem(legend,cell.width,0).x<=legend.width+1,'Legend cell fits at index'+i)
      }
      clickVisible(named('mapLegendPart1'),named('coolingViewport'))
      compare(plugin.sensorPart,'cpu');compare(plugin.computerMapVisible,false)
    }
    function test_page_keyboard_focus_reveals_controls() {
      host.width=350;host.height=340;plugin.hintsVisible=false
      clickVisible(tab('fans'))
      var viewport=named('fansViewport'),restore=named('fanRestoreButton')
      viewport.contentY=0;wait(10);restore.forceActiveFocus();wait(30)
      verify(restore.mapToItem(viewport,0,0).y>=-1)
      verify(restore.mapToItem(viewport,0,restore.height).y<=viewport.height+1,'Focused restore control scrolls into view')
      named('computerMapToggle').forceActiveFocus();wait(30)
      verify(named('computerMapToggle').mapToItem(viewport,0,0).y>=-1,'Focused navigation is visible above the longer profile surface')
      clickVisible(tab('sensors'))
      var chart=named('sensorHistoryChart')
      chart.forceActiveFocus();wait(30)
      var cooling=named('coolingViewport')
      verify(chart.mapToItem(cooling,0,chart.height).y<=cooling.height+1)
    }
    function test_history_back_and_error_recovery() {
      plugin.hintsVisible=false;clickVisible(tab('fans'))
      clickVisible(named('fanHistoryButton'),named('fansViewport'))
      compare(plugin.historyFanChannel,'pwm2')
      clickVisible(named('backToFanControls'),named('coolingViewport'))
      compare(plugin.fansOpen,true);compare(plugin.activeFanChannel,'pwm2')
      clickVisible(named('fanHistoryButton'),named('fansViewport'))
      pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_Escape);wait(20)
      compare(plugin.fansOpen,true);compare(plugin.expanded,false)
      clickVisible(tab('sensors'))
      var proc=nodes(plugin).filter(function(n){return n.command&&n.command.indexOf('--sensor-history')>=0})[0]
      proc.running=false;plugin.historyPending=false;plugin.historyReadError=true;wait(20)
      clickVisible(named('retrySensorHistory'),named('coolingViewport'))
      compare(proc.running,true);compare(plugin.historyReadError,false)
      proc.running=false;proc.exited(0)
    }
    function test_fan_commands_inert() {
      plugin.setExpanded(true);plugin.sensorsOpen=true;plugin.fansOpen=true;plugin.activityController.stop();MockData.populate(plugin.activityController);wait(20)
      var proc=nodes(plugin).filter(function(n){return n.command&&n.command[0]==='/usr/local/lib/loadlet/fan-control'})[0]
      verify(!!proc)
      var boost=nodes(plugin).filter(function(n){return n.text==='Разгон 60%'})[0]
      clickVisible(boost,named('fansViewport'));wait(10)
      compare(proc.running,true);compare(proc.command.join(' '),'/usr/local/lib/loadlet/fan-control request boost pwm2 60 10')
      proc.running=false;proc.exited(126);wait(10);compare(plugin.fanStatusKey,'fan_action_failed')
      var viewport=named('fansViewport');viewport.contentY=Math.max(0,viewport.contentHeight-viewport.height);wait(10)
      plugin.activityController.stop();MockData.populate(plugin.activityController);wait(10)
      var restore=nodes(plugin).filter(function(n){return n.iconName==='restore'&&n.text&&n.text.indexOf('Вернуть')>=0})[0]
      mouseClick(restore,restore.width/2,restore.height/2);wait(10)
      compare(proc.command.join(' '),'/usr/local/lib/loadlet/fan-control request restore pwm2')
      proc.running=false;proc.exited(0);compare(plugin.fanStatusKey,'fan_action_sent')
      plugin.fanAction('pwm1',100,'boost');compare(proc.running,false)
    }
    function test_identification_command_and_assignment() {
      plugin.setExpanded(true);plugin.sensorsOpen=true;plugin.fansOpen=true;wait(30)
      var proc=nodes(plugin).filter(function(n){return n.command&&n.command[0]==='/usr/local/lib/loadlet/fan-control'})[0]
      plugin.identificationPercent=0
      var fansViewport=named('fansViewport')
      verify(fansViewport.contentHeight<=fansViewport.height+1,'Normal Fans view requires no scroll')
      var disclosure=named('fanIdentificationToggle')
      mouseClick(disclosure,disclosure.width/2,disclosure.height/2);wait(20)
      fansViewport.contentY=Math.max(0,fansViewport.contentHeight-fansViewport.height);wait(20)
      var identify=named('identifyFanButton')
      verify(identify.visible)
      mouseClick(identify,identify.width/2,identify.height/2);wait(10)
      compare(proc.command.join(' '),'/usr/local/lib/loadlet/fan-control request identify pwm2 0 5')
      proc.running=false;proc.exited(0);plugin.activityController.stop();MockData.populate(plugin.activityController)
      plugin.assignFan('pwm2','fan_cpu');compare(plugin.fanPlace('pwm2'),'fan_cpu')
      plugin.computerMapVisible=true;wait(20)
      var map=named('computerMap');map.picked('fan_cpu');wait(30)
      compare(plugin.computerMapVisible,false);compare(plugin.activeFanChannel,'pwm2')
      map=named('computerMap');map.picked('cpu');wait(30)
      compare(plugin.fansOpen,false);compare(plugin.selectedSensor.category,'cpu')
      var viewport=named('coolingViewport')
      verify(viewport.contentHeight<=viewport.height+1,'Main Cooling view requires no scroll')
    }
    function test_settings_categories_fit_data() {
      return ['tiles','icon','sampling','diagnostics'].map(function(section){return {tag:section,section:section}})
    }
    function test_settings_categories_fit(data) {
      plugin.hintsVisible=false;plugin.setExpanded(true);plugin.setSettingsOpen(true);plugin.settingsSection=data.section;wait(30)
      var viewport=named('settingsViewport')
      verify(viewport.contentHeight<=viewport.height+1,'Settings category fits: '+data.section)
    }
    function test_sensor_history_parse_failure() {
      var proc=nodes(plugin).filter(function(n){return n.command&&n.command.indexOf('--sensor-history')>=0})[0]
      verify(!!proc);plugin.historyReadError=false
      proc.stdout.text='not-json';proc.stdout.streamFinished();proc.running=false;proc.exited(0)
      compare(plugin.historyReadError,true,'Malformed success output remains an error')
      plugin.loadSensorHistory();compare(plugin.historyReadError,false)
      proc.stdout.text='{"sensors":{}}';proc.stdout.streamFinished();compare(plugin.historyReadError,true)
      proc.running=false
    }
    function test_compact_gpu_survives_collapse() {
      plugin.settings={locale:'ru',iconIndicator:false,compactTile0:'cpu',compactTile1:'gpu'}
      plugin.setExpanded(true);MockData.populate(plugin.activityController)
      plugin.setExpanded(false);wait(10)
      compare(plugin.gpus.length,1,'Collapsing preserves a GPU used by a compact tile')
      compare(plugin.compactRamStrip,true)
      plugin.persistSettings({compactTile1:'ram'});compare(plugin.compactRamStrip,false)
    }
    function test_geometry_data() {
      return [
        {tag:"normal",font:12,width:1600,height:1200,fontOnly:false},
        {tag:"font16",font:16,width:1600,height:1200,fontOnly:false},
        {tag:"font24",font:24,width:1600,height:1200,fontOnly:false},
        {tag:"font24_clamped",font:24,width:1280,height:660,fontOnly:false},
        {tag:"narrow",font:12,width:320,height:310,fontOnly:false},
        {tag:"font_only24",font:24,width:1600,height:1200,fontOnly:true}
      ]
    }
    function test_geometry(data) {
      host.width=data.width;host.height=data.height;Style.fontBaseSize=data.font
      Style.spacingScaleWithFont=!data.fontOnly;wait(60)
      var panel=pick('fittedContentWidth')
      var rows=nodes(plugin).filter(function(n){return n.rowIndex!==undefined && n.processData!==undefined && n.visible})
      verify(rows.length>0 && rows.length<=4)
      var hint=nodes(plugin).filter(function(n){return n.text!==undefined && String(n.text).indexOf('e подробнее')===0})[0]
      var bottom=rows[rows.length-1].mapToItem(panel,0,rows[rows.length-1].height).y
      verify(bottom<=hint.parent.mapToItem(panel,0,0).y,"Rows overlap footer")
      var row=rows[0]
      var cols=row.children.filter(function(n){return n.spacing!==undefined && n.children.length>=6})[0]
      var right=0
      for(var i=0;i<cols.children.length;i++) if(cols.children[i].visible) right=Math.max(right,cols.children[i].x+cols.children[i].width)
      verify(cols.x+right<=row.width,"Columns exceed row")
    }
    function test_expanded_process_budget() {
      plugin.hintsVisible=false;plugin.setExpanded(true);wait(30)
      verify(pick("ensureSelected").height>=plugin.processRowHeight*4,"Expanded summaries reserve four process rows")
    }
    function test_expanded_clamped() {
      Style.fontBaseSize=24;host.width=960;host.height=660
      plugin.setExpanded(true);wait(80)
      verify(pick('ensureSelected').height>=plugin.processRowHeight)
    }
    function test_selection_reorder() {
      plugin.selectProcess(0);var pid=plugin.selectedProcess.pid
      var list=plugin.activityController._processes.slice()
      list[3]=Object.assign({},list[3]);list[3].cpu=99
      plugin.activityController._processes=list;wait(10)
      compare(plugin.selectedProcess.pid,pid)
    }
    function test_selection_removed() {
      plugin.selectProcess(0)
      plugin.activityController._processes=plugin.activityController._processes.slice(1)
      wait(10);compare(plugin.selectedProcess,null)
    }
    function test_selection_pid_reused() {
      plugin.selectProcess(0);var list=plugin.activityController._processes.slice()
      list[0]=Object.assign({},list[0]);list[0].startTicks++
      plugin.activityController._processes=list;wait(10);compare(plugin.selectedProcess,null)
    }
    function test_settings_escape() {
      plugin.setSettingsOpen(true);wait(20);pick('moveRequested').forceActiveFocus()
      keyClick(Qt.Key_Escape);wait(10);compare(plugin.settingsOpen,false)
    }
    function test_settings_dropdown() {
      plugin.setSettingsOpen(true);plugin.settingsSection="sampling";wait(20)
      var d=nodes(plugin).filter(function(n){return n.options!==undefined && n.label==='Частота обновления'})[0]
      d.open();wait(10);keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(20)
      compare(plugin.samplingSpeedSetting,'Balanced')
      d.open();wait(10);keyClick(Qt.Key_Escape);wait(10)
      compare(d.popupOpen,false);compare(plugin.settingsOpen,true)
    }
    function test_language_blocks_action() {
      plugin.selectProcess(0);plugin.languageExpanded=true
      pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_X);wait(10)
      compare(pick('confirmationOpen').confirmationOpen,false)
    }
    function test_confirm_escape_and_locale() {
      plugin.setExpanded(true);wait(20);plugin.focusSearch()
      verify(pick('confirmationOpen').request(plugin.sortedProcesses[0],false))
      wait(10);compare(pick('handleKey').cancelText,'Отмена')
      keyClick(Qt.Key_Escape);wait(10);compare(pick('confirmationOpen').confirmationOpen,false)
    }
    function test_shortcuts() {
      plugin.hintsVisible=false;pick('moveRequested').forceActiveFocus()
      keyClick(Qt.Key_Question);wait(10);compare(plugin.hintsVisible,true)
    }
    function test_compact_bar_tooltip_data() {
      return ['en','ru','de','zh'].map(function(locale){return {tag:locale,locale:locale}})
    }
    function test_compact_bar_tooltip(data) {
      plugin.settings={locale:data.locale,iconIndicator:false,iconShape:10,iconLoadThreshold:50}
      var ctrl=plugin.activityController
      ctrl.glanceCpu=27;ctrl.glanceMemory=61
      ctrl.glanceMemoryUsed=9.11*1024*1024*1024;ctrl.glanceMemoryTotal=14.9*1024*1024*1024
      ctrl.glanceUpdatedAt=100000;ctrl.iconTemperature=72;ctrl.thermalUpdatedAt=100000;ctrl.freshnessClock=115000
      var header=nodes(plugin).filter(function(n){return n.text==='Loadlet'})
      verify(header.length>0,'the retained brand is visible in every supported locale')
      var tip=plugin.barIcon.parent.tooltipText
      verify(tip.indexOf('27%')>=0 && tip.indexOf('9.11 GiB / 14.9 GiB')>=0,'raw below-threshold measurements stay visible')
      var lines=tip.split('\n')
      verify(lines.length<=4,'hover must not include the settings tutorial')
      verify(lines.every(function(line){return line.length<=48}),'tooltip line exceeds compact copy budget')
      tooltipBubble.tooltipText=tip;wait(10)
      verify(tooltipBubble.implicitWidth<=Style.space(420),'native tooltip exceeds compact width')
      verify(tooltipBubble.implicitHeight<=Style.space(110),'native tooltip exceeds compact height')
      var clickHints={en:'Click: overview',ru:'Левая кнопка: обзор',de:'Klick: Übersicht',zh:'左键：概览'}
      verify(tip.split('\n').slice(2).join('\n')===clickHints[data.locale],'hint describes only the retained left-click action')
      verify(tip.indexOf(clickHints[data.locale])>=0,'hover retains the overview hint')
      verify(tip.indexOf(plugin.iconLegend)<0,'full icon legend belongs only in preferences')
      verify(plugin.iconLegend.indexOf('50')>=0,'preferences still explain the threshold')
      ctrl.freshnessClock=135000;wait(10)
      tip=plugin.barIcon.parent.tooltipText
      verify(tip.indexOf('27%')<0 && tip.indexOf('72')<0,'stale samples must not be shown as current')
      verify(tip.split('\n').length<=3)
    }
    function test_bar_pointer_routes() {
      plugin.close();plugin.bar=inertBar;inertBar.shownTooltip="";inertBar.requestedCommand=""
      var button=plugin.barIcon.parent
      mouseMove(host,host.width+20,host.height+20);wait(10)
      mouseMove(button,button.width/2,button.height/2);wait(20)
      compare(inertBar.shownTooltip,button.tooltipText,'actual host hover forwards compact copy')
      mouseClick(button,button.width/2,button.height/2,Qt.RightButton);wait(20)
      compare(plugin.opened,false,'right-click must not open a closed panel')
      mouseClick(button,button.width/2,button.height/2,Qt.MiddleButton);wait(20)
      compare(plugin.opened,false)
      mouseClick(button,button.width/2,button.height/2,Qt.LeftButton);wait(20)
      compare(plugin.opened,true);compare(plugin.expanded,false)
      mouseClick(button,button.width/2,button.height/2,Qt.RightButton);wait(20)
      compare(plugin.opened,true);compare(plugin.expanded,false,'right-click must not expand the overview')
      plugin.setSettingsOpen(true);plugin.languageExpanded=true;wait(20)
      mouseClick(button,button.width/2,button.height/2,Qt.RightButton);wait(20)
      compare(plugin.settingsOpen,true);compare(plugin.languageExpanded,true);compare(plugin.expanded,false)
      plugin.setSettingsOpen(false);plugin.setExpanded(false)
      pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_E);wait(20)
      compare(plugin.expanded,true,'internal details remain available through the panel')
      plugin.activityController.stop();MockData.populate(plugin.activityController);wait(20)
      plugin.sortKey='name';plugin.processQuery='fire';wait(10);plugin.selectProcess(0)
      var selected=plugin.selectedProcessKey
      verify(selected!=='');verify(plugin.searchField!==null);verify(plugin.processViewport!==null)
      var panel=pick('fittedContentWidth'),w=panel.width,h=panel.height
      mouseClick(button,button.width/2,button.height/2,Qt.RightButton);wait(20)
      compare(plugin.processQuery,'fire');compare(plugin.selectedProcessKey,selected)
      compare(plugin.sortKey,'name');compare(panel.width,w);compare(panel.height,h)
      compare(plugin.expanded,true);compare(inertBar.requestedCommand,'')
      plugin.close();wait(20);plugin.openDetails();wait(20)
      compare(plugin.opened,true);compare(plugin.expanded,true,'details IPC owner remains available')
      pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_Escape);wait(10)
      compare(plugin.opened,true);compare(plugin.expanded,false)
      keyClick(Qt.Key_Escape);wait(10);compare(plugin.opened,false)
      compare(inertBar.requestedCommand,'','no pointer route launches a separate application')
      plugin.settings={locale:'ru',iconIndicator:false,openExpanded:true}
      mouseClick(button,button.width/2,button.height/2,Qt.LeftButton);wait(20)
      compare(plugin.opened,true);compare(plugin.expanded,true)
      // The inert bar fills the host; use a point outside its expanded popup.
      button.triggerPress(Qt.LeftButton);wait(20)
      compare(plugin.opened,false);compare(plugin.settings.openExpanded,true)
    }
    function test_header_sizes() {
      var all=nodes(plugin)
      var lang=all.filter(function(n){return n.iconName==='language' && n.text!==undefined})[0]
      var icons=all.filter(function(n){return n.iconName==='help'||n.iconName==='settings'||n.iconName==='expand'})
      for(var i=0;i<icons.length;i++) compare(icons[i].height,lang.height)
    }
    function test_fixture_topology() {
      verify(Array.isArray(plugin.snapshot.topology))
      verify(plugin.corePaintCompact.cells.some(function(c){return c.usage>0}))
      verify(plugin.corePaintCompact.cells.some(function(c){return c.kind==='performance'}))
      verify(plugin.corePaintCompact.cells.some(function(c){return c.kind==='efficiency'}))
    }
    function test_guard_locale() {
      compare(pick('confirmationOpen').blockReason({pid:1}),'Защищённый системный процесс')
    }
    function test_icon_states_and_slot() {
      var icon=nodes(plugin).filter(function(n){return n.objectName==='activityBarIcon'})[0]
      icon.thermalSampleAt=Date.now()
      compare(icon.shapeIndex,10)
      icon.fresh=true; icon.cpu=30; icon.ram=44
      tryCompare(icon,'status',Image.Ready)
      var normal=String(icon.source)
      icon.cpu=95;wait(10);verify(String(icon.source)!==normal)
      icon.hot=true;icon.temperatureFresh=true;wait(10);compare(icon.thermalAlert,true)
      icon.temperatureFresh=false;wait(10);compare(icon.thermalAlert,false)
      for(var i=0;i<11;i++) {
        icon.shape=i;tryCompare(icon,'status',Image.Ready);compare(icon.shapeIndex,i)
        compare(icon.width,Style.bar.iconCanvas);compare(icon.height,Style.bar.iconCanvas)
      }
      icon.fresh=false;wait(10)
      var stale=String(icon.source)
      icon.cpu=0;icon.ram=0;wait(10);compare(String(icon.source),stale)
    }
    function test_split_icon_left_right_pixel_symmetry() {
      plugin.settings={locale:'en',iconIndicator:false,iconMotion:false,iconShape:10}
      // A uniform opaque canvas excludes the panel behind transparent SVG pixels.
      var canvas=createTemporaryObject(symmetryIconComponent,host)
      verify(canvas!==null)
      var icon=canvas.icon;icon.fresh=true;icon.shape=10
      for(var i=0;i<3;i++) {
        icon.cpu=[0,50,100][i];icon.ram=icon.cpu
        tryCompare(icon,'status',Image.Ready);wait(30)
        var pixels=grabImage(canvas)
        verify(pixels.width>0 && pixels.height>0,'native icon must have actual pixels')
        for(var y=0;y<pixels.height;y++)for(var x=0;x<pixels.width/2;x++)
          compare(pixels.pixel(x,y),pixels.pixel(pixels.width-1-x,y),
                  'equal-load quiet icon must mirror left/right at pixel '+x+','+y)
      }
    }
    function test_icon_raster_matches_svg_data_url() {
      var icons=nodes(plugin).filter(function(n){return n.shapeIndex!==undefined})
      compare(icons.length,2)
      for(var i=0;i<icons.length;i++) {
        var icon=icons[i]
        tryCompare(icon,'status',Image.Ready)
        var svg=decodeURIComponent(String(icon.source).split(',',2)[1])
        verify(svg.indexOf('width="'+icon.sourceSize.width+'" height="'+icon.sourceSize.height+'"')>=0,
               'data-URL decoding must not rasterize a fixed 16px SVG and upscale it')
        compare(icon.implicitWidth,icon.sourceSize.width)
        compare(icon.implicitHeight,icon.sourceSize.height)
        compare(icon.sourceSize.width,Math.max(1,Math.ceil(icon.width*icon.rasterDpr)))
      }
    }
    function test_icon_hidpi_refresh_keeps_logical_size() {
      plugin.close()
      var icon=plugin.barIcon
      verify(icon!==null)
      icon.motionEnabled=false
      icon.fresh=true
      for(var i=0;i<24;i++) {
        icon.cpu=(i*17)%100;icon.ram=(i*23)%100
        tryCompare(icon,'status',Image.Ready)
        wait(5)
        compare(icon.width,Style.bar.iconCanvas,'decoded pixels must not resize the bar icon')
        compare(icon.height,Style.bar.iconCanvas)
        var sceneBounds=icon.mapToItem(plugin,0,0,icon.width,icon.height)
        fuzzyCompare(sceneBounds.width,Style.bar.iconCanvas,0.01,'native custom-icon normalization must not shrink Loadlet')
        fuzzyCompare(sceneBounds.height,Style.bar.iconCanvas,0.01)
        compare(icon.sourceSize.width,Math.ceil(Style.bar.iconCanvas*icon.rasterDpr))
        compare(icon.sourceSize.height,Math.ceil(Style.bar.iconCanvas*icon.rasterDpr))
      }
    }
    function test_icon_preferences_and_frame() {
      plugin.settings={locale:'ru',iconIndicator:false,iconShape:1};wait(10)
      var panel=pick('fittedContentWidth')
      plugin.setSettingsOpen(true);plugin.settingsSection='icon';wait(20)
      var w=panel.width,h=panel.height
      var dropdown=nodes(plugin).filter(function(n){return n.objectName==='iconShapeDropdown'})[0]
      dropdown.open();wait(10);keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(20)
      compare(plugin.iconShapeSetting,2)
      compare(pick('shapeIndex').shapeIndex,2)
      var heat=nodes(plugin).filter(function(n){return n.objectName==='iconHeatDropdown'})[0]
      heat.open();wait(10);keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(20)
      compare(plugin.activityController.heatThreshold,85)
      compare(panel.width,w);compare(panel.height,h)
      plugin.setSettingsOpen(false);wait(20);compare(panel.width,w);compare(panel.height,h)
      plugin.resetPreferences();compare(plugin.iconShapeSetting,10);compare(plugin.activityController.heatThreshold,80)
    }
    function test_split_icon_default_and_mapping() {
      compare(plugin.iconShapeSetting,10)
      var icons=nodes(plugin).filter(function(n){return n.shapeIndex!==undefined})
      compare(icons.length,2)
      for(var i=0;i<icons.length;i++) {
        var icon=icons[i]
        compare(icon.shapeIndex,10)
        icon.fresh=true;icon.cpu=50;icon.ram=100;icon.hot=false
        tryCompare(icon,'status',Image.Ready)
        var svg=decodeURIComponent(String(icon.source).split(',',2)[1])
        verify(svg.indexOf('M3 11V12H5V11Z')>=0,'selected cutout cheeks retained')
        var cpu=svg.match(/<g id="cpu-cells">(.*?)<\/g>/)[1]
        var ram=svg.match(/<g id="ram-cells">(.*?)<\/g>/)[1]
        compare((cpu.match(/opacity="1"/g)||[]).length,3)
        compare((ram.match(/opacity="1"/g)||[]).length,6)
      }
      var legends=['Left eye: CPU','Левый глаз: CPU','Linkes Auge: CPU','左眼表示CPU']
      var locales=['en','ru','de','zh']
      for(var l=0;l<locales.length;l++) {
        plugin.settings={locale:locales[l],iconIndicator:false};wait(10)
        verify(plugin.iconLegend.indexOf(legends[l])===0)
      }
      plugin.settings={locale:'en',iconIndicator:false,iconShape:1};wait(10)
      compare(plugin.iconShapeSetting,1)
      verify(plugin.iconLegend.indexOf('Mouth: CPU')===0)
    }
    function test_unrelated_settings_do_not_refresh_sampling() {
      var ctrl=createTemporaryObject(controllerComponent,host,{settings:{locale:'ru',samplingSpeed:'Efficient'}})
      ctrl.active=true;ctrl.stop();ctrl.state='ready'
      ctrl.due={resources:123};ctrl._metrics={cpu:42,memory:55}
      compare(ctrl.profileName,'Efficient')
      ctrl.settings={locale:'en',samplingSpeed:'Efficient',iconLoadThreshold:60,iconShape:1,iconMotion:false}
      compare(ctrl.state,'ready')
      compare(ctrl.due.resources,123,'presentation settings must not reschedule collection')
      compare(ctrl.pending,'');compare(ctrl.metrics.cpu,42)
      ctrl.state='stopped'
      ctrl.settings={locale:'en',samplingSpeed:'Balanced'}
      compare(ctrl.profileName,'Balanced')
      compare(ctrl.state,'starting','actual profile changes still refresh sampling')
      ctrl.active=false;ctrl.stop()
    }
    function test_icon_load_threshold() {
      compare(plugin.iconLoadThresholdSetting,50)
      var ctrl=plugin.activityController
      ctrl.glanceCpu=49.99;ctrl.glanceMemory=55
      ctrl.glanceUpdatedAt=Date.now();ctrl.freshnessClock=Date.now()
      var icons=nodes(plugin).filter(function(n){return n.shapeIndex!==undefined})
      compare(icons.length,2)
      for(var i=0;i<icons.length;i++) {
        compare(icons[i].gaugeCpu,0);compare(icons[i].gaugeRam,55)
        compare(icons[i].cpu,49.99);compare(icons[i].ram,55)
      }
      var rawMetrics=JSON.stringify(ctrl.metrics),rawSnapshot=JSON.stringify(ctrl.snapshot)
      var tooltip=pick('tooltipText')
      verify(tooltip.tooltipText.indexOf('CPU 50%')>=0,'tooltip retains the real sample, not gauge zero')
      ctrl.glanceCpu=50;wait(10)
      for(var j=0;j<icons.length;j++) compare(icons[j].gaugeCpu,50)
      plugin.setSettingsOpen(true);wait(20)
      var dropdown=nodes(plugin).filter(function(n){return n.objectName==='iconLoadThresholdDropdown'})[0]
      verify(dropdown!==undefined);compare(dropdown.value,'50')
      dropdown.open();wait(10);keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(20)
      compare(plugin.iconLoadThresholdSetting,60);compare(plugin.settings.iconLoadThreshold,60)
      compare(JSON.stringify(ctrl.metrics),rawMetrics);compare(JSON.stringify(ctrl.snapshot),rawSnapshot)
      for(var k=0;k<icons.length;k++) {compare(icons[k].gaugeCpu,0);compare(icons[k].gaugeRam,0)}
      plugin.setSettingsOpen(false);plugin.setSettingsOpen(true);wait(10)
      var reopened=nodes(plugin).filter(function(n){return n.objectName==='iconLoadThresholdDropdown'})[0]
      verify(reopened!==undefined);compare(reopened.value,'60')
      ctrl.iconTemperature=83;ctrl.thermalUpdatedAt=Date.now();ctrl.freshnessClock=Date.now();ctrl.updateHeatAlert()
      compare(ctrl.heatAlert,true)
      plugin.persistSettings({iconLoadThreshold:0});wait(10)
      for(var a=0;a<icons.length;a++) {compare(icons[a].gaugeCpu,50);compare(icons[a].gaugeRam,55);compare(icons[a].thermalAlert,true)}
      ctrl.glanceCpu=-1;wait(10);for(var b=0;b<icons.length;b++) compare(icons[b].gaugeCpu,-1)
      ctrl.freshnessClock=ctrl.glanceUpdatedAt+35000;wait(10)
      for(var c=0;c<icons.length;c++) {compare(icons[c].gaugeCpu,-1);compare(icons[c].gaugeRam,-1)}
      plugin.resetPreferences();compare(plugin.iconLoadThresholdSetting,50)
    }
    function test_icon_semantics_and_header() {
      var icons=nodes(plugin).filter(function(n){return n.shapeIndex!==undefined})
      compare(icons.length,2)
      var ctrl=plugin.activityController
      ctrl.glanceUpdatedAt=Date.now();ctrl.freshnessClock=Date.now()
      ctrl.glanceCpu=70;ctrl.glanceMemory=92;wait(10)
      for(var i=0;i<icons.length;i++) {
        compare(icons[i].cpuColor,plugin.pressureColor(70))
        compare(icons[i].ramColor,plugin.pressureColor(92))
        compare(icons[i].shapeIndex,plugin.iconShapeSetting)
      }
      plugin.setSettingsOpen(true);wait(20)
      var toggle=nodes(plugin).filter(function(n){return n.objectName==='iconMotionToggle'})[0]
      toggle.clicked();wait(10);compare(plugin.booleanSetting('iconMotion',true),false)
      for(var j=0;j<icons.length;j++) compare(icons[j].motionEnabled,false)
    }
    function test_heat_motion_lifecycle() {
      var icon=nodes(plugin).filter(function(n){return n.objectName==='activityBarIcon'})[0]
      icon.motionEnabled=true;icon.temperatureFresh=true;icon.hot=false;icon.lastMotionAt=0;icon.heatLevel=1
      icon.cpu=85;icon.ram=92;icon.fresh=true
      var source=String(icon.source)
      icon.hot=true;tryCompare(icon,'motionRunning',true)
      source=String(icon.source)
      wait(180);verify(Math.abs(icon.rotation)>4)
      compare(String(icon.source),source,'rotation must not rebuild SVG')
      wait(800);compare(icon.motionRunning,true,'motion should remain visible beyond the old 600ms')
      compare(String(icon.source),source)
      verify(Math.abs(icon.rotation)<=6)
      tryCompare(icon,'motionRunning',false,1500);compare(icon.rotation,0)
      icon.thermalSampleAt=Date.now();wait(30);compare(icon.motionRunning,false)
      icon.lastMotionAt=Date.now()-15001;icon.thermalSampleAt=Date.now()-1
      tryCompare(icon,'motionRunning',true)
      icon.temperatureFresh=false;compare(icon.motionRunning,false);compare(icon.rotation,0)
      icon.lastMotionAt=0;icon.temperatureFresh=true;tryCompare(icon,'motionRunning',true)
      icon.motionEnabled=false;compare(icon.motionRunning,false);compare(icon.rotation,0)
      icon.motionEnabled=true;icon.lastMotionAt=0;icon.requestWiggle();tryCompare(icon,'motionRunning',true)
      icon.hot=false;compare(icon.motionRunning,false);compare(icon.rotation,0)
      icon.hot=true;icon.lastMotionAt=0
      icon.motionEnabled=true;icon.lastMotionAt=0;icon.requestWiggle();tryCompare(icon,'motionRunning',true)
      icon.visible=false;compare(icon.motionRunning,false);compare(icon.rotation,0)
      icon.visible=true;icon.hot=false;icon.lastMotionAt=0;icon.requestWiggle();compare(icon.motionRunning,false)
    }
    function test_heat_severity_and_replay() {
      var ctrl=plugin.activityController
      ctrl.iconTemperature=80;ctrl.thermalUpdatedAt=Date.now();ctrl.freshnessClock=Date.now();ctrl.updateHeatAlert()
      compare(ctrl.heatLevel,1);compare(ctrl.heatMotionInterval,15000)
      ctrl.iconTemperature=85;ctrl.updateHeatAlert();compare(ctrl.heatLevel,2);compare(ctrl.heatMotionInterval,10000)
      ctrl.iconTemperature=90;ctrl.updateHeatAlert();compare(ctrl.heatLevel,3);compare(ctrl.heatMotionInterval,5000)
      ctrl.iconTemperature=95;ctrl.updateHeatAlert();compare(ctrl.heatLevel,4);compare(ctrl.heatMotionInterval,3000)
      var icon=nodes(plugin).filter(function(n){return n.objectName==='activityBarIcon'})[0]
      icon.cancelWiggle();icon.lastMotionAt=Date.now()-2990;icon.requestWiggle();compare(icon.motionRunning,false)
      icon.lastMotionAt=Date.now()-3001;icon.requestWiggle();tryCompare(icon,'motionRunning',true)
      ctrl.freshnessClock=ctrl.thermalUpdatedAt+35000
      compare(ctrl.heatLevel,0);compare(icon.motionRunning,false);compare(icon.rotation,0)
    }
    function test_diagnostic_controls() {
      compare(plugin.activityController.journalEnabled,false)
      plugin.setSettingsOpen(true);plugin.settingsSection="diagnostics";wait(20)
      var toggle=nodes(plugin).filter(function(n){return n.objectName==='diagnosticJournalToggle'})[0]
      toggle.clicked();wait(10);compare(plugin.activityController.journalEnabled,true)
      plugin.close();wait(10);compare(plugin.activityController.collectionEnabled,true)
      plugin.settings={locale:'ru',iconIndicator:false,diagnosticJournal:false};wait(10)
      compare(plugin.activityController.collectionEnabled,false)
      plugin.open();plugin.activityController.stop();plugin.setSettingsOpen(true);plugin.settingsSection="diagnostics";wait(20)
      var period=nodes(plugin).filter(function(n){return n.objectName==='diagnosticPeriodDropdown'})[0]
      period.open();wait(10);keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(20);compare(period.value,'6')
    }
    function test_thermal_freshness() {
      var ctrl=plugin.activityController
      ctrl.iconTemperature=83;ctrl.thermalUpdatedAt=100000;ctrl.freshnessClock=115500
      ctrl.updateHeatAlert();compare(ctrl.heatAlert,true);compare(ctrl.thermalFresh,true)
      ctrl.iconTemperature=77;ctrl.updateHeatAlert();compare(ctrl.heatAlert,true)
      ctrl.iconTemperature=74;ctrl.updateHeatAlert();compare(ctrl.heatAlert,false)
      ctrl.iconTemperature=83;ctrl.updateHeatAlert();compare(ctrl.heatAlert,true)
      ctrl.freshnessClock=135000;compare(ctrl.thermalFresh,false);compare(ctrl.heatAlert,false)
      ctrl.freshnessClock=99999;compare(ctrl.thermalFresh,false)
    }
    function test_background_disabled_stops() {
      plugin.settings={locale:'ru',iconIndicator:true}
      plugin.close();wait(10)
      compare(plugin.activityController.collectionEnabled,true)
      plugin.settings={locale:'ru',iconIndicator:false};wait(10)
      compare(plugin.activityController.collectionEnabled,false)
      compare(plugin.activityController.glanceFresh,false)
      compare(plugin.activityController.thermalFresh,false)
    }
    function test_icon_freshness_between_sparse_samples() {
      var ctrl = plugin.activityController
      compare(ctrl.backgroundInterval,15000)
      compare(ctrl.glanceMaxAge,35000)
      ctrl.glanceUpdatedAt = 100000
      ctrl.freshnessClock = 115500
      compare(ctrl.glanceFresh,true)
      ctrl.freshnessClock = 134999
      compare(ctrl.glanceFresh,true)
      ctrl.freshnessClock = 135000
      compare(ctrl.glanceFresh,false)
      ctrl.freshnessClock = 99999
      compare(ctrl.glanceFresh,false)
    }
  }
}
