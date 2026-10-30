import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Host
import qs.Ui
import "I18n.js" as I18n

Column {
  id: root
  objectName: "fastDiagnostics"
  property var activity
  property string language: "ru"
  property int periodSeconds: 7200
  property string session: ""
  property double rangeStart: 0
  property double rangeEnd: 0
  property string selectedSeries: ""
  property var report: ({series:[],sessions:[],process_frames:[],top_processes:[]})
  property string reportPath: ""
  property string error: ""
  property string notice: ""
  property string action: ""
  property string runner: "omarchy"
  property bool panelOpen: true
  property bool agentVisible: false
  property bool agentAvailable: false
  property var agentModels: []
  property var agents: []
  property string selectedAgent: ""
  readonly property var agent: agents.find(function(a){return a.value===selectedAgent}) || null
  readonly property bool inlineAgent: !!agent && agent.inline===true
  property bool detailsVisible: false
  property bool agentDetailsVisible: false
  property bool customModel: false
  property string savedAgentModel: ""
  property string agentModel: savedAgentModel
  property string defaultAgentModel: ""
  signal agentModelSelected(string model)
  readonly property var modelOptions: [{value:"",label:t("capture_model_default")+(defaultAgentModel ? " · "+modelLabel(defaultAgentModel) : "")}]
    .concat(agentModels).concat([{value:"__custom__",label:t("capture_model_custom")}])
  property string agentAnswer: ""
  property string answerModel: ""
  property var answerRange: []
  property string agentQuestion: ""
  readonly property bool analyzing: busy && action==="analyze"
  property bool waitingFlush: false
  property bool timedOut: false
  property string captured: ""
  readonly property bool busy: query.running || waitingFlush
  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("diagnostic-report")).replace(/^file:\/\//,""))
  readonly property var series: report.series || []
  readonly property var sensor: series.find(function(s){return s.id===selectedSeries}) || series.find(function(s){return s.unit==="°C"}) || series[0] || null
  readonly property var cpu: series.find(function(s){return s.id==="cpu"}) || null
  readonly property double cursorTime: thermalPlot.selectedTime
  readonly property var processFrame: {
    var frames=report.process_frames || [], best=null
    var target=cursorTime>0 ? cursorTime : frames.length ? frames[frames.length-1].time : 0
    var selectedSession=thermalPlot.selectedPoint ? thermalPlot.selectedPoint.session : ""
    frames.forEach(function(f){if((!selectedSession || f.session===selectedSession) && (!best || Math.abs(f.time-target)<Math.abs(best.time-target)))best=f})
    return best && Math.abs(best.time-target)<=Math.max(3,report.resolution_seconds || 1) ? best : null
  }
  spacing: Style.spacing.md
  function t(key,a,b,c) { return I18n.t(key,language,a,b,c) }
  function modelLabel(value) {
    var found=agentModels.find(function(m){return m.value===value})
    return found ? found.label : value
  }
  function chooseModel(value) {
    customModel=value==="__custom__"
    if(!customModel) {agentModel=value;agentModelSelected(value)}
    else Qt.callLater(function(){customModelField.forceActiveFocus();customModelField.selectAll()})
  }
  function request(kind) {
    if(busy || (kind==="analyze" && (!agentAvailable || !inlineAgent || (customModel && !agentModel.trim()))) || (kind==="handoff" && !agent))return
    if(kind==="agent-info")agentAvailable=false
    if(kind==="read" || kind==="export")reportPath=""
    if(kind==="analyze") {agentAnswer="";answerModel="";answerRange=[]}
    action=kind;error="";notice="";timedOut=false
    deadline.interval=30000
    if(activity && activity.captureEnabled && kind!=="launch" && kind!=="agent-info") {
      waitingFlush=true;deadline.restart();activity.requestCaptureAction("flush")
    } else runQuery()
  }
  function runQuery() {
    waitingFlush=false;captured=""
    var argv=["/usr/bin/python3","-I",helper]
    if(action==="launch")argv=argv.concat(["--launch",runner,"--report",reportPath])
    else if(action==="agent-info")argv.push("--agent-info")
    else {
      argv=argv.concat(["--seconds",String(periodSeconds)])
      if(rangeEnd>rangeStart)argv=argv.concat(["--start",String(rangeStart),"--end",String(rangeEnd)])
      if(session)argv=argv.concat(["--session",session])
      if(action==="export")argv.push("--export")
      if(action==="analyze")argv=argv.concat(["--analyze","--question",agentQuestion || t("capture_question_default"),"--model",agentModel,"--language",language])
      if(action==="handoff")argv=argv.concat(["--handoff",selectedAgent,"--question",agentQuestion || t("capture_question_default")])
    }
    deadline.interval=action==="analyze" ? 150000 : 30000
    query.command=argv;deadline.restart();query.running=true
  }
  function cancelQuery(message) {
    deadline.stop();waitingFlush=false;timedOut=true
    error=message || ""
    if(query.running) {query.signal(15);escalation.restart()}
  }
  onPanelOpenChanged: if(!panelOpen && analyzing)cancelQuery(t("capture_agent_cancelled"))
  Connections {
    target: root.activity
    function onCaptureFlushed() { if(root.waitingFlush)root.runQuery() }
  }
  Row {
    visible:!root.agentVisible
    width: parent.width;spacing:Style.spacing.sm
    Button {
      objectName:"captureToggle"
      width:(parent.width-parent.spacing)/2
      text:root.t(root.activity && root.activity.captureWanted ? "capture_stop" : "capture_start")
      foreground:Host.Color.popups.text;accent:Host.Color.accent
      bordered:true;focusable:true
      onClicked:root.activity.setCapture(!root.activity.captureWanted)
    }
    Button {
      objectName:"captureMarker"
      width:(parent.width-parent.spacing)/2
      text:root.t("capture_marker")
      foreground:Host.Color.popups.text;accent:Host.Color.accent
      bordered:true;focusable:true
      enabled:root.activity && root.activity.captureEnabled
      onClicked:root.activity.requestCaptureAction("marker")
    }
  }
  Text {
    width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
    text:root.activity && root.activity.captureError ? root.t("diagnostic_export_failed")+" · "+root.activity.captureError
      :root.t(root.activity && root.activity.captureEnabled ? "capture_running" : "capture_idle",
        root.activity ? root.activity.captureSequence : 0,root.activity ? root.activity.captureMissed : 0)
    color:root.activity && root.activity.captureError ? Host.Color.urgent : Host.Color.popups.text
    font.family:Style.font.family;font.pixelSize:Style.font.caption
  }
  ChoiceDropdown {
    enabled:!root.busy
    width:parent.width;label:root.t("diagnostic_period");value:String(root.periodSeconds)
    options:[60,600,3600,7200,21600,86400].map(function(n){return {value:String(n),label:n<3600 ? root.t("capture_minutes",n/60) : root.t("diagnostic_hours",n/3600)}})
    foreground:Host.Color.popups.text;accent:Host.Color.accent
    onChanged:function(value){root.periodSeconds=Number(value);root.session="";root.rangeStart=0;root.rangeEnd=0}
  }
  Row {
    width:parent.width;spacing:Style.spacing.sm
    Button {
      objectName:"captureRead"
      width:(parent.width-parent.spacing)/2
      text:root.t("capture_read")
      selected:!root.agentVisible
      enabled:!root.busy;foreground:Host.Color.popups.text;accent:Host.Color.accent;bordered:true;focusable:true
      onClicked:{root.agentVisible=false;root.request("read")}
    }
    Button {
      objectName:"captureInlineAgentToggle"
      width:(parent.width-parent.spacing)/2;text:root.t("capture_inline_agent")
      selected:root.agentVisible
      foreground:Host.Color.popups.text;accent:Host.Color.accent;bordered:true;focusable:true
      enabled:!root.busy
      onClicked:{root.agentVisible=true;root.request("agent-info")}
    }
  }
  Text {
    visible:root.rangeEnd>root.rangeStart || root.session!==""
    width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
    text:root.rangeEnd>root.rangeStart ? root.t("capture_selected_range",Qt.formatDateTime(new Date(root.rangeStart*1000),"dd.MM HH:mm:ss"),Qt.formatDateTime(new Date(root.rangeEnd*1000),"HH:mm:ss")) : root.t("capture_selected_session")
    color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
  }
  Column {
    width:parent.width;spacing:Style.spacing.sm;visible:root.agentVisible
    Text {
      visible:root.busy && root.action==="agent-info"
      width:parent.width;text:root.t("capture_models_loading");textFormat:Text.PlainText
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    ChoiceDropdown {
      objectName:"captureAgentRunner"
      width:parent.width;label:root.t("capture_agent")
      value:root.selectedAgent;options:root.agents
      foreground:Host.Color.popups.text;accent:Host.Color.accent
      enabled:!root.busy && root.agents.length>0
      onChanged:function(value){root.selectedAgent=value;root.agentAnswer="";root.answerModel=""}
    }
    ChoiceDropdown {
      objectName:"captureAgentModel"
      visible:root.inlineAgent
      width:parent.width;label:root.t("capture_agent_model")
      value:root.customModel ? "__custom__" : root.agentModel
      options:root.modelOptions
      foreground:Host.Color.popups.text;accent:Host.Color.accent
      enabled:!root.busy && root.agentAvailable
      onChanged:function(value){root.chooseModel(value)}
    }
    TextField {
      id:customModelField;objectName:"captureAgentCustomModel"
      visible:root.inlineAgent && root.customModel
      width:parent.width;text:root.agentModel;maximumLength:200
      placeholderText:"provider/model";Accessible.name:root.t("capture_model_custom")
      foreground:Host.Color.popups.text;accent:Host.Color.accent
      enabled:!root.busy
      onTextEdited:root.agentModel=text
      onEditingFinished:if(root.customModel){root.agentModel=text.trim();root.agentModelSelected(root.agentModel)}
    }
    Text {
      width:parent.width;text:root.t("capture_agent_question");textFormat:Text.PlainText
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    QQC.ScrollView {
      id:questionScroll
      width:parent.width;height:Style.space(96);clip:true
      contentWidth:availableWidth
      QQC.ScrollBar.horizontal.policy:QQC.ScrollBar.AlwaysOff
      QQC.TextArea {
        id:questionField;objectName:"captureAgentQuestion"
        width:questionScroll.availableWidth
        implicitHeight:Math.max(questionScroll.availableHeight,contentHeight+topPadding+bottomPadding)
        text:root.agentQuestion;textFormat:TextEdit.PlainText;wrapMode:TextEdit.Wrap
        placeholderText:root.t("capture_question_default")
        Accessible.name:root.t("capture_agent_question")
        color:Host.Color.popups.text;placeholderTextColor:Qt.darker(Host.Color.popups.text,1.6)
        selectionColor:Style.selectionFillFor(Host.Color.popups.text,Host.Color.accent)
        selectedTextColor:Host.Color.popups.text;selectByMouse:true
        font.family:Style.font.family;font.pixelSize:Style.font.body
        leftPadding:Style.spacing.controlPaddingX;rightPadding:leftPadding
        topPadding:Style.spacing.inputPaddingY;bottomPadding:topPadding
        enabled:!root.busy
        background:BorderSurface {
          color:Style.controlFill(questionField.activeFocus,questionField.hovered,Host.Color.popups.text,Host.Color.accent)
          borderSpec:Border.controlSpec(questionField.activeFocus ? "focus" : questionField.hovered ? "hover-cursor" : "normal",Host.Color.popups.text,Host.Color.accent)
          radius:Style.cornerRadius
        }
        onTextChanged:{if(length>2000)remove(2000,length);root.agentQuestion=text}
        Keys.onPressed:function(event){
          if((event.key===Qt.Key_Return || event.key===Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier) && !root.busy && root.agent) {
            root.request(root.inlineAgent ? "analyze" : "handoff");event.accepted=true
          }
        }
      }
    }
    Text {
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      text:root.t(root.inlineAgent ? "capture_agent_notice" : "capture_terminal_hint")
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    Row {
      width:parent.width;spacing:Style.spacing.sm
      Button {
        objectName:"captureAnalyzeInline"
        width:parent.width-(agentCancel.visible ? agentCancel.width+parent.spacing : 0)
        text:root.t(root.analyzing ? "capture_agent_wait" : root.inlineAgent ? "capture_analyze_inline" : "capture_analyze")
        foreground:Host.Color.popups.text;accent:Host.Color.accent;bordered:true;focusable:true
        enabled:!root.busy && !!root.agent && (!root.inlineAgent || (root.agentAvailable && (!root.customModel || root.agentModel.trim()!=="")))
        onClicked:root.request(root.inlineAgent ? "analyze" : "handoff")
      }
      Button {
        id:agentCancel;objectName:"captureCancel"
        visible:root.busy;width:Math.max(implicitWidth,parent.width*.3)
        text:root.t("profile_cancel")
        foreground:Host.Color.popups.text;accent:Host.Color.accent;bordered:true;focusable:true
        onClicked:root.cancelQuery(root.t("capture_agent_cancelled"))
      }
    }
    Text {
      visible:root.agents.length===0 && !root.busy
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      text:root.t("capture_pi_missing")
      color:Host.Color.urgent;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    Text {
      visible:root.answerModel!==""
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      text:root.modelLabel(root.answerModel)+(root.answerRange.length===2 ? " · "+Qt.formatDateTime(new Date(root.answerRange[0]*1000),"dd.MM HH:mm:ss")+" – "+Qt.formatDateTime(new Date(root.answerRange[1]*1000),"dd.MM HH:mm:ss") : "")
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    TextEdit {
      objectName:"captureAgentAnswer"
      visible:root.agentAnswer!==""
      width:parent.width;height:contentHeight
      text:root.agentAnswer;textFormat:TextEdit.PlainText;wrapMode:TextEdit.Wrap
      readOnly:true;selectByMouse:true;activeFocusOnTab:true
      color:Host.Color.popups.text;selectionColor:Host.Color.accent
      font.family:Style.font.family;font.pixelSize:Style.font.body
      Accessible.name:root.t("capture_inline_agent")
    }
    Button {
      visible:root.agentAnswer!==""
      width:parent.width;text:root.t("capture_copy_answer")
      foreground:Host.Color.popups.text;accent:Host.Color.accent;bordered:true;focusable:true
      onClicked:Quickshell.clipboardText=root.agentAnswer
    }
    Button {
      width:parent.width;text:root.t("capture_agent_details")
      selected:root.agentDetailsVisible
      iconText:root.agentDetailsVisible ? "▾" : "▸"
      foreground:Host.Color.popups.text;accent:Host.Color.accent;focusable:true
      onClicked:root.agentDetailsVisible=!root.agentDetailsVisible
    }
    Text {
      visible:root.agentDetailsVisible
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      text:root.inlineAgent ? root.t("capture_inline_hint")+"\n"+root.t("capture_models_hint") : root.t("capture_terminal_hint")
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
  }
  Text {
    visible:root.notice!==""
    width:parent.width;text:root.notice;wrapMode:Text.WordWrap;textFormat:Text.PlainText
    color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
  }
  Text {
    visible:root.error!==""
    width:parent.width;text:root.error
    wrapMode:Text.WrapAnywhere;textFormat:Text.PlainText
    color:Host.Color.urgent;font.family:Style.font.family;font.pixelSize:Style.font.caption
  }
  Button {
    visible:root.busy && !root.agentVisible
    width:parent.width;text:root.t("profile_cancel")
    foreground:Host.Color.popups.text;accent:Host.Color.accent;bordered:true;focusable:true
    onClicked:root.cancelQuery(root.t("capture_agent_cancelled"))
  }
  Column {
    visible:!root.agentVisible
    width:parent.width;spacing:Style.spacing.md
    ChoiceDropdown {
      visible:root.series.length>0
      width:parent.width;label:root.t("capture_signal")
      value:root.sensor ? root.sensor.id : ""
      options:root.series.map(function(s){return {value:s.id,label:s.label+" · "+s.unit}})
      foreground:Host.Color.popups.text;accent:Host.Color.accent
      onChanged:function(value){root.selectedSeries=value}
    }
    Text {
      visible:root.report.records!==undefined
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      text:root.t("capture_coverage",root.report.records || 0,(root.report.gaps || []).length)
        +"\n"+root.t("capture_limits",root.report.invalid_records || 0,root.report.omitted_by_capacity || 0)
        +(root.report.available_range && root.report.available_range[0]!==null ? "\n"+Qt.formatDateTime(new Date(root.report.available_range[0]*1000),"dd.MM HH:mm:ss")+" – "+Qt.formatDateTime(new Date(root.report.available_range[1]*1000),"dd.MM HH:mm:ss") : "")
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    SensorHistoryChart {
      id:thermalPlot;objectName:"captureThermalPlot"
      subsecond:true
      visible:root.sensor!==null
      width:parent.width;height:Style.space(150)
      points:root.sensor ? root.sensor.points : []
      unit:root.sensor ? root.sensor.unit : "°C"
      ceiling:root.sensor && root.sensor.unit==="°C" ? 100 : 0
      windowSeconds:root.report.requested_range ? root.report.requested_range[1]-root.report.requested_range[0] : root.periodSeconds
      referenceTime:root.report.requested_range ? root.report.requested_range[1] : 0
      hint:root.sensor ? root.sensor.label : "";emptyText:root.t("chart_empty")
      gapText:root.t("chart_gap");liveText:root.t("chart_live")
      onSelectedTimeChanged: {
        if(cpuPlot.points.length && selectedTime>=0) {
          var nearest=0
          cpuPlot.points.forEach(function(p,i){if(Math.abs(p.time-selectedTime)<Math.abs(cpuPlot.points[nearest].time-selectedTime))nearest=i})
          cpuPlot.selectIndex(nearest)
        } else cpuPlot.clearSelection()
      }
    }
    SensorHistoryChart {
      id:cpuPlot;objectName:"captureCpuPlot"
      subsecond:true
      visible:root.cpu!==null && root.sensor!==root.cpu
      width:parent.width;height:Style.space(130)
      points:root.cpu ? root.cpu.points : [];unit:"%";ceiling:100
      windowSeconds:root.report.requested_range ? root.report.requested_range[1]-root.report.requested_range[0] : root.periodSeconds
      referenceTime:root.report.requested_range ? root.report.requested_range[1] : 0
      hint:"CPU";emptyText:root.t("chart_empty");gapText:root.t("chart_gap");liveText:root.t("chart_live")
    }
    Button {
      objectName:"captureZoom"
      visible:root.sensor!==null
      width:parent.width;text:root.t("capture_zoom")
      enabled:root.cursorTime>0 && !root.busy
      foreground:Host.Color.popups.text;accent:Host.Color.accent;bordered:true;focusable:true
      onClicked:{root.rangeStart=root.cursorTime-30;root.rangeEnd=root.cursorTime+30;root.request("read")}
    }
    Text {
      visible:(root.report.events || []).length>0
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      text:(root.report.events || []).slice(-6).map(function(e){return Qt.formatDateTime(new Date(e.time*1000),"HH:mm:ss")+" · "+(e.type==="marker" ? root.t("capture_marker") : e.reason || e.type)}).join("\n")
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    Text {
      objectName:"captureProcessWindow"
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      visible:root.report.records>0
      text:root.processFrame ? root.t("capture_process_at",Qt.formatDateTime(new Date(root.processFrame.time*1000),"HH:mm:ss"))
        +"\n"+root.processFrame.processes.map(function(p){return p.name+" · PID "+p.pid+" · "+(p.cpu===null ? "—" : Number(p.cpu).toFixed(1)+"%")}).join("\n")
        :root.t("capture_no_process")
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
  }
  Button {
    objectName:"captureDetailsToggle"
    width:parent.width;text:root.t("capture_details")
    selected:root.detailsVisible
    iconText:root.detailsVisible ? "▾" : "▸"
    foreground:Host.Color.popups.text;accent:Host.Color.accent;focusable:true
    onClicked:root.detailsVisible=!root.detailsVisible
  }
  Column {
    width:parent.width;spacing:Style.spacing.md;visible:root.detailsVisible
    ChoiceDropdown {
      objectName:"captureInterval"
      width:parent.width;label:root.t("capture_interval")
      value:String(root.activity ? root.activity.captureInterval : 500)
      options:[1000,500,250].map(function(n){return {value:String(n),label:n+" ms"}})
      foreground:Host.Color.popups.text;accent:Host.Color.accent
      onChanged:function(value){if(root.activity)root.activity.setCaptureInterval(Number(value))}
    }
    Text {
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      text:root.t("capture_hint")
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    ChoiceDropdown {
      width:parent.width;label:root.t("capture_session");value:root.session;enabled:!root.busy
      options:[{value:"",label:root.t("capture_all_sessions")}].concat((root.report.sessions || []).map(function(s){
        return {value:s.id,label:Qt.formatDateTime(new Date(s.start*1000),"dd.MM HH:mm:ss")}
      }))
      foreground:Host.Color.popups.text;accent:Host.Color.accent
      onChanged:function(value){root.session=value}
    }
    Button {
      objectName:"captureExport"
      width:parent.width;text:root.t("diagnostic_export")
      enabled:!root.busy;foreground:Host.Color.popups.text;accent:Host.Color.accent;bordered:true;focusable:true
      onClicked:root.request("export")
    }
    Text {
      visible:root.reportPath!==""
      width:parent.width;text:root.reportPath;wrapMode:Text.WrapAnywhere;textFormat:Text.PlainText
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    ChoiceDropdown {
      visible:root.reportPath!==""
      width:parent.width;label:root.t("capture_agent");value:root.runner
      options:[{value:"omarchy",label:"Omarchy"}].concat(root.agents)
      foreground:Host.Color.popups.text;accent:Host.Color.accent
      onChanged:function(value){root.runner=value}
    }
    Text {
      visible:root.reportPath!==""
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      text:root.t("capture_agent_hint")
      color:Host.Color.popups.text;font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    Row {
      visible:root.reportPath!==""
      width:parent.width;spacing:Style.spacing.sm
      Button {
        objectName:"captureAgentLaunch"
        width:(parent.width-parent.spacing)/2
        text:root.t("capture_analyze")
        enabled:!root.busy;foreground:Host.Color.popups.text;accent:Host.Color.accent;bordered:true;focusable:true
        onClicked:root.request("launch")
      }
      Button {
        width:(parent.width-parent.spacing)/2
        text:root.t("diagnostic_copy_prompt")
        foreground:Host.Color.popups.text;accent:Host.Color.accent;bordered:true;focusable:true
        onClicked:Quickshell.clipboardText=I18n.t("diagnostic_prompt",root.language,root.reportPath)
      }
    }
  }
  Process {
    id:query
    stdout:SplitParser {
      onRead:function(line) {
        if(root.captured.length+line.length>2*1024*1024) {root.error=root.t("diagnostic_export_failed");root.timedOut=true;query.signal(9);return}
        root.captured+=line
      }
    }
    onExited:function(code) {
      deadline.stop();escalation.stop()
      if(root.timedOut)return
      try {
        var result=JSON.parse(root.captured)
        if(code!==0 || result.error) {
          root.error=root.t(root.action==="analyze" ? "capture_agent_failed" : "diagnostic_export_failed")
            +(typeof result.error==="string" ? " · "+result.error.slice(0,500) : "")
          return
        }
        if(root.action==="agent-info") {
          if(!Array.isArray(result.models) || result.models.length>256)throw new Error("models")
          if(!Array.isArray(result.agents) || result.agents.length>64)throw new Error("agents")
          root.agents=result.agents
          if(!root.agents.some(function(a){return a.value===root.selectedAgent}))root.selectedAgent=root.agents.length ? root.agents[0].value : ""
          root.agentAvailable=result.available===true
          root.agentModels=result.models
          root.defaultAgentModel=[result.provider,result.model].filter(function(v){return !!v}).join("/")
          root.customModel=root.agentModel!=="" && !root.agentModels.some(function(m){return m.value===root.agentModel})
          if(result.model_error)root.error=String(result.model_error).slice(0,500)
        } else if(root.action==="analyze") {
          if(typeof result.answer!=="string" || result.answer.length>65536)throw new Error("answer")
          root.agentAnswer=result.answer;root.answerModel=String(result.model || "Pi")
          root.answerRange=result.range || []
        } else if(root.action==="export" || root.action==="handoff") {
          if(typeof result.path!=="string" || result.path[0]!=="/")throw new Error("path")
          root.reportPath=result.path
          if(root.action==="handoff") {
            Quickshell.clipboardText=I18n.t("diagnostic_prompt",root.language,result.path)+"\n"+root.agentQuestion
            root.notice=root.t("capture_handed_off")
          }
        } else if(root.action==="read") {
          if(result.schema!==2 || !Array.isArray(result.series) || result.series.length>128)throw new Error("schema")
          root.report=result
        }
      } catch(e){root.error=root.t("diagnostic_export_failed")}
    }
  }
  Timer {
    id:deadline;interval:30000
    onTriggered:root.cancelQuery(root.t(root.action==="analyze" ? "capture_agent_failed" : "diagnostic_export_failed"))
  }
  Timer {id:escalation;interval:3000;onTriggered:if(query.running)query.signal(9)}
  Component.onDestruction:{deadline.stop();escalation.stop();if(query.running)query.signal(15)}
}
