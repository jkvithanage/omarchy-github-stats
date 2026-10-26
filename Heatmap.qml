pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons

Item {
    id: root
    required property var periodStats
    required property string period
    readonly property var layout: periodStats ? periodStats.layout : null
    readonly property bool annual: period === "year"
    readonly property real gap: Style.space(4)
    readonly property real labelWidth: annual ? Style.space(30) : 0
    readonly property real tileWidth: annual ? Style.space(22) : Math.max(Style.space(32), (width - gap * 6) / 7)
    readonly property real tileHeight: annual ? tileWidth : Style.space(period === "week" ? 82 : 58)
    readonly property real headerHeight: Style.space(annual ? 34 : period === "month" ? 20 : 0)
    property alias contentX: viewport.contentX
    signal daySelected(string date)
    signal tileFocused(Item tile)
    objectName: "contribution-chart"
    implicitHeight: layout ? headerHeight + layout.rows * (tileHeight + gap) + Style.space(16) : 0
    visible: layout !== null

    function focusDate(index, step) {
        for (var next = index + step; next >= 0 && next < tiles.count; next += step) {
            var tile = tiles.itemAt(next)
            if (tile.modelData) { tile.forceActiveFocus(); return }
        }
    }

    function reveal(tile) {
        var left = grid.x + tile.x
        var right = left + tile.width
        if (left < viewport.contentX) viewport.contentX = left
        else if (right > viewport.contentX + viewport.width) viewport.contentX = right - viewport.width
        viewport.contentX = Math.max(0, Math.min(viewport.contentX, viewport.contentWidth - viewport.width))
        root.tileFocused(tile)
    }

    onPeriodChanged: viewport.contentX = 0

    Flickable {
        id: viewport
        anchors.fill: parent
        clip: true
        contentWidth: root.labelWidth + (root.layout ? root.layout.columns * (root.tileWidth + root.gap) - root.gap : 0)
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.horizontal: Controls.ScrollBar {
            policy: viewport.contentWidth > viewport.width ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
        }

        Repeater {
            model: root.annual && root.layout ? root.layout.months : []
            Text {
                required property var modelData
                x: root.labelWidth + modelData.column * (root.tileWidth + root.gap)
                text: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][Number(modelData.date.slice(5)) - 1]
                    + "\n" + modelData.date.slice(0, 4)
                color: Commons.Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }

        Repeater {
            model: root.period === "week" ? [] : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            Text {
                required property string modelData
                required property int index
                x: root.annual ? 0 : index * (root.tileWidth + root.gap)
                y: root.annual ? root.headerHeight + index * (root.tileHeight + root.gap) : 0
                width: root.annual ? root.labelWidth : root.tileWidth
                text: modelData
                horizontalAlignment: Text.AlignHCenter
                color: Commons.Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }

        Item {
            id: grid
            x: root.labelWidth
            y: root.headerHeight

            Repeater {
                id: tiles
                model: root.layout ? root.layout.cells : []
                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property int level: modelData ? ["NONE", "FIRST_QUARTILE", "SECOND_QUARTILE", "THIRD_QUARTILE", "FOURTH_QUARTILE"].indexOf(modelData.contributionLevel) : 0
                    objectName: modelData ? "contribution-" + modelData.date : "calendar-padding"
                    x: (root.annual ? Math.floor(index / 7) : index % 7) * (root.tileWidth + root.gap)
                    y: (root.annual ? index % 7 : Math.floor(index / 7)) * (root.tileHeight + root.gap)
                    width: root.tileWidth
                    height: root.tileHeight
                    activeFocusOnTab: modelData !== null
                    Accessible.ignored: modelData === null
                    Accessible.role: Accessible.StaticText
                    Accessible.name: modelData ? modelData.date + ": " + modelData.contributionCount + " contributions (UTC)" : ""
                    onActiveFocusChanged: if (activeFocus && modelData) {
                        root.daySelected(modelData.date)
                        root.reveal(tile)
                    }
                    Keys.onLeftPressed: root.focusDate(index, root.annual ? -7 : -1)
                    Keys.onRightPressed: root.focusDate(index, root.annual ? 7 : 1)
                    Keys.onUpPressed: root.focusDate(index, root.annual ? -1 : root.period === "month" ? -7 : -1)
                    Keys.onDownPressed: root.focusDate(index, root.annual ? 1 : root.period === "month" ? 7 : 1)
                    HoverHandler {
                        id: hover
                        enabled: tile.modelData !== null
                        onHoveredChanged: if (hovered && tile.modelData) root.daySelected(tile.modelData.date)
                    }
                    Controls.ToolTip {
                        id: tooltip
                        objectName: "contribution-tooltip"
                        visible: tile.modelData !== null && (tile.activeFocus || hover.hovered)
                        text: tile.Accessible.name
                        width: Math.min(implicitWidth, Math.max(120, root.width))
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
                    Rectangle {
                        visible: tile.modelData !== null
                        width: parent.width
                        height: root.annual ? parent.height : Style.space(28)
                        radius: Style.space(3)
                        color: tile.level === 0 ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.1)
                            : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2 + tile.level * 0.2)
                        border.width: tile.activeFocus ? 2 : 0
                        border.color: Commons.Color.foreground
                    }
                    Text {
                        visible: tile.modelData !== null && !root.annual
                        y: Style.space(32)
                        width: parent.width
                        text: !tile.modelData ? "" : (root.period === "week"
                            ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][new Date(tile.modelData.date + "T00:00:00Z").getUTCDay()] + "\n" : "")
                            + tile.modelData.date.slice(8) + "\n" + tile.modelData.contributionCount
                        horizontalAlignment: Text.AlignHCenter
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }
    }
}
