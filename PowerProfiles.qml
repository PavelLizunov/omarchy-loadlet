import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Commons as Host
import qs.Ui
import "I18n.js" as I18n

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
  property var cpuCapabilities: ({policies:[]})
  property string statusKey: ""
  property string pendingId: ""
  property string pendingPayload: ""
  property string operation: "apply"
  readonly property bool running: applyProcess.running
  readonly property var profiles: {
    try {
      var saved=JSON.parse(String(settings.powerProfiles || "[]"))
      if (Array.isArray(saved) && saved.length) return saved
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
  component SvgButton: Button {
    id: button
    property string iconName: ""
    iconText: iconName ? "\u2003" : ""
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
    if (!draft.id || !draft.name || !String(draft.name).trim()) return
    if (Object.values(draft.config.fans).concat(Object.values(draft.config.gpuFans)).some(function(value){return !Number.isInteger(value)||value<0||value>100})) return
    var list=profiles.slice()
    var index=list.findIndex(function(p){return p.id===draft.id})
    if (index<0 && list.length>=12) return
    if (index<0) list.push(JSON.parse(JSON.stringify(draft)))
    else list[index]=JSON.parse(JSON.stringify(draft))
    var change={powerProfiles:JSON.stringify(list)}
    if(settings.activePowerProfile===draft.id)change.activePowerProfile=""
    saveSettings(change)
    statusKey="profile_saved"
  }
  function applyProfile(profile) {
    if (running) return
    pendingId=profile.id
    pendingPayload=String(Qt.btoa(Array.from(JSON.stringify(profile.config),function(c){return c.charCodeAt(0)}))).replace(/\+/g,"-").replace(/\//g,"_")
    operation="apply";statusKey="profile_pending";applyProcess.running=true
  }
  Component.onCompleted: {
    selectProfile(selectedId)
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
        if(text.length<65536)root.cpuCapabilities=JSON.parse(text)
        if(root.editorOpen && !root.draft.id)root.selectProfile(root.selectedId)
      }catch(error){}
    } }
  }
  Process {
    id: applyProcess
    command:root.operation==="restore"
      ? ["/usr/local/lib/loadlet/power-profile","request","restore"]
      : ["/usr/local/lib/loadlet/power-profile","request","apply",root.pendingPayload]
    onStarted:deadline.restart()
    onExited:function(code){
      deadline.stop()
      root.statusKey=code===0 ? "profile_applied" : "profile_failed"
      if(code===0){root.saveSettings({activePowerProfile:root.operation==="restore"?"":root.pendingId});root.applied()}
    }
  }
  Timer { id:statusDeadline;interval:5000;onTriggered:statusProcess.signal(9) }
  Timer { id:deadline;interval:150000;onTriggered:{applyProcess.signal(15);root.statusKey="profile_failed"} }

  Flow {
    width:parent.width
    spacing:Style.spacing.xs
    Repeater {
      model:root.profiles
      SvgButton {
        required property var modelData
        objectName:"powerProfile-"+modelData.id
        width:Math.min(Math.max(Style.space(100),(parent.width-Style.space(36)-parent.spacing*3)/3),Math.max(Style.space(100),implicitWidth))
        height:Style.spacing.controlHeight
        text:modelData.name
        iconName:modelData.icon || "fans"
        selected:root.settings.activePowerProfile===modelData.id
        foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
        bordered:true;focusable:true;enabled:!root.running
        onClicked:root.applyProfile(modelData)
      }
    }
    SvgButton {
      objectName:"profileEditorToggle"
      width:Style.space(36);height:Style.spacing.controlHeight
      text:"";iconName:"settings";tooltipText:I18n.t("profile_edit",root.language)
      foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
      bordered:true;focusable:true;selected:root.editorOpen
      onClicked:{root.editorOpen=!root.editorOpen;if(root.editorOpen)root.selectProfile(root.selectedId)}
    }
  }
  Text {
    width:parent.width;visible:root.statusKey!==""
    text:I18n.t(root.statusKey,root.language);textFormat:Text.PlainText;wrapMode:Text.Wrap
    color:root.statusKey==="profile_failed"?Host.Color.urgent:root.foreground
    font.family:Style.font.family;font.pixelSize:Style.font.caption
  }
  Column {
    width:parent.width
    visible:root.editorOpen && !!root.draft.config
    spacing:Style.spacing.sm
    ChoiceDropdown {
      objectName:"powerProfileDropdown"
      width:parent.width
      label:I18n.t("profile_edit",root.language)
      value:root.selectedId
      options:root.profiles.map(function(p){return {value:p.id,label:p.name}})
      onChanged:function(id){root.selectProfile(id)}
    }
    Row {
      width:parent.width;spacing:Style.spacing.sm
      TextField {
        objectName:"powerProfileName"
        width:(parent.width-parent.spacing)/2;height:Style.spacing.controlHeight
        text:root.draft.name || "";maximumLength:40
        Accessible.name:I18n.t("profile_name",root.language)
        onTextEdited:{var next=Object.assign({},root.draft);next.name=text;root.draft=next}
      }
      ChoiceDropdown {
        width:(parent.width-parent.spacing)/2;showLabel:false
        value:root.draft.icon || "fans"
        options:[{value:"quiet",label:I18n.t("profile_idle",root.language)},{value:"games",label:I18n.t("profile_games",root.language)},{value:"fans",label:I18n.t("fans",root.language)}]
        onChanged:function(icon){var next=Object.assign({},root.draft);next.icon=icon;root.draft=next}
      }
    }
    Toggle {
      objectName:"profileBoostToggle"
      width:parent.width
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
      onTextEdited:if(acceptableInput)root.changeCpu("maxMHz",Number(text))
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
          onTextEdited:if(acceptableInput || text==="")root.changeFan(modelData.id,text,false)
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
          onTextEdited:if(acceptableInput || text==="")root.changeFan(modelData.id,text,true)
        }
      }
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
        text:I18n.t("profile_delete",root.language);iconName:"close"
        foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
        bordered:true;focusable:true
        enabled:root.profiles.length>1 && root.settings.activePowerProfile!==root.selectedId
        onClicked:{
          var remaining=root.profiles.filter(function(p){return p.id!==root.selectedId})
          root.saveSettings({powerProfiles:JSON.stringify(remaining)})
          root.selectProfile(remaining[0].id)
        }
      }
      SvgButton {
        objectName:"savePowerProfileButton"
        text:I18n.t("profile_save",root.language);iconName:"check"
        foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
        bordered:true;focusable:true;onClicked:root.saveDraft()
      }
      SvgButton {
        objectName:"newPowerProfileButton"
        text:I18n.t("profile_new",root.language);iconName:"copy"
        foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
        bordered:true;focusable:true
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
