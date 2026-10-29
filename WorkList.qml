pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Column {
    id: root
    required property var section
    required property bool refreshing
    required property string sectionName
    signal openUrl(string url)
    signal linkFocused(Item link)
    spacing: Style.space(10)

    Text {
        width: root.width
        visible: !root.section || !root.section.data || root.section.stale || root.refreshing
        text: !root.section ? "Waiting for " + root.sectionName + "."
            : root.section.errorKind ? root.sectionName + " refresh failed." + (root.section.data ? " Showing stale data." : " See refresh status below.")
            : root.refreshing ? "Refreshing " + root.sectionName + "…" : root.sectionName + " have not loaded yet."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }

    Repeater {
        model: root.section && root.section.data ? root.section.data.groups : []
        Column {
            id: group
            required property var modelData
            required property int index
            readonly property string heading: index === 0 ? "Authored" : root.sectionName === "PRs" ? "Review requests" : "Assigned"
            width: root.width
            spacing: Style.space(8)
            Item { visible: group.index > 0; width: root.width; height: Style.space(8) }
            PanelSeparator { visible: group.index > 0; strength: 0.28 }
            InfoText {
                id: heading
                objectName: "work-heading"
                width: root.width
                text: group.heading + " · " + (group.modelData.rows.length < group.modelData.total
                    ? group.modelData.rows.length + " of " + group.modelData.total + " shown" : group.modelData.total)
                tooltipText: group.modelData.label + ". " + group.modelData.rows.length + " preview items of " + group.modelData.total + " total."
                font.bold: true
                onActiveFocusChanged: if (activeFocus) root.linkFocused(heading)
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }
            Text {
                width: root.width
                visible: group.modelData.total === 0
                text: "No matching open work."
                color: Commons.Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }
            Repeater {
                model: group.modelData.rows
                Column {
                    id: row
                    required property var modelData
                    required property int index
                    width: root.width
                    spacing: Style.space(4)
                    PanelSeparator { objectName: row.index > 0 ? "work-row-separator" : ""; visible: row.index > 0 }
                    InfoText {
                        id: itemLink
                        objectName: "work-link-" + row.modelData.number
                        width: root.width
                        text: row.modelData.title + " "
                        tooltipText: "Open " + row.modelData.repository + " #" + row.modelData.number + " in browser"
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        link: true
                        Accessible.name: "Open " + row.modelData.title + " · " + row.modelData.repository + " #" + row.modelData.number + " · " + row.modelData.role
                            + (row.modelData.isDraft ? " · Draft" : "") + (row.modelData.isPrivate ? " · Private" : "")
                        onActivated: root.openUrl(row.modelData.url)
                        onActiveFocusChanged: if (activeFocus) root.linkFocused(itemLink)
                    }
                    Text {
                        width: root.width
                        text: row.modelData.repository + " #" + row.modelData.number
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }
                    Flow {
                        width: root.width
                        spacing: Style.space(8)
                        Repeater {
                            model: [
                                { label: row.modelData.role.indexOf(" · ") >= 0 ? row.modelData.role.split(" · ").slice(1).join(" · ") : "", icon: "" },
                                { label: row.modelData.isDraft ? "Draft" : "", icon: "" },
                                { label: row.modelData.isPrivate ? "Private" : "", icon: "" }
                            ]
                            Text {
                                required property var modelData
                                visible: modelData.label !== ""
                                width: Math.min(implicitWidth, root.width)
                                text: modelData.icon + " " + modelData.label
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                color: Commons.Color.foreground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                Accessible.name: modelData.label
                            }
                        }
                    }
                    RelativeTime {
                        id: updatedTime
                        objectName: "work-updated-" + row.modelData.number
                        width: root.width
                        timestamp: Date.parse(row.modelData.updatedAt)
                        font.pixelSize: Style.font.bodySmall
                        onActiveFocusChanged: if (activeFocus) root.linkFocused(updatedTime)
                    }
                }
            }
            Button {
                id: allLink
                text: "View all"
                iconText: ""
                tooltipText: "View all " + group.modelData.label + " in browser"
                focusable: true
                Accessible.role: Accessible.Link
                Accessible.name: "View all " + group.modelData.label
                onClicked: root.openUrl(group.modelData.url)
                onActiveFocusChanged: if (activeFocus) root.linkFocused(allLink)
            }
        }
    }

    Text {
        width: root.width
        objectName: "work-stale"
        visible: root.section !== null && root.section.stale
        text: root.section ? root.sectionName + " updated: " + new Date(root.section.lastSuccess).toLocaleString()
            + (root.section.stale ? " · stale" : "") : ""
        wrapMode: Text.Wrap
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
    }
}
