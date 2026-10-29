import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "I18n.js" as I18n
import "HeatPolicy.js" as Heat

// Detail sampling is panel-gated. Optional icon sampling requests CPU/RAM and CPU thermals.
Item {
  id: root
  visible: false
  property var settings: ({})
  readonly property string language: I18n.resolveLanguage(settings && settings.locale || "ru", Qt.locale().name)
  property bool active: false
  property bool backgroundEnabled: false
  readonly property bool journalEnabled: settings && settings.diagnosticJournal === true
  readonly property bool sensorRecording: settings && settings.sensorRecording === true
  property bool sensorWriterEnabled: false
  property string sensorRecordingError: ""
  readonly property bool savedCapture: settings && settings.diagnosticCapture === true
  readonly property int savedCaptureInterval: settings && [250,500,1000].indexOf(Number(settings.diagnosticCaptureInterval)) >= 0 ? Number(settings.diagnosticCaptureInterval) : 500
  property bool captureWanted: false
  property int captureInterval: 500
  signal capturePreferencesRequested(bool wanted, int interval)
  property bool captureEnabled: false
  property int captureAppliedInterval: 0
  property string captureSession: ""
  property string captureError: ""
  property double captureSequence: 0
  property double captureMissed: 0
  property double captureDuration: 0
  property string captureAction: ""
  signal captureFlushed()
  readonly property bool collectionEnabled: active || backgroundEnabled || journalEnabled || sensorRecording || captureWanted || captureEnabled
  property bool journalWriterEnabled: false
  property string journalError: ""
  readonly property int backgroundInterval: 15000
  readonly property int glanceMaxAge: backgroundInterval * 2 + 5000
  property bool expanded: false
  property bool sensorsActive: false
  property bool gpuEnabled: expanded
  property bool storageEnabled: expanded
  property bool sensorSummaryEnabled: false
  readonly property var sensorSnapshot: _sensorSnapshot
  property var _sensorSnapshot: Model.emptySensorSnapshot()
  property var sensorHistory: ({})
  property double sensorsUpdatedAt: 0
  readonly property bool sensorsFresh: sensorsUpdatedAt > 0 && freshnessClock >= sensorsUpdatedAt
    && freshnessClock - sensorsUpdatedAt < (sensorRecording ? 45000 : 15000)
  property string errorText: ""
  property string state: "stopped" // stopped, starting, ready, stopping, backoff
  property string pending: ""
  property var buffer: []
  property int bufferSize: 0
  property var due: ({})
  property double lastTick: 0
  property int failures: 0
  readonly property bool sampling: reader.running
  readonly property var snapshot: _snapshot
  readonly property var thermalSnapshot: _thermalSnapshot
  readonly property var storageSnapshot: _storageSnapshot
  readonly property var gpuSnapshot: _gpuSnapshot
  readonly property var gpus: _gpus
  property var processGpus: ({})
  property double processGpusUpdatedAt: 0
  readonly property bool processGpusFresh: gpuEnabled && processGpusUpdatedAt > 0
    && freshnessClock >= processGpusUpdatedAt && freshnessClock - processGpusUpdatedAt <= Math.max(10000, profile.gpus * 3)
  readonly property var processes: _processes
  readonly property var metrics: _metrics
  readonly property bool processMetricsReady: _processMetricsReady
  property bool cpuReady: false
  readonly property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("activity-sampler")).replace(/^file:\/\//, ""))
  readonly property var profile: Model.samplingProfile(settings && settings.samplingSpeed || "Efficient")
  readonly property string profileName: profile.name
  readonly property int historySamples: Math.max(20, Math.min(240, Math.round(Number(settings && settings.historySamples) || 60)))
  property var _snapshot: Model.emptySnapshot()
  property var _thermalSnapshot: Model.emptyThermalSnapshot()
  property var _storageSnapshot: Model.emptyStorageSnapshot()
  property var _gpuSnapshot: Model.emptyGpuSnapshot()
  property var _gpus: []
  property var _processes: []
  property var _metrics: Model.emptyMetrics()
  property bool _processMetricsReady: false
  property var previous: Model.emptySnapshot()
  property var previousProcesses: Model.emptyProcessSnapshot()
  property var previousGpu: Model.emptyGpuSnapshot()
  property var glancePrevious: Model.emptySnapshot()
  property real glanceCpu: -1
  property real glanceMemory: -1
  property double glanceMemoryUsed: 0
  property double glanceMemoryTotal: 0
  property double glanceUpdatedAt: 0
  property double freshnessClock: 0
  readonly property bool glanceFresh: glanceUpdatedAt > 0 && freshnessClock >= glanceUpdatedAt
    && freshnessClock - glanceUpdatedAt < glanceMaxAge
  property bool memoryAlert: false
  property real iconTemperature: -1
  property double thermalUpdatedAt: 0
  property bool heatAlert: false
  property int heatLevel: 0
  readonly property int heatMotionInterval: Heat.interval(heatLevel)
  readonly property int heatThreshold: {
    var n = Number(settings && settings.iconHeatThreshold)
    return isFinite(n) && n >= 60 && n <= 110 ? Math.round(n) : 80
  }
  readonly property bool thermalFresh: thermalUpdatedAt > 0 && freshnessClock >= thermalUpdatedAt
    && freshnessClock - thermalUpdatedAt < glanceMaxAge && iconTemperature > 0

  function clearThermal() {
    iconTemperature = -1; thermalUpdatedAt = 0; heatAlert = false; heatLevel = 0
  }

  function updateHeatAlert() {
    heatLevel = Heat.nextLevel(heatLevel, iconTemperature, heatThreshold, thermalFresh)
    heatAlert = heatLevel > 0
  }

  function updateThermal(next) {
    if (!thermalFresh) { heatAlert = false; heatLevel = 0 }
    var selected = Model.cpuTemperature(next.temperatures)
    if (!selected) { clearThermal(); return }
    iconTemperature = selected.value
    thermalUpdatedAt = Date.now()
    freshnessClock = thermalUpdatedAt
    updateHeatAlert()
  }

  onHeatThresholdChanged: { heatAlert = false; heatLevel = 0; updateHeatAlert() }
  onThermalFreshChanged: if (!thermalFresh) { heatAlert = false; heatLevel = 0 }

  function clearGlance() {
    glancePrevious = Model.emptySnapshot()
    glanceCpu = -1; glanceMemory = -1
    glanceMemoryUsed = 0; glanceMemoryTotal = 0
    glanceUpdatedAt = 0; memoryAlert = false
  }

  function updateGlance(next) {
    var before = glancePrevious
    if (before.sample > 0 && next.sample > before.sample && next.sample - before.sample <= glanceMaxAge / 1000
        && next.cpu.total > before.cpu.total && next.cpu.idle >= before.cpu.idle) {
      var total = next.cpu.total - before.cpu.total
      glanceCpu = Math.max(0, Math.min(100, (total - (next.cpu.idle - before.cpu.idle)) / total * 100))
    } else glanceCpu = -1
    glanceMemoryTotal = next.memory.total
    glanceMemoryUsed = Math.max(0, next.memory.total - next.memory.available)
    glanceMemory = glanceMemoryUsed / glanceMemoryTotal * 100
    if (glanceMemory >= 85) memoryAlert = true
    else if (glanceMemory < 80) memoryAlert = false
    glancePrevious = next
    glanceUpdatedAt = Date.now()
    freshnessClock = glanceUpdatedAt
  }

  function resetData() {
    clearThermal()
    previous = Model.emptySnapshot()
    previousProcesses = Model.emptyProcessSnapshot()
    previousGpu = Model.emptyGpuSnapshot()
    _snapshot = Model.emptySnapshot()
    _thermalSnapshot = Model.emptyThermalSnapshot()
    _storageSnapshot = Model.emptyStorageSnapshot()
    _gpuSnapshot = Model.emptyGpuSnapshot()
    if (!sensorRecording) {
      _sensorSnapshot = Model.emptySensorSnapshot()
      sensorsUpdatedAt = 0
      sensorHistory = ({})
    }
    _gpus = []; processGpus = ({}); processGpusUpdatedAt = 0
    _processes = []; _processMetricsReady = false
    cpuReady = false
    _metrics = Model.emptyMetrics()
    due = ({})
  }

  function start() {
    if (!collectionEnabled || reader.running || state === "starting" || state === "stopping" || state === "backoff") return
    journalWriterEnabled = false
    sensorWriterEnabled = false
    resetData()
    clearGlance()
    pending = ""; buffer = []; bufferSize = 0
    state = "starting"
    watchdog.restart()
    reader.running = true
  }

  function stop() {
    scheduler.stop(); retry.stop(); watchdog.stop(); warmup.stop(); processWarmup.stop()
    pending = ""; buffer = []; bufferSize = 0; journalWriterEnabled = false
    resetData()
    if (reader.running || state === "starting") {
      state = "stopping"
      reader.running = false
      shutdown.restart()
    } else if (state !== "stopping") state = "stopped"
  }

  function fail() {
    errorText = I18n.t("reader_error", language)
    failures = Math.min(5, failures + 1)
    clearGlance()
    stop()
    if (state !== "stopping") recover()
  }

  function recover() {
    if (!collectionEnabled) { state = "stopped"; return }
    state = "backoff"
    retry.interval = Math.min(30000, 2000 * Math.pow(2, Math.max(0, failures - 1)))
    retry.restart()
  }

  function refresh() {
    due = ({})
    if (state === "stopped") start()
    else dispatch()
  }

  function refreshProcessCycle() {
    due.processes = 0
    dispatch()
  }

  function configureCapture(wanted, interval) {
    captureInterval = interval
    captureWanted = wanted
    due["capture-config"] = 0
    if (wanted) start()
    dispatch()
  }

  function setCapture(wanted) {
    capturePreferencesRequested(wanted, captureInterval)
    configureCapture(wanted, captureInterval)
  }

  function setCaptureInterval(interval) {
    if ([250,500,1000].indexOf(interval) < 0) return
    capturePreferencesRequested(captureWanted, interval)
    configureCapture(captureWanted, interval)
  }

  onSavedCaptureChanged: configureCapture(savedCapture, savedCaptureInterval)
  onSavedCaptureIntervalChanged: configureCapture(savedCapture, savedCaptureInterval)

  function requestCaptureAction(action) {
    if (!captureEnabled || (action !== "marker" && action !== "flush")) return
    captureAction = "capture-" + action
    dispatch()
  }

  function dispatch() {
    if (!collectionEnabled || state !== "ready" || pending !== "") return
    var now = Date.now()
    var maxGap = active ? 15000 : glanceMaxAge
    if (lastTick > 0 && (now < lastTick || now - lastTick > maxGap)) { resetData(); clearGlance() }
    lastTick = now

    var configure = captureWanted !== captureEnabled || (captureWanted && captureInterval !== captureAppliedInterval)
    if (configure && (due["capture-config"] || 0) <= now) {
      pending = captureWanted ? "capture-" + captureInterval : "capture-off"
      buffer = []; bufferSize = 0; watchdog.restart(); reader.write(pending + "\n")
      return
    }
    if (captureAction && captureEnabled) {
      pending = captureAction; captureAction = ""
      buffer = []; bufferSize = 0; watchdog.restart(); reader.write(pending + "\n")
      return
    }
    var kinds = !active ? ["glance", "thermals"] : expanded
      ? ["resources", "processes", "thermals", "gpus", "storage"]
      : ["resources", "processes", "thermals"]
    if (active && !sensorsActive) {
      if (gpuEnabled && kinds.indexOf("gpus") < 0) kinds.push("gpus")
      if (storageEnabled && kinds.indexOf("storage") < 0) kinds.push("storage")
      if (sensorSummaryEnabled) kinds.push("sensors")
    }
    if (active && sensorsActive) {
      kinds = ["sensors", "glance", "thermals"]
      if (gpuEnabled) kinds.push("gpus")
    }
    if (captureEnabled) kinds.unshift("capture-status")
    if (sensorRecording && kinds.indexOf("sensors") < 0) kinds.push("sensors")
    if (sensorRecording !== sensorWriterEnabled) {
      var recordingKind = sensorRecording ? "sensors-on" : "sensors-off"
      if ((due[recordingKind] || 0) <= now) {
        pending = recordingKind; buffer = []; bufferSize = 0; watchdog.restart()
        reader.write(recordingKind + "\n")
        return
      }
    }
    if (journalEnabled !== journalWriterEnabled) {
      var configurationKind=journalEnabled ? "journal-on" : "journal-off"
      if ((due[configurationKind] || 0) <= now || !journalEnabled) {
        pending=configurationKind;buffer=[];bufferSize=0;watchdog.restart()
        reader.write(configurationKind+"\n")
        return
      }
    }
    if (journalEnabled && journalWriterEnabled) {
      if (!active || sensorsActive) kinds = kinds.concat(["processes"])
      kinds = kinds.concat(["diagnostics", "journal"])
    }

    for (var i = 0; i < kinds.length; i++) {
      var kind = kinds[i]
      if ((due[kind] || 0) > now) continue
      pending = kind
      buffer = []; bufferSize = 0
      watchdog.restart()
      reader.write(kind + "\n")
      return
    }
  }

  function consume(line) {
    if (!collectionEnabled || state !== "ready" || pending === "") return
    var value = String(line)
    if (value.indexOf("snapshot-end\t") !== 0) {
      bufferSize += value.length + 1
      if (bufferSize > 262144 || buffer.length >= 8192) { fail(); return }
      buffer.push(value)
      return
    }
    if (value !== "snapshot-end\t" + pending) { fail(); return }
    var kind = pending
    var raw = buffer.join("\n")
    pending = ""; buffer = []; bufferSize = 0
    watchdog.stop()
    if (!accept(kind, raw)) { fail(); return }
    errorText = ""

    var interval = kind.indexOf("capture-") === 0 ? (active ? 1000 : backgroundInterval)
      : kind === "journal-on" || kind === "journal-off" ? 60000
      : kind === "sensors-on" || kind === "sensors-off" ? 60000
      : kind === "sensors" ? (sensorRecording ? 15000 : 3000)
      : kind === "journal" ? 15000 : kind === "diagnostics" ? 60000
      : kind === "processes" && !active ? 30000
      : kind === "glance" || !active ? backgroundInterval : kind === "processes" && !_processMetricsReady ? 600
      : (kind === "resources" ? profile.resources : profile[kind])
    due[kind] = Date.now() + interval
    if (active && kind === "processes" && !_processMetricsReady) processWarmup.restart()
    Qt.callLater(dispatch)
  }

  function accept(kind, raw) {
    if (kind.indexOf("capture-") === 0) {
      var captureLines = String(raw).split("\n")
      if (captureLines[0] !== "schema\tactivity-diagnostics\t2") return false
      var status = ({})
      captureLines.slice(1).forEach(function(line) { var pair = line.split("\t"); status[pair[0]] = pair[1] })
      captureEnabled = status.enabled === "1"
      captureAppliedInterval = Number(status.interval) || 0
      captureSession = status.session || ""
      captureError = status.error || ""
      captureSequence = Number(status.sequence) || 0
      captureMissed = Number(status.missed) || 0
      captureDuration = Number(status["duration-ms"]) || 0
      if (captureWanted !== captureEnabled) due["capture-config"] = Date.now() + 30000
      if (kind === "capture-flush") captureFlushed()
      if (!captureWanted && !active && !backgroundEnabled && !journalEnabled && !sensorRecording) stop()
      return true
    }
    if (kind === "resources" || kind === "glance") {
      var next = Model.parseSnapshot(raw)
      if (next.schema !== 1 || next.sample <= 0 || next.memory.total <= 0 || next.cpu.total <= 0) return false
      updateGlance(next)
      if (kind === "glance" || !active) return true
      if (previous.sample > 0 && next.cpu.total > previous.cpu.total) {
        _metrics = Model.nextMetrics(previous, next, metrics, historySamples)
        cpuReady = true
      } else if (!cpuReady) {
        _metrics = Model.baselineMetrics(next, metrics)
        // Request a quick second sample 400ms after opening so CPU metrics populate immediately
        if (active) warmup.restart()
      }
      previous = next; _snapshot = next
    } else if (kind === "processes") {
      var ps = Model.parseProcessSnapshot(raw)
      if (ps.schema !== 1 || ps.sample <= 0) return false
      if (active && previousProcesses.sample > 0) {
        _processes = Model.nextProcesses(previousProcesses, ps, snapshot.memory.total)
        _processMetricsReady = true
      }
      previousProcesses = ps
    } else if (kind === "thermals") {
      var thermal = Model.parseThermalSnapshot(raw)
      if (thermal.schema !== 1 || thermal.sample <= 0) return false
      updateThermal(thermal)
      _thermalSnapshot = thermal
    } else if (kind === "sensors") {
      var sensors = Model.parseSensorSnapshot(raw)
      if (sensors.schema !== 1 || sensors.sample <= 0) return false
      if (sensorRecording || (active && (sensorsActive || sensorSummaryEnabled))) {
        sensorRecordingError = sensors.recordingError || ""
        sensorHistory = Model.nextSensorHistory(sensorHistory, sensors, sensorRecording ? 1440 : 240, sensorRecording ? 60 : 15)
        _sensorSnapshot = sensors
        _thermalSnapshot = sensors
        sensorsUpdatedAt = Date.now()
        freshnessClock = sensorsUpdatedAt
        updateThermal(sensors)
      }
    } else if (kind === "sensors-on" || kind === "sensors-off") {
      var recordingLines = String(raw).split("\n")
      if (recordingLines[0] !== "schema\tactivity-sensor-recording\t1") return false
      sensorWriterEnabled = recordingLines.indexOf("enabled\t1") >= 0
      sensorRecordingError = ""
      for (var row = 0; row < recordingLines.length; row++)
        if (recordingLines[row].indexOf("error\t") === 0) sensorRecordingError = recordingLines[row].slice(6)
      due.sensors = 0
    } else if (kind === "gpus") {
      var gpu = Model.parseGpuSnapshot(raw)
      if (gpu.schema !== 1 || gpu.sample <= 0) return false
      if (gpuEnabled) {
        _gpus = Model.nextGpus(previousGpu, gpu)
        processGpus = Model.nextProcessGpus(previousGpu, gpu)
        processGpusUpdatedAt = Date.now()
        freshnessClock = processGpusUpdatedAt
        previousGpu = gpu; _gpuSnapshot = gpu
      }
    } else if (kind === "storage") {
      var storage = Model.parseStorageSnapshot(raw)
      if (storage.schema !== 1 || storage.sample <= 0) return false
      if (storageEnabled) _storageSnapshot = storage
    } else if (["journal-on", "journal-off", "journal", "diagnostics"].indexOf(kind) >= 0) {
      var lines = String(raw).split("\n")
      if (lines[0] !== "schema\tactivity-journal\t1") return false
      for (var j=1;j<lines.length;j++) {
        if (lines[j] === "enabled\t1") journalWriterEnabled = true
        else if (lines[j] === "enabled\t0") journalWriterEnabled = false
        else if (lines[j].indexOf("error\t")===0) journalError=lines[j].slice(6)
      }
      if(kind==='journal-on' || kind==='journal-off') {
        due.glance=0;due.thermals=0;due.processes=0;due.diagnostics=0;due.journal=0
      }
    } else return false
    return true
  }

  onActiveChanged: {
    if (active) {
      failures = 0
      errorText = ""
      start()
      dispatch()
    } else {
      warmup.stop(); processWarmup.stop()
      resetData()
      if (!collectionEnabled) { stop(); clearGlance() }
      else dispatch()
      errorText = ""
    }
  }
  onBackgroundEnabledChanged: {
    if (collectionEnabled) start()
    else { stop(); clearGlance() }
  }
  onJournalEnabledChanged: {
    due["journal-on"]=0;due["journal-off"]=0;due.diagnostics=0;due.journal=0
    if (collectionEnabled) { start();dispatch() }
    else { stop();clearGlance() }
  }
  onSensorRecordingChanged: {
    due["sensors-on"] = 0; due["sensors-off"] = 0; due.sensors = 0
    if (collectionEnabled) { start(); dispatch() } else stop()
  }
  Component.onCompleted: {
    configureCapture(savedCapture, savedCaptureInterval)
    if (collectionEnabled) start()
  }

  onExpandedChanged: {
    if (!expanded && !gpuEnabled) {
      previousGpu = Model.emptyGpuSnapshot()
      _gpus = []; _gpuSnapshot = Model.emptyGpuSnapshot()
      processGpus = ({}); processGpusUpdatedAt = 0
    } else {
      due.gpus = 0
      due.storage = 0
      dispatch()
    }
  }

  onSensorsActiveChanged: {
    due.sensors = 0
    due.thermals = 0
    if (!sensorsActive) { due.resources = 0; due.processes = 0 }
    dispatch()
  }
  onGpuEnabledChanged: { due.gpus = 0; dispatch() }
  onStorageEnabledChanged: { due.storage = 0; dispatch() }
  onSensorSummaryEnabledChanged: { due.sensors = 0; dispatch() }

  onProfileNameChanged: if (active) refresh()
  onCaptureIntervalChanged: if (captureWanted) { due["capture-config"] = 0; dispatch() }

  Component.onDestruction: {
    stop()
    if (reader.running) reader.signal(9)
  }

  Process {
    id: reader
    command: [root.helperPath, "--activity-reader"]
    clearEnvironment: true
    environment: ({ "PATH": "/usr/bin", "LC_ALL": "C", "HOME": Quickshell.env("HOME"), "XDG_STATE_HOME": Quickshell.env("XDG_STATE_HOME") })
    stdinEnabled: true
    stdout: SplitParser { onRead: function(line) { root.consume(line) } }
    onStarted: {
      if (!root.collectionEnabled || root.state !== "starting") { root.stop(); return }
      watchdog.stop()
      root.state = "ready"
      root.lastTick = Date.now()
      scheduler.start()
      root.dispatch()
    }
    onExited: {
      root.journalWriterEnabled = false
      root.sensorWriterEnabled = false
      root.captureEnabled = false
      root.captureAppliedInterval = 0
      root.captureAction = ""
      var expected = root.state === "stopping"
      shutdown.stop(); scheduler.stop(); watchdog.stop(); warmup.stop(); processWarmup.stop()
      root.pending = ""; root.buffer = []; root.bufferSize = 0
      root.state = "stopped"
      if (!root.collectionEnabled) return
      if (!expected) {
        root.errorText = I18n.t("reader_error", root.language)
        root.failures = Math.min(5, root.failures + 1)
        root.resetData()
        root.clearGlance()
      }
      root.recover()
    }
  }

  Timer {
    id: scheduler
    interval: root.active ? (root.captureEnabled ? 1000 : root.sensorsActive ? 3000 : Math.max(750, root.profile.resources)) : root.backgroundInterval
    repeat: true
    onTriggered: {
      root.freshnessClock = Date.now()
      if (!root.active) { root.due.glance = 0; root.due.thermals = 0 }
      root.dispatch()
    }
  }

  Timer {
    id: warmup
    interval: 400
    repeat: false
    onTriggered: {
      due.resources = 0
      root.dispatch()
    }
  }

  Timer {
    id: retry
    repeat: false
    onTriggered: { root.state = "stopped"; root.start() }
  }

  Timer {
    id: processWarmup
    interval: 600
    repeat: false
    onTriggered: { root.due.processes = 0; root.dispatch() }
  }

  Timer {
    id: watchdog
    interval: 5000
    repeat: false
    onTriggered: root.fail()
  }

  Timer {
    id: shutdown
    interval: 1000
    repeat: false
    onTriggered: {
      if (reader.running) reader.signal(9)
      else { root.state = "stopped"; root.recover() }
    }
  }
}
