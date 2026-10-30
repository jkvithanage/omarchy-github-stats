pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "ServiceModel.js" as Model

BarWidget {
    id: root
    moduleName: "omarchy-github-stats"

    readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    property bool popupOpen: false
    property int tabIndex: 0
    property int periodIndex: 0
    readonly property string period: ["week", "month", "year"][periodIndex]
    readonly property var selectedStats: service && service.stats ? service.stats.periods[period] : null
    readonly property bool activityRestricted: selectedStats !== null && selectedStats.restrictedContributions > 0
    readonly property var repositoryState: service ? service.repositories : null
    readonly property var repositorySnapshot: repositoryState ? repositoryState.data : null
    readonly property string countText: service && service.todayCount !== null ? String(service.todayCount) : "—"
    readonly property string description: "GitHub: " + (countText === "—" ? "today's contributions unavailable" : countText + " contributions today")

    readonly property string repositoryExplanation: "Current snapshot of personally owned public and accessible private repositories, excluding forks and including archived repositories. Independent of the selected period."
    readonly property bool statusNeedsAttention: !service || service.refreshing || service.errorKind !== "" || !service.stats || service.todayCount === null
    readonly property string activeSectionName: ["Activity", "PRs", "Issues"][tabIndex]
    readonly property var activeSection: !service ? null : tabIndex === 0
        ? { lastSuccess: service.lastSuccess, stale: service.stale } : tabIndex === 1 ? service.prs : service.issues

    function sectionFreshness(section) {
        return section && section.lastSuccess > 0 ? new Date(section.lastSuccess).toLocaleString() + (section.stale ? " · stale" : "") : "not loaded"
    }
    function close() { popupOpen = false }
    function compactCount(count) {
        return count >= 1000000 ? Math.floor(count / 1000000) + "m"
            : count >= 1000 ? Math.floor(count / 1000) + "k" : String(count)
    }
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
        if (!popupOpen) { tabIndex = 0; periodIndex = 0; chart.resetKeyboardEntry() }
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
                spacing: Style.space(6)

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
                            objectName: "tab-" + modelData
                            readonly property var workSection: !root.service || index === 0 ? null : index === 1 ? root.service.prs : root.service.issues
                            readonly property double workTotal: workSection && workSection.data
                                ? workSection.data.groups[0].total + workSection.data.groups[1].total : -1
                            readonly property string countLabel: (workTotal < 0 ? "—" : root.compactCount(workTotal))
                                + (workSection && workSection.stale ? "*" : "")
                            readonly property bool narrow: width < Style.space(100)
                            readonly property string workSummary: workTotal < 0 ? modelData + " totals unavailable"
                                : workTotal + " open " + modelData + (workSection.stale ? " · saved data" : "")
                            width: parent.width / 3
                            text: modelData + (index === 0 ? (narrow ? "\n " : "") : (narrow ? "\n" : " ") + countLabel)
                            fontFamily: Style.font.family
                            fontSize: Style.font.bodySmall
                            horizontalPadding: Style.space(4)
                            tooltipText: index === 0 ? "" : workSummary
                                + (workSection && workSection.lastSuccess > 0 ? " · Updated " + new Date(workSection.lastSuccess).toLocaleString() : "")
                            selected: root.tabIndex === index
                            focusable: true
                            Accessible.role: Accessible.PageTab
                            Accessible.name: index === 0 ? modelData : workSummary
                            Accessible.description: tooltipText
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
                    spacing: Style.space(6)

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
                                verticalPadding: Style.space(2)
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

                    InfoText {
                        id: contributionTotal
                        objectName: "contribution-total"
                        width: parent.width
                        text: root.selectedStats ? root.selectedStats.contributions + " contributions"
                            : root.service && root.service.refreshing ? "Loading contributions…" : "Contributions unavailable"
                        font.pixelSize: Style.font.display
                        font.bold: true
                        tooltipText: "Activities GitHub counts in the selected period’s contribution calendar, including more than commits."
                        Accessible.name: text + " · " + ["7 days", "30 days", "12 months"][root.periodIndex]
                        onActiveFocusChanged: if (activeFocus) root.revealPopupItem(contributionTotal)
                    }

                    Row {
                        id: activityHeader
                        width: parent.width
                        spacing: Style.space(4)
                        Text {
                            width: parent.width - (activityStale.visible ? activityStale.width + parent.spacing : 0)
                            text: ["Last 7 days", "Last 30 days", "Last 12 months"][root.periodIndex]
                                + (root.selectedStats ? " · " + root.selectedStats.from.slice(0, 10) + " – " + root.selectedStats.to.slice(0, 10) : " · Activity unavailable")
                            color: Commons.Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            font.bold: true
                            wrapMode: Text.Wrap
                        }
                        InfoText {
                            id: activityStale
                            objectName: "stats-stale"
                            visible: root.service !== null && root.service.stale
                            text: "stale"
                            tooltipText: "Activity updated: " + (root.service ? root.sectionFreshness({ lastSuccess: root.service.lastSuccess, stale: root.service.stale }) : "not loaded")
                            onActiveFocusChanged: if (activeFocus) root.revealPopupItem(activityStale)
                        }
                    }

                    Heatmap {
                        id: chart
                        width: parent.width
                        periodStats: root.selectedStats
                        period: root.period
                        today: Model.localDate(root.service ? root.service.now : Date.now())
                        onTileFocused: function(tile) { root.revealPopupItem(tile) }
                    }

                    Button {
                        id: latestButton
                        objectName: "calendar-latest"
                        visible: root.period === "year"
                        text: "Latest"
                        tooltipText: "Show the newest contribution dates"
                        focusable: true
                        Accessible.name: tooltipText
                        Accessible.role: Accessible.Button
                        Accessible.onPressAction: chart.showLatest()
                        onClicked: chart.showLatest()
                        onActiveFocusChanged: if (activeFocus) root.revealPopupItem(latestButton)
                    }

                    Grid {
                        id: metricsGrid
                        width: parent.width
                        columns: 3
                        columnSpacing: Style.space(12)
                        rowSpacing: Style.space(4)
                        Repeater {
                            model: root.selectedStats ? [
                                { label: "Commits", accessibleLabel: "Commit contributions", value: root.selectedStats.commitContributions, meaning: "Commit contributions GitHub counts in the selected period, subject to eligibility and visibility rules." },
                                { label: "PRs", accessibleLabel: "PRs authored", value: root.selectedStats.prsAuthored, meaning: "PRs authored by you in the selected period, whether open or closed." },
                                { label: "Issues", accessibleLabel: "Issues authored", value: root.selectedStats.issuesAuthored, meaning: "Issues authored by you in the selected period, whether open or closed." }
                            ] : []
                            InfoText {
                                id: metric
                                required property var modelData
                                objectName: "metric-" + modelData.label
                                width: (metricsGrid.width - metricsGrid.columnSpacing * 2) / 3
                                text: modelData.label + ": " + modelData.value + (root.activityRestricted ? "+" : "")
                                font.pixelSize: Style.font.body
                                tooltipText: modelData.meaning + (root.activityRestricted ? " Visible activity only; restricted contributions are excluded. This is a lower bound." : "")
                                Accessible.name: modelData.accessibleLabel + ": " + (root.activityRestricted ? "at least " : "") + modelData.value
                                onActiveFocusChanged: if (activeFocus) root.revealPopupItem(metric)
                            }
                        }
                    }

                    InfoText {
                        id: restrictedActivity
                        objectName: "restricted-activity"
                        width: parent.width
                        visible: root.activityRestricted
                        text: root.activityRestricted ? root.selectedStats.restrictedContributions
                            + " private contributions have no breakdown. Counts marked + show visible activity only." : ""
                        tooltipText: "To include accessible private/internal contribution details, authorize read:user with: gh auth refresh --hostname github.com --scopes read:user, then refresh the widget. GitHub may still restrict activity your account cannot access."
                        onActiveFocusChanged: if (activeFocus) root.revealPopupItem(restrictedActivity)
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
                    spacing: Style.space(4)
                    Row {
                        id: repositoryHeader
                        width: parent.width
                        spacing: Style.space(6)
                        InfoText {
                            id: repositoryInfo
                            width: parent.width - stars.width - parent.spacing
                                - (repositoryStale.visible ? repositoryStale.width + parent.spacing : 0)
                            text: "Repositories · current"
                            tooltipText: root.repositoryExplanation
                            onActiveFocusChanged: if (activeFocus) root.revealPopupItem(repositoryInfo)
                        }
                        InfoText {
                            id: repositoryStale
                            objectName: "repositories-stale"
                            visible: root.repositoryState !== null && root.repositoryState.stale
                            text: "stale"
                            tooltipText: "Repositories updated: " + root.sectionFreshness(root.repositoryState)
                            onActiveFocusChanged: if (activeFocus) root.revealPopupItem(repositoryStale)
                        }
                        InfoText {
                            id: stars
                            objectName: "repository-stars"
                            text: " " + (root.repositorySnapshot ? root.repositorySnapshot.stars : "—") + " stars"
                            tooltipText: "Current stars received across the repository scope; not stars gained during the selected period. " + root.repositoryExplanation
                            Accessible.name: root.repositorySnapshot ? "Stars: " + root.repositorySnapshot.stars : "Stars unavailable"
                            onActiveFocusChanged: if (activeFocus) root.revealPopupItem(stars)
                        }
                    }
                    Grid {
                        id: languageGrid
                        width: parent.width
                        columns: 2
                        columnSpacing: Style.space(12)
                        rowSpacing: Style.space(4)
                        Repeater {
                            model: root.repositorySnapshot ? root.repositorySnapshot.languages : []
                            InfoText {
                                id: language
                                required property var modelData
                                objectName: "language-" + modelData.name
                                width: (languageGrid.width - languageGrid.columnSpacing) / 2
                                text: modelData.name + ": " + modelData.percentage.toFixed(1) + "%"
                                tooltipText: modelData.bytes + " GitHub-reported language bytes across the repository scope. Shares describe repository contents, not coding time or period activity."
                                Accessible.name: text + " repository language share"
                                onActiveFocusChanged: if (activeFocus) root.revealPopupItem(language)
                            }
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

                }

                PanelSeparator {}

                RecoveryStatus {
                    visible: root.statusNeedsAttention
                    width: parent.width
                    service: root.service
                    onActionFocused: function(action) { root.revealPopupItem(action) }
                }

                Row {
                    width: parent.width
                    spacing: Style.space(8)
                    RelativeTime {
                        id: freshness
                        objectName: "refresh-freshness"
                        width: parent.width - refreshButton.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        timestamp: root.activeSection ? root.activeSection.lastSuccess : 0
                        subject: root.activeSectionName + (root.activeSection && root.activeSection.stale ? " · stale" : "")
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
