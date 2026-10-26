import QtQuick
import QtTest
import Quickshell
import qs.Commons
import "imports/ActivityHost/Ui" as NativeHost
import "plugin" as Plugin
import "mock-data.js" as MockData

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
      plugin.open();plugin.activityController.stop()
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
      verify(button.visible);var small=panel.width
      mouseClick(button,button.width/2,button.height/2);wait(30)
      compare(plugin.expanded,true);verify(panel.width>small)
      compare(plugin.settingsOpen,data.page==='settings')
      compare(plugin.sensorsOpen,data.page==='cooling'||data.page==='fans')
      pick('moveRequested').forceActiveFocus();keyClick(Qt.Key_E);wait(30)
      compare(plugin.expanded,false,'E works on every page')
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
      verify(viewport.contentHeight>viewport.height,'The whole cooling page scrolls')
      viewport.contentY=viewport.contentHeight-viewport.height;wait(10)
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
    function test_chart_timestamp_selection() {
      plugin.sensorsOpen=true;wait(20)
      var chart=named('sensorHistoryChart')
      chart.points=[{time:100,value:40},{time:110,value:50},{time:200,value:60}]
      chart.selectAt(chart.width*0.12);compare(chart.selectedIndex,1)
      chart.forceActiveFocus();keyClick(Qt.Key_Right);compare(chart.selectedIndex,2)
      keyClick(Qt.Key_Left);compare(chart.selectedIndex,1)
      chart.points=[{time:110,value:50},{time:200,value:60},{time:210,value:61}]
      compare(chart.selectedPoint.time,110,'Selection follows the timestamp, not a shifting index')
      chart.points=[];keyClick(Qt.Key_Left);compare(chart.selectedIndex,-1)
    }
    function test_fan_commands_inert() {
      plugin.sensorsOpen=true;plugin.fansOpen=true;wait(20)
      var proc=nodes(plugin).filter(function(n){return n.command&&n.command[0]==='pkexec'})[0]
      verify(!!proc)
      var boost=nodes(plugin).filter(function(n){return n.text==='60%'})[0]
      mouseClick(boost,boost.width/2,boost.height/2);wait(10)
      compare(proc.running,true);compare(proc.command.join(' '),'pkexec /usr/local/lib/loadlet/fan-control boost pwm2 60 10')
      proc.running=false;proc.exited(126);wait(10);compare(plugin.fanStatusKey,'fan_action_failed')
      var restore=nodes(plugin).filter(function(n){return n.iconName==='restore'&&n.text&&n.text.indexOf('Вернуть')>=0})[0]
      mouseClick(restore,restore.width/2,restore.height/2);wait(10)
      compare(proc.command.join(' '),'pkexec /usr/local/lib/loadlet/fan-control restore pwm2')
      proc.running=false;proc.exited(0);compare(plugin.fanStatusKey,'fan_action_sent')
      plugin.fanAction('pwm1',100,'boost');compare(proc.running,false)
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
      plugin.setSettingsOpen(true);wait(20)
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
      plugin.setSettingsOpen(false)
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
      mouseClick(button,button.width/2,button.height/2,Qt.LeftButton);wait(20)
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
      var panel=pick('fittedContentWidth'), w=panel.width, h=panel.height
      plugin.setSettingsOpen(true);wait(20)
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
      plugin.setSettingsOpen(true);wait(20)
      var toggle=nodes(plugin).filter(function(n){return n.objectName==='diagnosticJournalToggle'})[0]
      toggle.clicked();wait(10);compare(plugin.activityController.journalEnabled,true)
      plugin.close();wait(10);compare(plugin.activityController.collectionEnabled,true)
      plugin.settings={locale:'ru',iconIndicator:false,diagnosticJournal:false};wait(10)
      compare(plugin.activityController.collectionEnabled,false)
      plugin.open();plugin.activityController.stop();plugin.setSettingsOpen(true);wait(20)
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
