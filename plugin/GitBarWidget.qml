import QtQuick
import QtQuick.Controls
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
    property string remoteUrl: ""
    property bool isRepo: false
    property bool loading: true
    property var repos: []
    property bool reposLoaded: false
    property var repoGroups: {
        var groups = []
        var groupMap = {}
        for (var i = 0; i < repos.length; i++) {
            var r = repos[i]
            var g = r.group || ""
            if (!(g in groupMap)) {
                groupMap[g] = { name: g, repos: [] }
                groups.push(groupMap[g])
            }
            groupMap[g].repos.push(r)
        }
        return groups
    }

    function truncBranch(name) {
        if (!name) return ""
        return name.length > root.maxBranchLength ? name.slice(0, root.maxBranchLength) + "\u2026" : name
    }

    function aheadBehindText() {
        if (!gitStatus) return ""
        var parts = []
        if (gitStatus.ahead > 0) parts.push("\u2191" + gitStatus.ahead)
        if (gitStatus.behind > 0) parts.push("\u2193" + gitStatus.behind)
        return parts.join(" ")
    }

    function changedFilesCount() {
        if (!gitStatus) return 0
        return (gitStatus.staged || 0) + (gitStatus.unstaged || 0) + (gitStatus.untracked || 0)
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
                            root.remoteUrl = ""
                            root.lastCommit = null
                        } else {
                            root.isRepo = true
                            root.gitStatus = data.status || null
                            root.projectName = data.project_name || ""
                            root.projectPath = data.project_path || ""
                            root.remoteUrl = data.remote_url || ""
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

    // ── Bar Pills ──

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "commit"
                color: root.isRepo
                    ? (root.gitStatus && root.gitStatus.dirty ? "#E5A100" : Theme.primary)
                    : Theme.surfaceContainerHighest
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
                color: "#E5A100"
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Medium
                visible: text !== ""
            }

            StyledRect {
                anchors.verticalCenter: parent.verticalCenter
                width: changesCountText.width + 8
                height: changesCountText.height + 2
                radius: height / 2
                color: Qt.rgba(0.9, 0.63, 0, 0.2)
                visible: root.isRepo && !root.loading && root.gitStatus && root.gitStatus.dirty

                StyledText {
                    id: changesCountText
                    anchors.centerIn: parent
                    text: root.changedFilesCount().toString()
                    color: "#E5A100"
                    font.pixelSize: Theme.fontSizeSmall - 2
                    font.weight: Font.Bold
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "commit"
                color: root.isRepo
                    ? (root.gitStatus && root.gitStatus.dirty ? "#E5A100" : Theme.primary)
                    : Theme.surfaceContainerHighest
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
        }
    }

    // ── Popout ──

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
                    contentHeight: popoutColumn.implicitHeight + Theme.spacingM
                    clip: true

                    Column {
                        id: popoutColumn
                        width: parent.width
                        spacing: Theme.spacingL

                        // ── Current Repo Session ──
                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            // Header: icon + name/path
                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: root.isRepo ? "folder" : "folder_off"
                                    color: root.isRepo ? Theme.primary : Theme.surfaceVariantText
                                    size: Theme.fontSizeLarge + 4
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - Theme.fontSizeLarge - 4 - Theme.spacingS

                                    StyledText {
                                        width: parent.width
                                        text: root.projectName || "No repository"
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: root.isRepo ? root.projectPath : "Focus a terminal in a git repo"
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }

                            // Branch + dirty badge + changes inline
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

                                StyledRect {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: dirtyText.width + Theme.spacingS * 2
                                    height: dirtyText.height + 4
                                    radius: height / 2
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

                                // Inline change counts
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXS
                                    visible: root.gitStatus && root.gitStatus.dirty

                                    Rectangle { width: 6; height: 6; radius: 3; anchors.verticalCenter: parent.verticalCenter; color: Theme.primary; visible: root.gitStatus && root.gitStatus.staged > 0 }
                                    StyledText { anchors.verticalCenter: parent.verticalCenter; text: root.gitStatus ? root.gitStatus.staged.toString() : ""; color: Theme.primary; font.pixelSize: Theme.fontSizeSmall - 2; visible: root.gitStatus && root.gitStatus.staged > 0 }

                                    Rectangle { width: 6; height: 6; radius: 3; anchors.verticalCenter: parent.verticalCenter; color: "#E5A100"; visible: root.gitStatus && root.gitStatus.unstaged > 0 }
                                    StyledText { anchors.verticalCenter: parent.verticalCenter; text: root.gitStatus ? root.gitStatus.unstaged.toString() : ""; color: "#E5A100"; font.pixelSize: Theme.fontSizeSmall - 2; visible: root.gitStatus && root.gitStatus.unstaged > 0 }

                                    Rectangle { width: 6; height: 6; radius: 3; anchors.verticalCenter: parent.verticalCenter; color: Theme.surfaceVariantText; visible: root.gitStatus && root.gitStatus.untracked > 0 }
                                    StyledText { anchors.verticalCenter: parent.verticalCenter; text: root.gitStatus ? root.gitStatus.untracked.toString() : ""; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 2; visible: root.gitStatus && root.gitStatus.untracked > 0 }
                                }
                            }

                            // Last commit inline
                            Row {
                                spacing: Theme.spacingS
                                visible: root.isRepo && root.lastCommit

                                DankIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "history"
                                    size: 14
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.lastCommit ? root.lastCommit.hash : ""
                                    color: Theme.primary
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.family: "monospace"
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.lastCommit ? root.lastCommit.message : ""
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    elide: Text.ElideRight
                                    width: 160
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.lastCommit ? root.lastCommit.time_ago : ""
                                    color: Theme.surfaceContainerHighest
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                }
                            }

                            // Action buttons
                            Row {
                                spacing: Theme.spacingXS
                                visible: root.isRepo

                                ActionButton {
                                    icon: "cloud_download"
                                    label: "Fetch"
                                    onClicked: Proc.runCommand("gitBar.fetch.action", ["git", "-C", root.projectPath, "fetch"], (stdout, exitCode) => { root.fetchGitStatus() }, 100)
                                }

                                ActionButton {
                                    icon: "cloud_upload"
                                    label: "Push"
                                    visible: root.gitStatus && root.gitStatus.ahead > 0
                                    onClicked: Proc.runCommand("gitBar.push.action", ["git", "-C", root.projectPath, "push"], (stdout, exitCode) => { root.fetchGitStatus() }, 100)
                                }

                                ActionButton {
                                    icon: "download"
                                    label: "Pull"
                                    visible: root.gitStatus && root.gitStatus.behind > 0
                                    onClicked: Proc.runCommand("gitBar.pull.action", ["git", "-C", root.projectPath, "pull"], (stdout, exitCode) => { root.fetchGitStatus() }, 100)
                                }

                                ActionButton {
                                    icon: "open_in_new"
                                    label: "Visit"
                                    visible: root.remoteUrl !== ""
                                    onClicked: Proc.runCommand("gitBar.visit", ["xdg-open", root.remoteUrl], () => {}, 100)
                                }
                            }
                        }

                        // ── All Projects (grouped) ──
                        Column {
                            width: parent.width
                            spacing: Theme.spacingM
                            visible: root.reposLoaded && root.repos.length > 0

                            Row {
                                spacing: Theme.spacingXS
                                DankIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "folder_open"
                                    size: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.isRepo ? "All projects" : "Projects"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.repos.length.toString()
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                }
                            }

                            Repeater {
                                model: root.repoGroups

                                Column {
                                    width: parent.width
                                    spacing: 2

                                    property var group: modelData

                                    // Group header
                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingXS
                                        height: 24
                                        visible: group.name !== ""

                                        Rectangle {
                                            width: 3
                                            height: 14
                                            radius: 1.5
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: Theme.surfaceContainerHighest
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: group.name
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Medium
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: group.repos.length.toString()
                                            color: Theme.surfaceContainerHighest
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                        }
                                    }

                                    // Repos in group
                                    Repeater {
                                        model: group.repos

                                        Item {
                                            width: parent.width
                                            height: 32

                                            HoverHandler { id: repoHover }
                                            property bool hovered: repoHover.hovered
                                            property bool isCurrent: modelData.path === root.projectPath

                                            StyledRect {
                                                anchors.fill: parent
                                                anchors.leftMargin: group.name !== "" ? Theme.spacingS : 0
                                                radius: Theme.cornerRadius
                                                color: hovered
                                                    ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                                                    : (isCurrent
                                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                                        : "transparent")

                                                Rectangle {
                                                    id: accentBar
                                                    width: 3
                                                    height: 18
                                                    radius: 1.5
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: modelData.dirty ? "#E5A100" : Theme.primary
                                                }

                                                // Info row (default)
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: accentBar.width + 4 + Theme.spacingXS
                                                    anchors.rightMargin: Theme.spacingXS
                                                    spacing: Theme.spacingS
                                                    visible: !hovered

                                                    StyledText {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width * 0.35
                                                        text: modelData.name
                                                        color: isCurrent ? Theme.primary : Theme.surfaceText
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.weight: Font.Medium
                                                        elide: Text.ElideRight
                                                        maximumLineCount: 1
                                                    }

                                                    StyledText {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width * 0.2
                                                        text: modelData.branch
                                                        color: Theme.surfaceVariantText
                                                        font.pixelSize: Theme.fontSizeSmall - 2
                                                        elide: Text.ElideRight
                                                        maximumLineCount: 1
                                                    }

                                                    StyledText {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: {
                                                            var parts = []
                                                            if (modelData.ahead > 0) parts.push("\u2191" + modelData.ahead)
                                                            if (modelData.behind > 0) parts.push("\u2193" + modelData.behind)
                                                            return parts.join(" ")
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

                                                // Hover row with actions
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: accentBar.width + 4 + Theme.spacingXS
                                                    anchors.rightMargin: Theme.spacingXS
                                                    spacing: Theme.spacingXS
                                                    visible: hovered

                                                    StyledText {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.name
                                                        color: Theme.surfaceText
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.weight: Font.Medium
                                                        elide: Text.ElideRight
                                                        width: parent.width - repoActions.width - Theme.spacingXS
                                                    }

                                                    Row {
                                                        id: repoActions
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 2

                                                        MiniAction {
                                                            icon: "cloud_download"
                                                            tooltip: "Fetch"
                                                            onClicked: Proc.runCommand("gitBar.repo.fetch." + modelData.name, ["git", "-C", modelData.path, "fetch"], (s, c) => { root.fetchRepos(); root.fetchGitStatus() }, 100)
                                                        }

                                                        MiniAction {
                                                            icon: "cloud_upload"
                                                            tooltip: "Push"
                                                            visible: modelData.ahead > 0
                                                            onClicked: Proc.runCommand("gitBar.repo.push." + modelData.name, ["git", "-C", modelData.path, "push"], (s, c) => { root.fetchRepos(); root.fetchGitStatus() }, 100)
                                                        }

                                                        MiniAction {
                                                            icon: "download"
                                                            tooltip: "Pull"
                                                            visible: modelData.behind > 0
                                                            onClicked: Proc.runCommand("gitBar.repo.pull." + modelData.name, ["git", "-C", modelData.path, "pull"], (s, c) => { root.fetchRepos(); root.fetchGitStatus() }, 100)
                                                        }

                                                        MiniAction {
                                                            icon: "open_in_new"
                                                            tooltip: "Visit"
                                                            visible: modelData.remote_url !== ""
                                                            onClicked: Proc.runCommand("gitBar.repo.visit." + modelData.name, ["xdg-open", modelData.remote_url], () => {}, 100)
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
            }
        }
    }

    // ── Inline Components ──

    component ActionButton: Rectangle {
        property string icon
        property string label
        signal clicked()

        width: btnRow.width + Theme.spacingM * 2
        height: 28
        radius: Theme.cornerRadius
        color: btnHover.hovered
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
            : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)

        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: clicked() }

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: icon
                size: 14
                color: btnHover.hovered ? Theme.primary : Theme.surfaceVariantText
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: label
                color: btnHover.hovered ? Theme.primary : Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Medium
            }
        }
    }

    component MiniAction: Rectangle {
        property string icon
        property string tooltip
        signal clicked()

        width: 22; height: 22; radius: 4
        color: miniHover.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
        ToolTip.visible: miniHover.hovered
        ToolTip.text: tooltip
        ToolTip.delay: 400

        HoverHandler { id: miniHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: clicked() }

        DankIcon {
            anchors.centerIn: parent
            name: icon
            size: 13
            color: miniHover.hovered ? Theme.primary : Theme.surfaceVariantText
        }
    }

    popoutWidth: 350
    popoutHeight: 500
}
