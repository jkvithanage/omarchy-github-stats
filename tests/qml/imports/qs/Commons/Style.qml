pragma Singleton
import QtQuick

// Host theme boundary for compositor-independent keyboard tests.
QtObject {
    readonly property QtObject font: QtObject {
        readonly property string family: "monospace"
        readonly property int caption: 10
        readonly property int bodySmall: 12
    }
    function space(value) { return value }
}
