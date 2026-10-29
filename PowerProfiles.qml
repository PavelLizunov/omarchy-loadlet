import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Commons as Host
import qs.Ui
import "I18n.js" as I18n
import "ProfileCodec.js" as ProfileCodec

Column {
  id: root
  property var settings: ({})
  property var channels: []
  property var gpus: []
  property string language: "ru"
  property color foreground: Host.Color.popups.text
  property color accent: Host.Color.accent
  property bool editorOpen: false
  property string selectedId: "idle"
  property var draft: ({})
  property bool deletePending: false
  property bool invalidCpuLimit: false
  property bool automationOptionsOpen: false
  readonly property var selectedProfile: profiles.filter(function(p) { return p.id===root.selectedId })[0] || profiles[0]
  readonly property string activeId: automatic.enabled ? (automatic.error ? "" : automatic.gaming ? "games" : automaticBaseId) : settings.activePowerProfile || ""
  readonly property string activeName: (profiles.filter(function(p) { return p.id===root.activeId })[0] || {}).name || I18n.t("profile_manual",language)
  function summary(profile) {
    if (!profile) return ""
    var cpu=profile.config.cpu, values=[]
    if (typeof cpu.boost === "boolean") values.push(I18n.t(cpu.boost ? "profile_turbo_on" : "profile_turbo_off",language))
    if (cpu.governor) values.push(cpu.governor)
    if (cpu.maxMHz) values.push(cpu.maxMHz+" MHz")
    Object.keys(profile.config.fans).forEach(function(id) {
      var place=root.settings["fanPlace_"+id]
      values.push((place && place!=="unknown" ? I18n.t("map_"+place,root.language) : id)+" "+profile.config.fans[id]+"%")
    })
    Object.keys(profile.config.gpuFans).forEach(function(id) { values.push("GPU "+profile.config.gpuFans[id]+"%") })
    return values.join(" · ") || I18n.t("profile_unchanged",language)
  }
  property var cpuCapabilities: ({policies:[]})
  property bool capabilitiesReady: false
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
  readonly property var profiles: {
    try {
      var saved=JSON.parse(String(settings.powerProfiles || "[]"))
      if (Array.isArray(saved) && saved.length && saved.length<=12
          && saved.every(function(p){return p && typeof p.id==="string" && /^[A-Za-z0-9_-]{1,64}$/.test(p.id)
            && typeof p.name==="string" && p.name.length<=40 && p.config && p.config.cpu
            && p.config.fans && p.config.gpuFans})) return saved
    } catch(error) {}
    var fans={}
    channels.forEach(function(channel){
      var output=settings["fanOutput_"+channel.id]
      fans[channel.id]=typeof output==="number" && output>=0 ? output : Math.round(channel.duty/255*100)
    })
    var cpu={}
    if (cpuCapabilities.boost !== null && cpuCapabilities.boost !== undefined) cpu.boost=cpuCapabilities.boost==="1"
    else if (cpuCapabilities.noTurbo !== null && cpuCapabilities.noTurbo !== undefined) cpu.boost=cpuCapabilities.noTurbo==="0"
    if (cpuCapabilities.policies && cpuCapabilities.policies.length) {
      var policy=cpuCapabilities.policies[0]
      cpu.governor=policy.scaling_governor || ""
      cpu.epp=policy.energy_performance_preference || ""
      cpu.maxMHz=Math.floor(Number(policy.scaling_max_freq || 0)/1000)
    }
    return [
      {id:"current",name:I18n.t("profile_current",language),icon:"fans",config:{fans:fans,cpu:cpu,gpuFans:{}}},
      {id:"idle",name:I18n.t("profile_idle",language),icon:"quiet",config:{fans:fans,cpu:{boost:false,governor:"powersave",epp:"power",maxMHz:0},gpuFans:{}}},
      {id:"games",name:I18n.t("profile_games",language),icon:"games",config:{fans:fans,cpu:{boost:true,governor:"performance",epp:"performance",maxMHz:0},gpuFans:{}}}
    ]
  }
  signal saveSettings(var values)
  signal applied()
  spacing: Style.spacing.sm
  Keys.onEscapePressed: function(event) {
    if (editorOpen && !running) { selectProfile(selectedId);editorOpen=false }
    else event.accepted=false
  }
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
  function changeCpu(key,value) {
    var next=JSON.parse(JSON.stringify(draft))
    next.config.cpu[key]=value
    draft=next
  }
  function changeFan(id,text,gpu) {
    var next=JSON.parse(JSON.stringify(draft))
    var values=gpu ? next.config.gpuFans : next.config.fans
    if (text==="") delete values[id]
    else values[id]=Number(text)
    draft=next
  }
  function saveDraft() {
    if (!draft.id || !draft.name || !String(draft.name).trim()) { statusKey="profile_invalid";return false }
    if (invalidCpuLimit || !Number.isInteger(draft.config.cpu.maxMHz || 0) || draft.config.cpu.maxMHz<0 || draft.config.cpu.maxMHz>10000) { statusKey="profile_invalid";return false }
    if (Object.values(draft.config.fans).concat(Object.values(draft.config.gpuFans)).some(function(value){return !Number.isInteger(value)||value<0||value>100})) { statusKey="profile_invalid";return false }
    var list=profiles.slice()
    var index=list.findIndex(function(p){return p.id===draft.id})
    if (index<0 && list.length>=12) return false
    if (index<0) list.push(JSON.parse(JSON.stringify(draft)))
    else list[index]=JSON.parse(JSON.stringify(draft))
    var change={powerProfiles:JSON.stringify(list)}
    if(settings.activePowerProfile===draft.id)change.activePowerProfile=""
    saveSettings(change)
    statusKey="profile_saved"
    return true
  }
  function applyProfile(profile) {
    if (running) return
    pendingId=profile.id
    pendingPayload=ProfileCodec.encode(profile.config)
    operation="apply";statusKey="profile_pending";applyProcess.running=true
  }
  Component.onCompleted: {
    selectProfile(settings.activePowerProfile || selectedId)
    statusDeadline.restart();statusProcess.running=true
  }
  Component.onDestruction: {
    deadline.stop();statusDeadline.stop()
    if (applyProcess.running) applyProcess.signal(15)
    if (statusProcess.running) statusProcess.signal(9)
  }
  Process {
    id: statusProcess
    command:["/usr/local/lib/loadlet/power-profile","status"]
    onExited:statusDeadline.stop()
    stdout:StdioCollector { waitForEnd:true; onStreamFinished:{
      try {
        if(text.length<65536){
          var value=JSON.parse(text)
          if(!value || !Array.isArray(value.policies))return
          root.cpuCapabilities=value;root.capabilitiesReady=true
        }
        if(root.editorOpen && !root.draft.id)root.selectProfile(root.selectedId)
      }catch(error){}
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
        root.applied();statusDeadline.restart();statusProcess.running=true
      }
    }
  }
  Timer {
    interval:5000;repeat:true;running:root.visible
    onTriggered:if(!statusProcess.running){statusDeadline.restart();statusProcess.running=true}
  }
  Timer { id:statusDeadline;interval:5000;onTriggered:statusProcess.signal(9) }
  Timer { id:deadline;interval:360000;onTriggered:{root.operationExpired=true;applyProcess.signal(15);root.statusKey="profile_failed"} }

  Text {
    objectName:"activeProfileLabel"
    width:parent.width
    text:I18n.t(root.automatic.error ? "profile_auto_error" : "profile_active",root.language,root.activeName)
    textFormat:Text.PlainText;wrapMode:Text.Wrap
    color:root.automatic.error ? Host.Color.urgent : root.foreground
    font.family:Style.font.family;font.pixelSize:Style.font.bodySmall;font.bold:true
  }
  ChoiceDropdown {
    objectName:"powerProfileDropdown"
    width:parent.width;visible:!root.editorOpen
    label:I18n.t("profile_choose",root.language)
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
      text:I18n.t("profile_apply",root.language);iconName:"check"
      foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
      bordered:true;focusable:true;enabled:!root.running && root.capabilitiesReady
      onClicked:root.applyProfile(root.selectedProfile)
    }
    SvgButton {
      objectName:"profileEditorToggle"
      width:(parent.width-parent.spacing)/2
      text:I18n.t("profile_edit_short",root.language);iconName:"edit"
      foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
      bordered:true;focusable:true;enabled:!root.running
      onClicked:{root.selectProfile(root.selectedProfile.id);root.editorOpen=true}
    }
  }
  SvgButton {
    objectName:"automationOptionsToggle"
    width:parent.width;visible:!root.editorOpen
    text:I18n.t("profile_auto_games",root.language);iconName:"games"
    foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
    bordered:true;focusable:true;selected:root.automationOptionsOpen || root.automatic.enabled
    onClicked:root.automationOptionsOpen=!root.automationOptionsOpen
  }
  Toggle {
    objectName:"autoGameProfilesToggle"
    visible:!root.editorOpen && (root.automationOptionsOpen || root.automatic.enabled)
    width:parent.width
    label:I18n.t("profile_auto_games",root.language)
    description:I18n.t(root.automatic.error ? "profile_auto_error" : root.automatic.gaming ? "profile_auto_playing" : "profile_auto_hint",root.language)
    checked:root.automatic.enabled
    enabled:!root.running && root.capabilitiesReady
    foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
    onClicked:{
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
    label:I18n.t("profile_auto_base",root.language)
    value:root.automaticBaseId
    options:root.profiles.filter(function(p){return p.id!=="games"}).map(function(p){return {value:p.id,label:p.name}})
    enabled:!root.running && !root.automatic.enabled
    onChanged:function(id){root.saveSettings({autoGameBaseProfile:id})}
  }
  Text {
    width:parent.width;visible:root.statusKey!==""
    text:I18n.t(root.statusKey,root.language);textFormat:Text.PlainText;wrapMode:Text.Wrap
    color:root.statusKey==="profile_failed" || root.statusKey==="profile_invalid" ? Host.Color.urgent:root.foreground
    font.family:Style.font.family;font.pixelSize:Style.font.caption
  }
  Column {
    width:parent.width
    visible:root.editorOpen && !!root.draft.config
    spacing:Style.spacing.sm
    enabled:!root.running
    Text {
      width:parent.width
      text:I18n.t("profile_edit",root.language)+" · "+(root.draft.name || "")
      textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
      font.family:Style.font.family;font.pixelSize:Style.font.body;font.bold:true
    }
    Row {
      width:parent.width;spacing:Style.spacing.xs
      SvgButton {
        objectName:"saveApplyPowerProfileButton"
        width:(parent.width-parent.spacing)/2
        text:I18n.t("profile_save_apply",root.language);iconName:"check"
        foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
        bordered:true;focusable:true;enabled:root.capabilitiesReady
        onClicked:if(root.saveDraft()){root.applyProfile(root.draft);root.editorOpen=false}
      }
      SvgButton {
        objectName:"cancelPowerProfileButton"
        width:(parent.width-parent.spacing)/2
        text:I18n.t("profile_cancel",root.language);iconName:"close"
        foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
        bordered:true;focusable:true
        onClicked:{root.selectProfile(root.selectedId);root.editorOpen=false}
      }
    }
    Text {
      width:parent.width;text:I18n.t("profile_name",root.language)
      textFormat:Text.PlainText;color:root.foreground
      font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    TextField {
      objectName:"powerProfileName"
      width:parent.width;height:Style.spacing.controlHeight
      text:root.draft.name || "";maximumLength:40
      Accessible.name:I18n.t("profile_name",root.language)
      onTextEdited:{var next=Object.assign({},root.draft);next.name=text;root.draft=next}
    }
    Toggle {
      objectName:"profileBoostToggle"
      width:parent.width
      visible:root.cpuCapabilities.boost!==null && root.cpuCapabilities.boost!==undefined
        || root.cpuCapabilities.noTurbo!==null && root.cpuCapabilities.noTurbo!==undefined
      label:I18n.t("profile_boost",root.language)
      checked:!!(root.draft.config && root.draft.config.cpu.boost)
      foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
      onClicked:root.changeCpu("boost",!checked)
    }
    ChoiceDropdown {
      objectName:"profileCpuMode"
      width:parent.width
      label:I18n.t("profile_cpu_mode",root.language)
      value:root.draft.config ? root.draft.config.cpu.governor || "" : ""
      options:[{value:"",label:I18n.t("profile_unchanged",root.language)},
        {value:"powersave",label:I18n.t("profile_idle",root.language)},
        {value:"performance",label:I18n.t("profile_games",root.language)}]
      onChanged:function(mode){root.changeCpu("governor",mode);root.changeCpu("epp",mode==="powersave"?"power":mode==="performance"?"performance":"")}
    }
    Text {
      width:parent.width;text:I18n.t("profile_max_mhz",root.language)
      textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
      font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    TextField {
      objectName:"profileMaxMhz"
      width:parent.width;height:Style.spacing.controlHeight
      text:String(root.draft.config ? root.draft.config.cpu.maxMHz || 0 : 0)
      validator:IntValidator{bottom:0;top:10000}
      Accessible.name:I18n.t("profile_max_mhz",root.language)
      onTextEdited:{root.invalidCpuLimit=!acceptableInput;if(acceptableInput)root.changeCpu("maxMHz",Number(text))}
    }
    Repeater {
      model:root.channels
      Row {
        required property var modelData
        width:parent.width;spacing:Style.spacing.sm
        Text {
          width:parent.width/2;height:Style.spacing.controlHeight
          text:modelData.id+" · "+I18n.t("map_"+(root.settings["fanPlace_"+modelData.id]||"unknown"),root.language)+" %"
          textFormat:Text.PlainText;color:root.foreground;elide:Text.ElideRight
          font.family:Style.font.family;font.pixelSize:Style.font.caption
        }
        TextField {
          width:parent.width/2-parent.spacing;height:Style.spacing.controlHeight
          text:root.draft.config && root.draft.config.fans[modelData.id]!==undefined ? String(root.draft.config.fans[modelData.id]) : ""
          validator:IntValidator{bottom:0;top:100}
          Accessible.name:modelData.id+" %"
          onTextEdited:root.changeFan(modelData.id,text,false)
        }
      }
    }
    Repeater {
      model:root.gpus.filter(function(g){return g.vendor==="NVIDIA" || String(g.name).indexOf("NVIDIA")>=0})
      Column {
        required property var modelData
        width:parent.width;spacing:Style.spacing.xs
        Text {
          width:parent.width;text:modelData.name+" · "+I18n.t("profile_gpu_fan",root.language)
          textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
          font.family:Style.font.family;font.pixelSize:Style.font.caption
        }
        TextField {
          width:parent.width;height:Style.spacing.controlHeight
          text:root.draft.config && root.draft.config.gpuFans[modelData.id]!==undefined ? String(root.draft.config.gpuFans[modelData.id]) : ""
          placeholderText:I18n.t("profile_gpu_auto",root.language)
          validator:IntValidator{bottom:0;top:100}
          Accessible.name:modelData.name+" %"
          onTextEdited:root.changeFan(modelData.id,text,true)
        }
      }
    }
    Text {
      width:parent.width
      visible:root.automatic.enabled && (root.selectedId==="games" || root.selectedId===root.automaticBaseId)
      text:I18n.t("profile_auto_edit_hint",root.language)
      textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
      font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    Text {
      width:parent.width;text:I18n.t("profile_hint",root.language)
      textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.foreground
      font.family:Style.font.family;font.pixelSize:Style.font.caption
    }
    Flow {
      width:parent.width;spacing:Style.spacing.xs
      SvgButton {
        objectName:"deletePowerProfileButton"
        text:I18n.t(root.deletePending ? "profile_delete_confirm" : "profile_delete",root.language);iconName:"trash"
        foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
        bordered:true;focusable:true
        enabled:!root.running && root.profiles.length>1 && root.settings.activePowerProfile!==root.selectedId
          && !(root.automatic.enabled && (root.selectedId==="games" || root.selectedId===root.automaticBaseId))
        onClicked:{
          if(!root.deletePending){root.deletePending=true;return}
          var remaining=root.profiles.filter(function(p){return p.id!==root.selectedId})
          root.saveSettings({powerProfiles:JSON.stringify(remaining)})
          root.selectProfile(remaining[0].id);root.editorOpen=false
        }
      }
      SvgButton {
        objectName:"savePowerProfileButton"
        text:I18n.t("profile_save",root.language);iconName:"save"
        foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
        bordered:true;focusable:true;onClicked:if(root.saveDraft())root.editorOpen=false
      }
      SvgButton {
        objectName:"newPowerProfileButton"
        text:I18n.t("profile_duplicate",root.language);iconName:"copy"
        foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
        bordered:true;focusable:true;enabled:root.profiles.length<12
        onClicked:{
          var copy=JSON.parse(JSON.stringify(root.draft))
          copy.id="custom-"+Date.now();copy.name=I18n.t("profile_new",root.language)
          root.selectedId=copy.id;root.draft=copy
        }
      }
      SvgButton {
        objectName:"restorePowerProfileButton"
        text:I18n.t("profile_restore",root.language);iconName:"restore"
        foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
        bordered:true;focusable:true;enabled:!root.running
        onClicked:{root.operation="restore";root.statusKey="profile_pending";applyProcess.running=true}
      }
    }
  }
}
