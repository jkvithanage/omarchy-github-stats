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
    property int periodIndex: 0
    readonly property string period: ["week", "month", "year"][periodIndex]
    readonly property var selectedStats: service && service.stats ? service.stats.periods[period] : null
    readonly property var repositoryState: service ? service.repositories : null
    readonly property var repositorySnapshot: repositoryState ? repositoryState.data : null
    readonly property string countText: service && service.todayCount !== null ? String(service.todayCount) : "—"
    readonly property string description: "GitHub: " + (countText === "—" ? "today's contributions unavailable" : countText + " contributions today")

    readonly property string calendarExplanation: "Dates and daily totals follow GitHub’s contribution calendar using UTC dates. Today is incomplete. Update times use your local timezone."
    readonly property string repositoryExplanation: "Current snapshot of personally owned public and accessible private repositories, excluding forks and including archived repositories. Independent of the selected period."
    readonly property bool statusNeedsAttention: !service || service.refreshing || service.errorKind !== "" || !service.stats || service.todayCount === null

    function sectionFreshness(section) {
        return section && section.lastSuccess > 0 ? new Date(section.lastSuccess).toLocaleString() + (section.stale ? " · stale" : "") : "not loaded"
    }
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
        if (!popupOpen) { tabIndex = 0; periodIndex = 0 }
        popupOpen = !popupOpen
    }

    implicitWidth: trigger.implicitWidth
    implicitHeight: trigger.implicitHeight

    WidgetButton {
        id: trigger
        objectName: "github-trigger"
        bar: root.bar
        anchors.centerIn: parent
        text: "" + (root.vertical ? "\n" : " ") + root.countText
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: root.description
        onPressed: function(button) { if (button === Qt.LeftButton) root.toggle() }
        Keys.onReturnPressed: root.toggle()
        Keys.onEnterPressed: root.toggle()
        Keys.onSpacePressed: root.toggle()
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            visible: trigger.activeFocus
            color: "transparent"
            border.width: 1
            border.color: trigger.foreground
            radius: Style.cornerRadius
        }
    }

    PopupCard {
        id: popup
        anchorItem: root
        bar: root.bar
        owner: root
        open: root.popupOpen
        contentWidth: fittedContentWidth(Style.space(370))
        contentHeight: cappedContentHeight(Style.space(520))
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
                        id: periodControls
                        width: parent.width
                        spacing: Style.space(4)
                        Repeater {
                            id: periods
                            model: ["7 days", "30 days", "12 months"]
                            Button {
                                required property string modelData
                                required property int index
                                width: Math.max(Style.space(90), (periodControls.width - periodControls.spacing * 2) / 3)
                                text: modelData
                                fontSize: Style.font.caption
                                horizontalPadding: Style.space(4)
                                selected: root.periodIndex === index
                                focusable: true
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: modelData
                                Accessible.checked: selected
                                onClicked: root.periodIndex = index
                                Keys.onLeftPressed: periods.itemAt((index + 2) % 3).forceActiveFocus()
                                Keys.onRightPressed: periods.itemAt((index + 1) % 3).forceActiveFocus()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - calendarInfo.width
                            text: "Activity"
                            color: Commons.Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            font.bold: true
                        }
                        InfoText {
                            id: calendarInfo
                            objectName: "calendar-info"
                            width: Style.space(28)
                            text: ""
                            horizontalAlignment: Text.AlignHCenter
                            tooltipText: root.calendarExplanation
                            Accessible.name: "About contribution dates"
                            onActiveFocusChanged: if (activeFocus) root.revealPopupItem(calendarInfo)
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.selectedStats
                            ? root.selectedStats.from.slice(0, 10) + " – " + root.selectedStats.to.slice(0, 10)
                            : "Period activity is unavailable until a complete refresh succeeds."
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }

                    Heatmap {
                        id: chart
                        width: parent.width
                        periodStats: root.selectedStats
                        period: root.period
                        onTileFocused: function(tile) { root.revealPopupItem(tile) }
                    }

                    Grid {
                        id: metricsGrid
                        width: parent.width
                        columns: 2
                        columnSpacing: Style.space(12)
                        rowSpacing: Style.space(8)
                        Repeater {
                            model: root.selectedStats ? [
                                { label: "Contributions", accessibleLabel: "Contributions", value: root.selectedStats.contributions, meaning: "Activities GitHub counts in the selected period’s contribution calendar, including more than commits." },
                                { label: "Commits", accessibleLabel: "Commit contributions", value: root.selectedStats.commitContributions, meaning: "Commit contributions GitHub counts in the selected period, subject to eligibility and visibility rules." },
                                { label: "PRs", accessibleLabel: "PRs authored", value: root.selectedStats.prsAuthored, meaning: "PRs authored by you in the selected period, whether open or closed." },
                                { label: "Issues", accessibleLabel: "Issues authored", value: root.selectedStats.issuesAuthored, meaning: "Issues authored by you in the selected period, whether open or closed." }
                            ] : []
                            InfoText {
                                id: metric
                                required property var modelData
                                objectName: "metric-" + modelData.label
                                width: (metricsGrid.width - metricsGrid.columnSpacing) / 2
                                text: modelData.label + ": " + modelData.value
                                font.pixelSize: Style.font.body
                                tooltipText: modelData.meaning
                                Accessible.name: modelData.accessibleLabel + ": " + modelData.value
                                onActiveFocusChanged: if (activeFocus) root.revealPopupItem(metric)
                            }
                        }
                    }
                    Text {
                        objectName: "stats-stale"
                        visible: root.service !== null && root.service.stale
                        width: parent.width
                        text: root.service ? "Activity stale · updated " + new Date(root.service.lastSuccess).toLocaleString() : ""
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
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

                PanelSeparator { visible: root.tabIndex === 0 }

                Column {
                    visible: root.tabIndex === 0
                    width: parent.width
                    spacing: Style.space(8)
                    InfoText {
                        id: repositoryInfo
                        width: parent.width
                        text: "Repositories · current"
                        font.pixelSize: Style.font.body
                        font.bold: true
                        tooltipText: root.repositoryExplanation
                        onActiveFocusChanged: if (activeFocus) root.revealPopupItem(repositoryInfo)
                    }
                    InfoText {
                        id: stars
                        objectName: "repository-stars"
                        width: parent.width
                        text: "  " + (root.repositorySnapshot ? root.repositorySnapshot.stars : "—") + " stars"
                        font.pixelSize: Style.font.body
                        tooltipText: "Current stars received across the repository scope; not stars gained during the selected period. " + root.repositoryExplanation
                        Accessible.name: root.repositorySnapshot ? "Stars: " + root.repositorySnapshot.stars : "Stars unavailable"
                        onActiveFocusChanged: if (activeFocus) root.revealPopupItem(stars)
                    }
                    Repeater {
                        model: root.repositorySnapshot ? root.repositorySnapshot.languages : []
                        InfoText {
                            id: language
                            required property var modelData
                            objectName: "language-" + modelData.name
                            width: parent.width
                            text: modelData.name + ": " + modelData.percentage.toFixed(1) + "%"
                            tooltipText: modelData.bytes + " GitHub-reported language bytes across the repository scope. Shares describe repository contents, not coding time or period activity."
                            Accessible.name: text + " repository language share"
                            onActiveFocusChanged: if (activeFocus) root.revealPopupItem(language)
                        }
                    }
                    Text {
                        visible: !root.repositorySnapshot || root.repositorySnapshot.totalBytes === 0
                        width: parent.width
                        text: root.repositorySnapshot ? "No repository language bytes reported."
                            : root.repositoryState && root.repositoryState.errorKind ? "Repository snapshots unavailable. See refresh status below."
                            : root.service && root.service.refreshing ? "Loading repository snapshots…" : "Repository snapshots have not loaded yet."
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }
                    Text {
                        objectName: "repositories-stale"
                        visible: root.repositoryState !== null && root.repositoryState.stale
                        width: parent.width
                        text: root.repositoryState ? "Repositories stale · updated " + new Date(root.repositoryState.lastSuccess).toLocaleString() : ""
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }

                PanelSeparator {}

                Text {
                    objectName: "refresh-status"
                    visible: root.statusNeedsAttention
                    width: parent.width
                    text: root.service ? root.service.statusText : "Waiting for the shared GitHub service."
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Commons.Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }

                Row {
                    width: parent.width
                    spacing: Style.space(8)
                    InfoText {
                        id: freshness
                        objectName: "refresh-freshness"
                        width: parent.width - refreshButton.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.service && root.service.lastSuccess > 0
                            ? "Updated " + new Date(root.service.lastSuccess).toLocaleString() : "No successful update yet."
                        font.pixelSize: Style.font.caption
                        tooltipText: root.service ? [
                            "Activity: " + root.sectionFreshness({ lastSuccess: root.service.lastSuccess, stale: root.service.stale }),
                            "Repositories: " + root.sectionFreshness(root.service.repositories),
                            "PRs: " + root.sectionFreshness(root.service.prs),
                            "Issues: " + root.sectionFreshness(root.service.issues)
                        ].join("\n") : "Waiting for the shared GitHub service."
                        onActiveFocusChanged: if (activeFocus) root.revealPopupItem(freshness)
                    }
                    Button {
                        id: refreshButton
                        objectName: "refresh-button"
                        iconText: ""
                        iconSpinning: root.service !== null && root.service.refreshing
                        tooltipText: root.service && root.service.refreshing ? "Refreshing GitHub activity" : "Refresh GitHub activity"
                        focusable: true
                        enabled: root.service !== null && !root.service.refreshing && root.service.retryAt <= root.service.now
                        Accessible.role: Accessible.Button
                        Accessible.name: tooltipText
                        onClicked: root.service.refresh()
                        onActiveFocusChanged: if (activeFocus) root.revealPopupItem(refreshButton)
                    }
                }
            }
        }
    }
}
