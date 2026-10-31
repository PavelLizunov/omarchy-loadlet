import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Host
import qs.Ui
import "MemoryWatch.js" as Watch
import "Model.js" as Model

// One explicit one-hour session; samples come from the existing native reader.
Column {
  id: root
  objectName: "memoryWatch"
  property var locale: null
  property bool running: false
  property var frames: []
  property bool interrupted: false
  property bool notificationsEnabled: true
  property bool notificationError: false
  property bool eventsExpanded: false
  readonly property alias eventsControl: eventsButton
  property var events: []
  property var notificationQueue: []
  property string stateKey: "memory_watch_idle"
  property string selectedKey: ""
  property string systemField: "used"
  property string processField: "anon"
  property double clock: Date.now() / 1000
  readonly property var latest: frames.length ? frames[frames.length-1] : null
  readonly property bool stale: !!latest && (clock < latest.time || clock-latest.time > 75)
  readonly property var rows: Watch.summaries(frames)
  readonly property var leaders: rows.slice(0,10)
  readonly property var selected: rows.find(function(row) { return row.key === root.selectedKey }) || null
  readonly property var systemPoints: Watch.series(frames, systemField, "")
  readonly property var processPoints: selected ? Watch.series(frames, processField, selected.key) : []
  spacing: Style.spacing.sm

  function t(key,a,b,c) { return locale ? locale.t(key,a,b,c) : key }
  function bytes(kib) { return typeof kib === "number" && isFinite(kib) && kib >= 0
    ? Model.formatBytes(kib*1024,"",function(v,d) { return root.locale ? root.locale.number(v,d) : v.toFixed(d) }) : "—" }
  function delta(kib) { return kib === null || kib === undefined ? "—" : (kib < 0 ? "−" : "+") + bytes(Math.abs(kib)) }
  function begin() {
    frames = []; selectedKey = ""; interrupted = false; stateKey = "memory_watch_running"
    events = []; eventsExpanded = false; notificationQueue = []; notificationError = false
    clock = Date.now()/1000
    sessionLimit.restart()
    running = true
  }
  function stop(key) {
    running = false; sessionLimit.stop(); notificationQueue = []
    stateKey = key || "memory_watch_stopped"
  }
  function observe(raw) {
    if (!running) return
    var next = Watch.parse(raw)
    if (!next) { interrupted = true; stateKey = "memory_watch_unavailable"; return }
    frames = Watch.append(frames,next,interrupted)
    interrupted = false; clock = Date.now()/1000; stateKey = "memory_watch_running"
    if (!selectedKey && leaders.length) selectedKey = leaders[0].key
    recordEvents(next)
  }
  function interrupt() { if (running) { interrupted = true; stateKey = "memory_watch_unavailable" } }
  function copyReport() {
    var report = Watch.report(frames,rows,selectedKey,events)
    if (report.length > 524288) { stateKey = "memory_watch_report_large"; return }
    Quickshell.clipboardText = report
  }
  function recordEvents(frame) {
    var seen = events.map(function(event) { return event.process.key })
    var found = Watch.summaries(frames).filter(function(row) { return row.candidate && seen.indexOf(row.key) < 0 })
      .slice(0,Math.max(0,20-events.length)).map(function(row) {
        return {time:frame.time, process:row, system:frame.system, pressure:frame.pressure, coverage:frame.coverage}
      })
    if (!found.length) return
    events = events.concat(found)
    if (notificationsEnabled) {
      notificationQueue = notificationQueue.concat(found).slice(0,20)
      sendNotification()
    }
  }
  function eventText(event) {
    var p = event.process
    return t("memory_watch_event",p.name + " · PID " + p.pid,delta(p.growth),locale ? locale.duration(p.span) : String(Math.round(p.span)) + " s")
  }
  function sendNotification() {
    if (!running || !notificationsEnabled || notifier.running || notificationCooldown.running || !notificationQueue.length) return
    var batch = notificationQueue
    notificationQueue = []
    var body = batch.slice(0,3).map(function(event) { return root.eventText(event) }).join("\n")
    if (batch.length > 3) body += "\n" + t("memory_watch_more_events",batch.length-3)
    body += "\n" + t("memory_watch_notification_hint")
    // The desktop notification body supports markup; process names are plain data.
    body = body.replace(/[\x00-\x08\x0b-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/g," ")
      .replace(/&/g,"＆").replace(/</g,"‹").replace(/>/g,"›").slice(0,4000)
    notifier.command = ["/usr/bin/timeout","--kill-after=1s","5s",
      "/usr/share/omarchy/bin/omarchy-notification-send","--app-name","Loadlet","-u","normal","-t","10000",
      "Loadlet · " + t("memory_watch_notification_title"),body,
      "--exec","/usr/share/omarchy/bin/omarchy-shell","slovn.activity-lite.status","memory"]
    notificationCooldown.restart()
    notificationError = false
    notifier.running = true
  }
  onNotificationsEnabledChanged: if (!notificationsEnabled) notificationQueue = []
  Process {
    id: notifier
    onExited: function(code) { root.notificationError = code !== 0 }
  }
  Component.onDestruction: if (notifier.running) notifier.signal(15)
  Timer { id: notificationCooldown; interval: 60000; onTriggered: root.sendNotification() }
  Timer { id: sessionLimit; interval: 3600000; onTriggered: root.stop("memory_watch_finished") }
  Timer { interval: 5000; running: root.visible && root.frames.length > 0; repeat: true; onTriggered: root.clock = Date.now()/1000 }

  Row {
    width: parent.width; spacing: Style.spacing.sm
    SvgIcon { name: "ram"; tint: Host.Color.popups.text }
    Text {
      width: parent.width - Style.space(16) - parent.spacing
      text: root.t("memory_watch_title")
      textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Host.Color.popups.text
      font.family: Style.font.family; font.pixelSize: Style.font.heading
    }
  }
  Text {
    width: parent.width; text: root.t("memory_watch_intro")
    textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Host.Color.popups.text
    font.family: Style.font.family; font.pixelSize: Style.font.caption
  }
  Toggle {
    objectName: "memoryWatchNotifications"
    width: parent.width
    label: root.t("memory_watch_notifications")
    description: root.t("memory_watch_notifications_hint")
    checked: root.notificationsEnabled
    foreground: Host.Color.popups.text; accent: Host.Color.accent
    Accessible.role: Accessible.CheckBox; Accessible.name: label; Accessible.checked: checked
    onClicked: root.notificationsEnabled = !root.notificationsEnabled
  }
  Text {
    width: parent.width; visible: root.notificationError
    text: root.t("memory_watch_notification_failed")
    textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Host.Color.popups.text
    font.family: Style.font.family; font.pixelSize: Style.font.caption
  }
  Button {
    id: eventsButton
    objectName: "memoryWatchEvents"
    width: parent.width
    text: root.t("memory_watch_events",root.events.length)
    selected: root.eventsExpanded; focusable: true; leftAlign: true
    foreground: Host.Color.popups.text; accent: Host.Color.accent
    Accessible.role: Accessible.Button; Accessible.name: text
    onClicked: root.eventsExpanded = !root.eventsExpanded
  }
  Column {
    width: parent.width; visible: root.eventsExpanded; spacing: Style.spacing.sm
    Text {
      width: parent.width; text: root.t(root.events.length >= 20 ? "memory_watch_events_full" : "memory_watch_events_hint")
      textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Host.Color.popups.text
      font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    Repeater {
      model: root.events.length
      Text {
        required property int index
        readonly property var event: root.events[root.events.length-1-index]
        width: parent.width
        text: event ? (root.locale ? root.locale.dateTime(event.time,false,false) : "") + "\n" + root.eventText(event)
          + "\n" + root.t("memory_watch_event_context",root.bytes(event.system.MemAvailable),
            event.pressure.some === null ? "—" : (root.locale ? root.locale.number(event.pressure.some,2) : String(event.pressure.some))) : ""
        textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Host.Color.popups.text
        font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
      }
    }
  }
  Text {
    width: parent.width
    text: root.t(root.running && root.stale ? "memory_watch_unavailable" : root.stateKey)
      + (root.latest ? " · " + root.locale.dateTime(root.latest.time,false,false) : "")
    textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Host.Color.popups.text
    font.family: Style.font.family; font.pixelSize: Style.font.caption
  }
  Column {
    width: parent.width; visible: root.latest !== null; spacing: Style.spacing.sm
    Text {
      width: parent.width
      text: root.latest ? root.t("memory_watch_system",root.bytes(root.latest.system.used),root.bytes(root.latest.system.MemAvailable),root.bytes(root.latest.system.cache))
        + "\n" + root.t("memory_watch_parts",root.bytes(root.latest.system.AnonPages),root.bytes(root.latest.system.Shmem),root.bytes(root.latest.system.SUnreclaim))
        + "\n" + root.t("memory_watch_pressure",root.bytes(root.latest.system.swap),root.latest.pressure.some === null ? "—" : root.locale.number(root.latest.pressure.some,2),root.latest.pressure.full === null ? "—" : root.locale.number(root.latest.pressure.full,2)) : ""
      textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Host.Color.popups.text
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }
    ChoiceDropdown {
      width: parent.width
      label: root.t("memory_watch_chart")
      value: root.systemField
      options: ["used","cache","AnonPages","Shmem","SUnreclaim","swap"].map(function(key) {
        return {value:key,label:root.t("memory_watch_metric_"+key)}
      })
      onChanged: function(value) { root.systemField = value }
    }
    SensorHistoryChart {
      width: parent.width; height: Style.space(135); locale: root.locale
      points: root.systemPoints; unit: "MiB"; ceiling: 0
      emptyText: root.t("memory_watch_no_value"); gapText: root.t("memory_watch_gap"); liveText: root.t("memory_watch_live")
      hint: root.t("memory_watch_metric_"+root.systemField)
    }
    Text {
      width: parent.width
      text: root.latest ? root.t("memory_watch_coverage",root.latest.coverage.retained,root.latest.coverage.observed,root.latest.coverage.pss)
        + "\n" + root.t("memory_watch_missing",root.latest.coverage.unavailable,root.latest.coverage.zombies,
          root.t(root.latest.coverage.limited ? "memory_watch_limited" : "memory_watch_within_limits")) : ""
      textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Host.Color.popups.text
      font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    Text {
      width: parent.width; text: root.t("memory_watch_candidates")
      textFormat: Text.PlainText; color: Host.Color.popups.text
      font.family: Style.font.family; font.pixelSize: Style.font.subtitle
    }
    Repeater {
      model: root.leaders.length
      Button {
        required property int index
        readonly property var entry: root.leaders[index]
        width: parent.width
        text: entry ? entry.name + " · PID " + entry.pid + " · " + root.delta(entry.growth)
          + (entry.candidate ? " · " + root.t("memory_watch_candidate") : "") : ""
        tooltipText: text
        selected: !!entry && root.selectedKey === entry.key
        foreground: Host.Color.popups.text; accent: Host.Color.accent; focusable: true; leftAlign: true
        Accessible.role: Accessible.Button; Accessible.name: text
        onClicked: if (entry) root.selectedKey = entry.key
      }
    }
    Text {
      width: parent.width
      text: root.selected ? root.t("memory_watch_process",root.bytes(root.selected.anon),root.bytes(root.selected.pss),root.bytes(root.selected.uss))
        + "\n" + root.t("memory_watch_baseline",root.bytes(root.selected.baseline),root.bytes(root.selected.peak),root.selected.samples)
        + "\n" + root.t("memory_watch_growth",root.delta(root.selected.growth),root.delta(root.selected.rate),root.locale.duration(root.selected.span))
        + "\n" + root.t(root.selected.candidate ? "memory_watch_suspect" : "memory_watch_not_proven") : root.t("memory_watch_select")
      textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Host.Color.popups.text
      font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    ChoiceDropdown {
      width: parent.width
      label: root.t("memory_watch_process_chart")
      value: root.processField
      options: ["anon","pss","uss"].map(function(key) { return {value:key,label:root.t("memory_watch_metric_"+key)} })
      onChanged: function(value) { root.processField = value }
    }
    SensorHistoryChart {
      width: parent.width; height: Style.space(135); locale: root.locale
      points: root.processPoints; unit: "MiB"; ceiling: 0
      emptyText: root.t(root.selected ? "memory_watch_no_value" : "memory_watch_select"); gapText: root.t("memory_watch_gap"); liveText: root.t("memory_watch_live")
      hint: root.selected ? root.selected.name + " · PID " + root.selected.pid + " · " + root.t("memory_watch_metric_"+root.processField) : ""
    }
    Text {
      width: parent.width; text: root.t("memory_watch_limits")
      textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Host.Color.popups.text
      font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
  }
}
