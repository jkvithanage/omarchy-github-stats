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
    readonly property string countText: service && service.todayCount !== null ? String(service.todayCount) : "—"
    readonly property string description: "GitHub: " + (countText === "—" ? "today's contributions unavailable" : countText + " contributions today (UTC)")

    function close() { popupOpen = false }
    function toggle() {
        if (!popupOpen) tabIndex = 0
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

                Text {
                    width: parent.width
                    text: root.tabIndex === 0 ? "Today (UTC): " + root.countText + " contributions"
                        : (root.tabIndex === 1 ? "Pull request previews are not available yet." : "Issue previews are not available yet.")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Commons.Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                Text {
                    visible: root.tabIndex === 0
                    width: parent.width
                    text: "Period heatmaps, activity summaries, stars, and repository languages are not available yet."
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
