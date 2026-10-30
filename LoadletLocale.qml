import QtQuick
import Quickshell.Io
import qs.Commons as Host

// One panel-owned catalog/format adapter. Host language remains read-only.
QtObject {
  id: root
  property string requestedLanguage: "system"
  readonly property bool followsSystem: !requestedLanguage || requestedLanguage === "system"
  readonly property var registry: Host.I18n.parseCatalog(Host.I18n.registryFile.text())
  readonly property string language: resolveLanguage(followsSystem ? Host.I18n.language : requestedLanguage)
  readonly property string baseLanguage: language.split("-")[0]
  readonly property var localeSettings: registry[language] || ({})
  readonly property string formatLocale: localeSettings.formatLocale || language.replace("-", "_")
  readonly property var qtLocale: Qt.locale(formatLocale)
  readonly property bool hasCatalog: Object.keys(language === "en" ? nativeStrings.englishStrings
    : overrideActive ? exactStrings : nativeStrings.languageStrings).length > 0
  readonly property bool rightToLeft: localeSettings.direction === "rtl"
    || ["ar", "he", "fa", "ur"].indexOf(baseLanguage) >= 0
  readonly property var languages: Object.keys(registry).map(function(code) {
    return {value: code, label: registry[code].name, description: registry[code].englishName}
  }).sort(function(a, b) { return a.description.localeCompare(b.description) })
  readonly property bool overrideActive: language !== nativeStrings.language
  readonly property var exactStrings: nativeStrings.parseCatalog(overrideFile.text())
  readonly property var baseStrings: nativeStrings.parseCatalog(overrideBaseFile.text())

  property Host.Translations nativeStrings: Host.Translations {
    directory: Qt.resolvedUrl("i18n")
  }
  property FileView overrideFile: FileView {
    path: root.overrideActive ? root.nativeStrings.catalogPath(root.language) : ""
    watchChanges: true; printErrors: false; blockLoading: true
    onFileChanged: reload()
  }
  property FileView overrideBaseFile: FileView {
    path: root.overrideActive && root.baseLanguage !== root.language && root.baseLanguage !== "en"
      ? root.nativeStrings.catalogPath(root.baseLanguage) : ""
    watchChanges: true; printErrors: false; blockLoading: true
    onFileChanged: reload()
  }

  function resolveLanguage(value) {
    var code = String(value || "en").trim().replace(/_/g, "-").toLowerCase()
    if (code === "zh" || /^zh-(cn|hans)(-|$)/.test(code)) return "zh-CN"
    if (/^zh-(tw|hk|mo|hant)(-|$)/.test(code)) return "zh-TW"
    var keys = Object.keys(registry)
    var exact = keys.find(function(key) { return key.toLowerCase() === code })
    if (exact) return exact
    var base = code.split("-")[0]
    return registry[base] ? base : "en"
  }
  function t(key, p1, p2, p3) {
    var value = nativeStrings.t(key)
    if (overrideActive) {
      var layers = [exactStrings, baseStrings, nativeStrings.englishStrings]
      value = key
      for (var i = 0; i < layers.length; ++i) {
        var entry = layers[i][key]
        if (entry && typeof entry === "object") entry = entry.other
        if (typeof entry === "string" && entry.length) { value = entry; break }
      }
    }
    var args = [p1, p2, p3]
    return String(value).replace(/%([1-3])/g, function(token, index) {
      var arg = args[Number(index) - 1]
      return arg === undefined ? token : typeof arg === "number" ? root.number(arg) : String(arg)
    })
  }
  function number(value, decimals) {
    var n = Number(value)
    if (!isFinite(n)) return "—"
    if (followsSystem && language === Host.I18n.language)
      return Host.I18n.formatNumber(n, decimals)
    // Match the host registry for an override without changing its singleton.
    var text = decimals === undefined ? String(n) : n.toFixed(decimals)
    var zero = (localeSettings.zeroDigit || "0").charCodeAt(0)
    return text.replace(".", localeSettings.decimal || ".").replace(/[0-9]/g, function(digit) {
      return String.fromCharCode(zero + Number(digit))
    })
  }
  function duration(value) {
    var seconds = Math.max(0, Math.floor(Number(value) || 0))
    var days = Math.floor(seconds / 86400), hours = Math.floor(seconds % 86400 / 3600)
    var minutes = Math.floor(seconds % 3600 / 60)
    return days ? t("duration_days_hours", days, hours) : hours ? t("duration_hours_minutes", hours, minutes)
      : minutes ? t("duration_minutes", minutes) : t("duration_seconds", seconds)
  }
  function dateTime(value, timeOnly, subsecond) {
    var date = new Date(Number(value) * 1000)
    if (!isFinite(date.getTime())) return "—"
    var time = date.toLocaleTimeString(qtLocale, subsecond ? "HH:mm:ss.zzz" : "HH:mm:ss")
    return timeOnly ? time : date.toLocaleDateString(qtLocale, Locale.ShortFormat) + " " + time
  }
}
