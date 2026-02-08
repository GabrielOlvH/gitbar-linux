import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "gitbar"

    property string gitBarPath: pluginData.gitBarPath || "/home/gabriel/Projects/Personal/gitbar-linux"
    property int detectInterval: parseInt(pluginData.detectInterval) || 3
    property int maxBranchLength: parseInt(pluginData.maxBranchLength) || 15

    property var gitStatus: null
    property string projectName: ""
    property string projectPath: ""
    property var lastCommit: null
    property bool isRepo: false
    property bool loading: true
    property var repos: []
    property bool reposLoaded: false

    function truncBranch(name) {
        if (!name) return ""
        return name.length > root.maxBranchLength ? name.slice(0, root.maxBranchLength) + "\u2026" : name
    }

    function aheadBehindText() {
        if (!gitStatus) return ""
        var parts = []
        if (gitStatus.ahead > 0) parts.push("+" + gitStatus.ahead)
        if (gitStatus.behind > 0) parts.push("-" + gitStatus.behind)
        return parts.join("/")
    }

    Timer {
        interval: root.detectInterval * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchGitStatus()
    }

    function fetchGitStatus() {
        Proc.runCommand(
            "gitBar.detect",
            ["bun", "run", root.gitBarPath + "/src/index.ts"],
            (stdout, exitCode) => {
                if (exitCode === 0 && stdout.trim()) {
                    try {
                        var data = JSON.parse(stdout)
                        if (data.error) {
                            root.isRepo = false
                            root.gitStatus = null
                            root.projectName = ""
                            root.projectPath = ""
                            root.lastCommit = null
                        } else {
                            root.isRepo = true
                            root.gitStatus = data.status || null
                            root.projectName = data.project_name || ""
                            root.projectPath = data.project_path || ""
                            root.lastCommit = data.last_commit || null
                        }
                        root.loading = false
                    } catch (e) {
                        console.error("GitBar: Failed to parse JSON:", e)
                    }
                }
            },
            100
        )
    }

    // Scan all repos on startup and periodically
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchRepos()
    }

    function fetchRepos() {
        Proc.runCommand(
            "gitBar.scan",
            ["bun", "run", root.gitBarPath + "/src/index.ts", "--scan"],
            (stdout, exitCode) => {
                if (exitCode === 0 && stdout.trim()) {
                    try {
                        var data = JSON.parse(stdout)
                        root.repos = data.repos || []
                        root.reposLoaded = true
                    } catch (e) {
                        console.error("GitBar: Failed to parse scan JSON:", e)
                    }
                }
            },
            500
        )
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "commit"
                color: root.isRepo ? Theme.surfaceVariantText : Theme.surfaceContainerHighest
                size: Theme.fontSizeLarge
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.loading ? "..." : root.truncBranch(root.gitStatus ? root.gitStatus.branch : "")
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                visible: root.isRepo
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.aheadBehindText()
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                visible: text !== ""
            }

            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: root.gitStatus ? (root.gitStatus.dirty ? "#E5A100" : Theme.primary) : Theme.surfaceVariantText
                visible: root.isRepo && !root.loading
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "commit"
                color: root.isRepo ? Theme.surfaceVariantText : Theme.surfaceContainerHighest
                size: Theme.fontSizeMedium
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.loading ? ".." : root.truncBranch(root.gitStatus ? root.gitStatus.branch : "")
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                visible: root.isRepo
            }

            Rectangle {
                width: 6
                height: 6
                radius: 3
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.gitStatus ? (root.gitStatus.dirty ? "#E5A100" : Theme.primary) : Theme.surfaceVariantText
                visible: root.isRepo && !root.loading
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: ""
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popout.headerHeight - Theme.spacingL

                Flickable {
                    anchors.fill: parent
                    contentHeight: popoutColumn.implicitHeight
                    clip: true

                Column {
                    id: popoutColumn
                    width: parent.width
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingM

                    // Project header
                    Column {
                        width: parent.width
                        spacing: 2

                        StyledText {
                            text: root.projectName || "No repo"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                        }

                        StyledText {
                            width: parent.width
                            text: root.projectPath || ""
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall - 2
                            elide: Text.ElideMiddle
                            visible: text !== ""
                        }
                    }

                    // Branch + ahead/behind
                    Row {
                        spacing: Theme.spacingS
                        visible: root.isRepo

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "commit"
                            color: Theme.primary
                            size: Theme.fontSizeMedium
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.gitStatus ? root.gitStatus.branch : ""
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.aheadBehindText()
                            color: "#E5A100"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            visible: text !== ""
                        }

                        // Dirty/clean badge
                        StyledRect {
                            anchors.verticalCenter: parent.verticalCenter
                            width: dirtyText.width + Theme.spacingS * 2
                            height: dirtyText.height + 4
                            radius: Theme.cornerRadius
                            color: root.gitStatus && root.gitStatus.dirty
                                ? Qt.rgba(0.9, 0.63, 0, 0.15)
                                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)

                            StyledText {
                                id: dirtyText
                                anchors.centerIn: parent
                                text: root.gitStatus ? (root.gitStatus.dirty ? "dirty" : "clean") : ""
                                color: root.gitStatus && root.gitStatus.dirty ? "#E5A100" : Theme.primary
                                font.pixelSize: Theme.fontSizeSmall - 2
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // Status breakdown
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: root.isRepo && root.gitStatus && root.gitStatus.dirty

                        StatusRow {
                            label: "Staged"
                            count: root.gitStatus ? root.gitStatus.staged : 0
                            dotColor: Theme.primary
                            visible: count > 0
                        }

                        StatusRow {
                            label: "Unstaged"
                            count: root.gitStatus ? root.gitStatus.unstaged : 0
                            dotColor: "#E5A100"
                            visible: count > 0
                        }

                        StatusRow {
                            label: "Untracked"
                            count: root.gitStatus ? root.gitStatus.untracked : 0
                            dotColor: Theme.surfaceVariantText
                            visible: count > 0
                        }
                    }

                    // Separator
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.surfaceContainerHighest
                        visible: root.isRepo && root.lastCommit
                    }

                    // Last commit
                    Column {
                        width: parent.width
                        spacing: 2
                        visible: root.isRepo && root.lastCommit

                        StyledText {
                            text: "Last commit"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall - 2
                        }

                        Row {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: root.lastCommit ? root.lastCommit.hash : ""
                                color: Theme.primary
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: "monospace"
                            }

                            StyledText {
                                text: root.lastCommit ? root.lastCommit.time_ago : ""
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        StyledText {
                            width: parent.width
                            text: root.lastCommit ? root.lastCommit.message : ""
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }
                    }

                    // Projects overview (when not in a repo, or always at bottom)
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: root.reposLoaded && root.repos.length > 0

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.surfaceContainerHighest
                            visible: root.isRepo
                        }

                        StyledText {
                            text: root.isRepo ? "All projects" : "Projects"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall - 2
                        }

                        Repeater {
                            model: root.repos

                            Item {
                                width: parent.width
                                height: 30

                                StyledRect {
                                    anchors.fill: parent
                                    radius: Theme.cornerRadius
                                    color: modelData.path === root.projectPath
                                        ? Theme.surfaceContainerHigh
                                        : "transparent"

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingXS
                                        anchors.rightMargin: Theme.spacingXS
                                        spacing: Theme.spacingS

                                        Rectangle {
                                            width: 6
                                            height: 6
                                            radius: 3
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: modelData.dirty ? "#E5A100" : Theme.primary
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width * 0.35
                                            text: modelData.name
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width * 0.25
                                            text: modelData.branch
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: {
                                                var parts = []
                                                if (modelData.ahead > 0) parts.push("+" + modelData.ahead)
                                                if (modelData.behind > 0) parts.push("-" + modelData.behind)
                                                return parts.length > 0 ? parts.join("/") : ""
                                            }
                                            color: "#E5A100"
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            visible: text !== ""
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.last_commit_ago || ""
                                            color: Theme.surfaceContainerHighest
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            visible: text !== ""
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                }
            }
        }
    }

    // Inline component for status rows
    component StatusRow: Row {
        property string label
        property int count
        property color dotColor

        spacing: Theme.spacingS

        Rectangle {
            width: 8
            height: 8
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: dotColor
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: label
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: count.toString()
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
        }
    }

    popoutWidth: 340
    popoutHeight: 500
}
