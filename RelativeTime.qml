pragma ComponentBehavior: Bound
import QtQuick

InfoText {
    id: root
    required property double timestamp
    property double now: Date.now()
    readonly property double age: Math.max(0, now - timestamp)
    text: timestamp <= 0 || !isFinite(timestamp) ? "Update time unavailable"
        : "Updated " + (age < 60000 ? "just now"
        : age < 3600000 ? Math.floor(age / 60000) + "m ago"
        : age < 86400000 ? Math.floor(age / 3600000) + "h ago"
        : age < 604800000 ? Math.floor(age / 86400000) + "d ago"
        : new Date(timestamp).toLocaleDateString(Qt.locale(), Locale.ShortFormat))
    tooltipText: timestamp > 0 && isFinite(timestamp) ? new Date(timestamp).toLocaleString() : "No successful update time available."

    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }
}
