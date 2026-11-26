import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Io
import qs.Commons
import qs.Commons as Host
import qs.Ui
import "ProfileCodec.js" as ProfileCodec
import "Model.js" as Model

Column {
  id: root
  function t(key, a, b, c) { return locale ? locale.t(key, a, b, c) : key }
  property var settings: ({})
  property bool active: visible
  property var channels: []
  property bool fanBusy: false
  readonly property var writableFans: channels.filter(Model.fanChannelWritable)
  readonly property var boardFans: {
    var discovered = writableFans.filter(function(channel) { return !Model.isGpuFan(channel) })
    return discovered.length ? discovered : [2,3,4,5].map(function(n) {
      var id = "pwm" + n
      return {id:id, legacyId:id, backend:"it8613", label:id, minPercent:0, maxPercent:100}
    })
  }
  readonly property var gpuFans: writableFans.filter(Model.isGpuFan)
  function fanLabel(channel) {
    return Model.isGpuFan(channel)
      ? (channel.owner || root.t("gpu")) + " · " + channel.label
      : channel.label || channel.id
  }
  function oldGpuKey(channel) {
    if (channel.backend !== "nvidia") return ""
    return channel.id.split(".")[1].replace(/^(\w{4})_(\w{2})_(\w{2})_(\w)$/, "$1:$2:$3.$4")
  }
  function gpuFanValue(values, channel) {
    return values[channel.id] === undefined ? values[oldGpuKey(channel)] : values[channel.id]
  }
  function saveFanValuesValid(values, gpu) {
    var keys = Object.keys(values)
    if (keys.length > (gpu ? 8 : 16)) return false
    var candidates = gpu ? gpuFans : boardFans
    return keys.every(function(id) {
      var value = values[id]
      var matching = candidates.filter(function(channel) {
        return channel.id === id || (gpu && oldGpuKey(channel) === id)
      })
      return Number.isInteger(value) && value >= 0 && value <= 100
        && matching.every(function(channel) { return Model.fanPercentAllowed(channel, value) })
    })
  }
  readonly property var supportedGovernors: ["powersave", "performance", "schedutil", "ondemand", "conservative"]
  readonly property var governors: {
    var reported = cpuCapabilities.governors || cpuCapabilities.availableGovernors
    var list = []
    if (Array.isArray(reported)) {
      list = reported
    } else {
      var lists = (cpuCapabilities.policies || []).map(function(policy) {
        return String(policy.scaling_available_governors || "").split(/\s+/).filter(Boolean)
      }).filter(function(items) { return items.length > 0 })
      if (lists.length) {
        list = lists[0].filter(function(governor) {
          return lists.every(function(items) { return items.indexOf(governor) >= 0 })
        })
      }
    }
    return list.filter(function(governor) { return supportedGovernors.indexOf(governor) >= 0 })
  }
  readonly property var platformProfiles: {
    var values = cpuCapabilities.platformProfiles || cpuCapabilities.platformProfileChoices
    return Array.isArray(values) ? values.filter(function(value) { return value !== "custom" }) : []
  }
  function cpuChoices(values) {
    return [{value:"",label:root.t("profile_unchanged")}].concat(values.map(function(value) {
      return {value:value,label:value}
    }))
  }
  property var locale: null
  function number(value) { return locale ? locale.number(value) : Host.I18n.formatNumber(value) }
  LayoutMirroring.enabled: locale ? locale.rightToLeft : Host.I18n.rightToLeft
  LayoutMirroring.childrenInherit: true
  property string language: locale ? locale.language : "en"
  property color foreground: Host.Color.popups.text
  property color accent: Host.Color.accent
  property bool editorOpen: false
  onEditorOpenChanged: if(!editorOpen) Qt.callLater(function(){if(root.visible && !root.editorOpen)editProfileButton.forceActiveFocus()})
  property Item editorHost: null
  property string selectedId: "idle"
  property var draft: ({})
  readonly property var iconOptions: [
    {value:"quiet",label:"profile_icon_moon"},
    {value:"games",label:"profile_icon_gamepad"},
    {value:"fans",label:"fans"},
    {value:"cpu",label:"cpu"},
    {value:"gpu",label:"gpu"},
    {value:"category",label:"profile_icon_tag"}
  ]
  property bool deletePending: false
  property bool invalidCpuLimit: false
  property bool automationOptionsOpen: false
  readonly property var selectedProfile: profiles.filter(function(p) { return p.id===root.selectedId })[0] || profiles[0]
  readonly property string activeId: automatic.error ? "" : automatic.enabled ? (automatic.gaming ? "games" : automaticBaseId) : settings.activePowerProfile || ""
  readonly property string activeName: (profiles.filter(function(p) { return p.id===root.activeId })[0] || {}).name || root.t("profile_manual")
  function summary(profile) {
    if (!profile) return ""
    var cpu=profile.config.cpu, values=[]
    if (typeof cpu.boost === "boolean") values.push(root.t(cpu.boost ? "profile_turbo_on" : "profile_turbo_off"))
    if (cpu.governor) values.push(cpu.governor)
    if (cpu.platformProfile) values.push(cpu.platformProfile)
    if (cpu.maxMHz) values.push(root.number(cpu.maxMHz)+" MHz")
    Object.keys(profile.config.fans).forEach(function(id) {
      var channel = root.boardFans.find(function(item) { return item.id === id }) || {id:id}
      var place = Model.fanSetting(root.settings, "Place", channel, "unknown")
      values.push((place && place!=="unknown" ? root.t("map_"+place) : id)+" "+root.number(profile.config.fans[id])+"%")
    })
    Object.keys(profile.config.gpuFans).forEach(function(id) {
      var channel = root.gpuFans.find(function(item) { return item.id === id || root.oldGpuKey(item) === id })
      values.push((channel ? root.fanLabel(channel) : id) + " " + root.number(profile.config.gpuFans[id]) + "%")
    })
    return values.join(" · ") || root.t("profile_unchanged")
  }
  property var cpuCapabilities: ({policies:[]})
  property bool capabilitiesReady: false
  property int statusExitCode: -1
  property bool statusExpired: false
  property var pendingCapabilities: null
  property bool statusSuperseded: false
  function clearCapabilities() {
    pendingCapabilities = null
    capabilitiesReady = false
    cpuCapabilities = {policies:[],automatic:{enabled:false,gaming:null,error:"status_unavailable"}}
  }
  function finishStatus() {
    if (statusExpired || statusSuperseded || statusExitCode !== 0 || !pendingCapabilities) return
    cpuCapabilities = pendingCapabilities
    capabilitiesReady = true
    if (editorOpen && !draft.id) selectProfile(selectedId)
  }
  property string statusKey: ""
  property string pendingId: ""
  property string pendingPayload: ""
  property string operation: "apply"
  readonly property var automatic: cpuCapabilities.automatic || ({enabled:false,gaming:false,error:""})
  readonly property string automaticBaseId: {
    var id=settings.autoGameBaseProfile || (settings.activePowerProfile!=="games" ? settings.activePowerProfile : "idle")
    return (profiles.filter(function(p){return p.id===id && p.id!=="games"})[0]
      || profiles.filter(function(p){return p.id==="idle"})[0] || profiles.filter(function(p){return p.id!=="games"})[0] || {}).id || ""
  }
  property string pendingBaseId: ""
  property bool operationExpired: false
  readonly property bool running: applyProcess.running
  readonly property bool busy: running
  readonly property bool mutationBlocked: busy || fanBusy
  readonly property var profiles: {
    try {
      var saved=JSON.parse(String(settings.powerProfiles || "[]"))
      if (Array.isArray(saved) && saved.length && saved.length<=12
          && saved.every(function(p){return p && typeof p.id==="string" && /^[A-Za-z0-9_-]{1,64}$/.test(p.id)
            && typeof p.name==="string" && p.name.length<=40 && p.config && p.config.cpu
            && p.config.fans && p.config.gpuFans})) return saved
    } catch(error) {}
    var fans={}
    var currentGpuFans = {}
    writableFans.forEach(function(channel) {
      var output = Model.fanSetting(settings, "Output", channel, -1)
      if (Model.isGpuFan(channel)) {
        if (Model.fanPercentAllowed(channel, output)) currentGpuFans[channel.id] = output
      } else {
        var speed = Model.fanPercentAllowed(channel, output) ? output : channel.percent
        if (Model.fanPercentAllowed(channel, speed)) fans[channel.id] = speed
      }
    })
    var cpu={}
    if (cpuCapabilities.boost !== null && cpuCapabilities.boost !== undefined) cpu.boost=cpuCapabilities.boost==="1"
    else if (cpuCapabilities.noTurbo !== null && cpuCapabilities.noTurbo !== undefined) cpu.boost=cpuCapabilities.noTurbo==="0"
    if (typeof cpuCapabilities.platformProfile === "string"
        && platformProfiles.indexOf(cpuCapabilities.platformProfile) >= 0)
      cpu.platformProfile = cpuCapabilities.platformProfile
    if (cpuCapabilities.policies && cpuCapabilities.policies.length) {
      var policy=cpuCapabilities.policies[0]
      cpu.governor=policy.scaling_governor || ""
      cpu.epp=policy.energy_performance_preference || ""
      cpu.maxMHz=Math.floor(Number(policy.scaling_max_freq || 0)/1000)
    }
    return [
      {id:"current",name:root.t("profile_current"),icon:"fans",config:{fans:fans,cpu:cpu,gpuFans:currentGpuFans}},
      {id:"idle",name:root.t("profile_idle"),icon:"quiet",config:{fans:fans,cpu:{boost:false,governor:"powersave",epp:"power",maxMHz:0},gpuFans:{}}},
      {id:"games",name:root.t("profile_games"),icon:"games",config:{fans:fans,cpu:{boost:true,governor:"performance",epp:"performance",maxMHz:0},gpuFans:{}}}
    ]
  }
  signal saveSettings(var values)
  signal applied()
  spacing: Style.spacing.sm
  component SvgButton: Button {
    id: button
    property string iconName: ""
    iconText: iconName ? "\u2003" : ""
    Accessible.role: Accessible.Button
    Accessible.name: text || tooltipText
    SvgIcon {
      id: glyph
      name: button.iconName
      width: button.iconSize; height: width
      anchors.centerIn: parent
      tint: button.selected ? button._selectedColor : button.foreground
      Component.onCompleted: {
        for (var row of button.children) for (var item of (row.children || []))
          if (item.text === "\u2003") { glyph.parent=item; return }
      }
    }
  }

  function selectProfile(id) {
    var profile=profiles.filter(function(p){return p.id===id})[0] || profiles[0]
    if (!profile) return
    selectedId=profile.id
    draft=JSON.parse(JSON.stringify(profile))
    deletePending=false;invalidCpuLimit=false
  }
  function beginEdit() {
    if (running || !selectedProfile) return
    selectProfile(selectedProfile.id)
    statusKey="";editorOpen=true
  }
  function newProfile(source) {
    if (running || profiles.length>=12 || !source) return
    var copy=JSON.parse(JSON.stringify(source))
    copy.id="custom-"+Date.now();copy.name=root.t("profile_new")
    draft=copy;deletePending=false;invalidCpuLimit=false
    statusKey="";editorOpen=true
  }
  function cancelEdit() {
    selectProfile(selectedId)
    editorOpen=false
    if (statusKey==="profile_invalid") statusKey=""
  }
  function changeIcon(value) {
    if (!iconOptions.some(function(option){return option.value===value})) return
    draft=Object.assign({},draft,{icon:value})
  }
  function changeCpu(key,value) {
    var next=JSON.parse(JSON.stringify(draft))
    next.config.cpu[key]=value
    draft=next
  }
  function changeGovernor(governor) {
    var next = JSON.parse(JSON.stringify(draft))
    var epp = governor === "powersave" ? "power" : governor === "performance" ? "performance" : ""
    var policies = cpuCapabilities.policies || []
    var supported = epp && policies.length && policies.every(function(policy) {
      return String(policy.energy_performance_available_preferences || "").split(/\s+/).indexOf(epp) >= 0
    })
    next.config.cpu.governor = governor
    next.config.cpu.epp = supported ? epp : ""
    draft = next
  }
  function changeFan(id, text, gpu) {
    var next = JSON.parse(JSON.stringify(draft))
    var values = gpu ? next.config.gpuFans : next.config.fans
    var channel = gpu ? gpuFans.find(function(item) { return item.id === id }) : null
    var oldKey = channel ? oldGpuKey(channel) : ""
    if (oldKey && values[oldKey] !== undefined) {
      gpuFans.filter(function(item) { return root.oldGpuKey(item) === oldKey }).forEach(function(item) {
        if (values[item.id] === undefined) values[item.id] = values[oldKey]
      })
      delete values[oldKey]
    }
    if (text === "") delete values[id]
    else values[id] = Number(text)
    draft = next
  }
  function saveDraft() {
    if (!draft.id || !draft.name || !String(draft.name).trim()) { statusKey="profile_invalid";return false }
    if (invalidCpuLimit || !Number.isInteger(draft.config.cpu.maxMHz || 0) || draft.config.cpu.maxMHz<0 || draft.config.cpu.maxMHz>10000) { statusKey="profile_invalid";return false }
    if (!saveFanValuesValid(draft.config.fans, false) || !saveFanValuesValid(draft.config.gpuFans, true)) { statusKey="profile_invalid";return false }
    var list=profiles.slice()
    var index=list.findIndex(function(p){return p.id===draft.id})
    if (index<0 && list.length>=12) return false
    if (index<0) list.push(JSON.parse(JSON.stringify(draft)))
    else list[index]=JSON.parse(JSON.stringify(draft))
    var change={powerProfiles:JSON.stringify(list)}
    if(settings.activePowerProfile===draft.id
        && (index<0 || JSON.stringify(profiles[index].config)!==JSON.stringify(draft.config)))change.activePowerProfile=""
    saveSettings(change)
    selectedId=draft.id
    statusKey="profile_saved"
    return true
  }
  function applyProfile(profile) {
    if (mutationBlocked || !profile) return
    pendingId=profile.id
    pendingPayload=ProfileCodec.encode(profile.config)
    operation="apply";statusKey="profile_pending";applyProcess.running=true
  }
  function reconcileDirectFan() {
    if (statusProcess.running) statusSuperseded = true
    pendingCapabilities = null
    cpuCapabilities = Object.assign({}, cpuCapabilities, {automatic:{enabled:false,gaming:false,error:""}})
    statusKey = ""
  }
  function refreshStatus() {
    if (active && !fanBusy && !statusProcess.running) {
      statusSuperseded = false
      statusDeadline.restart()
      statusProcess.running = true
    }
  }
  onActiveChanged: if(active)refreshStatus()
  Component.onCompleted: {
    selectProfile(settings.activePowerProfile || selectedId)
    refreshStatus()
  }
  Component.onDestruction: {
    deadline.stop();statusDeadline.stop()
    if (applyProcess.running) applyProcess.signal(15)
    if (statusProcess.running) statusProcess.signal(9)
  }
  Process {
    id: statusProcess
    command:["/usr/local/lib/loadlet/power-profile","status"]
    onStarted:{root.statusExitCode=-1;root.statusExpired=false;root.pendingCapabilities=null}
    onExited:function(code){
      statusDeadline.stop();root.statusExitCode=code
      if (root.statusSuperseded) { Qt.callLater(root.refreshStatus); return }
      if(code!==0 || root.statusExpired)root.clearCapabilities()
      else root.finishStatus()
    }
    stdout:StdioCollector { waitForEnd:true; onStreamFinished:{
      if(root.statusExpired || root.statusSuperseded)return
      try {
        if(text.length>=65536)throw new Error("Status exceeds budget")
        var value=JSON.parse(text)
        if(!value || !Array.isArray(value.policies))throw new Error("Invalid status")
        root.pendingCapabilities=value
        root.finishStatus()
      }catch(error){root.clearCapabilities()}
    } }
  }
  Process {
    id: applyProcess
    command:root.operation==="restore" || root.operation==="auto-off"
      ? ["/usr/local/lib/loadlet/power-profile","request",root.operation]
      : ["/usr/local/lib/loadlet/power-profile","request",root.operation,root.pendingPayload]
    onStarted:{root.operationExpired=false;deadline.restart()}
    onExited:function(code){
      deadline.stop()
      if(root.operationExpired){root.statusKey="profile_failed";return}
      root.statusKey=code===0 ? "profile_applied" : "profile_failed"
      if(code===0){
        root.statusKey=root.operation==="auto-off" ? "profile_auto_stopped" : root.operation==="auto-config" ? "profile_auto_started" : "profile_applied"
        if(root.operation==="apply" || root.operation==="restore")root.saveSettings({activePowerProfile:root.operation==="restore"?"":root.pendingId,autoGameProfiles:false})
        else root.saveSettings(root.operation==="auto-config" ? {autoGameProfiles:true,autoGameBaseProfile:root.pendingBaseId} : {autoGameProfiles:false,activePowerProfile:root.automaticBaseId})
        root.applied();root.refreshStatus()
      }
    }
  }
  Timer {
    interval:5000;repeat:true;running:root.active
    onTriggered:root.refreshStatus()
  }
  Timer { id:statusDeadline;interval:5000;onTriggered:{root.statusExpired=true;root.statusExitCode=1;if(!root.statusSuperseded)root.clearCapabilities();statusProcess.signal(9)} }
  Timer { id:deadline;interval:360000;onTriggered:{root.operationExpired=true;applyProcess.signal(15);root.statusKey="profile_failed"} }

  Text {
    objectName:"activeProfileLabel"
    width:parent.width
    text:root.t(root.automatic.error ? "profile_auto_error" : "profile_active",root.activeName)
    textFormat:Text.PlainText;wrapMode:Text.Wrap
    color:root.automatic.error ? Host.Color.urgent : root.foreground
    font.family:Style.font.family;font.pixelSize:Style.font.bodySmall;font.bold:true
  }
  ChoiceDropdown {
    objectName:"powerProfileDropdown"
    width:parent.width;visible:!root.editorOpen
    label:root.t("profile_choose")
    value:root.selectedProfile ? root.selectedProfile.id : ""
    options:root.profiles.map(function(p){return {value:p.id,label:p.name}})
    onChanged:function(id){root.selectProfile(id)}
  }
  Text {
    objectName:"profileSummary"
    width:parent.width;visible:!root.editorOpen
    text:root.summary(root.selectedProfile)
    textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
    font.family:Style.font.family;font.pixelSize:Style.font.caption
  }
  Row {
    width:parent.width;spacing:Style.spacing.sm;visible:!root.editorOpen
    SvgButton {
      objectName:"applyPowerProfileButton"
      width:(parent.width-parent.spacing)/2
      text:root.t("profile_apply");iconName:"check"
      foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
      bordered:true;focusable:true;enabled:!root.mutationBlocked && root.capabilitiesReady
      onClicked:root.applyProfile(root.selectedProfile)
    }
    SvgButton {
      id:editProfileButton
      objectName:"profileEditorToggle"
      width:(parent.width-parent.spacing)/2
      text:root.t("profile_edit_short");iconName:"edit"
      foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
      bordered:true;focusable:true;enabled:!root.running
      onClicked:root.beginEdit()
    }
  }
  SvgButton {
    objectName:"newPowerProfileButton"
    width:parent.width;visible:!root.editorOpen
    text:root.t("profile_new");iconName:"edit"
    foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
    bordered:true;focusable:true;enabled:!root.running && root.profiles.length<12
    onClicked:root.newProfile(root.selectedProfile)
  }
  SvgButton {
    objectName:"automationOptionsToggle"
    width:parent.width;visible:!root.editorOpen
    text:root.t("profile_auto_games");iconName:"games"
    foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
    bordered:true;focusable:true;selected:root.automationOptionsOpen || root.automatic.enabled
    onClicked:root.automationOptionsOpen=!root.automationOptionsOpen
  }
  Toggle {
    objectName:"autoGameProfilesToggle"
    visible:!root.editorOpen && (root.automationOptionsOpen || root.automatic.enabled)
    width:parent.width
    label:root.t("profile_auto_games")
    description:root.t(root.automatic.error ? "profile_auto_error" : root.automatic.gaming ? "profile_auto_playing" : "profile_auto_hint")
    checked:root.automatic.enabled
    enabled:!root.mutationBlocked && root.capabilitiesReady
    foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
    onClicked:{
      if (root.mutationBlocked) return
      if(root.automatic.enabled){root.operation="auto-off"}
      else {
        var game=root.profiles.filter(function(p){return p.id==="games"})[0]
        var base=root.profiles.filter(function(p){return p.id===root.automaticBaseId && p.id!=="games"})[0]
          ||root.profiles.filter(function(p){return p.id==="idle"})[0]
        if(!game || !base){root.statusKey="profile_failed";return}
        root.pendingBaseId=base.id
        root.pendingPayload=ProfileCodec.encode({game:game.config,base:base.config})
        root.operation="auto-config"
      }
      root.statusKey="profile_pending";applyProcess.running=true
    }
  }
  ChoiceDropdown {
    objectName:"automaticBaseProfile"
    width:parent.width;visible:!root.editorOpen && (root.automationOptionsOpen || root.automatic.enabled)
    label:root.t("profile_auto_base")
    value:root.automaticBaseId
    options:root.profiles.filter(function(p){return p.id!=="games"}).map(function(p){return {value:p.id,label:p.name}})
    enabled:!root.running && !root.automatic.enabled
    onChanged:function(id){root.saveSettings({autoGameBaseProfile:id})}
  }
  Text {
    width:parent.width;visible:root.statusKey!==""
    text:root.t(root.statusKey);textFormat:Text.PlainText;wrapMode:Text.Wrap
    color:root.statusKey==="profile_failed" || root.statusKey==="profile_invalid" ? Host.Color.urgent:root.foreground
    font.family:Style.font.family;font.pixelSize:Style.font.caption
  }
  SvgButton {
    objectName:"restorePowerProfileButton"
    width:parent.width;visible:!root.editorOpen
    text:root.t("profile_restore");iconName:"restore"
    foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
    bordered:true;focusable:true;enabled:!root.mutationBlocked
    onClicked:{
      if (root.mutationBlocked) return
      root.operation="restore";root.statusKey="profile_pending";applyProcess.running=true
    }
  }

  component SectionHeading: Row {
    property string label: ""
    property string iconName: ""
    width:parent.width;spacing:Style.spacing.sm
    SvgIcon { name:parent.iconName; tint:root.foreground; anchors.verticalCenter:parent.verticalCenter }
    Text {
      width:parent.width-Style.space(16)-parent.spacing
      text:parent.label;textFormat:Text.PlainText;wrapMode:Text.Wrap
      color:root.foreground;font.family:Style.font.family;font.pixelSize:Style.font.bodySmall;font.bold:true
    }
  }

  Item {
    id: editorPage
    objectName:"powerProfileEditorPage"
    LayoutMirroring.enabled: root.locale ? root.locale.rightToLeft : Host.I18n.rightToLeft
    LayoutMirroring.childrenInherit: true
    parent:root.editorHost || root
    visible:root.editorOpen && root.editorHost!==null
    width:parent.width;height:parent.height
    enabled:!root.running
    Keys.onEscapePressed:root.cancelEdit()
    onVisibleChanged:if(visible) {
      editorViewport.contentY=0
      Qt.callLater(function(){if(editorPage.visible)profileName.forceActiveFocus()})
    }
    Flickable {
      id:editorViewport
      objectName:"profileEditorViewport"
      anchors.top:parent.top;anchors.left:parent.left;anchors.right:parent.right
      anchors.bottom:editorFooter.top;anchors.bottomMargin:Style.spacing.sm
      contentWidth:width;contentHeight:editorBody.implicitHeight
      clip:true;boundsBehavior:Flickable.StopAtBounds
      onContentHeightChanged:contentY=Math.max(0,Math.min(contentY,contentHeight-height))
      ScrollBar.vertical:ScrollBar {
        objectName:"profileEditorScrollBar"
        parent:editorPage
        anchors.top:editorViewport.top;anchors.bottom:editorViewport.bottom
        anchors.left:editorViewport.right;anchors.leftMargin:Style.spacing.xs
        width:Style.space(4);padding:0;policy:ScrollBar.AlwaysOn;visible:size<1
        contentItem:Rectangle { implicitWidth:Style.space(4);implicitHeight:Style.space(40);color:root.accent;opacity:0.65 }
        background:null
      }
      Connections {
        target:editorViewport.Window.window
        function onActiveFocusItemChanged() {
          var window=editorViewport.Window.window
          if(!window || !editorPage.visible)return
          var item=window.activeFocusItem,ancestor=item
          while(ancestor && ancestor!==editorViewport.contentItem)ancestor=ancestor.parent
          if(!ancestor)return
          var top=item.mapToItem(editorViewport.contentItem,0,0).y
          if(top<editorViewport.contentY)editorViewport.contentY=Math.max(0,top)
          else if(top+item.height>editorViewport.contentY+editorViewport.height)
            editorViewport.contentY=Math.max(0,Math.min(editorViewport.contentHeight-editorViewport.height,top+item.height-editorViewport.height))
        }
      }
      Column {
        id:editorBody
        objectName:"profileEditorBody"
        width:editorViewport.width
        spacing:Style.spacing.sm
        Text {
          width:parent.width;text:root.t("profile_editor_hint")
          textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
          font.family:Style.font.family;font.pixelSize:Style.font.caption
        }
        Text {
          width:parent.width;text:root.t("profile_name")
          textFormat:Text.PlainText;color:root.foreground
          font.family:Style.font.family;font.pixelSize:Style.font.caption
        }
        TextField {
          id:profileName
          objectName:"powerProfileName"
          width:parent.width;height:Style.spacing.controlHeight
          text:root.draft.name || "";maximumLength:40
          Accessible.name:root.t("profile_name")
          onTextEdited:{var next=Object.assign({},root.draft);next.name=text;root.draft=next}
        }
        Text {
          width:parent.width;text:root.t("profile_icon")
          textFormat:Text.PlainText;color:root.foreground
          font.family:Style.font.family;font.pixelSize:Style.font.caption
        }
        Grid {
          id:iconPicker
          objectName:"profileIconPicker"
          width:parent.width;columns:width>=Style.space(550) ? 3 : 2
          spacing:Style.spacing.xs
          Repeater {
            model:root.iconOptions
            SvgButton {
              required property var modelData
              objectName:"profileIcon-"+modelData.value
              width:(iconPicker.width-iconPicker.spacing*(iconPicker.columns-1))/iconPicker.columns
              iconName:modelData.value;text:root.t(modelData.label)
              selected:(root.draft.icon || "fans")===modelData.value
              foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
              fontSize:Style.font.caption;focusable:true;bordered:true
              Accessible.role:Accessible.RadioButton
              Accessible.checkable:true;Accessible.checked:selected
              onClicked:root.changeIcon(modelData.value)
            }
          }
        }
        SectionHeading { label:root.t("cpu");iconName:"cpu" }
        Toggle {
          objectName:"profileBoostToggle"
          width:parent.width
          visible:root.cpuCapabilities.boost!==null && root.cpuCapabilities.boost!==undefined
            || root.cpuCapabilities.noTurbo!==null && root.cpuCapabilities.noTurbo!==undefined
          label:root.t("profile_boost")
          checked:!!(root.draft.config && root.draft.config.cpu.boost)
          foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
          onClicked:root.changeCpu("boost",!checked)
        }
        ChoiceDropdown {
          objectName:"profileCpuMode"
          width:parent.width
          label:root.t("profile_cpu_mode")
          value:root.draft.config ? root.draft.config.cpu.governor || "" : ""
          options:root.cpuChoices(root.governors)
          onChanged:function(mode){root.changeGovernor(mode)}
        }
        ChoiceDropdown {
          objectName:"profilePlatformProfile"
          width:parent.width
          visible:root.platformProfiles.length > 0
          label:root.t("profile_platform")
          value:root.draft.config ? root.draft.config.cpu.platformProfile || "" : ""
          options:root.cpuChoices(root.platformProfiles)
          onChanged:function(mode) { root.changeCpu("platformProfile",mode) }
        }
        Text {
          width:parent.width;text:root.t("profile_max_mhz")
          textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
          font.family:Style.font.family;font.pixelSize:Style.font.caption
        }
        TextField {
          objectName:"profileMaxMhz"
          width:parent.width;height:Style.spacing.controlHeight
          text:String(root.draft.config ? root.draft.config.cpu.maxMHz || 0 : 0)
          validator:IntValidator{locale:Qt.locale("C").name;bottom:0;top:10000}
          Accessible.name:root.t("profile_max_mhz")
          onTextEdited:{
            root.invalidCpuLimit = !acceptableInput || !/^\d+$/.test(text)
            if (!root.invalidCpuLimit) root.changeCpu("maxMHz",Number(text))
          }
        }
        SectionHeading { label:root.t("sensors");iconName:"fans" }
        Repeater {
          model:root.boardFans
          Column {
            required property var modelData
            width:parent.width;spacing:Style.spacing.xs
            Text {
              width:parent.width
              text:root.fanLabel(modelData) + " · " + root.t("map_" + Model.fanSetting(root.settings, "Place", modelData, "unknown"))
                + " · " + root.t("fan_driver_range", root.number(modelData.minPercent), root.number(modelData.maxPercent))
              textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
              font.family:Style.font.family;font.pixelSize:Style.font.caption
            }
            TextField {
              width:parent.width;height:Style.spacing.controlHeight
              text:root.draft.config && root.draft.config.fans[modelData.id]!==undefined ? String(root.draft.config.fans[modelData.id]) : ""
              placeholderText:root.t("profile_unchanged")
              validator:IntValidator{locale:Qt.locale("C").name;bottom:modelData.minPercent;top:modelData.maxPercent}
              Accessible.name:root.fanLabel(modelData)+" %"
              onTextEdited:root.changeFan(modelData.id,text,false)
            }
          }
        }
        Repeater {
          model:root.gpuFans
          Column {
            required property var modelData
            width:parent.width;spacing:Style.spacing.xs
            Text {
              width:parent.width
              text:root.fanLabel(modelData) + " · " + root.t("fan_driver_range", root.number(modelData.minPercent), root.number(modelData.maxPercent))
              textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
              font.family:Style.font.family;font.pixelSize:Style.font.caption
            }
            TextField {
              width:parent.width;height:Style.spacing.controlHeight
              readonly property var output: root.draft.config ? root.gpuFanValue(root.draft.config.gpuFans, modelData) : undefined
              text:output === undefined ? "" : String(output)
              placeholderText:root.t("profile_gpu_auto")
              validator:IntValidator{locale:Qt.locale("C").name;bottom:modelData.minPercent;top:modelData.maxPercent}
              Accessible.name:root.fanLabel(modelData)+" %"
              onTextEdited:root.changeFan(modelData.id,text,true)
            }
          }
        }
        Text {
          width:parent.width
          visible:root.automatic.enabled && (root.draft.id==="games" || root.draft.id===root.automaticBaseId)
          text:root.t("profile_auto_edit_hint")
          textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
          font.family:Style.font.family;font.pixelSize:Style.font.caption
        }
        Text {
          width:parent.width;text:root.t("profile_hint")
          textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
          font.family:Style.font.family;font.pixelSize:Style.font.caption
        }
        Flow {
          width:parent.width;spacing:Style.spacing.xs
          SvgButton {
            objectName:"duplicatePowerProfileButton"
            text:root.t("profile_duplicate");iconName:"copy"
            width:Math.min(implicitWidth,parent.width)
            foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
            bordered:true;focusable:true;enabled:root.profiles.length<12
            onClicked:{root.newProfile(root.draft);editorViewport.contentY=0;profileName.forceActiveFocus()}
          }
          SvgButton {
            objectName:"deletePowerProfileButton"
            text:root.t(root.deletePending ? "profile_delete_confirm" : "profile_delete");iconName:"trash"
            width:Math.min(implicitWidth,parent.width)
            foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
            bordered:true;focusable:true
            visible:root.profiles.some(function(p){return p.id===root.draft.id})
            enabled:!root.running && root.profiles.length>1 && root.settings.activePowerProfile!==root.draft.id
              && !(root.automatic.enabled && (root.draft.id==="games" || root.draft.id===root.automaticBaseId))
            onClicked:{
              if(!root.deletePending){root.deletePending=true;return}
              var remaining=root.profiles.filter(function(p){return p.id!==root.draft.id})
              root.saveSettings({powerProfiles:JSON.stringify(remaining)})
              root.selectProfile(remaining[0].id);root.editorOpen=false
            }
          }
        }
      }
    }
    Column {
      id:editorFooter
      width:parent.width;anchors.bottom:parent.bottom;spacing:Style.spacing.xs
      Text {
        objectName:"profileEditorStatus"
        width:parent.width;visible:root.statusKey!==""
        text:root.t(root.statusKey);textFormat:Text.PlainText;wrapMode:Text.Wrap
        color:root.statusKey==="profile_invalid" || root.statusKey==="profile_failed" ? Host.Color.urgent : root.foreground
        font.family:Style.font.family;font.pixelSize:Style.font.caption
      }
      Row {
        width:parent.width;spacing:Style.spacing.sm
        SvgButton {
          objectName:"cancelPowerProfileButton"
          width:(parent.width-parent.spacing)/2
          text:root.t("profile_cancel");iconName:"close"
          foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
          bordered:true;focusable:true;onClicked:root.cancelEdit()
        }
        SvgButton {
          objectName:"savePowerProfileButton"
          width:(parent.width-parent.spacing)/2
          text:root.t("profile_save");iconName:"save"
          foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
          bordered:true;focusable:true;onClicked:if(root.saveDraft())root.editorOpen=false
        }
      }
    }
  }
}
