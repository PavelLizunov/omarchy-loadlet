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
    # Only native geometry and the production icon; no host services or I/O.
    for name in ('BarIconContent.qml', 'IconContentBounds.qml'):
        text = (HOST / 'Ui' / name).read_text().replace('import qs.Commons', 'import RasterHost.Commons')
        (ui / name).write_text(text)
    (ui / 'qmldir').write_text('module RasterHost.Ui\nBarIconContent 1.0 BarIconContent.qml\nIconContentBounds 1.0 IconContentBounds.qml\n')
    (commons / 'qmldir').write_text('module RasterHost.Commons\nsingleton Style 1.0 Style.qml\nsingleton Color 1.0 Color.qml\n')
    (commons / 'Style.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var bar: ({iconCanvas:16,iconSize:16}) }\n')
    (commons / 'Color.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property color foreground:"#d8dee9"; property color background:"#2e3440"; property color accent:"#81a1c1"; property color urgent:"#bf616a" }\n')
    for name in ('ActivityIcon.qml', 'ActivityIconSvg.js', 'HeatPolicy.js'):
        (plugin / name).write_text((ROOT / name).read_text().replace('import qs.Commons', 'import RasterHost.Commons'))
    (base / 'tst_raster.qml').write_text('''import QtQuick
import QtTest
import RasterHost.Ui as NativeHost
import "plugin" as Plugin
Item {
  width:80; height:60
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
