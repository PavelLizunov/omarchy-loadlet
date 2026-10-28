import QtQuick
import qs.Commons
import qs.Commons as Host

Image {
  id: root
  property string name: ""
  property color tint: Host.Color.popups.text
  // Small original outline symbols; no font or external asset dependency.
  readonly property var paths: ({
    quiet: '<path d="M16 3a9 9 0 1 0 5 14A8 8 0 0 1 16 3Z"/>',
    games: '<path d="M7 7h10c5 0 6 12 3 13-2 1-4-4-6-4h-4c-2 0-4 5-6 4C1 19 2 7 7 7Z M7 10v5m-2-2h4m7-2h.01m2 3h.01"/>',
    overview: '<path d="M3 3v18h18M7 16v-5m5 5V7m5 9v-3"/>',
    temperature: '<path d="M9 14.5V5a3 3 0 0 1 6 0v9.5a5 5 0 1 1-6 0Z"/><path d="M12 8v10"/><circle cx="12" cy="18" r="1"/>',
    fans: '<circle cx="12" cy="12" r="2"/><path d="M10 10C4 9 4 3 8 3c4 0 5 4 4 7m2 0c1-6 7-6 7-2 0 4-4 5-7 4m0 2c6 1 6 7 2 7-4 0-5-4-4-7m-2 0c-1 6-7 6-7 2 0-4 4-5 7-4"/>',
    cpu: '<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 3v3m6-3v3M9 18v3m6-3v3M3 9h3m-3 6h3m12-6h3m-3 6h3"/><rect x="10" y="10" width="4" height="4"/>',
    ram: '<rect x="3" y="6" width="18" height="11" rx="1"/><path d="M6 17v3m4-3v3m4-3v3m4-3v3M7 10v3m5-3v3m5-3v3"/>',
    gpu: '<rect x="3" y="5" width="18" height="13" rx="1"/><circle cx="11" cy="11.5" r="3.5"/><path d="M17 9h1m-1 5h1M6 18v3m4-3v3m-7-3H1"/>',
    network: '<path d="M5 12a10 10 0 0 1 14 0M2 8a15 15 0 0 1 20 0M8 16a6 6 0 0 1 8 0"/><circle cx="12" cy="20" r="1"/>',
    disk: '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="12" cy="11" r="4"/><path d="m12 11 4 5M6 17h1"/>',
    storage: '<path d="m5 4-3 11v5h20v-5L19 4Z M2 15h20M6 18h1m3 0h1"/>',
    language: '<path d="M3 5h12M9 3v2M5 5c1 5 4 8 9 10M13 5c-1 5-4 8-9 10m10 6 4-10 4 10m-6-3h4"/>',
    help: '<circle cx="12" cy="12" r="9"/><path d="M9 9a3 3 0 1 1 5 2c-1 1-2 1-2 3m0 3h.01"/>',
    settings: '<path d="m9 3-1 3-3 1-2 3 2 2-1 3 2 3 3-1 3 4 3-4 3 1 2-3-1-3 2-2-2-3-3-1-1-3Z"/><circle cx="12" cy="12" r="3"/>',
    expand: '<path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5"/>',
    collapse: '<path d="M3 8h5V3m8 0v5h5M8 21v-5H3m13 5v-5h5"/>',
    restore: '<path d="M3 10a9 9 0 1 1 2 8M3 4v6h6"/>',
    check: '<path d="m4 12 5 5L20 6"/>',
    stop: '<circle cx="12" cy="12" r="9"/><path d="m8 8 8 8m0-8-8 8"/>',
    kill: '<path d="M7 15H5V9a7 7 0 0 1 14 0v6h-2v5H7Z M10 20v-3m4 3v-3"/><circle cx="9" cy="10" r="1"/><circle cx="15" cy="10" r="1"/>',
    export: '<path d="M12 3v12m-4-4 4 4 4-4M4 15v6h16v-6"/>',
    copy: '<rect x="8" y="8" width="12" height="13" rx="1"/><path d="M16 8V3H3v13h5"/>',
    close: '<path d="m6 6 12 12M6 18 18 6"/>'
  })
  readonly property string strokeColor: "#" + [tint.r, tint.g, tint.b].map(function(channel) {
    return Math.round(channel * 255).toString(16).padStart(2, "0")
  }).join("")
  width: Style.space(16)
  height: width
  fillMode: Image.PreserveAspectFit
  readonly property int pixelWidth: Math.max(1, Math.ceil(width * Screen.devicePixelRatio))
  readonly property int pixelHeight: Math.max(1, Math.ceil(height * Screen.devicePixelRatio))
  sourceSize.width: pixelWidth
  sourceSize.height: pixelHeight
  source: paths[name] ? "data:image/svg+xml;utf8," + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="' + pixelWidth + '" height="' + pixelHeight
      + '" viewBox="0 0 24 24" fill="none" stroke="' + strokeColor + '" stroke-opacity="' + tint.a
      + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + paths[name] + '</svg>') : ""
}
