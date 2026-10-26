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
        width: parent.width
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
            width: parent.width
            spacing: Style.space(8)
            Text {
                width: parent.width
                text: group.modelData.label + " · " + group.modelData.total + " total · showing " + group.modelData.rows.length
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }
            Text {
                width: parent.width
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
                    width: parent.width
                    spacing: Style.space(4)
                    Text {
                        width: parent.width
                        text: row.modelData.title
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.repository + " #" + row.modelData.number + "\n" + row.modelData.role
                            + (row.modelData.isDraft ? " · Draft" : "") + (row.modelData.isPrivate ? " · Private" : "")
                            + "\nUpdated: " + new Date(row.modelData.updatedAt).toLocaleString()
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }
                    Button {
                        id: itemLink
                        text: "Open #" + row.modelData.number
                        focusable: true
                        Accessible.role: Accessible.Link
                        Accessible.name: "Open " + row.modelData.title + " · " + row.modelData.repository + " #" + row.modelData.number + " · " + row.modelData.role
                        onClicked: root.openUrl(row.modelData.url)
                        onActiveFocusChanged: if (activeFocus) root.linkFocused(itemLink)
                    }
                }
            }
            Button {
                id: allLink
                text: "View all"
                focusable: true
                Accessible.role: Accessible.Link
                Accessible.name: "View all " + group.modelData.label
                onClicked: root.openUrl(group.modelData.url)
                onActiveFocusChanged: if (activeFocus) root.linkFocused(allLink)
            }
        }
    }

    Text {
        width: parent.width
        visible: root.section && root.section.lastSuccess > 0
        text: root.section ? root.sectionName + " updated: " + new Date(root.section.lastSuccess).toLocaleString()
            + (root.section.stale ? " · stale" : "") : ""
        wrapMode: Text.Wrap
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
    }
}
