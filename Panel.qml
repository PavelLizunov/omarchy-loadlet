import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Host
import qs.Ui
import "Model.js" as Model
import "I18n.js" as I18n
import "ActivityIconSvg.js" as IconVector

Panel {
  id: root

  moduleName: "slovn.activity-lite"
  ipcTarget: "slovn.activity-lite"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property alias activityController: activity
  property Item barIcon: null

  // Read-only diagnostics for lifecycle checks.
  IpcHandler {
    target: "slovn.activity-lite.status"
    function status(): string {
      return JSON.stringify({
        opened: root.opened,
        expanded: root.expanded,
        sensorsOpen: root.sensorsOpen,
        sensorSample: activity.sensorSnapshot.sample,
        temperatureSensors: activity.sensorSnapshot.temperatures.length,
        fanSensors: activity.sensorSnapshot.fans.length,
        fanControlChannels: activity.sensorSnapshot.controls ? activity.sensorSnapshot.controls.length : 0,
        ramStrip: root.compactRamStrip,
        fanTab: root.fansOpen,
        sensorsFresh: activity.sensorsFresh,
        state: activity.state,
        sampling: activity.sampling,
        sample: activity.snapshot.sample,
        processesReady: activity.processMetricsReady,
        processes: activity.processes.length,
        error: activity.errorText,
        pending: activity.pending,
        due: activity.due,
        processSample: activity.previousProcesses.sample,
        iconFresh: activity.glanceFresh,
        iconCpu: activity.glanceCpu,
        iconMemory: activity.glanceMemory,
        iconLoadThreshold: root.iconLoadThresholdSetting,
        iconGaugeCpu: root.barIcon ? root.barIcon.gaugeCpu : -1,
        iconGaugeMemory: root.barIcon ? root.barIcon.gaugeRam : -1,
        backgroundEnabled: activity.backgroundEnabled,
        iconIntervalMs: activity.backgroundInterval,
        iconUpdatedAt: activity.glanceUpdatedAt,
        iconMaxAgeMs: activity.glanceMaxAge,
        iconShape: root.iconShapeSetting,
        iconTemperature: activity.iconTemperature,
        temperatureFresh: activity.thermalFresh,
        temperatureUpdatedAt: activity.thermalUpdatedAt,
        heatAlert: activity.heatAlert && activity.thermalFresh,
        heatLevel: activity.heatLevel,
        heatMotionIntervalMs: activity.heatMotionInterval,
        journalEnabled: activity.journalEnabled,
        journalWriterEnabled: activity.journalWriterEnabled,
        journalError: activity.journalError,
        heatThreshold: activity.heatThreshold,
        productName: "Loadlet",
        iconRevision: "2.14.0",
        rightClickAction: "none",
        iconTooltip: button.tooltipText,
        iconConsumer: String(Qt.resolvedUrl("Panel.qml")),
        iconPalette: root.iconShapeSetting === IconVector.defaultShape ? "vivid-gauges" : "legacy",
        iconDesign: root.iconShapeSetting === IconVector.defaultShape ? "symmetric-split-die-cheeks" : "legacy",
        iconFill: root.iconShapeSetting === IconVector.defaultShape ? "six-rows-floor" : "continuous",
        iconSizeRevision: "native-canvas-v1",
        iconRaster: root.barIcon ? { width: root.barIcon.width, height: root.barIcon.height,
          sceneWidth: root.barIcon.mapToItem(root, 0, 0, root.barIcon.width, root.barIcon.height).width,
          sceneHeight: root.barIcon.mapToItem(root, 0, 0, root.barIcon.width, root.barIcon.height).height,
          slotWidth: button.width, slotHeight: button.height,
          dpr: root.barIcon.rasterDpr, sourceWidth: root.barIcon.sourceSize.width,
          sourceHeight: root.barIcon.sourceSize.height, decodedWidth: root.barIcon.implicitWidth,
          decodedHeight: root.barIcon.implicitHeight, ready: root.barIcon.status === Image.Ready } : null,
        iconMotion: root.booleanSetting("iconMotion", true),
        mode: root.opened ? "detail" : (activity.backgroundEnabled ? "glance" : "off")
      })
    }
    function details(): void { root.openDetails() }
    function preferences(): void { root.open(); root.setSettingsOpen(true) }
  }

  property bool expanded: false
  property bool settingsOpen: false
  property bool sensorsOpen: false
  property bool fansOpen: false
  property string fanStatusKey: ""
  property int fanDuration: 10
  property string pendingFanChannel: ""
  property int pendingFanSpeed: 100
  property string pendingFanAction: "boost"
  function fanAction(channel, speed, action) {
    if (fanController.running || !/^pwm[2-5]$/.test(channel)) return
    pendingFanChannel = channel; pendingFanSpeed = speed; pendingFanAction = action
    fanStatusKey = "fan_action_pending"
    fanController.running = true
  }
  Process {
    id: fanController
    command: root.pendingFanAction === "restore"
      ? ["/usr/local/lib/loadlet/fan-control", "request", "restore", root.pendingFanChannel]
      : ["/usr/local/lib/loadlet/fan-control", "request", root.pendingFanAction, root.pendingFanChannel, String(root.pendingFanSpeed), String(root.pendingFanAction === "identify" ? 5 : root.fanDuration)]
    onStarted: fanDeadline.restart()
    onExited: function(code) { fanDeadline.stop(); root.fanStatusKey = code === 0 ? "fan_action_sent" : "fan_action_failed"; activity.refresh() }
  }
  Timer { id: fanDeadline; interval: 150000; onTriggered: { fanController.signal(9); root.fanStatusKey = "fan_action_failed" } }
  property int sensorWindowSeconds: 600
  property string selectedSensorId: ""
  property string sensorPart: ""
  property bool computerMapVisible: false
  property string focusedFanChannel: ""
  readonly property string activeFanChannel: {
    var channels=activity.sensorSnapshot.controls || []
    return channels.some(function(channel){return channel.id===root.focusedFanChannel}) ? focusedFanChannel : channels.length ? channels[0].id : ""
  }
  property bool sensorOptionsOpen: false
  property bool fanAssignmentOpen: false
  property bool fanIdentificationOpen: false
  property string settingsSection: "tiles"
  property int identificationPercent: 0
  readonly property var fanPlaces: ["unknown", "fan_cpu", "fan_front", "fan_rear", "fan_top", "fan_ssd"]
  function fanPlace(channel) {
    var place = String(root.setting("fanPlace_" + channel, "unknown"))
    return fanPlaces.indexOf(place) >= 0 ? place : "unknown"
  }
  function assignFan(channel, place) {
    if (!/^pwm[2-5]$/.test(channel) || fanPlaces.indexOf(place) < 0) return
    var change = {}; change["fanPlace_" + channel] = place
    root.persistSettings(change)
  }
  function fanChannel(sensor) {
    if (sensor.category !== "motherboard") return ""
    var match = String(sensor.label || "").match(/^fan([2-5])$/)
    return match ? "pwm" + match[1] : ""
  }
  readonly property var sensorAssignments: {
    try { var value = JSON.parse(String(root.setting("sensorAssignments", "{}"))); return value && typeof value === "object" && !Array.isArray(value) ? value : ({}) }
    catch (error) { return ({}) }
  }
  readonly property var sensorPlaces: ["automatic", "cpu", "gpu", "memory", "storage", "motherboard", "fan_cpu", "fan_front", "fan_rear", "fan_top", "fan_ssd"]
  function sensorKey(sensor) { return JSON.stringify([sensor.chip || "", sensor.location || "", sensor.label || ""]) }
  function sensorPlace(sensor) {
    var place = sensorAssignments[root.sensorKey(sensor)]
    return sensorPlaces.indexOf(place) >= 0 ? place : "automatic"
  }
  function assignSensor(sensor, place) {
    if (sensorPlaces.indexOf(place) < 0) return
    var assignments = Object.assign({}, sensorAssignments)
    if (place === "automatic") delete assignments[root.sensorKey(sensor)]
    else assignments[root.sensorKey(sensor)] = place
    root.selectedSensorId = sensor.id
    root.persistSettings({sensorAssignments:JSON.stringify(assignments)})
    // Keep the edited sensor visible when its new category leaves the filter.
    if (!root.sensorMatches(sensor, root.sensorPart)) root.sensorPart = ""
  }
  function sensorMatches(sensor, part) {
    if (!part) return true
    var manual = root.sensorPlace(sensor)
    if (manual !== "automatic") return manual === part
    if (part.indexOf("fan_") === 0) return sensor.fan === true && root.fanPlace(root.fanChannel(sensor)) === part
    return sensor.category === part
  }
  readonly property var filteredSensors: coolingSensors.filter(function(sensor) { return root.sensorMatches(sensor, root.sensorPart) })
  function selectPart(part) {
    historyFanChannel = ""
    computerMapVisible = false
    sensorPart = part
    selectedSensorId = ""
    focusedFanChannel = ""
    if (part.indexOf("fan_") === 0) {
      var channels = activity.sensorSnapshot.controls || []
      var assigned = channels.filter(function(channel) { return root.fanPlace(channel.id) === part })
      focusedFanChannel = assigned.length === 1 ? assigned[0].id : ""
      fansOpen = true
      sensorsOpen = true
    } else {
      fansOpen = false
      sensorsOpen = true
      loadSensorHistory()
    }
  }
  function showFanHistory(channel) {
    var sensor = coolingSensors.filter(function(item) { return root.fanChannel(item) === channel && item.fan })[0]
    if (!sensor) return
    computerMapVisible = false
    historyFanChannel = channel
    sensorPart = ""
    selectedSensorId = sensor.id
    fansOpen = false
    sensorsOpen = true
    loadSensorHistory()
  }
  property var savedSensors: []
  property bool historyPending: false
  property bool historyReadError: false
  property string historyFanChannel: ""
  function returnToFanControls() {
    root.focusedFanChannel = historyFanChannel
    historyFanChannel = ""
    root.fansOpen = true
    root.sensorsOpen = true
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }
  readonly property var currentSensors: activity.sensorSnapshot.temperatures.concat(activity.sensorSnapshot.fans.map(function(sensor) { return Object.assign({}, sensor, {fan:true}) }))
  readonly property var coolingSensors: {
    var byId = {}
    savedSensors.forEach(function(sensor) { byId[sensor.id] = sensor })
    currentSensors.forEach(function(sensor) { byId[sensor.id] = sensor })
    return Object.keys(byId).map(function(id) { return byId[id] })
  }
  readonly property var selectedSensor: filteredSensors.filter(function(sensor) { return sensor.id === root.selectedSensorId })[0] || filteredSensors[0] || null
  function loadSensorHistory() {
    if (sensorHistoryReader.running) return
    historyPending = true
    historyReadError = false
    sensorHistoryReader.running = true
  }
  onSensorsOpenChanged: {
    if (!sensorsOpen) { fansOpen = false; sensorPart = ""; focusedFanChannel = ""; historyFanChannel = "" }
    else if (!fansOpen) loadSensorHistory()
  }
  Component.onDestruction: {
    historyDeadline.stop(); fanDeadline.stop()
    if (sensorHistoryReader.running) sensorHistoryReader.signal(9)
    if (fanController.running) fanController.signal(9)
  }
  Process {
    id: sensorHistoryReader
    command: ["python3", "-I", decodeURIComponent(String(Qt.resolvedUrl("activity-report")).replace("file://", "")), "--sensor-history"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: {
      try {
        if (text.length > 240000) throw new Error("History output exceeds budget")
        var sensors = JSON.parse(text).sensors
        if (!Array.isArray(sensors) || sensors.length > 128 || sensors.some(function(sensor) {
          return !sensor || typeof sensor.id !== "string" || !Array.isArray(sensor.history)
            || sensor.history.length > 3001 || sensor.history.some(function(point) {
              return !point || typeof point.time !== "number" || !isFinite(point.time)
                || typeof point.value !== "number" || !isFinite(point.value)
            })
        })) throw new Error("Invalid sensor history")
        root.savedSensors = sensors
      } catch (error) { root.historyReadError = true }
    } }
    onStarted: historyDeadline.restart()
    onExited: function(code) { historyDeadline.stop(); root.historyPending = false; root.historyReadError = root.historyReadError || code !== 0 }
  }
  Timer { id: historyDeadline; interval: 5000; onTriggered: { sensorHistoryReader.signal(9); root.historyPending = false; root.historyReadError = true } }
  property bool settingsControlActive: false
  property bool hintsVisible: false
  property bool languageExpanded: false
  property bool cursorActive: false
  property int selectedProcessIndex: 0
  property string selectedProcessKey: ""
  property string processQuery: ""
  property string sortKey: "cpu"
  property bool sortAscending: false
  property Item searchField: null
  property var processViewport: null

  readonly property string effectiveLanguage: I18n.resolveLanguage(root.setting("locale", "ru"), Qt.locale().name)
  readonly property color foreground: Host.Color.popups.text
  readonly property color accent: Host.Color.accent
  readonly property color urgent: Host.Color.urgent
  readonly property color dim: Qt.darker(root.foreground, 1.25)
  readonly property var snapshot: activity.snapshot
  readonly property var storageSnapshot: activity.storageSnapshot
  readonly property var gpuSnapshot: activity.gpuSnapshot
  readonly property var gpus: activity.gpus
  readonly property var processes: activity.processes
  readonly property var metrics: activity.metrics
  readonly property bool processMetricsReady: activity.processMetricsReady
  readonly property bool hasSnapshot: snapshot.sample > 0

  // Shared Process Table Column Geometry (guarantees 1:1 alignment between Header and Rows)
  readonly property int colPidWidth: Style.space(56)
  readonly property int colUserWidth: Style.space(86)
  readonly property int colCpuWidth: Style.space(64)
  readonly property int colRssWidth: Style.space(82)
  readonly property int colRamPctWidth: Style.space(56)
  readonly property int colTimeWidth: Style.space(68)
  readonly property int colActionWidth: Style.space(22)
  readonly property int tableSpacing: Style.spacing.sm
  readonly property int tableSideMargin: Style.spacing.sm
  readonly property real processRowHeight: Math.max(Style.space(expanded ? 28 : 26), Style.font.bodySmall + Style.spacing.sm * 2)
  readonly property real tableWidth: Math.max(0, panel.contentWidth - panel.padding * 2 - Border.left(panel.borderSpec) - Border.right(panel.borderSpec))
  readonly property bool showProcessPidColumn: tableWidth >= Style.space(400)
  readonly property bool showProcessRamPercentColumn: tableWidth >= Style.space(420)
  readonly property bool showProcessUserColumn: tableWidth >= Style.space(600)
  readonly property bool showProcessTimeColumn: tableWidth >= Style.space(540)

  function processNameWidth(rowWidth, isCompact) {
    var inner = Math.max(0, rowWidth - tableSideMargin * 2)
    var fixed = colCpuWidth + colRssWidth + colActionWidth
    var gaps = 3
    if (showProcessPidColumn) { fixed += colPidWidth; gaps++ }
    if (showProcessRamPercentColumn) { fixed += colRamPctWidth; gaps++ }
    if (!isCompact && showProcessUserColumn) { fixed += colUserWidth; gaps++ }
    if (!isCompact && showProcessTimeColumn) { fixed += colTimeWidth; gaps++ }
    return Math.max(1, inner - fixed - tableSpacing * gaps)
  }

  readonly property var cpuTemperature: activity.thermalFresh ? { value: activity.iconTemperature } : null
  readonly property int compactTileCount: Number(root.setting("compactTileCount", 2)) === 3 ? 3 : 2
  readonly property var compactTiles: Array.from({length: compactTileCount}, function(_, index) {
    var defaults = ["cpu", "ram", "gpu"]
    var key = String(root.setting("compactTile" + index, defaults[index]))
    return root.tileOptions.indexOf(key) >= 0 || key.indexOf("gpu:") === 0 ? key : defaults[index]
  }).filter(function(key) { return key !== "none" })
  readonly property var tileOptions: ["cpu", "ram", "gpu", "temperature", "fans", "network", "disk", "storage", "none"]
    .concat(root.gpus.map(function(gpu) { return "gpu:" + gpu.id }))
  readonly property bool compactRamStrip: root.booleanSetting("compactRamStrip", true) && compactTiles.indexOf("ram") < 0
  readonly property real ramStripHeight: Math.max(Style.space(32), Style.font.caption + Style.spacing.sm * 2 + Style.space(5))
  readonly property real tileHeight: Math.max(Style.space(100), Style.font.caption * 4 + Style.font.title + Style.spacing.md * 2 + Style.space(14))
  function tileTitle(key) {
    if (key.indexOf("gpu:") === 0) {
      var gpu = root.gpus.filter(function(item) { return "gpu:" + item.id === key })[0]
      return gpu ? root.compactGpuName(gpu) : I18n.t("gpu", effectiveLanguage) + " " + key.slice(4)
    }
    return I18n.t(key === "temperature" ? "temperatures" : key, effectiveLanguage)
  }
  function sensorOwner(sensor) {
    var category = String(sensor.category || "unknown")
    var owner = String(sensor.owner || "")
    var prefix = I18n.t("sensor_owner_" + category, effectiveLanguage)
    return prefix + (owner ? " · " + owner : "")
      + (category === "memory" && sensor.location ? " · " + sensor.location : "")
  }
  function sensorLabel(sensor) {
    var label = String(sensor.label || "")
    var mapped = { Tctl: "sensor_cpu_control", Tdie: "sensor_cpu_die", Composite: "sensor_composite", edge: "sensor_gpu_edge", junction: "sensor_gpu_hotspot", mem: "sensor_gpu_memory" }
    if (mapped[label]) return I18n.t(mapped[label], effectiveLanguage)
    if (sensor.category === "gpu" && label === sensor.owner) return I18n.t("temp_unit", effectiveLanguage)
    var boardChannel = label.match(/^temp(\d+)$/i)
    if (sensor.category === "motherboard" && boardChannel) return I18n.t("board_temp_channel",effectiveLanguage,boardChannel[1])
    var ccd = label.match(/^Tccd(\d+)$/i)
    if (ccd) return I18n.t("sensor_ccd", effectiveLanguage, ccd[1])
    var fan = label.match(/^fan(\d+)$/i)
    if (fan) {
      var place = root.fanPlace(root.fanChannel(sensor))
      return I18n.t("sensor_fan", effectiveLanguage, fan[1])
        + (place !== "unknown" ? " · " + I18n.t("map_" + place, effectiveLanguage) : "")
    }
    return I18n.t("sensor_reading", effectiveLanguage)
  }
  property string selectedDiskId: "all"
  property string selectedStoragePath: ""
  property bool storageSelectionPinned: false
  readonly property var diskItems: Model.diskCycleItems(metrics)
  readonly property var storageItems: Model.storageVolumes(storageSnapshot)
  readonly property var activeDisk: Model.selectDiskItem(diskItems, selectedDiskId)
  readonly property var activeStorage: Model.selectStorageVolume(
    storageItems,
    selectedStoragePath,
    storageSelectionPinned
  )
  readonly property real storageUsedFraction: Model.storageUsedFraction(activeStorage)
  readonly property bool canCycleDisks: diskItems.length > 1
  readonly property bool canCycleStorage: storageItems.length > 1
  readonly property int dieGapCompact: Style.space(2)
  readonly property int dieGapExpanded: Style.space(3)
  readonly property var corePaintSizesCompact: ({
    gap: dieGapCompact,
    domainGap: Style.space(4),
    pad: Style.space(3),
    performance: Style.space(9),
    efficiency: Style.space(6),
    same: Style.space(6)
  })
  readonly property var corePaintSizesExpanded: ({
    gap: dieGapExpanded,
    domainGap: Style.space(6),
    pad: Style.space(4),
    performance: Style.space(14),
    efficiency: Style.space(10),
    same: Style.space(10)
  })
  readonly property var corePaintCompact: expanded
    ? Model.emptyCorePaint()
    : Model.paintCoreLayout(metrics.cores, snapshot.topology, corePaintSizesCompact, "compact")
  readonly property var corePaintExpanded: expanded
    ? Model.paintCoreLayout(metrics.cores, snapshot.topology, corePaintSizesExpanded, "expanded")
    : Model.emptyCorePaint()
  readonly property var sortedProcesses: expanded
    ? Model.filterAndSortProcesses(processes, processQuery, sortKey, sortAscending)
    : []
  readonly property var topProcesses: expanded
    ? []
    : Model.filterAndSortProcesses(processes, "", sortKey, sortAscending).slice(0, compactProcessLimit)
  property int compactProcessLimit: 4
  readonly property var selectedProcess: {
    var list = expanded ? sortedProcesses : topProcesses
    if (list.length === 0) return null
    if (!selectedProcessKey) return null
    for (var i = 0; i < list.length; i++) {
      if (Model.processIdentityKey(list[i]) === selectedProcessKey) return list[i]
    }
    return null
  }
  readonly property string samplingSpeedSetting: normalizedSamplingSpeed(setting("samplingSpeed", "Efficient"))
  readonly property int historySamplesSetting: Math.max(20, Math.min(240,
    Math.round(Number(setting("historySamples", 60)) || 60)))
  readonly property string temperatureUnitSetting: normalizedTemperatureUnit(setting("temperatureUnit", "Celsius"))
  readonly property bool showFrequencies: booleanSetting("showFrequencies", true)
  readonly property bool openExpandedByDefault: booleanSetting("openExpanded", false)
  readonly property int iconShapeSetting: IconVector.shapeIndex(setting("iconShape", IconVector.defaultShape))
  readonly property int iconLoadThresholdSetting: IconVector.loadThreshold(setting("iconLoadThreshold", 50))
  readonly property string iconLegend: I18n.t(iconShapeSetting === IconVector.defaultShape
    ? "icon_split_legend" : "icon_legend", effectiveLanguage)
    + "\n" + I18n.t("icon_load_threshold_desc", effectiveLanguage, iconLoadThresholdSetting)

  function refresh() {
    activity.refresh()
  }

  function setExpanded(value) {
    if (!value && processActions.confirmationOpen) processActions.cancel()
    expanded = value
    cursorActive = false
    selectedProcessIndex = 0
    selectedProcessKey = ""
    languageExpanded = false
    if (!expanded) {
      processQuery = ""
    }
    Qt.callLater(function() {
      if (root.opened && keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function openDetails() {
    root.open()
    root.setSettingsOpen(false)
    root.sensorsOpen = false
    if (!root.expanded) root.setExpanded(true)
    else root.languageExpanded = false
  }

  function setSettingsOpen(value) {
    settingsOpen = value
    settingsControlActive = value
    languageExpanded = false
    if (!value) {
      Qt.callLater(function() {
        if (root.opened && keyCatcher) keyCatcher.forceActiveFocus()
      })
    }
  }

  function restoreProcessCursor() {
    var list = expanded ? sortedProcesses : topProcesses
    if (list.length === 0) {
      selectedProcessIndex = 0
      selectedProcessKey = ""
      return
    }
    if (selectedProcessKey) {
      for (var i = 0; i < list.length; i++) {
        if (Model.processIdentityKey(list[i]) === selectedProcessKey) {
          selectedProcessIndex = i
          return
        }
      }
    }
    selectedProcessIndex = 0
    selectedProcessKey = ""
  }

  function selectProcess(index) {
    var list = expanded ? sortedProcesses : topProcesses
    if (list.length === 0) return
    selectedProcessIndex = Math.max(0, Math.min(list.length - 1, index))
    selectedProcessKey = Model.processIdentityKey(list[selectedProcessIndex])
    cursorActive = true
  }

  function moveProcess(delta) {
    var list = expanded ? sortedProcesses : topProcesses
    if (list.length === 0) return
    selectProcess(selectedProcessIndex + delta)
    pointerGate.reset()
    Qt.callLater(function() {
      if (root.processViewport && root.processViewport.ensureSelected) root.processViewport.ensureSelected()
    })
  }

  function setSort(nextKey) {
    if (sortKey === nextKey) sortAscending = !sortAscending
    else {
      sortKey = nextKey
      sortAscending = nextKey === "name"
    }
  }

  function cycleSort(delta) {
    var keys = ["cpu", "memory", "pid", "runtime", "name"]
    var index = keys.indexOf(sortKey)
    if (index < 0) index = 0
    index = (index + delta + keys.length) % keys.length
    setSort(keys[index])
  }

  function focusSearch() {
    if (!expanded || !searchField) return
    searchField.forceActiveFocus()
    searchField.selectAll()
  }

  function finishSearch() {
    if (searchField) searchField.focus = false
    keyCatcher.forceActiveFocus()
  }

  function percentText(value) {
    return Math.round(Number(value) || 0) + "%"
  }

  function booleanSetting(name, fallback) {
    var value = setting(name, fallback)
    if (typeof value === "boolean") return value
    if (typeof value === "string") {
      var normalized = value.trim().toLowerCase()
      if (normalized === "true" || normalized === "on" || normalized === "yes") return true
      if (normalized === "false" || normalized === "off" || normalized === "no") return false
    }
    return value === undefined || value === null ? fallback : !!value
  }

  function normalizedSamplingSpeed(value) {
    return Model.samplingProfile(value).name
  }

  function normalizedTemperatureUnit(value) {
    return String(value || "Celsius").toLowerCase() === "fahrenheit"
      ? "Fahrenheit"
      : "Celsius"
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    var current = root.settings || ({})
    for (var existing in current) if (existing !== "id") entry[existing] = current[existing]
    for (var key in values) entry[key] = values[key]
    if (values.samplingSpeed !== undefined) {
      delete entry.refreshIntervalMs
      delete entry.processRefreshIntervalMs
      delete entry.thermalRefreshIntervalMs
      delete entry.gpuRefreshIntervalMs
      delete entry.storageRefreshIntervalMs
    }

    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function resetPreferences() {
    persistSettings({
      locale: "ru",
      samplingSpeed: "Efficient",
      historySamples: 60,
      temperatureUnit: "Celsius",
      showFrequencies: true,
      openExpanded: false,
      iconIndicator: true,
      iconShape: IconVector.defaultShape,
      iconLoadThreshold: 50,
      iconHeatThreshold: 80,
      iconMotion: true,
      diagnosticJournal: false, sensorAssignments: "{}",
      fanPlace_pwm2: "unknown", fanPlace_pwm3: "unknown", fanPlace_pwm4: "unknown", fanPlace_pwm5: "unknown",
      compactTileCount: 2, compactTile0: "cpu", compactTile1: "ram", compactTile2: "gpu", compactRamStrip: true, sensorRecording: false
    })
  }

  function swapBadgeText() {
    if (!hasSnapshot || !snapshot.memory.swapTotal) return ""
    return I18n.t("swap", root.effectiveLanguage) + " " + percentText(metrics.swap)
  }

  function memoryBreakdownText() {
    if (!snapshot.memory.total) return I18n.t("used", root.effectiveLanguage) + " — · " + I18n.t("cache", root.effectiveLanguage) + " —"
    var usedText = Model.formatCompactBytes(snapshot.memory.total - snapshot.memory.available)
    var totalText = Model.formatCompactBytes(snapshot.memory.total)
    var cacheText = Model.formatCompactBytes(snapshot.memory.cached)
    return usedText + " / " + totalText + " · " + I18n.t("cache", root.effectiveLanguage) + " " + cacheText
  }

  function cpuCardDetail() {
    var parts = []
    if (cpuTemperature)
      parts.push(Model.formatTemperature(cpuTemperature.value, temperatureUnitSetting))
    return parts.join(" · ")
  }

  function frequencyText(value, unit) {
    if (!showFrequencies) return ""
    var frequency = Number(value)
    if (!isFinite(frequency) || frequency < 0) return ""
    return Math.round(frequency) + " " + unit
  }

  function gpuFrequencyText(gpu) {
    if (!showFrequencies) return ""
    var frequency = Number(gpu && gpu.frequencyMHz)
    if (!isFinite(frequency) || frequency < 0) return ""
    if (frequency === 0) return I18n.t("gpu_idle", effectiveLanguage)
    return Math.round(frequency) + " MHz"
  }

  function cpuCardLabel() {
    var frequency = frequencyText(snapshot.cpuFrequencyMHz, "MHz")
    return frequency ? I18n.t("cpu", root.effectiveLanguage) + " · " + frequency : I18n.t("cpu", root.effectiveLanguage)
  }

  function memoryCardLabel() {
    var speed = frequencyText(snapshot.memorySpeedMTs, "MT/s")
    return speed ? I18n.t("ram", root.effectiveLanguage) + " · " + speed : I18n.t("ram", root.effectiveLanguage)
  }

  function compactGpuName(gpu) {
    var name = String(gpu && gpu.name || "GPU")
    name = name.replace(/^Intel Corporation[ ]*/i, "")
      .replace(/^NVIDIA Corporation[ ]*/i, "")
      .replace(/^NVIDIA[ ]*/i, "")
      .replace(/^Advanced Micro Devices[^]]*\][ ]*/i, "")
      .replace(/^AMD[ ]*/i, "")
    var bracketed = name.match(/\[([^\]]+)\]/g)
    if (bracketed && bracketed.length) name = bracketed[bracketed.length - 1].slice(1, -1)
    return name || "GPU"
  }

  function gpuUsageText(gpu) {
    var usage = Number(gpu && gpu.usage)
    return isFinite(usage) && usage >= 0 ? Math.round(usage) + "%" : I18n.t("sampling", root.effectiveLanguage)
  }

  function gpuUsageAndClockText(gpu) {
    var usage = gpuUsageText(gpu)
    var frequency = gpuFrequencyText(gpu)
    return frequency ? usage + " · " + frequency : usage
  }

  function gpuMemoryLabel(gpu) {
    if (gpu && gpu.memoryKind === "shared") return I18n.t("gpu_shared", effectiveLanguage)
    if (gpu && gpu.memoryKind === "vram") return "VRAM"
    return I18n.t("gpu_memory", effectiveLanguage)
  }

  function gpuMemoryText(gpu) {
    var used = Number(gpu && gpu.memoryUsed)
    var total = Number(gpu && gpu.memoryTotal)
    if (!isFinite(used) || used < 0) return "—"
    var usedText = Model.formatCompactBytes(used)
    if (!isFinite(total) || total <= 0) return usedText
    return usedText + " / " + Model.formatCompactBytes(total)
  }

  function resetDriveSelection() {
    selectedDiskId = "all"
    selectedStoragePath = ""
    storageSelectionPinned = false
  }

  function cycleDisk(delta) {
    var next = Model.cycleItemId(diskItems, selectedDiskId, "id", delta)
    if (next !== "") selectedDiskId = next
  }

  function cycleStorage(delta) {
    var current = activeStorage ? activeStorage.path : selectedStoragePath
    var next = Model.cycleItemId(storageItems, current, "path", delta)
    if (next === "") return
    storageSelectionPinned = true
    selectedStoragePath = next
  }

  function pagerText(items, currentId, key) {
    if (!items || items.length <= 1) return ""
    var wanted = String(currentId || "")
    var index = 0
    for (var i = 0; i < items.length; i++) {
      if (String(items[i][key]) === wanted) {
        index = i
        break
      }
    }
    return (index + 1) + "/" + items.length
  }

  function diskCardLabel() {
    if (!canCycleDisks) return I18n.t("disk", root.effectiveLanguage)
    return activeDisk && activeDisk.id !== "all" ? String(activeDisk.name || I18n.t("disk", root.effectiveLanguage)) : I18n.t("disk", root.effectiveLanguage)
  }

  function diskPagerText() {
    return pagerText(diskItems, activeDisk ? activeDisk.id : selectedDiskId, "id")
  }

  function diskCardRead() {
    return activeDisk ? Number(activeDisk.read || 0) : Number(metrics.diskRead || 0)
  }

  function diskCardWrite() {
    return activeDisk ? Number(activeDisk.write || 0) : Number(metrics.diskWrite || 0)
  }

  function diskCardHistory() {
    return activeDisk && Array.isArray(activeDisk.history) ? activeDisk.history : metrics.diskHistory
  }

  function storageCardLabel() {
    if (!canCycleStorage) return I18n.t("storage", root.effectiveLanguage)
    return Model.storageVolumeLabel(activeStorage && activeStorage.path)
  }

  function storagePagerText() {
    return pagerText(storageItems, activeStorage ? activeStorage.path : selectedStoragePath, "path")
  }

  function storageCardValue() {
    if (storageSnapshot.sample <= 0) return "—"
    return activeStorage ? Model.formatBytes(activeStorage.used) + " / " + Model.formatBytes(activeStorage.total) : "—"
  }

  function storageCardDetail() {
    if (storageSnapshot.sample <= 0) return ""
    return activeStorage ? Model.formatBytes(activeStorage.available) + " " + I18n.t("free", root.effectiveLanguage) : ""
  }

  function pressureColor(value) {
    return IconVector.pressureColor(value, root.foreground, root.accent, root.urgent)
  }

  function sortLabel(key, label) {
    if (sortKey !== key) return label
    return label + (sortAscending ? " ↑" : " ↓")
  }

  onSortedProcessesChanged: {
    pointerGate.reset()
    restoreProcessCursor()
  }
  onTopProcessesChanged: restoreProcessCursor()

  onOpenedChanged: {
    if (opened) {
      expanded = openExpandedByDefault
      sensorPart = ""
      computerMapVisible = false
      sensorOptionsOpen = false
      historyFanChannel = ""
      fanAssignmentOpen = false
      fanIdentificationOpen = false
      focusedFanChannel = ""
      fansOpen = false
      sensorsOpen = false
      settingsOpen = false
      settingsControlActive = false
      languageExpanded = false
      cursorActive = false
      selectedProcessIndex = 0
      selectedProcessKey = ""
      processQuery = ""
      hintsVisible = false
      resetDriveSelection()
    } else {
      expanded = false
      fansOpen = false
      sensorsOpen = false
      settingsOpen = false
      settingsControlActive = false
      languageExpanded = false
      hintsVisible = false
      processQuery = ""
      resetDriveSelection()
    }
  }

  ActivityController {
    id: activity
    settings: root.settings
    active: root.opened
    backgroundEnabled: root.booleanSetting("iconIndicator", true)
    expanded: root.expanded
    sensorsActive: root.sensorsOpen && !root.settingsOpen
    gpuEnabled: root.expanded || root.settingsOpen || root.compactTiles.some(function(key) { return key === "gpu" || key.indexOf("gpu:") === 0 })
    storageEnabled: root.expanded || root.compactTiles.indexOf("storage") >= 0
    sensorSummaryEnabled: !root.sensorsOpen && (root.expanded || root.compactTiles.some(function(key) {
      return key === "temperature" || key === "fans" || key === "gpu" || key.indexOf("gpu:") === 0
    }))
  }
  DiagnosticExport { id: diagnosticExport; language: root.effectiveLanguage }

  ProcessActionController {
    id: processActions
    active: root.opened
    enabled: !root.settingsOpen && !root.languageExpanded && !root.sensorsOpen
    language: root.effectiveLanguage
    onConfirmationRequested: processConfirm.selectedIndex = 0
    onFocusRequested: if (root.opened) keyCatcher.forceActiveFocus()
    onRefreshRequested: activity.refreshProcessCycle()
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: root.processViewport
  }

  // Native slot dimensions are unchanged; draw inside the optical canvas.
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: vertical ? -1 : Style.bar.iconSlot
    fixedHeight: vertical ? Style.bar.iconSlot : -1
    ActivityIcon {
      objectName: "activityBarIcon"
      x: (parent.width - width) / 2
      y: (parent.height - height) / 2
      Component.onCompleted: root.barIcon = this
      cpu: activity.glanceCpu
      ram: activity.glanceMemory
      fresh: activity.glanceFresh
      loadThreshold: root.iconLoadThresholdSetting
      shape: root.iconShapeSetting
      hot: activity.heatAlert
      heatLevel: activity.heatLevel
      temperatureFresh: activity.thermalFresh
      thermalSampleAt: activity.thermalUpdatedAt
      motionEnabled: root.booleanSetting("iconMotion", true)
      foreground: button.foreground
      background: root.bar ? root.bar.background : Host.Color.background
    }
    tooltipText: (activity.glanceFresh
      ? "CPU " + (activity.glanceCpu >= 0 ? root.percentText(activity.glanceCpu) : "—")
        + " · " + I18n.t("ram", root.effectiveLanguage) + " "
        + Model.formatBytes(activity.glanceMemoryUsed) + " / " + Model.formatBytes(activity.glanceMemoryTotal) + "\n"
      : I18n.t("icon_no_data", root.effectiveLanguage) + "\n")
      + (activity.thermalFresh
        ? I18n.t("cpu", root.effectiveLanguage) + " " + Model.formatTemperature(activity.iconTemperature, root.temperatureUnitSetting)
          + (activity.heatAlert ? " · " + I18n.t("icon_hot", root.effectiveLanguage) : "") + "\n"
        : "")
      + I18n.t("tooltip", root.effectiveLanguage)
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    centerOnBar: false

    // Only the explicit size control changes the preferred frame; pages scroll inside it.
    contentWidth: panel.fittedContentWidth(root.expanded ? Style.space(900) : Style.space(480))
    contentHeight: panel.fittedContentHeight(Style.space(root.expanded ? 650 : 390))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // The real KeyboardPanel lives in a separate window. Handle fallback keys
      // here, inside that window, rather than on the bar widget's root item.
      Keys.priority: root.settingsOpen || root.languageExpanded || root.sensorsOpen ? Keys.AfterItem : Keys.BeforeItem
      Keys.forwardTo: [pageShortcuts]
      Item {
        id: pageShortcuts
        Keys.onPressed: function(event) {
          if (processActions.confirmationOpen || (root.searchField && root.searchField.activeFocus)) return
          var key = String(event.text || "").toLowerCase()
          if (key === "e") { root.setExpanded(!root.expanded); event.accepted = true }
          else if (key === "h" && !root.settingsOpen && !root.languageExpanded) {
            processActions.cancel(); root.fansOpen = false; root.sensorsOpen = !root.sensorsOpen
            event.accepted = true
          }
        }
      }
      Keys.onEscapePressed: {
        if (processActions.confirmationOpen) processActions.cancel()
        else if (root.languageExpanded) root.languageExpanded = false
        else if (root.settingsOpen) root.setSettingsOpen(false)
        else if (root.computerMapVisible) root.computerMapVisible = false
        else if (root.historyFanChannel) root.returnToFanControls()
        else if (root.sensorsOpen) root.sensorsOpen = false
        else keyCatcher.closeRequested()
      }
      blocked: !processActions.confirmationOpen
        && (!!(root.searchField && root.searchField.activeFocus)
          || root.settingsControlActive || root.languageExpanded || root.sensorsOpen)

      onMoveRequested: function(dx, dy) {
        if (processActions.confirmationOpen) {
          if (dx !== 0) processConfirm.selectedIndex = processConfirm.selectedIndex === 0 ? 1 : 0
          return
        }
        if (root.settingsOpen || root.languageExpanded || root.sensorsOpen) return
        if (dy !== 0) root.moveProcess(dy)
        else if (dx !== 0) root.cycleSort(dx)
      }
      onActivateRequested: {
        if (processActions.confirmationOpen) {
          if (processConfirm.selectedIndex === 0) processActions.cancel()
          else processActions.confirm()
          return
        }
        if (!root.expanded && !root.settingsOpen && !root.languageExpanded && !root.sensorsOpen) root.setExpanded(true)
      }
      onCloseRequested: {
        if (processActions.confirmationOpen) {
          processActions.cancel()
          return
        }
        if (root.languageExpanded) { root.languageExpanded = false; return }
        if (root.settingsOpen) root.setSettingsOpen(false)
        else if (root.computerMapVisible) root.computerMapVisible = false
        else if (root.historyFanChannel) root.returnToFanControls()
        else if (root.sensorsOpen) root.sensorsOpen = false
        else if (root.expanded) root.setExpanded(false)
        else root.close()
      }
      onDeleteRequested: {
        if (!root.settingsOpen && !root.languageExpanded && !root.sensorsOpen && !processActions.confirmationOpen && root.selectedProcess)
          processActions.request(root.selectedProcess, false)
      }
      onTabRequested: function(direction) {
        if (processActions.confirmationOpen) {
          processConfirm.selectedIndex = processConfirm.selectedIndex === 0 ? 1 : 0
          return
        }
        if (root.settingsOpen || root.languageExpanded) return
        root.switchPanel(direction)
      }
      onTextKey: function(text) {
        if (processActions.confirmationOpen) return
        var raw = String(text || "")
        var key = raw.toLowerCase()
        if (key === "e") root.setExpanded(!root.expanded)
        else if (key === "s") root.setSettingsOpen(!root.settingsOpen)
        else if (key === "?") root.hintsVisible = !root.hintsVisible
        else if (root.settingsOpen || root.languageExpanded) return
        else if (key === "h") { processActions.cancel(); root.fansOpen = false; root.sensorsOpen = !root.sensorsOpen }
        else if (root.sensorsOpen) return
        else if (key === "r") root.refresh()
        else if (key === "x" && root.selectedProcess) processActions.request(root.selectedProcess, false)
        else if (key === "/" && root.expanded) root.focusSearch()
        else if (key === "d" && root.expanded) root.cycleDisk(raw === "D" ? -1 : 1)
        else if (key === "v" && root.expanded) root.cycleStorage(raw === "V" ? -1 : 1)
        else if (key === "c") root.setSort("cpu")
        else if (key === "m") root.setSort("memory")
        else if (key === "p") root.setSort("pid")
        else if (key === "t" && root.expanded) root.setSort("runtime")
        else if (key === "n") root.setSort("name")
      }

      // 1. Permanent Pinned Header: Outside all scrolling!
      ActivityHeader {
        id: persistentHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(36)
      }

      // 2. Expandable Language Selection (matches slovn.mx-ergo & slovn.cetra standard)
      Column {
        id: languageSection
        visible: root.languageExpanded
        anchors.top: persistentHeader.bottom
        anchors.topMargin: Style.spacing.md
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(8)
        z: 60

        PanelSectionHeader {
          width: parent.width
          text: I18n.t("language", root.effectiveLanguage)
          foreground: root.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Grid {
          id: languageGrid
          width: parent.width
          columns: 3
          spacing: Style.space(6)

          readonly property real itemWidth: Math.floor((width - spacing * 2) / 3)

          Repeater {
            model: [
              { code: "system", label: I18n.t("lang_system", root.effectiveLanguage) },
              { code: "ru", label: "Русский" },
              { code: "en", label: "English" },
              { code: "de", label: "Deutsch" },
              { code: "zh", label: "简体中文" }
            ]

            Button {
              width: languageGrid.itemWidth
              height: Style.space(32)
              text: modelData.label
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              fontSize: Style.font.caption
              foreground: root.foreground
              accent: root.accent
              bordered: true
              focusable: true
              selected: root.setting("locale", "ru") === modelData.code
              onClicked: {
                var code = modelData.code
                root.languageExpanded = false
                root.persistSettings({ locale: code })
              }
            }
          }
        }
      }

      Row {
        id: pageTabs
        objectName: "pageTabs"
        visible: !root.settingsOpen && !root.languageExpanded
        anchors.top: persistentHeader.bottom
        anchors.topMargin: Style.spacing.sm
        width: parent.width
        spacing: Style.spacing.sm
        Repeater {
          model: [
            { key: "overview", icon: "overview", sensors: false, fans:false },
            { key: "sensors", icon: "temperature", sensors: true, fans:false },
            { key: "fans", icon: "fans", sensors: true, fans:true }
          ]
          SvgButton {
            required property var modelData
            width: (pageTabs.width - pageTabs.spacing * 2) / 3
            height: Style.space(30)
            text: I18n.t(modelData.key, root.effectiveLanguage)
            iconName: modelData.icon
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            fontSize: Style.font.bodySmall
            foreground: root.foreground
            accent: root.accent
            bordered: true
            focusable: true
            selected: root.sensorsOpen === modelData.sensors && root.fansOpen === modelData.fans
            onClicked: {
              processActions.cancel()
              root.computerMapVisible = false
              root.historyFanChannel = ""
              root.sensorPart = ""
              root.focusedFanChannel = ""
              root.fansOpen = modelData.fans
              root.sensorsOpen = modelData.sensors
              if (root.sensorsOpen && !root.fansOpen) root.loadSensorHistory()
            }
          }
        }
      }

      // The header and tabs stay pinned; each page owns its internal scrolling.
      Item {
        id: pageArea
        visible: !root.languageExpanded
        anchors.top: pageTabs.visible ? pageTabs.bottom : persistentHeader.bottom
        anchors.topMargin: Style.spacing.sm
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Loader {
          id: contentLoader
          anchors.fill: parent
          sourceComponent: root.settingsOpen
            ? settingsContent
            : (root.sensorsOpen ? (root.fansOpen ? fansContent : sensorsContent) : (root.expanded ? expandedContent : compactContent))
        }
      }

      ConfirmDialog {
        id: processConfirm
        anchors.fill: parent
        opened: processActions.confirmationOpen
        z: 100
        message: processActions.pendingAction
          ? I18n.t(processActions.pendingAction.action === "KILL" ? "confirm_kill" : "confirm_terminate",
                   root.effectiveLanguage,
                   processActions.pendingAction.name,
                   processActions.pendingAction.pid)
          : ""
        confirmText: processActions.pendingAction && processActions.pendingAction.action === "KILL"
          ? I18n.t("btn_kill", root.effectiveLanguage)
          : I18n.t("btn_terminate", root.effectiveLanguage)
        cancelText: I18n.t("cancel", root.effectiveLanguage)
        background: Host.Color.popups.background
        foreground: root.foreground
        selectedText: root.accent
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        cornerRadius: Style.cornerRadius
        onCanceled: processActions.cancel()
        onConfirmed: processActions.confirm()
      }
    }
  }

  component SvgButton: Button {
    id: svgButton
    property string iconName: ""
    iconText: iconName ? "\u2003" : ""
    SvgIcon {
      id: buttonSvg
      name: svgButton.iconName
      width: svgButton.iconSize
      height: width
      anchors.centerIn: parent
      tint: svgButton.selected ? svgButton._selectedColor : svgButton.foreground
      // Follow the native glyph slot even when the label is fitted or elided.
      Component.onCompleted: {
        var rows = svgButton.children
        for (var i = 0; i < rows.length; i++) {
          var items = rows[i].children || []
          for (var j = 0; j < items.length; j++) {
            if (items[j].text === "\u2003") { buttonSvg.parent = items[j]; return }
          }
        }
      }
    }
  }

  component SvgActionButton: PanelActionButton {
    id: svgAction
    property string iconName: ""
    SvgIcon {
      anchors.centerIn: parent
      name: svgAction.iconName
      width: Math.min(Style.space(16), svgAction.width - Style.spacing.sm)
      height: width
      tint: svgAction.enabled ? (svgAction._hot ? svgAction.hoverColor : svgAction.foreground)
        : Qt.darker(svgAction.foreground, 2)
    }
    Accessible.name: tooltipText
  }

  // --- Header Component: Permanent, outside scrolling, uniform 24px button height ---
  component ActivityHeader: Item {
    id: activityHeader
    readonly property int headerControlHeight: Style.space(24)

    Row {
      anchors.left: parent.left
      anchors.right: headerControls.left
      anchors.rightMargin: Style.spacing.md
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.md

      ActivityIcon {
        id: headerIcon
        objectName: "activityHeaderIcon"
        width: Style.font.display
        height: width
        cpu: activity.glanceCpu
        ram: activity.glanceMemory
        fresh: activity.glanceFresh
        loadThreshold: root.iconLoadThresholdSetting
        shape: root.iconShapeSetting
        hot: activity.heatAlert
        heatLevel: activity.heatLevel
        temperatureFresh: activity.thermalFresh
        thermalSampleAt: activity.thermalUpdatedAt
        motionEnabled: root.booleanSetting("iconMotion", true)
        foreground: root.foreground
        background: Host.Color.popups.background
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        width: Math.max(0, parent.width - headerIcon.width - parent.spacing)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: root.settingsOpen
            ? I18n.t("title", root.effectiveLanguage) + " · " + I18n.t("settings", root.effectiveLanguage)
            : root.sensorsOpen ? I18n.t("title", root.effectiveLanguage) + " · " + I18n.t(root.fansOpen ? "fans" : "sensors", root.effectiveLanguage)
            : (root.expanded
              ? I18n.t("title", root.effectiveLanguage) + " · " + I18n.t("all_processes", root.effectiveLanguage)
              : I18n.t("title", root.effectiveLanguage))
          color: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
        }

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: root.hasSnapshot
            ? (I18n.t("uptime_prefix", root.effectiveLanguage) + " " + Model.formatDuration(root.snapshot.uptime))
            : I18n.t("sampling", root.effectiveLanguage)
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }

    Row {
      id: headerControls
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.xs

      // Native language control keeps the same height with a font-independent icon.
      SvgButton {
        id: headerLanguageButton
        height: parent.parent.headerControlHeight
        anchors.verticalCenter: parent.verticalCenter
        text: root.effectiveLanguage.toUpperCase()
        iconName: "language"
        iconSize: Style.font.bodySmall
        fontSize: Style.font.caption
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        foreground: root.foreground
        accent: root.accent
        bordered: true
        focusable: true
        selected: root.languageExpanded
        horizontalPadding: Style.space(7)
        verticalPadding: 0
        tooltipText: I18n.t("language", root.effectiveLanguage) + " (" + root.effectiveLanguage.toUpperCase() + ")"
        onClicked: {
          root.languageExpanded = !root.languageExpanded
        }
      }

      SvgActionButton {
        visible: !root.settingsOpen
        size: parent.parent.headerControlHeight
        anchors.verticalCenter: parent.verticalCenter
        iconName: "help"
        tooltipText: I18n.t("shortcuts", root.effectiveLanguage)
        foreground: root.hintsVisible ? root.accent : root.foreground
        hoverColor: root.accent
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        bordered: true
        hasCursor: root.hintsVisible
        onClicked: root.hintsVisible = !root.hintsVisible
      }

      SvgActionButton {
        id: settingsButton
        size: parent.parent.headerControlHeight
        anchors.verticalCenter: parent.verticalCenter
        iconName: "settings"
        tooltipText: I18n.t("settings", root.effectiveLanguage)
        foreground: root.settingsOpen ? root.accent : root.foreground
        hoverColor: root.accent
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        bordered: true
        hasCursor: root.settingsOpen
        onClicked: root.setSettingsOpen(!root.settingsOpen)
      }

      SvgActionButton {
        id: expandButton
        objectName: "expandButton"
        size: parent.parent.headerControlHeight
        anchors.verticalCenter: parent.verticalCenter
        iconName: root.expanded ? "collapse" : "expand"
        tooltipText: root.expanded ? I18n.t("collapse", root.effectiveLanguage) : I18n.t("expand", root.effectiveLanguage)
        foreground: root.foreground
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        bordered: true
        onClicked: root.setExpanded(!root.expanded)
      }
    }
  }

  // --- Compact Content: Fits 100% within 480x390 without scrolling ---
  Component {
    id: compactContent

    Item {
      anchors.fill: parent

      // Pinned Action Buttons at bottom
      Row {
        id: compactActions
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(28)
        spacing: Style.spacing.md

        SvgButton {
          width: (parent.width - parent.spacing) / 2
          height: parent.height
          text: I18n.t("btn_terminate", root.effectiveLanguage)
          iconName: "stop"
          focusable: true
          bordered: true
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          enabled: !!root.selectedProcess && !processActions.running
          onClicked: processActions.request(root.selectedProcess, false)
        }

        SvgButton {
          width: (parent.width - parent.spacing) / 2
          height: parent.height
          text: I18n.t("btn_kill", root.effectiveLanguage)
          iconName: "kill"
          focusable: true
          bordered: true
          foreground: root.urgent
          accent: root.urgent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          enabled: !!root.selectedProcess && !processActions.running
          onClicked: processActions.request(root.selectedProcess, true)
        }
      }

      // Shortcut Hints / Status Bar (appears right above bottom buttons when `?` is active)
      BorderSurface {
        id: compactHintBar
        visible: root.hintsVisible || activity.errorText !== "" || processActions.status !== ""
        anchors.bottom: compactActions.top
        anchors.bottomMargin: Style.spacing.xs
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? Style.space(22) : 0
        color: Style.normalFillFor(root.foreground, root.accent)
        borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
        radius: Style.cornerRadius

        Text {
          anchors.centerIn: parent
          width: parent.width - Style.spacing.md * 2
          text: activity.errorText || processActions.status || I18n.t("hints_compact", root.effectiveLanguage)
          textFormat: Text.PlainText
          color: (activity.errorText !== "" || processActions.failed) ? root.urgent : root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
      }

      // Middle content pinned between top of pageArea and compactHintBar / compactActions
      Column {
        id: compactBody
        anchors.top: parent.top
        anchors.bottom: compactHintBar.visible ? compactHintBar.top : compactActions.top
        anchors.bottomMargin: Style.spacing.xs
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.spacing.xs

        Flickable {
          width: parent.width
          height: Math.min(root.tileHeight, Math.max(Style.space(80), compactBody.height - Style.space(100)
            - (root.compactRamStrip ? root.ramStripHeight + compactBody.spacing : 0)))
          contentWidth: width
          contentHeight: compactGrid.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Grid {
          id: compactGrid
          width: parent.width - Style.spacing.xs
          columns: Math.max(1, root.compactTiles.length)
          spacing: Style.spacing.sm
          Repeater {
            model: root.compactTiles
            SummaryTile {
              required property string modelData
              tile: modelData
              width: (compactGrid.width - compactGrid.spacing * (compactGrid.columns - 1)) / compactGrid.columns
              height: root.tileHeight
            }
          }
        }
        }

        DetailSurface {
          id: memoryStrip
          objectName: "compactRamStrip"
          visible: root.compactRamStrip
          width: parent.width
          height: visible ? root.ramStripHeight : 0
          readonly property bool ready: root.hasSnapshot && root.snapshot.memory.total > 0
          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Style.spacing.sm
            anchors.rightMargin: Style.spacing.sm
            anchors.topMargin: Style.spacing.xs
            text: I18n.t("ram", root.effectiveLanguage) + "  " + (memoryStrip.ready
              ? root.percentText(root.metrics.memory) + " · "
                + Model.formatCompactBytes(root.snapshot.memory.total - root.snapshot.memory.available)
                + " / " + Model.formatCompactBytes(root.snapshot.memory.total)
              : "—")
            textFormat: Text.PlainText
            color: memoryStrip.ready ? root.pressureColor(root.metrics.memory) : root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            elide: Text.ElideRight
          }
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.spacing.sm
            anchors.bottomMargin: Style.spacing.xs
            height: Style.space(3)
            radius: height / 2
            color: Util.alpha(root.foreground, 0.12)
            Rectangle {
              visible: memoryStrip.ready
              width: parent.width * Math.max(0, Math.min(1, root.metrics.memory / 100))
              height: parent.height
              radius: parent.radius
              color: root.pressureColor(root.metrics.memory)
            }
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        // Active Processes section with aligned header & absolute RAM
        Column {
          id: compactProcesses
          width: parent.width
          spacing: Style.space(2)

          ProcessHeader {
            id: compactTableHeader
            width: parent.width
            compact: true
          }

          Text {
            visible: root.topProcesses.length === 0
            text: root.processMetricsReady ? I18n.t("no_processes", root.effectiveLanguage) : I18n.t("sampling", root.effectiveLanguage)
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Repeater {
            model: root.topProcesses

            ProcessRow {
              required property var modelData
              required property int index
              width: parent.width
              processData: modelData
              rowIndex: index
              compact: true
              selected: root.cursorActive && root.selectedProcessKey === Model.processIdentityKey(modelData)
            }
          }
        }
      }
      Binding {
        target: root
        property: "compactProcessLimit"
        value: Math.max(0, Math.min(4, Math.floor(
          (compactBody.height - compactProcesses.y - compactTableHeader.height)
            / (root.processRowHeight + compactProcesses.spacing))))
      }
    }
  }

  component ComputerNavigator: Column {
    property bool showToggle: true
    width: parent.width
    spacing: Style.spacing.sm
    SvgButton {
      width: parent.width
      objectName: parent.showToggle ? "computerMapToggle" : "navigatorMapToggle"
      visible: parent.showToggle
      text: I18n.t(root.computerMapVisible ? "map_close" : "map_open", root.effectiveLanguage)
      iconName: "overview"
      selected: root.computerMapVisible
      foreground: root.foreground; accent: root.accent
      fontFamily: Style.font.family; fontSize: Style.font.bodySmall
      bordered: true; focusable: true
      onClicked: root.computerMapVisible = !root.computerMapVisible
    }
    ComputerMap {
      width: parent.width
      height: visible ? Math.min(implicitHeight, Style.space(285)) : 0
      visible: root.computerMapVisible
      language: root.effectiveLanguage
      selectedPart: root.sensorPart
      onPicked: function(part) { root.selectPart(part) }
    }
    Grid {
      id: mapLegend
      objectName: "mapLegend"
      width: parent.width
      visible: root.computerMapVisible
      columns: width >= Style.space(600) ? 3 : 2
      spacing: Style.spacing.xs
      Repeater {
        model: ["fan_rear","cpu","memory","fan_cpu","gpu","storage","motherboard","fan_front","fan_top","fan_ssd"]
        Button {
          required property string modelData
          required property int index
          objectName: "mapLegendPart" + index
          width: Math.floor((mapLegend.width-mapLegend.spacing*(mapLegend.columns-1))/mapLegend.columns)
          height: Style.space(25)
          text: (index+1)+" · "+I18n.t("map_"+modelData,root.effectiveLanguage)
          foreground: root.foreground; accent: root.accent
          fontFamily: Style.font.family; fontSize: Style.font.caption; bordered:true;focusable:true
          onClicked: root.selectPart(modelData)
        }
      }
    }
    Text {
      visible: root.computerMapVisible
      width: parent.width
      text: I18n.t("map_hint", root.effectiveLanguage)
      textFormat: Text.PlainText; wrapMode: Text.Wrap
      color: root.dim; font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    Button {
      width: parent.width
      objectName: "clearSensorFilter"
      visible: !root.computerMapVisible && root.sensorPart !== ""
      text: I18n.t("map_filter", root.effectiveLanguage, I18n.t("map_" + root.sensorPart, root.effectiveLanguage))
      foreground: root.foreground; accent: root.accent
      fontFamily: Style.font.family; fontSize: Style.font.caption
      bordered: true; focusable: true
      onClicked: { root.sensorPart = ""; root.focusedFanChannel = "" }
    }
  }

  component PageScrollBar: ScrollBar {
    required property Flickable viewport
    parent: viewport.parent
    anchors.top: viewport.top
    anchors.bottom: viewport.bottom
    anchors.left: viewport.right
    anchors.leftMargin: Style.spacing.xs
    width: Style.space(4)
    padding: 0
    policy: ScrollBar.AlwaysOn
    visible: size < 1
    contentItem: Rectangle { implicitWidth: Style.space(4); implicitHeight: Style.space(40); color: root.accent; opacity: 0.65 }
    background: null
    Connections {
      target: viewport.Window.window
      function onActiveFocusItemChanged() {
        var item = viewport.Window.window.activeFocusItem
        var ancestor = item
        while (ancestor && ancestor !== viewport.contentItem) ancestor = ancestor.parent
        if (!ancestor) return
        var top = item.mapToItem(viewport.contentItem, 0, 0).y
        if (top < viewport.contentY) viewport.contentY = Math.max(0, top)
        else if (top + item.height > viewport.contentY + viewport.height)
          viewport.contentY = Math.max(0, Math.min(viewport.contentHeight - viewport.height, top + item.height - viewport.height))
      }
    }
  }

  Component {
    id: sensorsContent
    Flickable {
      id: coolingViewport
      objectName: "coolingViewport"
      anchors.fill: parent
      contentWidth: width
      contentHeight: coolingBody.implicitHeight
      clip: true; boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: PageScrollBar { objectName: "coolingScrollBar"; viewport: coolingViewport }
      onContentHeightChanged: contentY = Math.max(0, Math.min(contentY, contentHeight - height))
      Column {
        id: coolingBody
        objectName: "coolingBody"
        width: parent.width
        spacing: Style.spacing.sm
        Row {
          width: parent.width; spacing: Style.spacing.sm
          SvgButton {
            objectName: "computerMapToggle"
            tooltipText: I18n.t("map_open", root.effectiveLanguage)
            width: (parent.width-parent.spacing*2)/3
            height: Style.spacing.controlHeight
            text: I18n.t(root.computerMapVisible ? "map_close_short" : "map_open_short", root.effectiveLanguage)
            iconName: "overview"; selected: root.computerMapVisible
            foreground: root.foreground; accent: root.accent
            fontFamily: Style.font.family; fontSize: Style.font.caption; bordered: true; focusable: true
            onClicked: root.computerMapVisible = !root.computerMapVisible
          }
          SvgButton {
            width: (parent.width-parent.spacing*2)/3
            height: Style.spacing.controlHeight
            text: I18n.t(activity.sensorRecording ? "sensor_recording_short_on" : "sensor_recording_short_off",root.effectiveLanguage)
            iconName: "storage"; selected: activity.sensorRecording
            foreground: root.foreground; accent: root.accent
            fontFamily: Style.font.family; fontSize: Style.font.caption
            bordered: true; focusable: true
            tooltipText: I18n.t("sensor_recording_hint",root.effectiveLanguage)
            onClicked: root.persistSettings({sensorRecording:!activity.sensorRecording})
          }
          SvgButton {
            width: (parent.width-parent.spacing*2)/3
            height: Style.spacing.controlHeight
            objectName: "sensorOptionsToggle"
            tooltipText: I18n.t("map_sensor_assignment", root.effectiveLanguage)
            text: I18n.t("map_category_short",root.effectiveLanguage)
            iconName: "settings"; selected: root.sensorOptionsOpen
            foreground: root.foreground; accent: root.accent
            fontFamily: Style.font.family; fontSize: Style.font.caption
            bordered: true; focusable: true
            onClicked: root.sensorOptionsOpen=!root.sensorOptionsOpen
          }
        }
        ComputerNavigator { showToggle: false; visible: root.computerMapVisible || root.sensorPart !== "" }
        SvgButton {
          objectName: "backToFanControls"
          visible: root.historyFanChannel !== "" && !root.computerMapVisible
          width: parent.width
          text: I18n.t("fan_back_controls", root.effectiveLanguage, root.historyFanChannel)
          iconName: "fans"; foreground: root.foreground; accent: root.accent
          fontFamily: Style.font.family; fontSize: Style.font.caption; focusable: true; bordered: true
          onClicked: root.returnToFanControls()
        }
      Column {
        id: coolingControls
        visible: !root.computerMapVisible
        width: parent.width
        spacing: Style.spacing.sm

        Text {
          width: parent.width
          visible: activity.sensorRecordingError !== "" || root.historyReadError
          text: I18n.t(root.historyReadError ? "sensor_history_error" : "sensor_recording_error",root.effectiveLanguage)
          textFormat: Text.PlainText; wrapMode: Text.Wrap
          color: activity.sensorRecordingError || root.historyReadError ? root.urgent : root.dim
          font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        Button {
          objectName: "retrySensorHistory"
          visible: root.historyReadError
          width: parent.width
          text: I18n.t("sensor_history_retry", root.effectiveLanguage)
          foreground: root.foreground; accent: root.accent; fontFamily: Style.font.family
          fontSize: Style.font.caption; bordered: true; focusable: true; enabled: !root.historyPending
          onClicked: root.loadSensorHistory()
        }
        Dropdown {
          width: parent.width
          enabled: root.filteredSensors.length > 0
          objectName: "sensorDropdown"
          label: I18n.t("sensor_device", root.effectiveLanguage)
          value: root.selectedSensor ? root.selectedSensor.id : ""
          options: root.filteredSensors.map(function(sensor) {
            return {value:sensor.id,label:root.sensorOwner(sensor) + " · " + root.sensorLabel(sensor)}
          })
          foreground: root.foreground; accent: root.accent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onChanged: function(value) { root.selectedSensorId = value }
        }
        Row {
          width: parent.width
          spacing: Style.spacing.xs
          Repeater {
            model: [600, 3600, 21600]
            Button {
              required property int modelData
              width: (coolingControls.width - Style.spacing.xs * 2) / 3
              height: Style.space(26)
              text: modelData < 3600 ? I18n.t("sensor_minutes",root.effectiveLanguage,modelData/60)
                : I18n.t("sensor_hours",root.effectiveLanguage,modelData/3600)
              selected: root.sensorWindowSeconds === modelData
              foreground: root.foreground; accent: root.accent
              fontSize: Style.font.caption
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              bordered: true; focusable: true
              onClicked: { root.sensorWindowSeconds = modelData; root.loadSensorHistory() }
            }
          }
        }
      }
        Text {
          width:parent.width
          visible:!root.computerMapVisible && root.fanStatusKey!==""
          text:I18n.t(root.fanStatusKey,root.effectiveLanguage)
          textFormat:Text.PlainText;wrapMode:Text.Wrap
          color:root.fanStatusKey==="fan_action_failed" ? root.urgent : root.dim
          font.family:Style.font.family;font.pixelSize:Style.font.caption
        }
        SensorCard {
          id: selectedSensorCard
          visible: !root.computerMapVisible && !!root.selectedSensor
          width: parent.width
          height: visible ? implicitHeight : 0
          sensor: root.selectedSensor || ({})
          fan: sensor.fan === true
        }
        Text {
          visible: !root.computerMapVisible && !root.selectedSensor
          width: parent.width
          text: root.historyPending ? I18n.t("sampling",root.effectiveLanguage)
            : I18n.t(root.sensorPart ? "map_no_sensors" : "no_temperature_sensors",root.effectiveLanguage)
          textFormat: Text.PlainText; wrapMode: Text.Wrap
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  Component {
    id: fansContent
    Flickable {
      id: fansViewport
      objectName: "fansViewport"
      anchors.fill: parent
      contentWidth: width
      contentHeight: fanBody.implicitHeight
      clip: true; boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: PageScrollBar { objectName: "fansScrollBar"; viewport: fansViewport }
      onContentHeightChanged: contentY = Math.max(0, Math.min(contentY, contentHeight - height))
      Column {
        id: fanBody
        objectName: "fanBody"
        width: parent.width
        spacing: Style.spacing.sm
        ComputerNavigator {}
        Text {
          width:parent.width
          visible:!root.computerMapVisible && root.fanStatusKey!==""
          text:I18n.t(root.fanStatusKey,root.effectiveLanguage)
          textFormat:Text.PlainText;wrapMode:Text.Wrap
          color:root.fanStatusKey==="fan_action_failed" ? root.urgent : root.dim
          font.family:Style.font.family;font.pixelSize:Style.font.caption
        }
        Column {
          width: parent.width
          visible: !root.computerMapVisible
          spacing: Style.spacing.sm
          Dropdown {
            objectName: "fanChannelDropdown"
            width: parent.width
            label: I18n.t("map_channel",root.effectiveLanguage)
            enabled: !!root.activeFanChannel
            value: root.activeFanChannel
            options: (activity.sensorSnapshot.controls || []).map(function(channel) {
              return {value:channel.id,label:channel.id+" · "+I18n.t("map_"+root.fanPlace(channel.id),root.effectiveLanguage)+" · "+I18n.t("fan_rpm",root.effectiveLanguage,channel.rpm)}
            })
            foreground: root.foreground; accent: root.accent; fontFamily:Style.font.family
            onChanged: function(value) { root.focusedFanChannel=value; root.fanIdentificationOpen=false }
          }
        }
        Text {
          visible: !root.computerMapVisible && root.sensorPart.indexOf("fan_") === 0
          width: parent.width
          text: I18n.t("map_assignment_hint", root.effectiveLanguage)
          textFormat: Text.PlainText; wrapMode: Text.Wrap
          color: root.dim; font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        Repeater {
          model: root.computerMapVisible ? [] : (activity.sensorSnapshot.controls || []).filter(function(channel) {
            return channel.id === root.activeFanChannel
          })
          DetailSurface {
            id: fanChannelCard
            required property var modelData
            width: fanBody.width
            height: channelBody.implicitHeight + Style.spacing.md * 2
            Column {
              id: channelBody
              x: Style.spacing.md; y: Style.spacing.md
              width: parent.width - Style.spacing.md * 2
              spacing: Style.spacing.sm
              SvgButton {
                objectName: "fanAssignmentToggle"
                height: Style.spacing.controlHeight
                width: parent.width
                text: I18n.t("map_assignment", root.effectiveLanguage, fanChannelCard.modelData.id)
                iconName: "settings"; selected: root.fanAssignmentOpen
                foreground: root.foreground; accent: root.accent; fontFamily: Style.font.family
                fontSize: Style.font.caption; bordered: true; focusable: true
                onClicked: root.fanAssignmentOpen = !root.fanAssignmentOpen
              }
              Dropdown {
                objectName: "fanAssignmentDropdown"
                width: parent.width
                visible: root.fanAssignmentOpen
                label: I18n.t("map_assignment", root.effectiveLanguage, fanChannelCard.modelData.id)
                value: root.fanPlace(fanChannelCard.modelData.id)
                options: root.fanPlaces.map(function(place) { return {value:place,label:I18n.t("map_" + place,root.effectiveLanguage)} })
                foreground: root.foreground; accent: root.accent
                fontFamily: Style.font.family
                onChanged: function(place) { root.assignFan(fanChannelCard.modelData.id, place) }
              }
              Text {
                width: parent.width
                text: modelData.id + " · " + I18n.t("fan_rpm",root.effectiveLanguage,modelData.rpm)
                  + " · " + Math.round(modelData.duty/255*100) + "% · "
                  + I18n.t(modelData.mode === 2 ? "fan_mode_auto" : modelData.mode === 0 ? "fan_mode_full" : "fan_mode_manual",root.effectiveLanguage)
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: root.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
              Row {
                width: parent.width; spacing:Style.spacing.sm
                Dropdown {
                  id: fanDurationDropdown
                  objectName: "fanDurationDropdown"
                  width:(parent.width-parent.spacing)/2
                  label:I18n.t("fan_boost_duration",root.effectiveLanguage)
                  value:String(root.fanDuration)
                  options:[5,10,30].map(function(n){return {value:String(n),label:I18n.t("sensor_minutes",root.effectiveLanguage,n)}})
                  foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
                  onChanged:function(value){root.fanDuration=Number(value)}
                }
                SvgButton {
                  width:(parent.width-parent.spacing)/2
                  anchors.bottom:parent.bottom
                  objectName: "fanHistoryButton"
                  height: fanDurationDropdown.rowHeight
                  text:I18n.t("map_fan_history",root.effectiveLanguage);iconName:"overview"
                  foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
                  bordered:true;focusable:true
                  onClicked:root.showFanHistory(fanChannelCard.modelData.id)
                }
              }
              Row {
                id: speeds
                width: parent.width
                spacing: Style.spacing.xs
                Repeater {
                  model: [60,80,100]
                  Button {
                    required property int modelData
                    width: (speeds.width - speeds.spacing*2)/3
                    text: I18n.t("fan_boost_percent", root.effectiveLanguage, modelData)
                    foreground: root.foreground; accent: root.accent
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    focusable: true; bordered: true; enabled: !fanController.running
                    onClicked: root.fanAction(channelBody.parent.modelData.id, modelData, "boost")
                  }
                }
              }
              SvgButton {
                objectName: "fanIdentificationToggle"
                width: parent.width
                text: I18n.t(root.fanIdentificationOpen ? "fan_identify_close" : "fan_identify_open", root.effectiveLanguage)
                iconName: "fans"; selected: root.fanIdentificationOpen
                foreground: root.foreground; accent: root.accent; fontFamily: Style.font.family
                fontSize: Style.font.caption; bordered: true; focusable: true
                onClicked: root.fanIdentificationOpen = !root.fanIdentificationOpen
              }
              Row {
                visible: root.fanIdentificationOpen
                width:parent.width;spacing:Style.spacing.sm
                Dropdown {
                  id: identifyPercentDropdown
                  objectName:"identifyPercentDropdown"
                  width:(parent.width-parent.spacing)/2
                  label:I18n.t("fan_identify_level",root.effectiveLanguage)
                  value:String(root.identificationPercent)
                  options:[0,5,10,20,30,40,50,60,80,100].map(function(n){return {value:String(n),label:n+"%"}})
                  foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family
                  onChanged:function(value){root.identificationPercent=Number(value)}
                }
                SvgButton {
                  objectName:"identifyFanButton"
                  height: identifyPercentDropdown.rowHeight
                  width:(parent.width-parent.spacing)/2;anchors.bottom:parent.bottom
                  text:I18n.t("fan_identify",root.effectiveLanguage);iconName:"fans"
                  foreground:root.urgent;accent:root.urgent;fontFamily:Style.font.family
                  bordered:true;focusable:true;enabled:!fanController.running
                  onClicked:root.fanAction(fanChannelCard.modelData.id,root.identificationPercent,"identify")
                }
              }
              Text {
                width:parent.width
                visible: root.fanIdentificationOpen
                text:I18n.t("fan_identify_hint",root.effectiveLanguage)
                textFormat:Text.PlainText;wrapMode:Text.Wrap
                color:root.dim;font.family:Style.font.family;font.pixelSize:Style.font.caption
              }
              SvgButton {
                objectName: "fanRestoreButton"
                width: parent.width
                text: I18n.t("fan_restore",root.effectiveLanguage)
                iconName: "restore"
                foreground: root.foreground; accent: root.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                focusable: true; bordered: true; enabled: !fanController.running
                onClicked: root.fanAction(modelData.id,100,"restore")
              }
            }
          }
        }
        Text {
          width: parent.width
          visible: !root.computerMapVisible && (!activity.sensorSnapshot.controls || activity.sensorSnapshot.controls.length === 0)
          text: I18n.t("fan_control_unavailable",root.effectiveLanguage)
          textFormat: Text.PlainText; wrapMode: Text.Wrap
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  component SensorCard: DetailSurface {
    id: sensorCard
    property var sensor: ({})
    property bool fan: false
    readonly property double chartNow: Math.max(Date.now()/1000, activity.freshnessClock/1000)
    readonly property var points: {
      var saved = root.savedSensors.filter(function(item) { return item.id === sensor.id })[0]
      var live = sensor.id ? activity.sensorHistory[sensor.id] || [] : []
      var offset = (activity.sensorsUpdatedAt || Date.now())/1000 - activity.sensorSnapshot.sample
      var all = (saved ? saved.history : []).concat(live.map(function(point) { return {time:point.wallTime || point.time + offset,value:point.value,breakBefore:point.breakBefore} }))
      var byTime = {}
      all.forEach(function(point) { byTime[point.time] = point })
      all = Object.keys(byTime).map(function(time) { return byTime[time] })
      var cutoff = chartNow - root.sensorWindowSeconds
      return all.filter(function(point) { return point.time >= cutoff && point.time <= chartNow }).sort(function(a,b) { return a.time-b.time })
    }
    readonly property var readings: points.map(function(point) { return point.value })
    readonly property bool historyGaps: points.some(function(point,index) { return point.breakBefore === true || (index > 0 && point.breakBefore === undefined && point.time - points[index-1].time > 60) })
    readonly property real span: points.length > 1 ? points[points.length - 1].time - points[0].time : 0
    function valueText(value) {
      if (!fan) return Model.formatTemperature(value, root.temperatureUnitSetting)
      return sensor.unit === "percent" ? Math.round(value) + "%"
        : I18n.t("fan_rpm", root.effectiveLanguage, Math.round(value))
    }
    implicitHeight: sensorCardBody.implicitHeight + Style.spacing.md * 2
    height: implicitHeight
    Column {
      id: sensorCardBody
      x: Style.spacing.md
      y: Style.spacing.md
      width: parent.width - Style.spacing.md * 2
      spacing: Style.spacing.xs
      Dropdown {
        objectName: "sensorAssignmentDropdown"
        width: parent.width
        visible: root.sensorOptionsOpen
        label: I18n.t("map_sensor_assignment", root.effectiveLanguage)
        value: root.sensorPlace(sensorCard.sensor)
        options: root.sensorPlaces.map(function(place) { return {value:place,label:I18n.t("map_" + place,root.effectiveLanguage)} })
        foreground: root.foreground; accent: root.accent
        fontFamily: Style.font.family
        onChanged: function(place) { root.assignSensor(sensorCard.sensor, place) }
      }
      Text {
        width: parent.width
        visible: root.expanded || root.sensorOptionsOpen
        text: root.sensorOwner(sensorCard.sensor)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
      Text {
        width: parent.width
        text: root.sensorLabel(sensorCard.sensor)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }
      Text {
        width: parent.width
        visible: root.sensorOptionsOpen
        text: [sensorCard.sensor.chip, sensorCard.sensor.label, sensorCard.sensor.location || sensorCard.sensor.id].join(" · ")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }
      Text {
        width: parent.width
        text: activity.sensorsFresh && root.currentSensors.some(function(item) { return item.id === sensorCard.sensor.id })
          && sensorCard.sensor.value !== undefined ? sensorCard.valueText(sensorCard.sensor.value) : "—"
        textFormat: Text.PlainText
        color: !sensorCard.fan && sensorCard.sensor.value >= activity.heatThreshold ? root.urgent : root.accent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.heading
        font.bold: true
      }
      SensorHistoryChart {
        width: parent.width
        height: Style.space(132)
        points: sensorCard.points.map(function(point) { return {time:point.time,value:!sensorCard.fan && root.temperatureUnitSetting === "Fahrenheit" ? point.value*9/5+32 : point.value,breakBefore:point.breakBefore} })
        windowSeconds: root.sensorWindowSeconds
        referenceTime: sensorCard.chartNow
        liveText: I18n.t("chart_live",root.effectiveLanguage)
        gapText: I18n.t("chart_gap",root.effectiveLanguage)
        emptyText: I18n.t(root.historyPending ? "sampling" : "chart_empty",root.effectiveLanguage)
        ceiling: sensorCard.fan ? (sensorCard.sensor.unit === "percent" ? 100 : 0) : (root.temperatureUnitSetting === "Fahrenheit" ? 248 : 120)
        unit: sensorCard.fan ? (sensorCard.sensor.unit === "percent" ? "%" : "RPM") : (root.temperatureUnitSetting === "Fahrenheit" ? "°F" : "°C")
        hint: I18n.t("chart_short_hint",root.effectiveLanguage)
        lineColor: root.accent
      }
      Text {
        width: parent.width
        visible: root.sensorOptionsOpen
        text: I18n.t("chart_interaction",root.effectiveLanguage)
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: root.dim; font.family: Style.font.family; font.pixelSize: Style.font.caption
      }
      Text {
        width: parent.width
        text: sensorCard.readings.length > 1
          ? I18n.t("sensor_range", root.effectiveLanguage,
              sensorCard.valueText(Math.min.apply(null, sensorCard.readings)),
              sensorCard.valueText(Math.max.apply(null, sensorCard.readings)))
            + " · " + I18n.t("sensor_duration", root.effectiveLanguage, Math.round(sensorCard.span))
            + (sensorCard.historyGaps ? " · " + I18n.t("sensor_gaps",root.effectiveLanguage) : "")
          : I18n.t("sensor_wait_history", root.effectiveLanguage)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  // --- Settings Content: Header is static outside, body scrolls internally ---
  Component {
    id: settingsContent

    Item {
      anchors.fill: parent

      // Done button pinned at bottom
      Row {
        id: settingsActions
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(32)
        spacing: Style.spacing.md

        SvgButton {
          width: (parent.width - parent.spacing) / 2
          height: parent.height
          text: I18n.t("reset_defaults", root.effectiveLanguage)
          iconName: "restore"
          foreground: root.dim
          accent: root.accent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          focusable: true
          bordered: true
          onClicked: root.resetPreferences()
        }

        SvgButton {
          width: (parent.width - parent.spacing) / 2
          height: parent.height
          text: I18n.t("done", root.effectiveLanguage)
          iconName: "check"
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          focusable: true
          bordered: true
          onClicked: root.setSettingsOpen(false)
        }
      }

      Row {
        id: settingsTabs
        objectName:"settingsTabs"
        width:parent.width;spacing:Style.spacing.xs
        Repeater {
          model:["tiles","icon","sampling","diagnostics"]
          Button {
            required property string modelData
            width:(settingsTabs.width-settingsTabs.spacing*3)/4;height:Style.space(28)
            text:I18n.t("settings_"+modelData,root.effectiveLanguage)
            selected:root.settingsSection===modelData
            foreground:root.foreground;accent:root.accent;fontFamily:Style.font.family;fontSize:Style.font.caption
            bordered:true;focusable:true
            onClicked:{root.settingsSection=modelData;settingsViewport.contentY=0}
          }
        }
      }
      // Each category owns a short independently fitted page.
      Flickable {
        id: settingsViewport
        objectName: "settingsViewport"
        anchors.top: settingsTabs.bottom
        anchors.topMargin:Style.spacing.sm
        anchors.bottom: settingsActions.top
        anchors.bottomMargin: Style.spacing.sm
        anchors.left: parent.left
        anchors.right: parent.right
        contentWidth: width
        contentHeight: settingsBodyCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: PageScrollBar { objectName: "settingsScrollBar"; viewport: settingsViewport }

        Column {
          id: settingsBodyCol
          objectName: "settingsBody"
          width: parent.width
          spacing: Style.spacing.md

          DetailSurface {
            visible:root.settingsSection!=="diagnostics"
            width: parent.width
            height: settingsGridCol.implicitHeight + Style.spacing.xl * 2

            Column {
              id: settingsGridCol
              x: Style.spacing.xl
              y: Style.spacing.xl
              width: Math.max(1, parent.width - Style.spacing.xl * 2)
              spacing: Style.spacing.md

              PanelSectionHeader {
                visible:false
                text: I18n.t("settings", root.effectiveLanguage)
                foreground: root.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              }

              Text {
                width: parent.width
                visible:false
                text: I18n.t("settings_desc", root.effectiveLanguage)
                color: root.dim
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Column {
                width:parent.width;spacing:Style.spacing.sm
                visible:root.settingsSection==="tiles"
              PanelSectionHeader {
                width: parent.width
                text: I18n.t("compact_tiles", root.effectiveLanguage)
                foreground: root.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              }
              Dropdown {
                width: parent.width
                label: I18n.t("compact_tile_count", root.effectiveLanguage)
                value: String(root.compactTileCount)
                options: [{value:"2",label:"2"},{value:"3",label:"3"}]
                foreground: root.foreground; accent: root.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onChanged: function(value) { root.persistSettings({compactTileCount:Number(value)}) }
              }
              Toggle {
                width: parent.width
                label: I18n.t("compact_ram_strip", root.effectiveLanguage)
                description: I18n.t("compact_ram_strip_hint", root.effectiveLanguage)
                checked: root.booleanSetting("compactRamStrip", true)
                foreground: root.foreground; accent: root.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: root.persistSettings({compactRamStrip:!root.booleanSetting("compactRamStrip", true)})
              }
              Repeater {
                model: root.compactTileCount
                Dropdown {
                  required property int index
                  width: parent.width
                  label: I18n.t("compact_tile_slot", root.effectiveLanguage, index + 1)
                  value: String(root.setting("compactTile" + index, ["cpu", "ram", "gpu"][index]))
                  options: root.tileOptions.map(function(key) { return { value: key, label: root.tileTitle(key) } })
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onChanged: function(next) {
                    var change = {}
                    change["compactTile" + index] = next
                    root.persistSettings(change)
                  }
                }
              }

              }
              Grid {
                id: preferenceGrid
                visible:root.settingsSection==="icon" || root.settingsSection==="sampling"
                width: parent.width
                columns: width >= Style.space(460) ? 2 : 1
                columnSpacing: Style.spacing.xl
                rowSpacing: Style.spacing.md

                Dropdown {
                  visible:root.settingsSection==="icon"
                  objectName: "iconShapeDropdown"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  label: I18n.t("icon_shape", root.effectiveLanguage)
                  value: String(root.iconShapeSetting)
                  options: Array.from({length: IconVector.bodies.length}, function(_, i) {
                    return {value: String(i), label: I18n.t("icon_shape_" + i, root.effectiveLanguage)}
                  })
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onChanged: function(next) { root.persistSettings({ iconShape: Number(next) }) }
                }

                Dropdown {
                  visible:root.settingsSection==="icon"
                  objectName: "iconLoadThresholdDropdown"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  label: I18n.t("icon_load_threshold", root.effectiveLanguage)
                  value: String(root.iconLoadThresholdSetting)
                  options: Array.from({length: 11}, function(_, i) {
                    return {value: String(i * 10), label: i * 10 + "%"}
                  })
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onChanged: function(next) { root.persistSettings({ iconLoadThreshold: Number(next) }) }
                }

                Dropdown {
                  visible:root.settingsSection==="icon"
                  objectName: "iconHeatDropdown"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  label: I18n.t("icon_heat_threshold", root.effectiveLanguage)
                  value: String(activity.heatThreshold)
                  options: [70, 75, 80, 85, 90, 95, 100].map(function(n) {
                    return {value: String(n), label: n + " °C"}
                  })
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onChanged: function(next) { root.persistSettings({ iconHeatThreshold: Number(next) }) }
                }

                Text {
                  visible:root.settingsSection==="icon"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  text: I18n.t("icon_heat_desc", root.effectiveLanguage, activity.heatThreshold - 5)
                  color: root.dim
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }

                Text {
                  visible:root.settingsSection==="icon"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  text: root.iconLegend + "\n" + I18n.t(root.iconShapeSetting === IconVector.defaultShape
                    ? "icon_split_colors" : "icon_load_colors", root.effectiveLanguage)
                  color: root.dim
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }

                Toggle {
                  visible:root.settingsSection==="icon"
                  objectName: "iconMotionToggle"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  label: I18n.t("icon_motion", root.effectiveLanguage)
                  description: I18n.t("icon_motion_desc", root.effectiveLanguage)
                  checked: root.booleanSetting("iconMotion", true)
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onClicked: root.persistSettings({iconMotion: !root.booleanSetting("iconMotion", true)})
                }

                Text {
                  visible:root.settingsSection==="icon"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  text: I18n.t("heat_steps",root.effectiveLanguage,activity.heatThreshold)
                  color: root.dim
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }

                Dropdown {
                  visible:root.settingsSection==="sampling"
                  id: speedDropdown
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  label: I18n.t("speed", root.effectiveLanguage)
                  value: root.samplingSpeedSetting
                  options: [
                    { value: "Efficient", label: I18n.t("speed_efficient", root.effectiveLanguage) },
                    { value: "Balanced", label: I18n.t("speed_balanced", root.effectiveLanguage) },
                    { value: "Fast", label: I18n.t("speed_fast", root.effectiveLanguage) }
                  ]
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onChanged: function(next) { root.persistSettings({ samplingSpeed: next }) }
                }

                Dropdown {
                  visible:root.settingsSection==="sampling"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  label: I18n.t("history", root.effectiveLanguage)
                  value: String(root.historySamplesSetting)
                  options: [
                    { value: "30", label: "30" },
                    { value: "60", label: "60" },
                    { value: "120", label: "120" }
                  ]
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onChanged: function(next) { root.persistSettings({ historySamples: Number(next) }) }
                }

                Dropdown {
                  visible:root.settingsSection==="sampling"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  label: I18n.t("temp_unit", root.effectiveLanguage)
                  value: root.temperatureUnitSetting
                  options: [
                    { value: "Celsius", label: I18n.t("celsius", root.effectiveLanguage) },
                    { value: "Fahrenheit", label: I18n.t("fahrenheit", root.effectiveLanguage) }
                  ]
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onChanged: function(next) { root.persistSettings({ temperatureUnit: next }) }
                }

                Toggle {
                  visible:root.settingsSection==="sampling"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  label: I18n.t("icon_indicator", root.effectiveLanguage)
                  description: I18n.t("icon_indicator_desc", root.effectiveLanguage)
                  checked: root.booleanSetting("iconIndicator", true)
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onClicked: root.persistSettings({ iconIndicator: !root.booleanSetting("iconIndicator", true) })
                }

                Toggle {
                  visible:root.settingsSection==="sampling"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  label: I18n.t("open_expanded", root.effectiveLanguage)
                  description: I18n.t("open_expanded_desc", root.effectiveLanguage)
                  checked: root.openExpandedByDefault
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onClicked: root.persistSettings({ openExpanded: !root.openExpandedByDefault })
                }

                Toggle {
                  visible:root.settingsSection==="sampling"
                  width: (preferenceGrid.width - preferenceGrid.columnSpacing * (preferenceGrid.columns - 1)) / preferenceGrid.columns
                  label: I18n.t("frequencies", root.effectiveLanguage)
                  description: I18n.t("frequencies_desc", root.effectiveLanguage)
                  checked: root.showFrequencies
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onClicked: root.persistSettings({ showFrequencies: !root.showFrequencies })
                }
              }
            }
          }

          DetailSurface {
            visible:root.settingsSection==="diagnostics"
            width: parent.width
            height: diagnosticColumn.implicitHeight+Style.spacing.xl*2
            Column {
              id: diagnosticColumn
              x: Style.spacing.xl; y: Style.spacing.xl
              width: parent.width-Style.spacing.xl*2
              spacing: Style.spacing.md
              Toggle {
                objectName: "diagnosticJournalToggle"
                width: parent.width
                label: I18n.t("diagnostic_journal",root.effectiveLanguage)
                description: I18n.t("diagnostic_journal_desc",root.effectiveLanguage)
                checked: root.booleanSetting("diagnosticJournal",false)
                foreground: root.foreground;accent: root.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: root.persistSettings({diagnosticJournal: !root.booleanSetting("diagnosticJournal",false)})
              }
              Text {
                width: parent.width
                text: activity.journalError ? I18n.t("diagnostic_write_failed",root.effectiveLanguage)
                  : I18n.t("diagnostic_retention",root.effectiveLanguage)
                color: activity.journalError ? root.urgent : root.dim
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption;wrapMode: Text.WordWrap
              }
              Dropdown {
                objectName: "diagnosticPeriodDropdown"
                width: parent.width
                label: I18n.t("diagnostic_period",root.effectiveLanguage)
                value: String(diagnosticExport.hours)
                options: [1,2,6,24,168].map(function(n){return {value:String(n),label:I18n.t("diagnostic_hours",root.effectiveLanguage,n)}})
                foreground: root.foreground;accent: root.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onChanged: function(n){diagnosticExport.hours=Number(n)}
              }
              SvgButton {
                objectName: "diagnosticExportButton"
                iconName: "export"
                width: parent.width
                text: I18n.t(diagnosticExport.running ? "diagnostic_exporting" : "diagnostic_export",root.effectiveLanguage)
                enabled: !diagnosticExport.running
                foreground: root.foreground;accent: root.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                focusable: true;bordered: true
                onClicked: diagnosticExport.request()
              }
              Text {
                width: parent.width
                visible: diagnosticExport.resultPath!=="" || diagnosticExport.error!==""
                text: diagnosticExport.error || diagnosticExport.resultPath
                textFormat: Text.PlainText
                color: diagnosticExport.error!=="" ? root.urgent : root.dim
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption;wrapMode: Text.WrapAnywhere
              }
              SvgButton {
                objectName: "diagnosticCopyPromptButton"
                iconName: "copy"
                width: parent.width
                visible: diagnosticExport.resultPath!==""
                text: I18n.t("diagnostic_copy_prompt",root.effectiveLanguage)
                foreground: root.foreground;accent: root.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                focusable: true;bordered: true
                onClicked: diagnosticExport.copyPrompt()
              }
            }
          }
        }
      }
    }
  }

  // --- Expanded Content: Pinned Action Buttons at bottom, dynamic scroll for processes ---
  Component {
    id: expandedContent

    Item {
      anchors.fill: parent

      // Pinned Action Buttons at bottom: NEVER pushed off screen!
      Row {
        id: expandedActions
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(30)
        spacing: Style.spacing.md

        SvgButton {
          width: (parent.width - parent.spacing) / 2
          height: parent.height
          text: I18n.t("btn_terminate", root.effectiveLanguage)
          iconName: "stop"
          focusable: true
          bordered: true
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          enabled: !!root.selectedProcess && !processActions.running
          onClicked: processActions.request(root.selectedProcess, false)
        }

        SvgButton {
          width: (parent.width - parent.spacing) / 2
          height: parent.height
          text: I18n.t("btn_kill", root.effectiveLanguage)
          iconName: "kill"
          focusable: true
          bordered: true
          foreground: root.urgent
          accent: root.urgent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          enabled: !!root.selectedProcess && !processActions.running
          onClicked: processActions.request(root.selectedProcess, true)
        }
      }

      // Shortcut Hints / Status Bar in Expanded Mode
      BorderSurface {
        id: expandedHintBar
        visible: root.hintsVisible || activity.errorText !== "" || processActions.status !== ""
        anchors.bottom: expandedActions.top
        anchors.bottomMargin: Style.spacing.xs
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? Style.space(22) : 0
        color: Style.normalFillFor(root.foreground, root.accent)
        borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
        radius: Style.cornerRadius

        Text {
          anchors.centerIn: parent
          width: parent.width - Style.spacing.md * 2
          text: activity.errorText || processActions.status || I18n.t("hints_expanded", root.effectiveLanguage)
          textFormat: Text.PlainText
          color: (activity.errorText !== "" || processActions.failed) ? root.urgent : root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
      }

      // Top summaries and table header
      Column {
        id: expandedTop
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.spacing.xs

        // Scroll summaries separately so processes retain useful vertical space.
        Flickable {
          id: summaryViewport
          width: parent.width
          height: Math.min(summaryGrid.implicitHeight, Math.max(Style.space(72),
            parent.parent.height - expandedActions.height
              - (expandedHintBar.visible ? expandedHintBar.height + Style.spacing.xs : 0)
              - Math.max(Style.space(130), root.processRowHeight * 4 + Style.space(74))))
          contentWidth: width
          contentHeight: summaryGrid.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Grid {
          id: summaryGrid
          width: summaryViewport.width - Style.spacing.sm
          columns: width >= Style.space(800) ? 4 : (width >= Style.space(600) ? 3 : (width >= Style.space(380) ? 2 : 1))
          spacing: Style.spacing.sm
          Repeater {
            model: ["cpu", "ram"].concat(root.gpus.length
              ? root.gpus.map(function(gpu) { return "gpu:" + gpu.id }) : ["gpu"])
              .concat(["temperature", "network", "disk", "storage"])
            SummaryTile {
              required property string modelData
              tile: modelData
              width: (summaryGrid.width - summaryGrid.spacing * (summaryGrid.columns - 1)) / summaryGrid.columns
              height: root.tileHeight
            }
          }
        }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Row {
          width: parent.width
          spacing: Style.spacing.sm

          PanelSectionHeader {
            text: I18n.t("all_processes", root.effectiveLanguage) + (root.processes.length > 0 ? " · " + root.sortedProcesses.length : "")
            foreground: root.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            anchors.verticalCenter: parent.verticalCenter
          }

          Item {
            width: Math.max(0, parent.width - parent.children[0].implicitWidth - searchBox.width - parent.spacing * 2)
            height: 1
          }

          TextField {
            id: searchBox
            width: Math.max(Style.space(160), Math.min(Style.space(240), parent.width * 0.35))
            placeholderText: I18n.t("search_placeholder", root.effectiveLanguage)
            foreground: root.foreground
            accent: root.accent
            font.pixelSize: Style.font.bodySmall
            verticalPadding: Style.spacing.xs
            onTextChanged: {
              root.processQuery = text
              root.selectedProcessIndex = 0
              root.selectedProcessKey = ""
              root.cursorActive = false
              pointerGate.reset()
            }
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.finishSearch()
                event.accepted = true
              }
            }
            Component.onCompleted: {
              text = root.processQuery
              root.searchField = searchBox
            }
            Component.onDestruction: if (root.searchField === searchBox) root.searchField = null
          }
        }

        ProcessHeader {
          id: expandedTableHeader
          width: parent.width
          compact: false
        }
      }

      // Middle Process List: fills ALL remaining vertical height between expandedTop and hintBar/actions
      Item {
        id: expandedListHost
        anchors.top: expandedTop.bottom
        anchors.topMargin: 2
        anchors.bottom: expandedHintBar.visible ? expandedHintBar.top : expandedActions.top
        anchors.bottomMargin: Style.spacing.xs
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true

        ListView {
          id: processList
          anchors.fill: parent
          model: root.sortedProcesses
          spacing: Style.space(2)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          reuseItems: true

          function ensureSelected() {
            if (root.selectedProcessIndex >= 0 && root.selectedProcessIndex < count)
              positionViewAtIndex(root.selectedProcessIndex, ListView.Contain)
          }

          Component.onCompleted: root.processViewport = processList
          Component.onDestruction: if (root.processViewport === processList) root.processViewport = null

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: ProcessRow {
            required property var modelData
            required property int index
            width: ListView.view.width
            processData: modelData
            rowIndex: index
            compact: false
            selected: root.cursorActive && root.selectedProcessKey === Model.processIdentityKey(modelData)
          }
        }

        Text {
          anchors.centerIn: parent
          visible: processList.count === 0
          text: root.processQuery
            ? I18n.t("no_processes", root.effectiveLanguage) + " (“" + root.processQuery + "”)"
            : (root.processMetricsReady ? I18n.t("no_processes", root.effectiveLanguage) : I18n.t("sampling", root.effectiveLanguage))
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
        }
      }
    }
  }

  component SummaryTile: MetricCard {
    id: summary
    property string tile: "cpu"
    readonly property string kind: tile.indexOf("gpu:") === 0 ? "gpu" : tile
    readonly property var gpu: {
      if (kind !== "gpu") return null
      if (tile === "gpu") return root.gpus.length ? root.gpus[0] : null
      return root.gpus.filter(function(item) { return "gpu:" + item.id === summary.tile })[0] || null
    }
    readonly property var gpuTemperature: activity.sensorsFresh && gpu
      ? activity.sensorSnapshot.temperatures.filter(function(sensor) { return sensor.category === "gpu" && sensor.location === summary.gpu.id })[0] || null : null
    iconName: kind
    label: kind === "cpu" ? (!root.expanded && root.compactTileCount === 3 ? "CPU" : root.cpuCardLabel())
      : kind === "ram" ? (!root.expanded && root.compactTileCount === 3 ? I18n.t("ram",root.effectiveLanguage) : root.memoryCardLabel())
      : kind === "gpu" && gpu ? root.compactGpuName(gpu) : root.tileTitle(kind)
    value: kind === "cpu" ? (activity.cpuReady ? root.percentText(root.metrics.cpu) : "—")
      : kind === "ram" ? (root.hasSnapshot ? root.percentText(root.metrics.memory) : "—")
      : kind === "gpu" ? (gpu ? root.gpuUsageText(gpu) : "—")
      : kind === "temperature" ? (root.cpuTemperature ? Model.formatTemperature(root.cpuTemperature.value, root.temperatureUnitSetting) : "—")
      : kind === "fans" ? (activity.sensorsFresh && activity.sensorSnapshot.fans.length
          ? (activity.sensorSnapshot.fans[0].unit === "percent" ? activity.sensorSnapshot.fans[0].value + "%"
            : I18n.t("fan_rpm", root.effectiveLanguage, activity.sensorSnapshot.fans[0].value)) : "—")
      : kind === "network" ? Model.formatBytes(root.metrics.download, "/s")
      : kind === "disk" ? Model.formatBytes(root.diskCardRead(), "/s")
      : root.activeStorage ? Model.formatCompactBytes(root.activeStorage.used) + " / " + Model.formatCompactBytes(root.activeStorage.total) : "—"
    detail: kind === "cpu" ? (root.cpuTemperature ? I18n.t("temp_unit", root.effectiveLanguage) + " " + root.cpuCardDetail() : I18n.t("sampling", root.effectiveLanguage))
      : kind === "ram" ? root.memoryBreakdownText()
      : kind === "gpu" && gpu ? [root.gpuFrequencyText(gpu), gpuTemperature ? Model.formatTemperature(gpuTemperature.value, root.temperatureUnitSetting) : ""].filter(function(value) { return value !== "" }).join(" · ")
        + "\n" + root.gpuMemoryLabel(gpu) + " " + root.gpuMemoryText(gpu)
      : kind === "temperature" ? I18n.t("cpu", root.effectiveLanguage)
      : kind === "fans" ? (activity.sensorsFresh && activity.sensorSnapshot.fans.length ? root.sensorOwner(activity.sensorSnapshot.fans[0]) : I18n.t("no_fan_sensors", root.effectiveLanguage))
      : kind === "network" ? "\uf093 " + Model.formatBytes(root.metrics.upload, "/s")
      : kind === "disk" ? "\uf093 " + Model.formatBytes(root.diskCardWrite(), "/s") : root.storageCardDetail()
    paint: kind === "cpu" && (root.expanded || root.compactTileCount === 2) ? (root.expanded ? root.corePaintExpanded : root.corePaintCompact) : Model.emptyCorePaint()
    history: kind === "cpu" ? root.metrics.cpuHistory : kind === "ram" ? root.metrics.memoryHistory
      : kind === "network" ? root.metrics.networkHistory : kind === "disk" ? root.diskCardHistory() : []
    badge: kind === "disk" ? root.diskPagerText() : kind === "storage" ? root.storagePagerText() : kind === "ram" ? root.swapBadgeText() : ""
    ceiling: kind === "cpu" || kind === "ram" ? 100 : 0
    bar: kind === "storage" && root.storageSnapshot.sample > 0 ? root.storageUsedFraction : -1
    tone: kind === "cpu" ? root.pressureColor(root.metrics.cpu) : kind === "ram" ? root.pressureColor(root.metrics.memory) : root.accent
    detailTone: kind === "cpu" && activity.heatAlert ? root.urgent : root.dim
    interactive: kind === "disk" ? root.canCycleDisks : kind === "storage" ? root.canCycleStorage : false
    onActivated: function(delta) { if (kind === "disk") root.cycleDisk(delta); else if (kind === "storage") root.cycleStorage(delta) }
  }

  // --- Sub-components (Cards, Rows, Cells) ---
  component MetricCard: BorderSurface {
    id: metricCard

    property string label: ""
    property string iconName: ""
    property string badge: ""
    property string value: ""
    property string detail: ""
    property color detailTone: root.dim
    property var history: []
    property var paint: ({ width: 0, height: 0, frames: [], cells: [] })
    property real ceiling: 0
    property real bar: -1
    property bool tall: false
    property bool interactive: false
    property string tooltipText: ""
    property color tone: root.accent
    property color badgeTone: root.dim
    readonly property bool showCores: !!(paint && Array.isArray(paint.cells) && paint.cells.length > 0)
    signal activated(int delta)

    implicitHeight: Math.max(Style.space(tall ? 104 : 72),
      Style.spacing.md * 2 + Style.font.caption * 2 + Style.font.heading + Style.space(12) + Style.spacing.sm * 2)
    color: Style.normalFillFor(root.foreground, root.accent)
    borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
    radius: Style.cornerRadius

    Item {
      anchors.fill: parent
      anchors.margins: Style.spacing.md

      Item {
        id: cardHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(cardLabel.implicitHeight, cardBadge.visible ? cardBadge.implicitHeight : 0)

        SvgIcon {
          id: metricIcon
          visible: metricCard.iconName !== ""
          name: metricCard.iconName
          width: Math.max(Style.space(14), Style.font.caption)
          height: width
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          tint: root.foreground
        }
        PanelSectionHeader {
          id: cardLabel
          anchors.left: metricIcon.visible ? metricIcon.right : parent.left
          anchors.leftMargin: metricIcon.visible ? Style.spacing.xs : 0
          anchors.right: cardBadge.visible ? cardBadge.left : parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.rightMargin: cardBadge.visible ? Style.spacing.xs : 0
          text: metricCard.label
          foreground: root.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }

        Text {
          id: cardBadge
          visible: metricCard.badge !== ""
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: metricCard.badge
          textFormat: Text.PlainText
          color: metricCard.badgeTone
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Item {
        id: cardBody
        anchors.top: cardHeader.bottom
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: cardFooter.top

        Column {
          anchors.left: parent.left
          anchors.right: coreDie.visible ? coreDie.left : parent.right
          anchors.rightMargin: coreDie.visible ? Style.spacing.sm : 0
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Text {
            width: parent.width
            text: value
            textFormat: Text.PlainText
            color: tone
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: detail
            textFormat: Text.PlainText
            color: metricCard.detailTone
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
          }
        }

        CoreHeatGrid {
          id: coreDie
          visible: metricCard.showCores
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: implicitWidth * Math.max(0, Math.min(1, parent.width * 0.48 / Math.max(1, implicitWidth), parent.height / Math.max(1, implicitHeight)))
          height: implicitHeight * Math.max(0, Math.min(1, parent.width * 0.48 / Math.max(1, implicitWidth), parent.height / Math.max(1, implicitHeight)))
          paint: metricCard.paint
        }
      }

      Item {
        id: cardFooter
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(12)

        Sparkline {
          anchors.fill: parent
          visible: metricCard.bar < 0 && Array.isArray(history) && history.length > 0
          values: history
          ceiling: metricCard.ceiling
          lineColor: tone
          fillColor: Util.alpha(tone, 0.12)
        }

        Rectangle {
          visible: metricCard.bar >= 0
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Style.space(4)
          radius: height / 2
          color: Util.alpha(root.foreground, 0.12)

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, metricCard.bar))
            height: parent.height
            radius: parent.radius
            color: metricCard.tone
          }
        }
      }
    }

    MouseArea {
      id: cardClick
      anchors.fill: parent
      enabled: metricCard.interactive
      hoverEnabled: metricCard.interactive
      cursorShape: metricCard.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
      acceptedButtons: Qt.LeftButton
      onClicked: function(mouse) {
        metricCard.activated((mouse.modifiers & Qt.ShiftModifier) ? -1 : 1)
      }
    }
  }

  component ActivityPair: Row {
    property string iconText: ""
    property string label: ""
    property string value: ""
    property string secondary: ""
    spacing: Style.spacing.md
    readonly property real naturalHeight: Math.max(icon.implicitHeight, labels.implicitHeight)

    Text {
      id: icon
      anchors.verticalCenter: parent.verticalCenter
      text: iconText
      color: root.accent
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.title
    }

    Column {
      id: labels
      width: Math.max(1, parent.width - icon.implicitWidth - parent.spacing)
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1

      Text {
        text: label
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Row {
        width: parent.width
        spacing: Style.spacing.xs

        Text {
          text: value
          color: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        Text {
          visible: secondary !== ""
          text: "·"
          color: root.dim
          font.pixelSize: Style.font.caption
        }

        Text {
          visible: secondary !== ""
          text: secondary
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  component DetailSurface: BorderSurface {
    color: Style.normalFillFor(root.foreground, root.accent)
    borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
    radius: Style.cornerRadius
  }

  component CoreHeatGrid: Item {
    id: heat
    property var paint: ({ width: 0, height: 0, frames: [], cells: [] })
    readonly property var frames: paint && Array.isArray(paint.frames) ? paint.frames : []
    readonly property var cells: paint && Array.isArray(paint.cells) ? paint.cells : []

    implicitWidth: Math.max(0, Number(paint && paint.width || 0))
    implicitHeight: Math.max(0, Number(paint && paint.height || 0))

    Repeater {
      model: heat.frames.length
      Rectangle {
        required property int index
        readonly property var frame: heat.frames[index] || ({})
        x: Number(frame.x || 0) * heat.width / Math.max(1, heat.implicitWidth)
        y: Number(frame.y || 0) * heat.height / Math.max(1, heat.implicitHeight)
        width: Number(frame.w || 0) * heat.width / Math.max(1, heat.implicitWidth)
        height: Number(frame.h || 0) * heat.height / Math.max(1, heat.implicitHeight)
        radius: 2
        color: "transparent"
        border.width: 1
        border.color: Util.alpha(root.foreground, 0.28)
      }
    }

    Repeater {
      model: heat.cells.length
      CoreDieCell {
        required property int index
        readonly property var cell: heat.cells[index] || ({})
        x: Number(cell.x || 0) * heat.width / Math.max(1, heat.implicitWidth)
        y: Number(cell.y || 0) * heat.height / Math.max(1, heat.implicitHeight)
        size: Math.max(1, Number(cell.size || 0) * Math.min(heat.width / Math.max(1, heat.implicitWidth), heat.height / Math.max(1, heat.implicitHeight)))
        usage: Number(cell.usage || 0)
        tooltipText: I18n.t("core_usage", root.effectiveLanguage, String(cell.name || "cpu" + index), Math.round(usage))
      }
    }
  }

  component CoreDieCell: Rectangle {
    property real size: Style.space(7)
    property real usage: 0
    property string tooltipText: ""

    width: size
    height: size
    radius: 1
    color: "transparent"
    border.width: 1
    border.color: Util.alpha(root.foreground, 0.22)

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: 0
      color: root.pressureColor(parent.usage)
      opacity: parent.usage < 8 ? 0 : 0.28 + 0.72 * Math.pow(parent.usage / 100, 1.35)
    }
    MouseArea {
      id: cellHover
      anchors.fill: parent
      hoverEnabled: true
      PanelToolTip {
        visible: cellHover.containsMouse
        text: cellHover.parent.tooltipText
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
      }
    }
  }

  // --- Precision Process Table Header & Row (100% matched geometry) ---
  component ProcessHeader: Item {
    id: headerRoot
    property bool compact: false
    implicitHeight: Math.max(Style.space(18), Style.font.bodySmall + Style.spacing.xs)

    Row {
      id: headerRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: root.tableSideMargin
      anchors.rightMargin: root.tableSideMargin
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.tableSpacing

      ProcessSortCell {
        width: root.processNameWidth(headerRoot.width, headerRoot.compact)
        sortKey: "name"
        label: headerRoot.compact
          ? I18n.t("busiest_processes", root.effectiveLanguage)
          : I18n.t("col_name", root.effectiveLanguage)
      }
      ProcessSortCell {
        visible: root.showProcessPidColumn
        width: root.colPidWidth
        sortKey: "pid"
        label: I18n.t("col_pid", root.effectiveLanguage)
        alignment: Text.AlignRight
      }
      ProcessCell {
        visible: !headerRoot.compact && root.showProcessUserColumn
        width: root.colUserWidth
        text: I18n.t("col_user", root.effectiveLanguage)
        dimmed: true
      }
      ProcessSortCell {
        width: root.colCpuWidth
        sortKey: "cpu"
        label: I18n.t("col_cpu", root.effectiveLanguage)
        alignment: Text.AlignRight
      }
      ProcessSortCell {
        width: root.colRssWidth
        sortKey: "memory"
        label: I18n.t("col_rss", root.effectiveLanguage)
        alignment: Text.AlignRight
      }
      ProcessSortCell {
        visible: root.showProcessRamPercentColumn
        width: root.colRamPctWidth
        sortKey: "memory"
        label: I18n.t("col_ram", root.effectiveLanguage)
        alignment: Text.AlignRight
      }
      ProcessSortCell {
        visible: !headerRoot.compact && root.showProcessTimeColumn
        width: root.colTimeWidth
        sortKey: "runtime"
        label: I18n.t("col_time", root.effectiveLanguage)
        alignment: Text.AlignRight
      }
      // Spacer matching the [✕] button width so header columns align 1:1 with data columns
      Item {
        width: root.colActionWidth
        height: 1
      }
    }
  }

  component ProcessSortCell: Item {
    id: sortCell
    property string sortKey: ""
    property string label: ""
    property int alignment: Text.AlignLeft
    implicitHeight: labelText.implicitHeight

    ProcessCell {
      id: labelText
      width: parent.width
      text: root.sortLabel(sortCell.sortKey, sortCell.label)
      dimmed: root.sortKey !== sortCell.sortKey
      emphasized: root.sortKey === sortCell.sortKey
      alignment: sortCell.alignment
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.setSort(sortCell.sortKey)
    }
  }

  component ProcessRow: CursorSurface {
    id: rowRoot
    property var processData: ({})
    property int rowIndex: -1
    property bool compact: false
    property bool selected: false

    hasCursor: selected
    foreground: root.foreground
    accent: root.accent
    implicitHeight: root.processRowHeight

    Row {
      anchors.fill: parent
      anchors.leftMargin: root.tableSideMargin
      anchors.rightMargin: root.tableSideMargin
      spacing: root.tableSpacing

      ProcessCell {
        width: root.processNameWidth(rowRoot.width, rowRoot.compact)
        text: String(processData.name || "unknown")
        emphasized: false
        font.bold: rowRoot.compact
      }

      ProcessCell {
        visible: root.showProcessPidColumn
        width: root.colPidWidth
        text: String(processData.pid || "")
        dimmed: true
        alignment: Text.AlignRight
      }

      ProcessCell {
        visible: !rowRoot.compact && root.showProcessUserColumn
        width: root.colUserWidth
        text: String(processData.user || "")
        dimmed: true
      }

      ProcessCell {
        id: cpuValue
        width: root.colCpuWidth
        text: Number(processData.cpu || 0).toFixed(1) + "%"
        alignment: Text.AlignRight
        emphasized: Number(processData.cpu || 0) >= 25
      }

      ProcessCell {
        id: rssValue
        width: root.colRssWidth
        text: Model.formatBytes(processData.rss || 0)
        alignment: Text.AlignRight
        emphasized: Number(processData.memory || 0) >= 15
      }

      ProcessCell {
        id: memoryValue
        visible: root.showProcessRamPercentColumn
        width: root.colRamPctWidth
        text: Number(processData.memory || 0).toFixed(1) + "%"
        dimmed: true
        alignment: Text.AlignRight
      }

      ProcessCell {
        visible: !rowRoot.compact && root.showProcessTimeColumn
        width: root.colTimeWidth
        text: Model.formatDuration(processData.elapsed)
        dimmed: true
        alignment: Text.AlignRight
      }

      // Quick terminate icon
      Item {
        id: killIcon
        width: root.colActionWidth
        height: Style.space(20)
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: killMouse.containsMouse ? Util.alpha(root.urgent, 0.25) : "transparent"
          border.color: killMouse.containsMouse ? root.urgent : "transparent"
          border.width: 1

          SvgIcon {
            anchors.centerIn: parent
            name: "close"
            width: Style.font.caption
            height: width
            tint: killMouse.containsMouse ? root.urgent : Util.alpha(root.foreground, 0.45)
          }
        }

        MouseArea {
          id: killMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: processActions.request(processData, false)
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      anchors.rightMargin: root.colActionWidth + root.tableSideMargin
      hoverEnabled: !compact
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        root.selectProcess(rowIndex)
        if (mouse.button === Qt.RightButton) {
          processActions.request(processData, false)
        }
      }
      onDoubleClicked: function(mouse) {
        root.selectProcess(rowIndex)
        processActions.request(processData, true)
      }
    }
  }

  component ProcessCell: Text {
    property bool dimmed: false
    property bool emphasized: false
    property int alignment: Text.AlignLeft

    color: emphasized ? root.accent : (dimmed ? root.dim : root.foreground)
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.bold: emphasized
    textFormat: Text.PlainText
    elide: Text.ElideRight
    horizontalAlignment: alignment
    verticalAlignment: Text.AlignVCenter
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
  }
}
