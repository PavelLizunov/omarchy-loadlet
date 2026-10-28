"""Exercise the real icon in the installed native bar loader at DPR 1 and 2."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HOST = Path(os.environ.get('ACTIVITY_TEST_HOST', '/usr/share/omarchy/shell')).resolve()

with tempfile.TemporaryDirectory(prefix='loadlet-raster-') as directory:
    base = Path(directory)
    commons = base / 'RasterHost/Commons'
    ui = base / 'RasterHost/Ui'
    plugin = base / 'plugin'
    for path in (commons, ui, plugin):
        path.mkdir(parents=True)
    # Exact host controls plus the actual Panel bar block; all data/I/O is inert.
    host_types = ('BarIconContent', 'IconContentBounds', 'BarIconButton', 'WidgetButton', 'OpticalGlyph')
    runtime = base / 'RasterRuntime'
    runtime.mkdir()
    (runtime / 'qmldir').write_text('module RasterRuntime\nsingleton Quickshell 1.0 Quickshell.qml\n')
    (runtime / 'Quickshell.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { function env(key) { return "" } }\n')
    for name in host_types:
        text = (HOST / 'Ui' / (name + '.qml')).read_text()
        text = text.replace('import qs.Commons', 'import RasterHost.Commons').replace('import Quickshell\n', 'import RasterRuntime\n')
        (ui / (name + '.qml')).write_text(text)
    (ui / 'qmldir').write_text('module RasterHost.Ui\n' + ''.join(f'{name} 1.0 {name}.qml\n' for name in host_types))
    (commons / 'qmldir').write_text('module RasterHost.Commons\nsingleton Style 1.0 Style.qml\nsingleton Color 1.0 Color.qml\n')
    (commons / 'Style.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
  property real factor: 1
  readonly property var easeOut: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]
  property var font: ({family:"monospace",body:12})
  property var bar: ({iconCanvas:16*factor,iconSize:12*factor,iconSlot:27*factor,iconFont:13*factor,sizeHorizontal:26*factor})
  function spaceReal(value) { return value*factor }
  function space(value) { return Math.round(value*factor) }
  function duration(value) { return value }
}
''')
    (commons / 'Color.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property color foreground:"#d8dee9"; property color background:"#2e3440"; property color accent:"#81a1c1"; property color urgent:"#bf616a" }\n')
    for name in ('ActivityIcon.qml', 'ActivityIconSvg.js', 'HeatPolicy.js'):
        (plugin / name).write_text((ROOT / name).read_text().replace('import qs.Commons', 'import RasterHost.Commons'))
    panel = (ROOT / 'Panel.qml').read_text()
    start = panel.index('  // Native slot dimensions are unchanged;')
    end = panel.index('\n  KeyboardPanel {', start)
    block = panel[start:end]
    (plugin / 'BarConsumer.qml').write_text('''import QtQuick
import RasterHost.Commons
import RasterHost.Commons as Host
import RasterHost.Ui
Item {
  id: root
  width: 27; height: 26
  property Item barIcon: null
  property var bar: inertBar
  property int iconLoadThresholdSetting: 50
  property int iconShapeSetting: 10
  property string effectiveLanguage: "en"
  property string temperatureUnitSetting: "Celsius"
  property bool opened: false
  function booleanSetting(key, fallback) { return fallback }
  function percentText(value) { return Math.round(value)+"%" }
  function toggle() { opened=!opened }
  QtObject {
    id: inertBar
    property string fontFamily: "monospace"
    property color foreground: "#d8dee9"
    property color barForeground: foreground
    property color background: "#2e3440"
    property color urgent: "#bf616a"
    property bool vertical: false
    property int barSize: 26
    property bool foregroundAnimationEnabled: false
    function registerClickTarget(item) {}
    function unregisterClickTarget(item) {}
    function hideTooltip(item) {}
    function showTooltip(item, text) {}
  }
  QtObject {
    id: activity
    property real glanceCpu: 70
    property real glanceMemory: 44
    property bool glanceFresh: true
    property real glanceMemoryUsed: 1
    property real glanceMemoryTotal: 2
    property bool heatAlert: false
    property int heatLevel: 0
    property bool thermalFresh: false
    property double thermalUpdatedAt: 0
    property real iconTemperature: 55
  }
  QtObject { id: inertI18n; function t(key, language) { return key } }
  QtObject { id: inertModel; function formatBytes(value) { return String(value) } function formatTemperature(value, unit) { return String(value) } }
''' + block.replace('I18n.t(', 'inertI18n.t(').replace('Model.format', 'inertModel.format') + '\n}\n')
    (base / 'tst_raster.qml').write_text('''import QtQuick
import QtTest
import RasterHost.Ui as NativeHost
import RasterHost.Commons as Host
import "plugin" as Plugin
Item {
  id: scene
  width:160; height:100
  Plugin.BarConsumer { id:consumer; x:60; y:32 }
  NativeHost.BarIconContent {
    id:slot
    width:24; height:24
    property Item icon:null
    sourceComponent: Component {
      Plugin.ActivityIcon {
        Component.onCompleted:slot.icon=this
        motionEnabled:false
      }
    }
  }
  TestCase {
    name:"NativeBarRasterBudget"
    when:windowShown
    function test_final_bar_size() {
      var icon=consumer.barIcon
      verify(icon!==null)
      tryCompare(icon,'status',Image.Ready)
      var bounds=icon.mapToItem(consumer,0,0,icon.width,icon.height)
      fuzzyCompare(bounds.width,16,0.01,'the native loader must not shrink the 16-unit canvas')
      fuzzyCompare(bounds.height,16,0.01)
      fuzzyCompare(bounds.x+bounds.width/2,consumer.width/2,0.01)
      fuzzyCompare(bounds.y+bounds.height/2,consumer.height/2,0.01)
      for(var factor of [1,1.5,2]) {
        Host.Style.factor=factor
        consumer.width=27*factor;consumer.height=26*factor
        wait(10)
        bounds=icon.mapToItem(consumer,0,0,icon.width,icon.height)
        fuzzyCompare(bounds.width,16*factor,0.01)
        fuzzyCompare(bounds.height,16*factor,0.01)
        consumer.bar.vertical=true
        consumer.width=26*factor;consumer.height=27*factor
        wait(0)
        bounds=icon.mapToItem(consumer,0,0,icon.width,icon.height)
        fuzzyCompare(bounds.width,16*factor,0.01)
        fuzzyCompare(bounds.height,16*factor,0.01)
        fuzzyCompare(bounds.x+bounds.width/2,consumer.width/2,0.01)
        fuzzyCompare(bounds.y+bounds.height/2,consumer.height/2,0.01)
        consumer.bar.vertical=false
      }
      Host.Style.factor=1;consumer.width=27;consumer.height=26
      var button=icon.parent
      compare(button.width,27);compare(button.height,26)
      mouseClick(button,button.width/2,button.height/2,Qt.LeftButton)
      compare(consumer.opened,true)
      mouseClick(button,button.width/2,button.height/2,Qt.RightButton)
      compare(consumer.opened,true,'right click must remain inert')
      mouseClick(button,button.width/2,button.height/2,Qt.MiddleButton)
      compare(consumer.opened,true,'middle click must remain inert')
      mouseClick(button,button.width/2,button.height/2,Qt.LeftButton)
      compare(consumer.opened,false)
      for(var i=0;i<40;i++) {
        icon.cpu=(i*17)%100;icon.ram=(i*23)%100
        tryCompare(icon,'status',Image.Ready);wait(5)
        bounds=icon.mapToItem(consumer,0,0,icon.width,icon.height)
        fuzzyCompare(bounds.width,16,0.01)
        compare(icon.sourceSize.width,Math.ceil(16*icon.rasterDpr))
        compare(icon.implicitWidth,icon.sourceSize.width)
      }
    }
    function test_refresh() {
      verify(slot.icon!==null)
      slot.icon.fresh=true
      for(var i=0;i<40;i++) {
        slot.icon.cpu=(i*17)%100;slot.icon.ram=(i*23)%100
        tryCompare(slot.icon,'status',Image.Ready)
        wait(10)
        compare(slot.icon.width,16,'decoded pixel size must not replace logical width')
        compare(slot.icon.height,16)
        compare(slot.icon.sourceSize.width,Math.ceil(16*slot.icon.rasterDpr))
        compare(slot.icon.sourceSize.height,Math.ceil(16*slot.icon.rasterDpr))
        verify(slot.icon.sourceSize.width<=32)
      }
    }
  }
}''')
    if os.environ.get('ACTIVITY_ICON_PREVIEW_DIR'):
        shutil.copytree(base, Path(os.environ['ACTIVITY_ICON_PREVIEW_DIR']))
    runner = os.environ.get('ACTIVITY_QMLTESTRUNNER') or shutil.which('qmltestrunner') or '/usr/lib/qt6/bin/qmltestrunner'
    for scale in ('1', '2'):
        print(f'Native bar raster scale factor: {scale}', flush=True)
        result = subprocess.run([runner, '-input', str(base / 'tst_raster.qml'), '-import', str(base)],
                                env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_SCALE_FACTOR=scale),
                                capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output, end='')
        if result.returncode or any(token in output for token in ('QWARN', 'QCRITICAL', 'TypeError:', 'ReferenceError:')):
            raise SystemExit(result.returncode or 1)
