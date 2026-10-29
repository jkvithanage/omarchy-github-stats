pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons

// Supplemental explanations stay available to pointer, keyboard and accessibility users.
Text {
    id: root
    property string tooltipText: ""
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    color: Commons.Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    activeFocusOnTab: tooltipText !== ""
    Accessible.role: Accessible.StaticText
    Accessible.name: text
    Accessible.description: tooltipText

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        visible: root.activeFocus
        color: "transparent"
        border.width: 1
        border.color: Commons.Color.foreground
    }
    HoverHandler { id: hover }
    Controls.ToolTip {
        id: tooltip
        objectName: "info-tooltip"
        visible: root.tooltipText !== "" && (hover.hovered || root.activeFocus)
        text: root.tooltipText
        width: Math.min(implicitWidth, root.parent ? root.parent.width : root.width)
        contentItem: Text {
            text: tooltip.text
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.tooltip.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
        background: Rectangle {
            color: Commons.Color.tooltip.background
            border.color: Commons.Color.tooltip.border
        }
    }
}
