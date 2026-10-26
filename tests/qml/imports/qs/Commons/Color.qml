pragma Singleton
import QtQuick

QtObject {
    property color foreground: "#eeeeee"
    property color accent: "#6699cc"
    readonly property QtObject tooltip: QtObject {
        readonly property color text: "#eeeeee"
        readonly property color background: "#202020"
        readonly property color border: "#eeeeee"
    }
}
