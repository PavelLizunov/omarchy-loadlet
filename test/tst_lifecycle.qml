import QtQuick
import QtTest
import ".." as Plugin

Item {
  Plugin.ActivityController { id: controller }
  TestCase {
    name: "ActivityLiteLifecycle"
    function cleanup() {
      controller.active = false
      tryCompare(controller, "sampling", false, 3000)
      tryCompare(controller, "state", "stopped", 3000)
    }
    function test_closed_is_idle() {
      compare(controller.sampling, false)
      compare(controller.state, "stopped")
      compare(controller.snapshot.sample, 0)
    }
    function test_open_sample_close() {
      controller.active = true
      tryCompare(controller, "state", "ready", 3000)
      tryVerify(function() { return controller.snapshot.sample > 0 }, 5000)
      controller.active = false
      tryCompare(controller, "sampling", false, 3000)
      compare(controller.snapshot.sample, 0)
    }
    function test_fast_reopen() {
      controller.active = true
      tryCompare(controller, "state", "ready", 3000)
      controller.active = false
      controller.active = true
      tryCompare(controller, "state", "ready", 6000)
      tryVerify(function() { return controller.snapshot.sample > 0 }, 5000)
    }
  }
}
