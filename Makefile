CXX ?= c++
CPPFLAGS ?=
CXXFLAGS ?= -O2 -pipe
LDFLAGS ?=
LDLIBS ?= -ldl

SAMPLER_FLAGS = -std=c++17 -DNDEBUG -fno-exceptions -fno-rtti \
	-fstack-protector-strong -fcf-protection -D_FORTIFY_SOURCE=3 \
	-Wall -Wextra -Wpedantic -Werror -ffile-prefix-map=$(CURDIR)=.
SAMPLER_LDFLAGS = -Wl,--as-needed -Wl,-z,relro -Wl,-z,now \
	-Wl,--build-id=none -s

.PHONY: all clean install-local check check-package check-install check-core check-ui

all: activity-sampler

activity-sampler: activity-sampler.cpp DiagnosticJournal.h FastDiagnostics.h
	LC_ALL=C $(CXX) $(CPPFLAGS) $(CXXFLAGS) $(SAMPLER_FLAGS) \
		$(LDFLAGS) $(SAMPLER_LDFLAGS) -o $@ $< $(LDLIBS)

clean:
	rm -f -- activity-sampler

check: check-package check-core check-ui check-install
	omarchy plugin validate .

check-package:
	PYTHONDONTWRITEBYTECODE=1 python3 test/package-checks.py

check-install:
	PYTHONDONTWRITEBYTECODE=1 python3 test/install-checks.py

check-core: activity-sampler
	PYTHONDONTWRITEBYTECODE=1 python3 test/fork-checks.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/publication-checks.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/content-regressions.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/content-checks.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/sensitive-checks.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/manifest-checks.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/lite-checks.py
	node test/controller-checks.js
	node test/icon-checks.js
	node docs/design-drafts/export-omarchy-characters.js
	node test/math-checks.js
	node test/catalog-checks.js
	PYTHONDONTWRITEBYTECODE=1 python3 test/diagnostic-checks.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/fast-diagnostics-checks.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/diagnostic-report-checks.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/sensor-controls.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/power-profile-checks.py
	PYTHONDONTWRITEBYTECODE=1 python3 test/game-detection-checks.py
	node test/profile-codec-checks.js
	PYTHONDONTWRITEBYTECODE=1 python3 test/nvidia-check.py

check-ui:
	PYTHONDONTWRITEBYTECODE=1 python3 test/ui-checks.py

# Explicit local deployment, never an automatic update job.
install-local: activity-sampler
	test ! -e "$(HOME)/.config/omarchy/plugins/slovn.activity-lite"
	install -d "$(HOME)/.config/omarchy/plugins/slovn.activity-lite"
	install -m644 Panel.qml PowerProfiles.qml ChoiceDropdown.qml ComputerMap.qml SvgIcon.qml ActivityIcon.qml ActivityIconSvg.js HeatPolicy.js DiagnosticExport.qml Diagnostics.qml ActivityController.qml ProcessActionController.qml Sparkline.qml SensorHistoryChart.qml Model.js I18n.js Messages.js ProfileCodec.js GameDetection.py manifest.json README.md LICENSE ATTRIBUTIONS.md "$(HOME)/.config/omarchy/plugins/slovn.activity-lite/"
	install -m755 activity-sampler process-signal activity-report diagnostic-report power-profile "$(HOME)/.config/omarchy/plugins/slovn.activity-lite/"
