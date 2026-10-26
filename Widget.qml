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
    property int periodIndex: 0
    readonly property string period: ["week", "month", "year"][periodIndex]
    readonly property var selectedStats: service && service.stats ? service.stats.periods[period] : null
    readonly property var detailDay: service && service.calendar ? service.calendar[detailDate] : null
    readonly property var repositoryState: service ? service.repositories : null
    readonly property var repositorySnapshot: repositoryState ? repositoryState.data : null
    readonly property string countText: service && service.todayCount !== null ? String(service.todayCount) : "—"
    readonly property string description: "GitHub: " + (countText === "—" ? "today's contributions unavailable" : countText + " contributions today (UTC)")

    function close() { popupOpen = false }
    function revealPopupItem(item) {
        var viewport = popupScroll.contentItem
        var point = item.mapToItem(content, 0, 0)
        var position = viewport.contentY
        if (point.y < position) position = point.y
        else if (point.y + item.height > position + viewport.height) position = point.y + item.height - viewport.height
        viewport.contentY = Math.max(0, Math.min(position, viewport.contentHeight - viewport.height))
    }
    onTabIndexChanged: if (popupScroll.contentItem) popupScroll.contentItem.contentY = 0
    function toggle() {
        if (!popupOpen) { tabIndex = 0; periodIndex = 0; detailDate = "" }
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
            id: popupScroll
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

                    Flow {
                        width: parent.width
                        spacing: Style.space(4)
                        Repeater {
                            id: periods
                            model: ["7 days", "30 days", "12 months"]
                            Button {
                                required property string modelData
                                required property int index
                                width: Math.max(Style.space(90), (parent.width - parent.spacing * 2) / 3)
                                text: modelData
                                fontSize: Style.font.caption
                                horizontalPadding: Style.space(4)
                                selected: root.periodIndex === index
                                focusable: true
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: modelData
                                Accessible.checked: selected
                                onClicked: { root.periodIndex = index; root.detailDate = "" }
                                Keys.onLeftPressed: periods.itemAt((index + 2) % 3).forceActiveFocus()
                                Keys.onRightPressed: periods.itemAt((index + 1) % 3).forceActiveFocus()
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.selectedStats
                            ? root.selectedStats.from.slice(0, 10) + " – " + root.selectedStats.to.slice(0, 10) + " (UTC)"
                            : "Period activity is unavailable until a complete refresh succeeds."
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }

                    Heatmap {
                        width: parent.width
                        periodStats: root.selectedStats
                        period: root.period
                        onDaySelected: function(date) { root.detailDate = date }
                        onTileFocused: function(tile) { root.revealPopupItem(tile) }
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

                WorkList {
                    objectName: "pr-work-list"
                    visible: root.tabIndex === 1
                    width: parent.width
                    section: root.service ? root.service.prs : null
                    refreshing: root.service ? root.service.refreshing : false
                    sectionName: "PRs"
                    onOpenUrl: function(url) { Qt.openUrlExternally(url) }
                    onLinkFocused: function(link) { root.revealPopupItem(link) }
                }

                WorkList {
                    objectName: "issue-work-list"
                    visible: root.tabIndex === 2
                    width: parent.width
                    section: root.service ? root.service.issues : null
                    refreshing: root.service ? root.service.refreshing : false
                    sectionName: "Issues"
                    onOpenUrl: function(url) { Qt.openUrlExternally(url) }
                    onLinkFocused: function(link) { root.revealPopupItem(link) }
                }

                Column {
                    visible: root.tabIndex === 0
                    width: parent.width
                    spacing: Style.space(8)
                    Text {
                        width: parent.width
                        text: "Current repository snapshots · all periods"
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }
                    Text {
                        width: parent.width
                        text: root.repositorySnapshot ? "Stars: " + root.repositorySnapshot.stars : "Stars: —"
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        Accessible.role: Accessible.StaticText
                        Accessible.name: text
                    }
                    Text {
                        width: parent.width
                        text: "Repository languages (code bytes)"
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }
                    Repeater {
                        model: root.repositorySnapshot ? root.repositorySnapshot.languages : []
                        Text {
                            required property var modelData
                            width: parent.width
                            text: modelData.name + ": " + modelData.percentage.toFixed(1) + "% · " + modelData.bytes + " bytes"
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            Accessible.role: Accessible.StaticText
                            Accessible.name: text
                        }
                    }
                    Text {
                        visible: !root.repositorySnapshot || root.repositorySnapshot.totalBytes === 0
                        width: parent.width
                        text: root.repositorySnapshot ? "No repository language bytes reported."
                            : root.repositoryState && root.repositoryState.errorKind ? "Repository snapshots unavailable. See refresh status below."
                            : root.service && root.service.refreshing ? "Loading complete repository snapshots…" : "Repository snapshots have not loaded yet."
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }
                    Text {
                        width: parent.width
                        text: "Personally owned public and accessible private repositories, excluding forks; includes archived repositories. Language shares describe repository contents."
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }
                    Text {
                        visible: root.repositoryState && root.repositoryState.lastSuccess > 0
                        width: parent.width
                        text: root.repositoryState ? "Repository snapshot updated: " + new Date(root.repositoryState.lastSuccess).toLocaleString()
                            + (root.repositoryState.stale ? " · stale" : "") : ""
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
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
