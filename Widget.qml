pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
    id: root
    moduleName: "omarchy-github-stats"

    readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    property bool popupOpen: false
    property int tabIndex: 0
    property string detailDate: ""
    readonly property var selectedStats: service && service.stats ? service.stats.periods.week : null
    readonly property var detailDay: service && service.calendar ? service.calendar[detailDate] : null
    readonly property string countText: service && service.todayCount !== null ? String(service.todayCount) : "—"
    readonly property string description: "GitHub: " + (countText === "—" ? "today's contributions unavailable" : countText + " contributions today (UTC)")

    function close() { popupOpen = false }
    function toggle() {
        if (!popupOpen) { tabIndex = 0; detailDate = "" }
        popupOpen = !popupOpen
    }

    implicitWidth: trigger.implicitWidth
    implicitHeight: trigger.implicitHeight

    Button {
        id: trigger
        anchors.centerIn: parent
        iconText: root.vertical ? "" : ""
        text: root.vertical ? "\n" + root.countText : root.countText
        tooltipText: root.description
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        foreground: root.bar ? root.bar.barForeground : Commons.Color.foreground
        focusable: true
        Accessible.role: Accessible.Button
        Accessible.name: root.description
        onClicked: root.toggle()
    }

    PopupCard {
        id: popup
        anchorItem: root
        bar: root.bar
        owner: root
        open: root.popupOpen
        contentWidth: fittedContentWidth(Style.space(370))
        contentHeight: fittedContentHeight(content.implicitHeight)
        onOpenChanged: if (open) Qt.callLater(function() { tabs.itemAt(0).forceActiveFocus() })

        Controls.ScrollView {
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth

            Shortcut {
                sequence: "Escape"
                enabled: root.popupOpen
                context: Qt.WindowShortcut
                onActivated: root.close()
            }

            Column {
                id: content
                width: parent.width
                spacing: Style.space(12)

                Text {
                    width: parent.width
                    text: "GitHub Stats" + (root.service && root.service.identity ? " · " + root.service.identity.login : "")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Commons.Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.subtitle
                }

                Row {
                    width: parent.width
                    Repeater {
                        id: tabs
                        model: ["Stats", "PRs", "Issues"]
                        Button {
                            required property string modelData
                            required property int index
                            width: parent.width / 3
                            text: modelData
                            fontFamily: Style.font.family
                            selected: root.tabIndex === index
                            focusable: true
                            Accessible.role: Accessible.PageTab
                            Accessible.name: modelData
                            Accessible.selected: selected
                            onClicked: root.tabIndex = index
                            Keys.onLeftPressed: tabs.itemAt((index + 2) % 3).forceActiveFocus()
                            Keys.onRightPressed: tabs.itemAt((index + 1) % 3).forceActiveFocus()
                        }
                    }
                }

                Column {
                    visible: root.tabIndex === 0
                    width: parent.width
                    spacing: Style.space(8)

                    Text {
                        text: "7 days"
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }

                    Text {
                        width: parent.width
                        text: root.selectedStats
                            ? root.selectedStats.from.slice(0, 10) + " – " + root.selectedStats.to.slice(0, 10) + " (UTC)"
                            : "Seven-day activity is unavailable until a complete refresh succeeds."
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }

                    Row {
                        visible: root.selectedStats !== null
                        width: parent.width
                        spacing: Style.space(4)
                        Repeater {
                            id: tiles
                            model: root.selectedStats ? root.selectedStats.days : []
                            Column {
                                id: tile
                                required property var modelData
                                required property int index
                                readonly property int level: ["NONE", "FIRST_QUARTILE", "SECOND_QUARTILE", "THIRD_QUARTILE", "FOURTH_QUARTILE"].indexOf(modelData.contributionLevel)
                                objectName: "contribution-" + modelData.date
                                width: (parent.width - parent.spacing * 6) / 7
                                spacing: Style.space(4)
                                activeFocusOnTab: true
                                Accessible.role: Accessible.StaticText
                                Accessible.name: modelData.date + ": " + modelData.contributionCount + " contributions (UTC)"
                                onActiveFocusChanged: if (activeFocus) root.detailDate = modelData.date
                                Keys.onLeftPressed: tiles.itemAt(Math.max(0, index - 1)).forceActiveFocus()
                                Keys.onRightPressed: tiles.itemAt(Math.min(6, index + 1)).forceActiveFocus()
                                HoverHandler {
                                    onHoveredChanged: if (hovered) root.detailDate = tile.modelData.date
                                }
                                Rectangle {
                                    width: parent.width
                                    height: Style.space(28)
                                    radius: Style.space(3)
                                    color: tile.level === 0 ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.1)
                                        : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2 + tile.level * 0.2)
                                    border.width: tile.activeFocus ? 2 : 0
                                    border.color: Commons.Color.foreground
                                }
                                Text {
                                    width: parent.width
                                    text: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][new Date(tile.modelData.date + "T00:00:00Z").getUTCDay()]
                                        + "\n" + tile.modelData.date.slice(8) + "\n" + tile.modelData.contributionCount
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Commons.Color.foreground
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }
                            }
                        }
                    }

                    Text {
                        objectName: "contribution-details"
                        width: parent.width
                        visible: root.selectedStats !== null
                        text: root.detailDay ? root.detailDay.date + ": " + root.detailDay.contributionCount + " contributions (UTC)"
                            : "Hover or focus a tile for its full date and count."
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        Accessible.role: Accessible.StaticText
                        Accessible.name: text
                    }

                    Text {
                        visible: root.selectedStats !== null
                        width: parent.width
                        text: "Today (UTC) is incomplete. Counts are contributions, including activity beyond commits."
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }

                    Repeater {
                        model: root.selectedStats ? [
                            "Contributions: " + root.selectedStats.contributions,
                            "Commit contributions: " + root.selectedStats.commitContributions,
                            "PRs authored: " + root.selectedStats.prsAuthored,
                            "Issues authored: " + root.selectedStats.issuesAuthored
                        ] : []
                        Text {
                            required property string modelData
                            width: parent.width
                            text: modelData
                            wrapMode: Text.Wrap
                            color: Commons.Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            Accessible.role: Accessible.StaticText
                            Accessible.name: text
                        }
                    }
                }

                Text {
                    visible: root.tabIndex !== 0
                    width: parent.width
                    text: root.tabIndex === 1 ? "Pull request previews are not available yet." : "Issue previews are not available yet."
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Commons.Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                Text {
                    visible: root.tabIndex === 0
                    width: parent.width
                    text: "30-day and annual views, stars, and repository languages are not available yet."
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Commons.Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }

                Text {
                    width: parent.width
                    text: root.service ? root.service.statusText : "Waiting for the shared GitHub service."
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Commons.Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }

                Text {
                    width: parent.width
                    text: root.service && root.service.lastSuccess > 0
                        ? "Last successful update: " + new Date(root.service.lastSuccess).toLocaleString() + (root.service.stale ? " · stale" : "")
                        : "No successful update yet."
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Commons.Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }

                Button {
                    text: root.service && root.service.refreshing ? "Refreshing…" : "Refresh"
                    focusable: true
                    enabled: root.service !== null && !root.service.refreshing && root.service.retryAt <= root.service.now
                    Accessible.role: Accessible.Button
                    Accessible.name: "Refresh GitHub contributions"
                    onClicked: root.service.refresh()
                }
            }
        }
    }
}
