pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "ServiceModel.js" as Model

Item {
    id: root

    property double now: Date.now()
    // Keep construction independent of the ticking clock's QML binding.
    property var model: new Model.Service(Date.now())
    readonly property var identity: model.identity
    readonly property var calendar: model.calendar
    readonly property var todayCount: model.todayCount(now)
    readonly property bool refreshing: model.active !== null
    readonly property double lastSuccess: model.lastSuccess
    readonly property bool stale: model.stale
    readonly property string errorKind: model.errorKind
    readonly property double retryAt: model.retryAt
    readonly property string statusText: model.statusText(now)

    function dispatch(request) {
        modelChanged()
        if (!request) return
        var worker = requestComponent.createObject(root, { request: request })
        worker.running = true
    }

    function refresh() {
        now = Date.now()
        dispatch(model.refresh(now))
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.now = Date.now()
            root.dispatch(root.model.tick(root.now))
        }
    }

    Component {
        id: requestComponent
        Process {
            id: worker
            required property var request
            property bool launched: false
            property bool settled: false
            command: request.command
            // Do not inherit gh's response-debug logging or interactive prompts.
            environment: ({ GH_PROMPT_DISABLED: "1", GH_DEBUG: null, GH_FORCE_TTY: null })
            stdout: StdioCollector { id: output }
            stderr: StdioCollector { id: errors }

            property Timer deadline: Timer {
                interval: 30000
                running: true
                onTriggered: {
                    worker.signal(9)
                    worker.finish(-1, worker.launched ? "timeout" : "gh")
                }
            }

            function finish(code, failure) {
                if (settled) return
                settled = true
                deadline.stop()
                var next = root.model.complete(request.id, {
                    code: code, stdout: output.text, stderr: errors.text, failure: failure
                }, Date.now())
                root.modelChanged()
                Qt.callLater(function() { root.dispatch(next) })
                destroy()
            }

            onStarted: launched = true
            onExited: function(exitCode) {
                deadline.stop()
                // Let both collectors finish before consuming the response.
                Qt.callLater(function() { worker.finish(exitCode, "") })
            }
        }
    }
}
