#!/usr/bin/env python3
"""Load the real plugin/components in an isolated native Quickshell instance."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SHELL = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")) / "shell"

with tempfile.TemporaryDirectory(prefix="github-stats-native-") as temporary:
    stage = Path(temporary)
    runtime = stage / "runtime"
    runtime.mkdir(mode=0o700)
    for name in ("Widget.qml", "Heatmap.qml", "WorkList.qml", "InfoText.qml", "Service.qml", "ServiceModel.js"):
        shutil.copyfile(ROOT / name, stage / name)
    for name in ("Ui", "Commons"):
        (stage / name).symlink_to(SHELL / name, target_is_directory=True)
    harness = (ROOT / "tests/native/shell.qml").read_text().replace('"../.."', '"."').replace('"../../ServiceModel.js"', '"ServiceModel.js"')
    (stage / "shell.qml").write_text(harness)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="wayland",
               QT_QPA_PLATFORMTHEME="basic", QT_QUICK_CONTROLS_STYLE="Basic",
               PATH=str(ROOT / "tests/native") + ":" + os.environ["PATH"],
               GH_DEBUG="api")  # The adapter must remove inherited debug logging.
    display = env.get("WAYLAND_DISPLAY", "wayland-1")
    if not display.startswith("/"):
        env["WAYLAND_DISPLAY"] = str(Path(os.environ["XDG_RUNTIME_DIR"]) / display)
    for mode in ("success", "stale", "auth", "network", "rate", "hang"):
        result = subprocess.run(["qs", "-p", str(stage / "shell.qml"), "--no-color"],
                                env=dict(env, STATS_FIXTURE=mode, STATS_FIXTURE_CONTROL=str(stage / "stale-control")), text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=38)
        output = result.stdout
        if result.returncode or f"NATIVE_SMOKE_PASS {mode}" not in output or "private-response-sentinel" in output or "ERROR" in output or "Error:" in output:
            raise SystemExit(f"Native smoke failed ({mode}):\n{output}")
        print(f"Native smoke passed: {mode}", flush=True)
