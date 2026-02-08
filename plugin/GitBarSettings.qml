import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "gitBar"

    StyledText {
        width: parent.width
        text: "GitBar Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Shows git branch and dirty state for the project in the currently focused terminal."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "gitBarPath"
        label: "GitBar Path"
        description: "Absolute path to the gitbar-linux repo"
        placeholder: "/home/gabriel/Projects/Personal/gitbar-linux"
        defaultValue: "/home/gabriel/Projects/Personal/gitbar-linux"
    }

    SelectionSetting {
        settingKey: "detectInterval"
        label: "Detection Interval"
        description: "How often to check the focused window and fetch git status"
        options: [
            {label: "2 seconds", value: "2"},
            {label: "3 seconds", value: "3"},
            {label: "5 seconds", value: "5"},
            {label: "10 seconds", value: "10"}
        ]
        defaultValue: "3"
    }

    SelectionSetting {
        settingKey: "maxBranchLength"
        label: "Max Branch Length"
        description: "Maximum characters to show for branch name in the pill"
        options: [
            {label: "10 chars", value: "10"},
            {label: "15 chars", value: "15"},
            {label: "20 chars", value: "20"},
            {label: "30 chars", value: "30"}
        ]
        defaultValue: "15"
    }
}
