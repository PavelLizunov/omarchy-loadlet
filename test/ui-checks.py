"""Run the real plugin with inert IO and installed host widgets, without Wayland."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[1]
HOST = Path(os.environ.get('ACTIVITY_TEST_HOST', '/usr/share/omarchy/shell')).resolve()
TYPES = {
    'Quickshell': '''pragma Singleton
import QtQuick
QtObject {
  property string clipboardText: ""
  function env(key) { return key === "USER" ? "demo" : "" }
  function execDetached(argv) {}
}''',
    'IpcHandler': 'import QtQuick\nItem { property string target: "" }',
    'Hyprland/Hyprland': '''pragma Singleton
import QtQuick
QtObject { signal rawEvent(var event) }''',
    'Io/Process': '''import QtQuick
Item {
  property bool running: false
  property var command: []
  property var environment: ({})
  property bool clearEnvironment: false
  property bool stdinEnabled: false
  property var stdout: null
  property var stderr: null
  signal started()
  signal exited(int code)
  function write(data) {}
  function signal(value) {}
}''',
    'Io/FileView': '''import QtQuick
Item {
  property string path: ""
  property bool watchChanges: false
  property bool printErrors: false
  property bool blockLoading: false
  signal loaded()
  signal loadFailed()
  signal fileChanged()
  function reload() {}
  function text() { return "" }
}''',
    'Io/SplitParser': 'import QtQuick\nItem { signal read(string line) }',
    'Io/StdioCollector': '''import QtQuick
Item {
  property string text: ""
  property bool waitForEnd: false
  signal streamFinished()
}''',
    'Io/IpcHandler': 'import QtQuick\nItem { property string target: "" }',
}

def prepare(directory):
    base = Path(directory)
    imports = base / 'imports'
    for module in ['Ui', 'Commons']:
        shutil.copytree(HOST / module, imports / 'ActivityHost' / module)
    # Import only reviewed display dependencies, not unrelated host services.
    commons = imports / 'ActivityHost/Commons'
    exports = ['singleton Border 1.0 Border.qml', 'singleton Color 1.0 Color.qml',
               'singleton Style 1.0 Style.qml', 'singleton Util 1.0 Util.qml']
    if (commons / 'I18n.qml').is_file():
        exports.append('singleton I18n 1.0 I18n.qml')
    exports.append('ShellIpc 1.0 ShellIpc.qml')
    (commons / 'qmldir').write_text('module ActivityHost.Commons\n' + '\n'.join(exports) + '\n')
    (commons / 'ShellIpc.qml').write_text('import QtQuick\nItem { property string target: "" }\n')
    for name, source in TYPES.items():
        dest = imports / 'ActivityFixture' / (name + '.qml')
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(source)
    (imports / 'ActivityFixture/qmldir').write_text('module ActivityFixture\nsingleton Quickshell 1.0 Quickshell.qml\nIpcHandler 1.0 IpcHandler.qml\n')
    (imports / 'ActivityFixture/Hyprland/qmldir').write_text('module ActivityFixture.Hyprland\nsingleton Hyprland 1.0 Hyprland.qml\n')
    (imports / 'ActivityFixture/Io/qmldir').write_text('module ActivityFixture.Io\n' + ''.join(
        f'{name} 1.0 {name}.qml\n' for name in ['Process', 'FileView', 'SplitParser', 'StdioCollector', 'IpcHandler']))
    # Keep host sizing formulas and card insets; replace only the Wayland window.
    host_window = (HOST / 'Ui/KeyboardPanel.qml').read_text()
    sizing = host_window[host_window.index('  function fittedContentWidth('):host_window.index('  function cappedContentHeight(')]
    (imports / 'ActivityHost/Ui/KeyboardPanel.qml').write_text('''import QtQuick
import qs.Commons
Item {
  id: root
  visible: open
  property Item anchorItem: null
  property QtObject bar: null
  property var owner: null
  property int padding: Style.spacing.popupPadding
  property int contentWidth: 280
  property int contentHeight: 200
  property bool centerOnBar: false
  property bool open: false
  property Item focusTarget: null
  property var borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
  readonly property real availableCardWidth: parent ? parent.width : 0
  readonly property real availableCardHeight: parent ? parent.height : 0
  readonly property real verticalContentInset: padding * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)
  width: contentWidth
  height: contentHeight
''' + sizing + '''
  BorderSurface {
    id: card
    anchors.fill: parent
    color: Color.popups.background
    borderSpec: root.borderSpec
    padding: root.padding
    radius: Style.cornerRadius
    Item {
      id: holder
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
    }
  }
  default property alias contentItem: holder.children
}''')
    # Render the actual bar tooltip's content without its Wayland PopupWindow.
    bar_source = (HOST / 'plugins/bar/Bar.qml').read_text()
    start = bar_source.index('      BorderSurface {\n        id: tooltipBubble')
    end = bar_source.index('\n    }\n\n    Component {', start)
    bubble = bar_source[start:end]
    (imports / 'ActivityHost/Ui/ActivityTooltipBubble.qml').write_text('''import QtQuick
import qs.Commons
import qs.Commons as Commons
Item {
  id: root
  property string tooltipText: ""
  property string fontFamily: Style.font.family
  implicitWidth: tooltipBubble.implicitWidth
  implicitHeight: tooltipBubble.implicitHeight
''' + bubble.replace('id: tooltipBubble', 'id: tooltipBubble\n        objectName: "activityTooltipBubble"') + '\n}\n')
    plugin = base / 'plugin'
    plugin.mkdir()
    for name in ['Panel.qml', 'ComputerMap.qml', 'SvgIcon.qml', 'ActivityIcon.qml', 'ActivityIconSvg.js', 'HeatPolicy.js', 'DiagnosticExport.qml', 'ActivityController.qml', 'ProcessActionController.qml', 'Sparkline.qml', 'SensorHistoryChart.qml', 'Model.js', 'I18n.js', 'Messages.js']:
        shutil.copyfile(ROOT / name, plugin / name)
    shutil.copyfile(ROOT / 'test/mock-data.js', base / 'mock-data.js')
    shutil.copyfile(ROOT / 'test/tst_panel.qml', base / 'tst_panel.qml')
    # Native MCP statically registers Quickshell; an identically named mock
    # cannot override it. Use a distinct fixture-only module to keep ALL I/O
    # inert in both native preview and QtTest. Runtime imports are unchanged.
    for source in [*imports.rglob('*.qml'), *imports.rglob('qmldir'), *plugin.glob('*.qml'), base / 'tst_panel.qml']:
        text = source.read_text().replace('import Quickshell.Io', 'import ActivityFixture.Io')
        text = text.replace('import Quickshell.Hyprland', 'import ActivityFixture.Hyprland')
        text = text.replace('import Quickshell\n', 'import ActivityFixture\n')
        # A distinct host-module name prevents mixed file:/qs: singleton
        # identities in the native adapter. All widgets share ONE palette.
        text = text.replace('import qs.', 'import ActivityHost.').replace('module qs.', 'module ActivityHost.')
        # Qt 6.12 adds QtQuick.Color. Qualify palette references only in copied
        # host widgets, preserving native geometry and control behavior.
        if (source.suffix == '.qml' and source.parent.name in ['Ui', 'Commons']
                and source.name != 'Color.qml' and 'Color.' in text):
            text = text.replace('import QtQuick', 'import QtQuick\nimport ActivityHost.Commons as Host', 1)
            text = re.sub(r'(?<![\w.])Color\.', 'Host.Color.', text)
        source.write_text(text)
    return imports

def main():
    subprocess.run([sys.executable, str(ROOT / 'test/icon-raster-checks.py')], check=True)
    if len(sys.argv) == 3 and sys.argv[1] == '--preview-dir':
        base = Path(sys.argv[2])
        base.mkdir(exist_ok=False)
        imports = prepare(base)
        for name in ['render-icon-update.qml', 'render-tooltip.qml', 'render-video-icon.qml']:
            (base / name).write_text((ROOT / 'test' / name).read_text()
                .replace('import qs.', 'import ActivityHost.'))
        print(f'Inert consumer: {base / "render-icon-update.qml"}; imports: {imports}')
        return
    with tempfile.TemporaryDirectory(prefix='activity-ui-') as directory:
        imports = prepare(directory)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
        runner = os.environ.get('ACTIVITY_QMLTESTRUNNER') or shutil.which('qmltestrunner') or '/usr/lib/qt6/bin/qmltestrunner'
        result = subprocess.run([runner, '-input', str(Path(directory) / 'tst_panel.qml'),
                                 '-import', str(imports)], env=env, timeout=30,
                                capture_output=True, text=True)
        print(result.stdout, end='')
        print(result.stderr, end='', file=sys.stderr)
        # QtTest can exit 0 with broken bindings. Warnings are not a UI pass.
        bad_diagnostics = any(token in result.stdout + result.stderr
                              for token in ['QWARN', 'QCRITICAL', 'TypeError:', 'ReferenceError:'])
        raise SystemExit(result.returncode or int(bad_diagnostics))

if __name__ == '__main__':
    main()
