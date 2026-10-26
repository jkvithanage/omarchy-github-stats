QT_BIN ?= /usr/lib/qt6/bin
OMARCHY_PATH ?= /usr/share/omarchy

.PHONY: test lint manifest smoke check
test:
	node tests/service.test.cjs
	QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic QT_QUICK_CONTROLS_STYLE=Basic $(QT_BIN)/qmltestrunner -import tests/qml/imports -input tests/qml

lint:
	node --check ServiceModel.js
	@imports=$$(mktemp -d); trap 'rm -rf "$$imports"' EXIT; \
	mkdir "$$imports/qs"; \
	ln -s "$(OMARCHY_PATH)/shell/Ui" "$$imports/qs/Ui"; \
	ln -s "$(OMARCHY_PATH)/shell/Commons" "$$imports/qs/Commons"; \
	$(QT_BIN)/qmllint -I "$$imports" Service.qml Widget.qml Heatmap.qml

manifest:
	$(OMARCHY_PATH)/bin/omarchy-plugin-validate .

smoke:
	python3 tests/native_smoke.py

check: test lint manifest
