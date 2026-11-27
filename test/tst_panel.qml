import QtQuick
import QtTest
import Quickshell
import qs.Commons
import qs.Commons as Host
import "imports/ActivityHost/Ui" as NativeHost
import "plugin" as Plugin
import "mock-data.js" as MockData
import "plugin/ProfileCodec.js" as ProfileCodec
import "plugin/Model.js" as Model

Item {
  id: host
  width: 1600
  height: 1200
  Plugin.Panel { id: plugin; anchors.fill: parent }
  Component { id: controllerComponent; Plugin.ActivityController {} }
  Component { id: localeComponent; Plugin.LoadletLocale {} }
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
    property color barForeground: Host.Color.foreground
    property color urgent: Host.Color.urgent
    property color background: Host.Color.background
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
    function populate() {
      var ctrl = plugin.activityController
      var fixture = {}
      MockData.populate(fixture)
      var snapshot = fixture._sensorSnapshot
      var rows = snapshot.controls.map(function(channel) {
        return ["control", channel.id, channel.duty, channel.mode, channel.rpm].join("\t")
      })
      snapshot.controls = Model.parseSensorSnapshot(rows.join("\n")).controls
      Object.keys(fixture).forEach(function(key) { ctrl[key] = fixture[key] })
    }
    function setHostLanguage(code) {
      var target = Host.I18n.languageFile.reader || Host.I18n.languageFile
      target.fixtureText = code
      if (Host.I18n.languageFile.reread) Host.I18n.languageFile.reread()
    }
    function init() {
      setHostLanguage("")
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
      var profiles=named("powerProfiles")
      profiles.statusKey="";profiles.editorOpen=false;profiles.automationOptionsOpen=false
      profiles.cpuCapabilities={policies:[]};profiles.capabilitiesReady=false;profiles.selectProfile("idle")
      profiles.statusExpired=false;profiles.statusSuperseded=false;profiles.statusExitCode=-1;profiles.pendingCapabilities=null
      plugin.activityController.resetData();plugin.activityController.lastTick=Date.now()
      populate(); plugin.hintsVisible=true
      wait(60)
    }
    function cleanup() { plugin.close(); plugin.bar=null; wait(60) }
    function named(name, scope) {
      var item=nodes(scope || plugin).filter(function(n){return n.objectName===name})[0]
      verify(!!item,'Missing '+name)
      return item
    }
    function memoryFrame(i, pid) {
      return 'schema\tactivity-memory-watch\t1\nsample\t'+(1000+i*30)+'\t'+(100+i*30)+'\t'+(100+i*30)+'\tfixture\n'
        +'memory\tMemTotal\t1000000\nmemory\tMemAvailable\t700000\n'
        +'process\t'+(pid||42)+'\t7\t1\tS\t300000\t'+(100000+i*4096)+'\t0\t-1\t-1\t<fixture>\n'
        +'coverage\t1\t1\t0\t0\t0\t0\t2'
    }
    function test_memory_session_events_and_notification() {
      var watch=named('memoryWatch')
      watch.notificationsEnabled=false;watch.begin()
      for(var i=0;i<=20;i++)watch.observe(memoryFrame(i))
      compare(watch.events.length,1);compare(watch.events[0].process.growth,81920)
      watch.observe(memoryFrame(21));compare(watch.events.length,1)
      watch.observe(memoryFrame(22,99));compare(watch.events.length,1,'Exited process event is retained')
      watch.stop();compare(watch.events.length,1)
      watch.begin();compare(watch.events.length,0)
      watch.notificationsEnabled=true
      for(var j=0;j<=20;j++)watch.observe(memoryFrame(j))
      var sender=nodes(watch).find(function(n){return n.command && n.command[0]==='/usr/bin/timeout'})
      verify(!!sender);compare(sender.running,true)
      compare(sender.command.slice(-4).join(' '),'--exec /usr/share/omarchy/bin/omarchy-shell slovn.activity-lite.status memory')
      verify(sender.command.join(' ').indexOf('<fixture>')<0,'Notification markup is neutralized')
      sender.running=false;sender.exited(1);compare(watch.notificationError,true)
      for(var k=0;k<=20;k++)watch.observe(memoryFrame(k,43))
      compare(watch.events.length,2);compare(sender.running,false,'Cooldown prevents a second immediate send')
      verify(watch.notificationQueue.length>0)
      watch.notificationsEnabled=false;compare(watch.notificationQueue.length,0)
      watch.begin()
      for(var pid=100;pid<121;pid++)for(var sample=0;sample<=20;sample++)watch.observe(memoryFrame(sample,pid))
      compare(watch.events.length,20,'Event retention is capped')
      watch.stop();compare(watch.notificationQueue.length,0)
      watch.notificationsEnabled=false;watch.frames=[];watch.events=[]
    }
    function test_memory_watch_start_stop_generation() {
      var watch=named("memoryWatch"), ctrl=plugin.activityController
      watch.notificationsEnabled=false
      var reader=nodes(ctrl).find(function(n){return n.command && n.command[1]==="--activity-reader"})
      reader.running=true
      ctrl.state="ready"
      watch.begin()
      compare(ctrl.pending,"memory-watch")
      var generation=ctrl.pendingMemoryWatchGeneration
      watch.stop();watch.begin()
      compare(ctrl.memoryWatchGeneration,generation+2)
      ctrl.buffer=memoryFrame(0).split("\n")
      ctrl.consume("snapshot-end\tmemory-watch")
      compare(watch.frames.length,0)
      compare(ctrl.memoryWatchDue,0)
      ctrl.dispatch();compare(ctrl.pending,"memory-watch")
      ctrl.buffer=memoryFrame(1).split("\n")
      ctrl.consume("snapshot-end\tmemory-watch")
      compare(watch.frames.length,1)
      watch.stop();ctrl.stop()
    }
    function test_memory_cleanup_is_direct_and_confirmed() {
      plugin.showPage('memory');wait(30)
      var cleanup=named('memoryCleanup'),action=named('memoryCleanupRun')
      verify(action.visible && action.enabled && named('memoryProcesses').visible)
      compare(action.text,'Очистить кэш…')
      var openerX=action.mapToItem(cleanup,action.width/2,0).x
      mouseClick(action,action.width/2,action.height/2)
      tryCompare(cleanup,'confirming',true)
      compare(cleanup.running,false)
      var viewport=named('memoryCleanupViewport'),prompt=named('memoryCleanupPrompt')
      verify(prompt.visible && prompt.mapToItem(viewport,0,prompt.height).y <= viewport.height)
      var cancel=named('memoryCleanupCancel')
      verify(cancel.visible)
      tryCompare(cancel,'x',openerX-cancel.width/2)
      mouseClick(cancel,cancel.width/2,cancel.height/2)
      tryCompare(cleanup,'confirming',false)
      compare(cleanup.running,false)
      verify(cleanup.active,'Cancel keeps the Memory page active')
      cleanup.watch.begin()
      tryVerify(function(){return cleanup.watch.running && !action.enabled},
        1000,'Observation disables cache cleanup')
      cleanup.watch.stop()
      tryVerify(function(){return !cleanup.watch.running && action.enabled},
        1000,'Stopping observation enables cache cleanup')
    }
    function test_language_picker_keys_and_search() {
      plugin.setExpanded(false);plugin.languageExpanded=true;wait(40)
      var search=named('languageSearch'),list=named('languageList')
      verify(list.height>160,'Picker uses the available height')
      search.text='';search.forceActiveFocus();keyClick(Qt.Key_E);keyClick(Qt.Key_H)
      compare(plugin.expanded,false);compare(plugin.languageExpanded,true);compare(search.text,'eh')
      search.text='';wait(20);list.forceActiveFocus()
      keyClick(Qt.Key_End);compare(list.currentIndex,list.count-1)
      keyClick(Qt.Key_Home);compare(list.currentIndex,0)
      keyClick(Qt.Key_PageDown);verify(list.currentIndex>0)
      keyClick(Qt.Key_PageUp);compare(list.currentIndex,0)
      search.text='de';wait(20);verify(list.count>0)
      search.text='zzzz-no-language';wait(20);compare(list.count,0)
      plugin.languageExpanded=false
    }
    function test_live_shell_language_and_saved_override() {
      var ctrl=plugin.activityController
      plugin.settings={locale:"system",iconIndicator:false};wait(10)
      compare(plugin.effectiveLanguage,"en");compare(ctrl.language,"en")
      ctrl.state="ready";ctrl.due={resources:123};ctrl.captureSession="locale-fixture"
      setHostLanguage("de");wait(10)
      compare(plugin.effectiveLanguage,"de");compare(ctrl.language,"de")
      compare(ctrl.state,"ready");compare(ctrl.due.resources,123)
      compare(ctrl.captureSession,"locale-fixture")
      plugin.persistSettings({locale:"ru"})
      setHostLanguage("en");wait(10)
      compare(plugin.effectiveLanguage,"ru");compare(ctrl.language,"ru")
      plugin.persistSettings({locale:"system"})
      setHostLanguage("uk");wait(10)
      compare(plugin.effectiveLanguage,"uk","Keep the registry locale while using English text fallback")
      setHostLanguage("zh-TW");wait(10)
      compare(plugin.effectiveLanguage,"zh-TW","Traditional Chinese must not use Simplified")
      plugin.persistSettings({locale:"zh"});compare(plugin.effectiveLanguage,"zh-CN")
      var localeAdapter = createTemporaryObject(localeComponent, host)
      verify(localeAdapter !== null)
      compare(localeAdapter.fileText({text: "{\"en\":{}}"}), "{\"en\":{}}")
      compare(localeAdapter.fileText({text: function() { return "{\"ru\":{}}" }}), "{\"ru\":{}}")
    }
    function test_fast_diagnostic_controls_and_report() {
      plugin.setSettingsOpen(true);plugin.settingsSection="diagnostics";wait(40)
      var view=named("fastDiagnostics"), ctrl=plugin.activityController
      ctrl.captureWanted=false;ctrl.captureEnabled=false;ctrl.captureAction=""
      named("captureToggle").clicked()
      compare(ctrl.captureWanted,true)
      ctrl.accept("capture-500","schema\tactivity-diagnostics\t2\nenabled\t1\ninterval\t500\nsession\tfixture\nsequence\t8\nmissed\t0\nerror\t")
      compare(ctrl.captureEnabled,true)
      ctrl.state="stopped";named("captureMarker").clicked();compare(ctrl.captureAction,"capture-marker")
      view.report={schema:2,records:2,requested_range:[100,110],resolution_seconds:1,sessions:[],gaps:[],
        series:[{id:"temp",label:"Tctl",unit:"°C",points:[{time:101,value:70},{time:102,value:85}]},
          {id:"cpu",label:"CPU",unit:"%",points:[{time:101,value:20},{time:102,value:80}]}],
        process_frames:[{time:102,session:"fixture",processes:[{name:"worker",pid:42,cpu:150,rss_kib:100}]}]}
      wait(30);named("captureThermalPlot").selectIndex(1)
      compare(named("captureCpuPlot").selectedTime,102)
      verify(named("captureProcessWindow").text.indexOf("worker")>=0)
      ctrl.captureWanted=false;ctrl.captureEnabled=false;ctrl.captureAction="";ctrl.stop()
      view.report={series:[],sessions:[],process_frames:[],top_processes:[]}
    }
    function test_pin_preserves_process_state() {
      plugin.setExpanded(true);wait(30)
      plugin.processQuery="fire";plugin.setSort("name");plugin.selectProcess(0)
      var selected=plugin.selectedProcessKey, viewport=plugin.processViewport
      var sample=plugin.activityController.previousProcesses.sample
      var keyTarget=pick('moveRequested'), popup=pick('fittedContentWidth')
      var width=popup.contentWidth,height=popup.contentHeight
      var settings=JSON.stringify(plugin.settings)
      var pin=named('pinPanelButton')
      mouseClick(pin,pin.width/2,pin.height/2);wait(30)
      compare(plugin.pinned,true);compare(plugin.opened,true);compare(popup.open,false)
      compare(named('pinnedPanelCard').visible,true)
      compare(keyTarget.parent.parent.objectName,'pinnedPanelCard')
      compare(plugin.selectedProcessKey,selected);compare(plugin.processQuery,"fire")
      compare(plugin.processViewport,viewport,'pinning must not recreate the content')
      compare(plugin.activityController.previousProcesses.sample,sample)
      compare(plugin.activityController.active,true)
      compare(popup.contentWidth,width);compare(popup.contentHeight,height)
      mouseClick(pin,pin.width/2,pin.height/2);wait(30)
      compare(plugin.pinned,false);compare(popup.open,true)
      compare(plugin.selectedProcessKey,selected);compare(plugin.processQuery,"fire")
      compare(plugin.processViewport,viewport)
      compare(JSON.stringify(plugin.settings),settings,'pinning is temporary')
    }
    function test_pin_pages_and_close_data() {
      return ['overview','sensors','fans','profiles','memory','settings'].map(function(page){return {tag:page,page:page}})
    }
    function test_pin_pages_and_close(data) {
      plugin.showPage(data.page==='settings'?'overview':data.page)
      plugin.setSettingsOpen(data.page==='settings');wait(20)
      var pin=named('pinPanelButton'),before=[plugin.sensorsOpen,plugin.fansOpen,plugin.profilesOpen,plugin.memoryOpen,plugin.settingsOpen]
      mouseClick(pin,pin.width/2,pin.height/2);wait(30)
      compare(plugin.pinned,true)
      compare([plugin.sensorsOpen,plugin.fansOpen,plugin.profilesOpen,plugin.memoryOpen,plugin.settingsOpen],before)
      verify(pin.Accessible.checked)
      var close=named('closePanelButton');mouseClick(close,close.width/2,close.height/2);wait(20)
      compare(plugin.opened,false);compare(plugin.pinned,false)
      plugin.open();wait(20);compare(plugin.pinned,false);compare(pick('fittedContentWidth').open,true)
    }
    function test_pin_preserves_profile_draft_and_escape() {
      plugin.showPage('profiles');wait(20)
      var profiles=named('powerProfiles');profiles.beginEdit();wait(20)
      profiles.draft=Object.assign({},profiles.draft,{name:'Unsaved fixture draft'})
      var pin=named('pinPanelButton');mouseClick(pin,pin.width/2,pin.height/2);wait(30)
      compare(profiles.editorOpen,true);compare(profiles.draft.name,'Unsaved fixture draft')
      pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_Escape);wait(20)
      compare(profiles.editorOpen,false);compare(plugin.pinned,true);compare(plugin.opened,true)
      keyClick(Qt.Key_Escape);wait(20);compare(plugin.overviewOpen,true);compare(plugin.pinned,true)
      keyClick(Qt.Key_Escape);wait(20);compare(plugin.opened,false);compare(plugin.pinned,false)
    }
    function test_all_pages_expand_data() {
      return ['overview','cooling','fans','profiles','settings'].map(function(page){return {tag:page,page:page}})
    }
    function test_all_pages_expand(data) {
      plugin.hintsVisible=false
      plugin.sensorsOpen=data.page==='cooling'||data.page==='fans'
      plugin.fansOpen=data.page==='fans';plugin.profilesOpen=data.page==='profiles'
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
      ;['cooling','fans','profiles','settings'].forEach(function(page){
        ;[{font:12,width:340,height:360},{font:16,width:760,height:680},{font:24,width:960,height:660}].forEach(function(size){
          result.push({tag:page+'-'+size.font,page:page,font:size.font,width:size.width,height:size.height})
        })
      })
      return result
    }
    function test_page_geometry(data) {
      host.width=data.width;host.height=data.height;Style.fontBaseSize=data.font
      plugin.hintsVisible=false;plugin.showPage(data.page==='cooling'?'sensors':data.page)
      plugin.setSettingsOpen(data.page==='settings');wait(30)
      var panel=pick('fittedContentWidth'),button=named('expandButton')
      verify(button.mapToItem(panel,button.width,button.height).x<=panel.width+1)
      var viewport=named(data.page==='settings'?'settingsViewport':data.page==='profiles'?'profilesViewport':data.page==='fans'?'fansViewport':'coolingViewport')
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
      var overview=tab('overview')
      compare(overview.selected,true)
      plugin.sensorsOpen=true;plugin.fansOpen=true;plugin.openDetails();wait(20)
      compare(plugin.sensorsOpen,false);compare(plugin.expanded,true)
    }
    function clickVisible(item, viewport) {
      tryVerify(function() { return item.visible }, 1000, 'Target must be visible: '+item.objectName)
      if (viewport) {
        var startY=item.mapToItem(viewport,0,0).y
        viewport.contentY=Math.max(0,Math.min(viewport.contentHeight-viewport.height,
          viewport.contentY+startY-Math.max(0,(viewport.height-item.height)/2)))
        wait(20)
        tryVerify(function() {
          var y=item.mapToItem(viewport,0,0).y
          if (y >= -1 && y + item.height <= viewport.height + 1) return true
          viewport.contentY=Math.max(0,Math.min(viewport.contentHeight-viewport.height,
            viewport.contentY+y-Math.max(0,(viewport.height-item.height)/2)))
          return false
        }, 1000, 'Target fits inside viewport: '+item.objectName)
      }
      mouseClick(item,item.width/2,item.height/2);wait(30)
    }
    function tab(key) {
      return named('pageTab-'+key)
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
      plugin.activityController.stop();populate();wait(20)
      var profiles=named('powerProfiles')
      profiles.applyProfile(profiles.profiles[1])
      var proc=nodes(profiles).filter(function(n){return n.command&&n.command.indexOf('apply')>=0})[0]
      profiles.operationExpired=true
      proc.running=false;proc.exited(0)
      compare(profiles.statusKey,'profile_failed')
      profiles.operationExpired=false
    }
    function test_power_profiles_create_save_apply_inert() {
      plugin.setExpanded(true);plugin.showPage('profiles')
      plugin.activityController.stop();populate();wait(20)
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
      profiles.editorOpen=false;wait(10)
      clickVisible(named('newPowerProfileButton'),named('profilesViewport'))
      var created=profiles.draft.id
      verify(created.indexOf('custom-')===0)
      compare(named('powerProfileName').text,profiles.draft.name,'New profile replaces the visible name binding')
      profiles.saveDraft();wait(10)
      verify(JSON.parse(plugin.settings.powerProfiles).some(function(p){return p.id===created}))
      clickVisible(named('deletePowerProfileButton'),named('profileEditorViewport'));wait(10)
      verify(JSON.parse(plugin.settings.powerProfiles).some(function(p){return p.id===created}),'Deletion needs confirmation')
      clickVisible(named('deletePowerProfileButton'),named('profileEditorViewport'));wait(10)
      verify(!JSON.parse(plugin.settings.powerProfiles).some(function(p){return p.id===created}))
    }
    function test_profile_status_callback_order_data() {
      return [{tag:'stdout-first',exitFirst:false},{tag:'exit-first',exitFirst:true}]
    }
    function test_profile_status_callback_order(data) {
      var profiles=named('powerProfiles')
      var proc=nodes(profiles).filter(function(n){return n.command&&n.command[1]==='status'})[0]
      verify(!!proc)
      proc.started();proc.stdout.text=JSON.stringify({policies:[],automatic:{enabled:false,error:''}})
      if(data.exitFirst)proc.exited(0)
      proc.stdout.streamFinished()
      if(!data.exitFirst){compare(profiles.capabilitiesReady,false);proc.exited(0)}
      compare(profiles.capabilitiesReady,true)
      plugin.persistSettings({activePowerProfile:'idle'})
      proc.started();proc.exited(1);proc.stdout.streamFinished()
      compare(profiles.capabilitiesReady,false);compare(profiles.activeId,'')
      proc.started();proc.stdout.text='invalid';proc.stdout.streamFinished();proc.exited(0)
      compare(profiles.capabilitiesReady,false)
      proc.started();profiles.statusExpired=true;profiles.clearCapabilities()
      proc.stdout.text='{"policies":[]}';proc.stdout.streamFinished();proc.exited(0)
      compare(profiles.capabilitiesReady,false,'Late output cannot revive expired status')
      proc.running=false
    }
    function test_overview_profiles_share_apply_and_clear_drafts() {
      var profiles=named('powerProfiles')
      profiles.capabilitiesReady=true;plugin.fanOutputDrafts={pwm2:80}
      var button=named('quickProfile-idle')
      verify(button.enabled);button.clicked();compare(profiles.running,true)
      var payload=profiles.pendingPayload
      profiles.applyProfile(profiles.profiles[2]);compare(profiles.pendingPayload,payload,'Busy apply is not replaced')
      var proc=nodes(profiles).filter(function(n){return n.command&&n.command.indexOf('apply')>=0})[0]
      proc.running=false;proc.exited(1)
      compare(profiles.statusKey,'profile_failed');verify(!plugin.settings.activePowerProfile)
      compare(plugin.fanOutputDrafts.pwm2,80,'Failure retains the draft')
      profiles.applyProfile(profiles.profiles[1]);proc.running=false;proc.exited(0)
      compare(plugin.settings.activePowerProfile,'idle');compare(Object.keys(plugin.fanOutputDrafts).length,0)
      plugin.fanOutputDrafts={pwm2:60};plugin.close();plugin.open()
      compare(Object.keys(plugin.fanOutputDrafts).length,0)
    }
    function test_profile_browse_edit_cancel_and_apply() {
      plugin.hintsVisible=false;plugin.setExpanded(true);clickVisible(tab('profiles'))
      var profiles=named('powerProfiles'),viewport=named('profilesViewport')
      profiles.capabilitiesReady=true
      var before=JSON.stringify(plugin.settings),panel=pick('fittedContentWidth'),height=panel.height,width=panel.width
      named('powerProfileDropdown').changed('games');wait(10)
      compare(profiles.selectedId,'games');compare(profiles.running,false)
      compare(JSON.stringify(plugin.settings),before,'Browsing is inert')
      clickVisible(named('profileEditorToggle'),viewport)
      compare(profiles.draft.id,'games');verify(named('powerProfileEditorPage').visible)
      verify(named('pageTabs').visible,'Navigation remains visible during editing')
      profiles.changeCpu('boost',false)
      clickVisible(named('cancelPowerProfileButton'))
      compare(JSON.stringify(plugin.settings),before);compare(profiles.draft.config.cpu.boost,true)
      compare(panel.height,height);compare(panel.width,width)
      clickVisible(named('profileEditorToggle'),viewport)
      named('powerProfileName').forceActiveFocus();keyClick(Qt.Key_Escape);wait(10)
      compare(profiles.editorOpen,false);compare(plugin.profilesOpen,true)
      clickVisible(named('profileEditorToggle'),viewport)
      pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_Escape);wait(10)
      compare(profiles.editorOpen,false);compare(plugin.profilesOpen,true)
      clickVisible(named('profileEditorToggle'),viewport)
      profiles.changeCpu('maxMHz',2000)
      clickVisible(named('savePowerProfileButton'))
      compare(profiles.running,false,'Save must not apply hardware');compare(profiles.editorOpen,false)
      compare(JSON.parse(plugin.settings.powerProfiles).filter(function(p){return p.id==='games'})[0].config.cpu.maxMHz,2000)
      clickVisible(named('applyPowerProfileButton'),viewport)
      compare(profiles.running,true,'Apply is explicit')
      var proc=nodes(profiles).filter(function(n){return n.command&&n.command.indexOf('apply')>=0})[0]
      compare(proc.command[3],ProfileCodec.encode(profiles.selectedProfile.config))
      proc.running=false;proc.exited(0)
      compare(plugin.settings.activePowerProfile,'games');compare(plugin.settings.autoGameProfiles,false)
      compare(panel.height,height);compare(panel.width,width)
    }
    function test_profile_auto_base_and_invalid_draft() {
      plugin.hintsVisible=false;clickVisible(tab('profiles'))
      var profiles=named('powerProfiles'),viewport=named('profilesViewport')
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
    function test_profile_discovered_fans_and_cpu_choices() {
      var ctrl=plugin.activityController, profiles=named("powerProfiles")
      var amd="amd.0000_03_00_0.pwm1", nv="nv.0000_01_00_0.fan0", hw="hw.nct6799.isa0290.pwm1"
      var legacyNv="0000:01:00.0"
      var rows=[
        ["fan-channel",nv,"nvidia","nvidia","RTX 5060 Ti","fan1","0000:01:00.0","40","auto","","30","100","1","",""],
        ["fan-channel",amd,"amdgpu","amdgpu","Radeon","fan1","0000:03:00.0","55","auto","1500","20","90","1","",""],
        ["fan-channel",hw,"hwmon","nct6799","Motherboard","System fan","isa0290","60","auto","1500","15","95","1","",""]
      ].map(function(fields){return fields.join("\t")})
      ctrl._sensorSnapshot=Object.assign({},ctrl.sensorSnapshot,{controls:Model.parseSensorSnapshot(rows.join("\n")).controls})
      plugin.assignFan(hw,"fan_front")
      compare(JSON.parse(plugin.settings.fanChannelPlaces)[hw],"fan_front")
      compare(profiles.boardFans.length,1)
      compare(profiles.boardFans[0].id,hw)
      compare(profiles.gpuFans.length,2)
      profiles.cpuCapabilities={policies:[{scaling_available_governors:"conservative ondemand schedutil powersave performance userspace"}],
        platformProfile:"custom",platformProfileChoices:["quiet","balanced","performance","custom"]}
      var current=profiles.profiles.find(function(profile){return profile.id==="current"})
      verify(current.config.cpu.platformProfile === undefined)
      plugin.persistSettings({powerProfiles:JSON.stringify([{id:"current",name:"Fixture",icon:"fans",
        config:{cpu:{},fans:{},gpuFans:{"0000:01:00.0":40}}}])})
      plugin.showPage("profiles");profiles.selectedId="current";profiles.beginEdit();wait(20)
      compare(named("profileCpuMode").options.map(function(item){return item.value}).join(","),
        ",conservative,ondemand,schedutil,powersave,performance")
      named("profileCpuMode").changed("ondemand")
      var platform=named("profilePlatformProfile")
      verify(platform.visible)
      compare(platform.options.map(function(item){return item.value}).join(","),",quiet,balanced,performance")
      platform.changed("balanced")
      compare(profiles.gpuFanValue(profiles.draft.config.gpuFans,profiles.gpuFans[0]),40)
      profiles.changeFan(nv,"45",true)
      compare(profiles.draft.config.gpuFans[legacyNv],undefined)
      profiles.changeFan(amd,"19",true);verify(!profiles.saveDraft())
      profiles.changeFan(amd,"80",true);verify(profiles.saveDraft())
      var config=JSON.parse(plugin.settings.powerProfiles)[0].config
      compare(config.cpu.platformProfile,"balanced");compare(config.cpu.governor,"ondemand")
      compare(config.gpuFans[nv],45);compare(config.gpuFans[amd],80)
    }
    function test_profile_fan_save_limits_data() {
      return [{tag:"board",gpu:false,limit:16}, {tag:"GPU",gpu:true,limit:8}]
    }
    function test_profile_fan_save_limits(data) {
      var profiles=named("powerProfiles"), values={}
      for (var i=1;i<=data.limit;i++) {
        var channel=data.gpu ? "nv.0000_01_00_0.fan"+(i-1) : "hw.nct6799.isa0290.pwm"+i
        values[channel]=100
      }
      verify(profiles.saveFanValuesValid(values,data.gpu))
      values[channel]=101
      verify(!profiles.saveFanValuesValid(values,data.gpu))
      values[channel]=100
      values[data.gpu ? "amd.0000_03_00_0.pwm1" : "hw.nct6799.isa02a0.pwm1"]=100
      verify(!profiles.saveFanValuesValid(values,data.gpu))
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
      compare(named('fanAssignmentToggle').text,plugin.t('map_assignment','pwm2'))
      clickVisible(named('fanAssignmentToggle'),viewport)
      verify(named('fanAssignmentDropdown').visible)
      compare(named('fanAssignmentDropdown').label,plugin.t('map_assignment','pwm2'))
      clickVisible(named('fanAssignmentToggle'),viewport)
      clickVisible(named('fanIdentificationToggle'),viewport)
      verify(named('identifyFanButton').visible)
      clickVisible(named('fanIdentificationToggle'),viewport)
      var restore=nodes(plugin).filter(function(n){return n.iconName==='restore'&&n.text&&n.text.indexOf('Вернуть')>=0})[0]
      verify(restore.visible,'Recovery control is retained')
      verify(viewport.contentHeight>0,'Fan controls retain a scrollable content surface')
      clickVisible(restore,viewport)
      var fan=nodes(plugin).filter(function(n){return n.command&&n.command[0]==='/usr/local/lib/loadlet/fan-control'})[0]
      fan.running=false;fan.exited(0);plugin.activityController.stop();populate();wait(20)
      var history=named('fanHistoryButton');clickVisible(history,viewport)
      compare(plugin.fansOpen,false);compare(plugin.selectedSensor.label,'fan2');compare(plugin.expanded,false)
      plugin.close();plugin.open();plugin.activityController.stop();populate();wait(20)
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
    function test_chart_negative_temperatures() {
      plugin.showPage("sensors");wait(20)
      var chart=named("sensorHistoryChart")
      chart.referenceTime=200;chart.windowSeconds=100
      chart.points=[{time:100,value:-20},{time:150,value:-10},{time:200,value:5}]
      compare(chart.minimum,-20)
      verify(chart.yFor(-20)>chart.yFor(-10))
      verify(chart.yFor(-10)>chart.yFor(0))
      verify(chart.yFor(0)>chart.yFor(5))
      chart.selectAt(chart.xFor(chart.points[1]))
      compare(chart.selectedPoint.value,-10)
      verify(named("chartReading",chart).text.indexOf("-10") >= 0)
    }
    function test_gpu_fan_commands_bounds_and_identity() {
      plugin.persistSettings({locale:"en",activePowerProfile:"idle",autoGameProfiles:true,fanOutput_pwm2:37})
      var id="nv.0000_01_00_0.fan0", ctrl=plugin.activityController, original=ctrl.sensorSnapshot
      var reader=nodes(ctrl).find(function(n){return n.command && n.command[1]==="--activity-reader"})
      reader.running=true
      ctrl.state="ready"
      var frame=Model.parseSensorSnapshot([
        ["fan-channel",id,"nvidia","nvidia","NVIDIA GeForce RTX 5060 Ti","fan1","0000:01:00.0","0","auto","","30","100","1","","gpu-speed"].join("\t"),
        "fan\tgpu-speed\tnvidia\tDriver speed\t0\tpercent\tgpu"
      ].join("\n"))
      ctrl._sensorSnapshot=Object.assign({},original,{
        controls:original.controls.concat(frame.controls), fans:original.fans.concat(frame.fans)
      })
      var gpuSnapshot=ctrl.sensorSnapshot
      plugin.showPage("sensors");plugin.computerMapVisible=true;wait(20)
      clickVisible(named("mapFan-"+id),named("coolingViewport"))
      compare(plugin.fansOpen,true);compare(plugin.activeFanChannel,id)
      verify(!named("fanAssignmentToggle").visible)
      verify(named("fanChannelReadings").text.indexOf("NVIDIA GeForce RTX 5060 Ti") >= 0)
      verify(named("fanChannelReadings").text.indexOf("RPM —") >= 0)
      compare(plugin.fanHistorySensor(id).id,"gpu-speed")
      compare(named("fanHistoryButton").text,"Output history")
      var input=named("fanOutputInput"), save=named("saveFanOutputButton")
      compare(input.text,"");compare(input.placeholderText,"30–100");verify(!save.enabled)
      input.text="29";verify(!input.acceptableInput);verify(!save.enabled)
      input.text="101";verify(!input.acceptableInput)
      input.text="30";verify(input.acceptableInput);verify(save.enabled)
      var proc=nodes(plugin).find(function(n){return n.command&&n.command[0]==="/usr/local/lib/loadlet/fan-control"})
      var profiles=named("powerProfiles")
      profiles.cpuCapabilities={policies:[],automatic:{enabled:true,gaming:true,error:""}}
      plugin.fanAction(id,29,"save");verify(!proc.running)
      save.clicked()
      compare(proc.command.slice(1).join(" "),"request save "+id+" 30")
      profiles.applyProfile(profiles.selectedProfile);verify(!profiles.running)
      proc.running=false;proc.exited(0)
      compare(JSON.parse(plugin.settings.fanChannelOutputs)[id],30)
      compare(plugin.settings.fanOutput_pwm2,37)
      compare(plugin.settings.activePowerProfile,"");compare(profiles.automatic.enabled,false)
      compare(plugin.settings.autoGameProfiles,false)
      named("fanIdentificationToggle").clicked()
      var target=named("fanTrialTarget")
      verify(target.visible)
      compare(target.text,"Trial channel: NVIDIA GeForce RTX 5060 Ti · Fan 1 · Graphics card")
      var choices=named("identifyPercentDropdown")
      compare(choices.options.map(function(item){return item.value}).join(","),"30,40,50,60,80,100")
      plugin.fanAction(id,20,"identify");verify(!proc.running)
      named("identifyFanButton").clicked()
      compare(proc.command.slice(1).join(" "),"request identify "+id+" 30 5")
      proc.running=false;proc.exited(0)
      plugin.fanDuration=5
      named("fanBoost80").clicked()
      compare(proc.command.slice(1).join(" "),"request boost "+id+" 80 5")
      proc.running=false;proc.exited(0)
      ctrl._sensorSnapshot=original;wait(20)
      compare(plugin.activeFanChannel,id);verify(!named("fanRestoreButton").enabled);verify(!save.enabled)
      plugin.fanAction(id,80,"boost");verify(!proc.running)
      ctrl._sensorSnapshot=gpuSnapshot;wait(20)
      compare(plugin.activeFanChannel,id)
      var restore=named("fanRestoreButton")
      verify(restore.enabled);compare(restore.text,"Restore automatic control")
      restore.clicked()
      compare(proc.command.slice(1).join(" "),"request restore "+id)
      proc.running=false;proc.exited(0)
      compare(Object.keys(JSON.parse(plugin.settings.fanChannelOutputs)).length,0)
      plugin.fanDuration=10
    }
    function test_hardware_markup_in_fan_controls() {
      var ctrl = plugin.activityController
      var id = "nv.0000_01_00_0.fan0"
      var owner = '<img src="https://example.invalid/x">RTX'
      var label = "<b>Fan</b> &amp; \u202e1"
      var safeOwner = '‹img src="https://example.invalid/x"›RTX'
      var safeLabel = "‹b›Fan‹/b› ＆amp;  1"
      var frame = Model.parseSensorSnapshot(
        ["fan-channel",id,"nvidia","nvidia",owner,label,"0000:01:00.0","40","auto","","30","100","1","",""].join("\t"))
      ctrl._sensorSnapshot = Object.assign({}, ctrl.sensorSnapshot, {controls:frame.controls, temperatures:[]})
      compare(frame.controls[0].owner, owner)
      compare(frame.controls[0].label, label)
      plugin.persistSettings({locale:"en", powerProfiles:JSON.stringify([
        {id:"idle", name:"Fixture", icon:"fans", config:{cpu:{}, fans:{}, gpuFans:{"nv.0000_01_00_0.fan0":40}}}
      ])})
      plugin.showPage("overview")
      compare(named("quickProfile-idle").tooltipText, safeOwner + " · " + safeLabel + " 40%")

      plugin.showPage("fans")
      var dropdown = named("fanChannelDropdown")
      compare(dropdown.value, id)
      var expected = safeOwner + " · " + safeLabel + " · 0000:01:00.0 · RPM —"
      compare(dropdown.currentLabel(), expected)
      verify(nodes(dropdown).some(function(item) {
        return item.text === expected && item.textFormat === Text.PlainText
      }))
      dropdown.open()
      tryCompare(dropdown, "popupOpen", true)
      verify(nodes(dropdown.optionView.currentItem).some(function(item) {
        return item.text === expected && item.textFormat === Text.PlainText
      }))
      dropdown.optionView.selectCurrent()
      compare(plugin.activeFanChannel, id)
      compare(named("fanChannelReadings").textFormat, Text.PlainText)

      plugin.showPage("sensors"); plugin.computerMapVisible = true
      var button = named("mapFan-" + id)
      compare(button.text, safeOwner + " · " + safeLabel)
      var gpuLegend = named("mapLegendPart4")
      compare(gpuLegend.tooltipText, plugin.t("map_gpu") + "\n" + safeOwner + " · " + safeLabel + " · 40%")
      button.clicked()
      compare(plugin.activeFanChannel, id)
    }
    function test_symmetric_page_margins_data() {
      return ['fans','cooling','profiles','settings'].map(function(page){return {tag:page,page:page}})
    }
    function test_symmetric_page_margins(data) {
      plugin.hintsVisible=false
      if(data.page==='settings')plugin.setSettingsOpen(true)
      else { clickVisible(tab(data.page==='cooling'?'sensors':data.page)) }
      var viewport=named(data.page==='profiles'?'profilesViewport':data.page==='fans'?'fansViewport':data.page==='cooling'?'coolingViewport':'settingsViewport')
      var body=named(data.page==='profiles'?'powerProfiles':data.page==='fans'?'fanBody':data.page==='cooling'?'coolingBody':'settingsBody')
      compare(body.width,viewport.width,'Content does not reserve an asymmetric scrollbar gutter')
      var tabs=named(data.page==='settings'?'settingsTabs':'pageTabs')
      compare(viewport.mapToItem(plugin,0,0).x,tabs.mapToItem(plugin,0,0).x)
      compare(viewport.width,tabs.width,'Scrolling content and navigation share both edges')
      if(data.page==='fans') {
        var duration=named('fanDurationDropdown'),history=named('fanHistoryButton')
        compare(history.height,duration.rowHeight,'Adjacent action matches the input height')
        compare(history.mapToItem(viewport,0,history.height).y,duration.mapToItem(viewport,0,duration.height).y)
      }
      var scroll=named(data.page==='profiles'?'profilesScrollBar':data.page==='fans'?'fansScrollBar':data.page==='cooling'?'coolingScrollBar':'settingsScrollBar')
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
      chart.selectAt((600-400)/600*named('chartPlot',chart).width)
      compare(chart.selectedIndex,-1);compare(chart.cursorInGap,true)
      var pointer=named('chartPointer',chart)
      mouseClick(pointer,chart.xFor(chart.points[0]),pointer.height/2);wait(10)
      compare(chart.pinned,true);compare(chart.selectedPoint.time,410)
      mouseMove(pointer,pointer.width-2,pointer.height/2);wait(10)
      compare(chart.selectedPoint.time,410,'Pinned reading does not follow hover')
      clickVisible(named('chartLiveButton',chart));compare(chart.selectedIndex,-1);compare(chart.pinned,false)
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
      plugin.setExpanded(true);plugin.sensorsOpen=true;plugin.fansOpen=true;plugin.activityController.stop();populate();wait(20)
      var proc=nodes(plugin).filter(function(n){return n.command&&n.command[0]==='/usr/local/lib/loadlet/fan-control'})[0]
      verify(!!proc)
      var boost=nodes(plugin).filter(function(n){return n.text==='Разгон 60%'})[0]
      clickVisible(boost,named('fansViewport'));wait(10)
      compare(proc.running,true);compare(proc.command.join(' '),'/usr/local/lib/loadlet/fan-control request boost pwm2 60 10')
      proc.running=false;proc.exited(126);wait(10);compare(plugin.fanStatusKey,'fan_action_failed')
      var viewport=named('fansViewport');viewport.contentY=Math.max(0,viewport.contentHeight-viewport.height);wait(10)
      plugin.activityController.stop();populate();wait(10)
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
      proc.running=false;proc.exited(0);plugin.activityController.stop();populate()
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
      plugin.setExpanded(true);populate()
      plugin.setExpanded(false);wait(10)
      compare(plugin.gpus.length,1,'Collapsing preserves a GPU used by a compact tile')
      compare(plugin.compactRamStrip,true)
      plugin.persistSettings({compactTile1:'ram'});compare(plugin.compactRamStrip,false)
    }
    function test_compact_shared_geometry_data() {
      return [
        {tag:'normal',width:480,height:416,font:12,language:'ru'},
        {tag:'narrow',width:350,height:360,font:12,language:'de'},
        {tag:'large-font',width:960,height:700,font:24,language:'en'},
        {tag:'cjk',width:480,height:416,font:12,language:'zh'}
      ]
    }
    function test_compact_shared_geometry(data) {
      host.width=data.width;host.height=data.height;Style.fontBaseSize=data.font
      plugin.hintsVisible=false
      plugin.persistSettings({locale:data.language,compactTile0:'cpu',compactTile1:'gpu',compactRamStrip:true})
      wait(30)
      var grid=named('compactGrid'),ram=named('compactRamStrip'),actions=named('compactActions')
      compare(grid.width,ram.width,'Cards and memory share both edges')
      compare(grid.width,actions.width,'Cards and footer share both edges')
      compare(grid.mapToItem(plugin,0,0).x,ram.mapToItem(plugin,0,0).x)
      var tiles=nodes(grid).filter(function(n){return n.tile!==undefined})
      compare(tiles.length,2);compare(tiles[0].width,tiles[1].width);compare(tiles[0].height,tiles[1].height)
      var values=tiles.map(function(t){return nodes(t).find(function(n){return n.text===t.value})})
      compare(values[0].mapToItem(plugin,0,0).y,values[1].mapToItem(plugin,0,0).y,'Metric values share a baseline')
    }
    function test_profile_editor_geometry_and_inert_save() {
      host.width=350;host.height=400;plugin.hintsVisible=false;plugin.showPage('profiles');wait(20)
      var profiles=named('powerProfiles');profiles.capabilitiesReady=true
      plugin.persistSettings({activePowerProfile:'idle'});profiles.selectProfile('idle')
      clickVisible(named('profileEditorToggle'),named('profilesViewport'))
      var viewport=named('profileEditorViewport'),body=named('profileEditorBody')
      compare(body.width,viewport.width,'Editor has no unilateral gutter')
      compare(body.width,named('savePowerProfileButton').parent.width,'Form and footer share both edges')
      var cancel=named('cancelPowerProfileButton'),save=named('savePowerProfileButton')
      compare(cancel.width,save.width);compare(cancel.height,save.height)
      clickVisible(named('profileIcon-gpu'),viewport)
      compare(profiles.draft.icon,'gpu')
      var name=named('powerProfileName');name.text='Quiet renamed';name.textEdited()
      clickVisible(save)
      compare(profiles.running,false);compare(profiles.editorOpen,false)
      compare(plugin.settings.activePowerProfile,'idle','Metadata-only save keeps active attribution')
      compare(profiles.selectedProfile.icon,'gpu');compare(profiles.selectedProfile.name,'Quiet renamed')
      clickVisible(tab('overview'));compare(named('quickProfile-idle').iconName,'gpu')
    }
    function test_profile_draft_routes_data() {
      return ['back','cancel','tab','settings','close','expand','language'].map(function(route){return {tag:route,route:route}})
    }
    function test_profile_draft_routes(data) {
      plugin.showPage('profiles');wait(20)
      var profiles=named('powerProfiles'),before=JSON.stringify(plugin.settings)
      profiles.beginEdit();profiles.changeIcon('cpu');wait(20)
      if(data.route==='back')clickVisible(named('profileEditorBack'))
      else if(data.route==='cancel')clickVisible(named('cancelPowerProfileButton'))
      else if(data.route==='tab')clickVisible(tab('sensors'))
      else if(data.route==='settings')plugin.setSettingsOpen(true)
      else if(data.route==='close')plugin.close()
      else if(data.route==='expand')plugin.setExpanded(true)
      else {
        plugin.languageExpanded=true;wait(10)
        plugin.persistSettings({locale:'de'});plugin.languageExpanded=false
        before=JSON.stringify(plugin.settings)
      }
      wait(20)
      var retained=data.route==='expand'||data.route==='language'
      compare(profiles.editorOpen,retained);compare(JSON.stringify(plugin.settings),before)
      if(retained)compare(profiles.draft.icon,'cpu')
      compare(profiles.running,false)
    }
    function test_tabs_single_row_and_focus_reveal() {
      host.width=320;host.height=390;plugin.hintsVisible=false;plugin.persistSettings({locale:'de'});wait(30)
      var tabs=named('pageTabs'),items=['overview','sensors','fans','profiles'].map(tab)
      verify(tabs.contentWidth>tabs.width,'Fixture exercises horizontal overflow')
      items.forEach(function(item){compare(item.y,items[0].y);compare(item.height,tabs.height)})
      var panel=pick('fittedContentWidth'),height=panel.height
      items.forEach(function(item){
        item.forceActiveFocus();wait(20)
        verify(item.mapToItem(tabs,0,0).x>=-1)
        verify(item.mapToItem(tabs,item.width,0).x<=tabs.width+1)
        mouseClick(item,item.width/2,item.height/2);wait(20)
        verify(item.selected);compare(panel.height,height)
      })
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
      compare(named('summaryGrid').width,named('expandedActions').width,'Expanded summaries and footer share both edges')
      var tiles=nodes(named('summaryGrid')).filter(function(n){return n.tile!==undefined})
      tiles.forEach(function(t){compare(t.height,tiles[0].height);compare(t.headerHeight,tiles[0].headerHeight)})
    }
    function test_expanded_clamped() {
      Style.fontBaseSize=24;host.width=960;host.height=660
      plugin.setExpanded(true);wait(80)
      verify(pick('ensureSelected').height>=plugin.processRowHeight)
    }
    function test_process_scroll_survives_live_reorder() {
      plugin.setExpanded(true);wait(30)
      var seed=plugin.activityController._processes[0],list=[]
      for(var i=0;i<80;i++)list.push(Object.assign({},seed,{pid:String(2000+i),startTicks:String(5000+i),cpu:80-i,name:'fixture-'+i}))
      plugin.activityController._processes=list;wait(30)
      var view=plugin.processViewport,model=view.model
      view.contentY=plugin.processRowHeight*20;wait(20)
      var position=view.contentY
      verify(position>0)
      plugin.activityController._processes=list.map(function(p,i){return Object.assign({},p,{cpu:i})});wait(30)
      compare(view.model,model,'Metrics do not replace the rank model')
      compare(view.contentY,position,'Live reorder preserves scroll rank')
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
    function test_process_authorization() {
      var actions=pick('confirmationOpen')
      var process={pid:42,startTicks:1234,user:'root',name:'windows',state:'S'}
      compare(actions.blockReason(process),'')
      verify(actions.request(process,false));wait(10)
      compare(actions.pendingAction.authorize,true)
      var dialog=pick('handleKey')
      verify(dialog.message.indexOf('root')>=0)
      verify(dialog.message.indexOf('авторизация')>=0)
      verify(dialog.message.indexOf('виртуальной машины')>=0)
      actions.confirm()
      var sender=nodes(actions).find(function(n){return n.command!==undefined})
      compare(sender.command.slice(-1)[0],'--authorize')
      sender.running=false;sender.exited(126)
      compare(actions.failed,true)
      compare(actions.status,'Авторизация администратора отменена или отклонена')
      verify(actions.request(process,false))
      actions.confirm()
      sender.running=false;sender.exited(78)
      compare(actions.failed,true)
      compare(actions.status,'Требуется системный помощник Loadlet')
      verify(actions.request(process,true))
      compare(actions.pendingAction.action,'KILL')
      actions.cancel()
      process.name='quickshell'
      verify(actions.blockReason(process)!=='')
      verify(!actions.request(process,false))
      process.name='worker';process.user='demo'
      verify(actions.request(process,false))
      compare(actions.pendingAction.authorize,false)
      actions.confirm()
      compare(sender.command.indexOf('--authorize'),-1)
      sender.running=false;sender.exited(0)
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
      var memoryText=(data.locale==='ru'||data.locale==='de') ? '9,11 GiB / 14,9 GiB' : '9.11 GiB / 14.9 GiB'
      verify(tip.indexOf('27%')>=0 && tip.indexOf(memoryText)>=0,'localized below-threshold measurements stay visible')
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
      plugin.activityController.stop();populate();wait(20)
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
      var tooltip=plugin.barIcon.parent
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
