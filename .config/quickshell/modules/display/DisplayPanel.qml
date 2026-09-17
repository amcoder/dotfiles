import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The panel behind the bar's monitor icon: every output with its power, its
// resolution and refresh, its scale, and -- on an ultrawide -- the swap
// between its native shape and the conventional 16:9 mode inside it, which is
// what sway-toggle-aspect does from the keyboard.
//
// Anything the panel changes holds until the next `swaymsg reload`, when sway
// reasserts what sway-outputs generated; "reset" is the same value a reload
// would restore, applied now.
BarPopup {
    id: root

    readonly property int rowHeight: 30
    readonly property int listRows: 6

    cardWidth: 420

    // A subscription covers every change, but the read is cheap and a panel
    // that opens on a stale list is worse than one extra read.
    onExpandedChanged: {
        if (root.expanded)
            DisplayService.refresh();
    }

    function formatHz(refresh: int): string {
        return (refresh / 1000).toFixed(2).replace(/\.?0+$/, "");
    }

    function formatScale(scale: real): string {
        return `${Number(scale.toFixed(2))}×`;
    }

    component Heading: Item {
        id: heading

        required property string title
        property string detail: ""

        width: parent.width
        implicitHeight: headingTitle.implicitHeight

        Text {
            id: headingTitle

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: heading.title
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: heading.detail
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }
    }

    component Link: Text {
        id: link

        signal activated

        color: linkMouse.containsMouse ? Theme.popupText : Theme.popupSubtext
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize

        MouseArea {
            id: linkMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: link.activated()
        }
    }

    // One choice in a row of them: the aspect, a refresh rate, a scale.
    component Chip: Rectangle {
        id: chip

        required property string text
        property bool selected: false

        signal activated

        implicitWidth: chipLabel.implicitWidth + 20
        implicitHeight: 28
        radius: 4
        color: {
            if (chip.selected)
                return Theme.popupSelection;
            if (chipMouse.containsMouse)
                return Theme.popupHover;
            return "transparent";
        }
        border.color: Theme.popupSelection
        border.width: chip.selected ? 0 : 1

        Text {
            id: chipLabel

            anchors.centerIn: parent
            text: chip.text
            color: chip.selected ? Theme.popupText : Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        MouseArea {
            id: chipMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: chip.activated()
        }
    }

    component PowerSwitch: MouseArea {
        id: toggle

        required property bool on

        implicitWidth: 40
        implicitHeight: 22
        cursorShape: toggle.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        opacity: toggle.enabled ? 1 : 0.5

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: toggle.on ? Theme.blue : Theme.surface1
        }

        Rectangle {
            x: toggle.on ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: width / 2
            color: toggle.on ? Theme.base : Theme.popupSubtext

            Behavior on x {
                NumberAnimation {
                    duration: 100
                }
            }
        }
    }

    // One selectable resolution, with its best refresh rate on the right.
    component ResolutionRow: ListRow {
        id: row

        required property var output
        required property var resolution

        readonly property bool isNative: DisplayService.sameResolution(row.resolution, row.output.nativeMode)

        height: root.rowHeight
        selected: DisplayService.sameResolution(row.resolution, row.output.current)

        onActivated: DisplayService.setResolution(row.output, row.resolution)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: `${row.resolution.width} × ${row.resolution.height}`
            color: row.selected ? Theme.popupText : Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: (row.isNative ? "native · " : "") + `${root.formatHz(row.resolution.refreshes[0])} Hz`
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }
    }

    Text {
        width: parent.width
        text: "Displays"
        color: Theme.popupText
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
    }

    Text {
        width: parent.width
        visible: DisplayService.outputs.length === 0
        text: "No outputs"
        color: Theme.popupSubtext
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize
    }

    Repeater {
        model: DisplayService.outputs

        Column {
            id: section

            required property var modelData
            required property int index

            readonly property var output: section.modelData
            readonly property var currentResolution: section.output.resolutions.find(r => DisplayService.sameResolution(r, section.output.current)) ?? null
            readonly property int currentIndex: section.output.resolutions.findIndex(r => DisplayService.sameResolution(r, section.output.current))
            readonly property var scales: {
                const offered = DisplayService.scales.slice();
                if (!offered.some(scale => Math.abs(scale - section.output.scale) < 0.001))
                    offered.push(section.output.scale);
                return offered.sort((a, b) => a - b);
            }

            width: parent.width
            spacing: 8

            Rectangle {
                width: parent.width
                height: 1
                visible: section.index > 0
                color: Theme.popupSelection
            }

            Item {
                width: parent.width
                implicitHeight: 40

                Icon {
                    id: kind

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    size: Appearance.iconSize
                    name: section.output.internal ? "laptop" : "monitor"
                    color: section.output.active ? Theme.popupText : Theme.popupSubtext
                }

                Column {
                    anchors.left: kind.right
                    anchors.right: reset.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        text: section.output.name
                        color: section.output.active ? Theme.popupText : Theme.popupSubtext
                        elide: Text.ElideRight
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.fontSize
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: section.output.description
                        color: Theme.popupSubtext
                        elide: Text.ElideRight
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.smallFontSize
                    }
                }

                Link {
                    id: reset

                    anchors.right: power.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: section.output.active && !(section.output.atNativeMode && section.output.atDefaultScale)
                    width: visible ? implicitWidth : 0
                    text: "reset"

                    onActivated: DisplayService.reset(section.output)
                }

                PowerSwitch {
                    id: power

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: section.output.active
                    enabled: !section.output.active || DisplayService.canDisable(section.output)

                    onClicked: DisplayService.setEnabled(section.output, !section.output.active)
                }
            }

            Column {
                width: parent.width
                spacing: 4
                visible: section.output.active && section.output.ultrawide

                Heading {
                    title: "Shape"
                }

                Row {
                    spacing: 6

                    Chip {
                        text: `Ultrawide · ${section.output.nativeMode?.width ?? 0} × ${section.output.nativeMode?.height ?? 0}`
                        selected: section.output.atNative

                        onActivated: {
                            if (!section.output.atNative)
                                DisplayService.toggleAspect(section.output);
                        }
                    }

                    Chip {
                        text: `16:9 · ${section.output.conventional?.width ?? 0} × ${section.output.conventional?.height ?? 0}`
                        selected: DisplayService.sameResolution(section.output.current, section.output.conventional)

                        onActivated: {
                            if (section.output.atNative)
                                DisplayService.toggleAspect(section.output);
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4
                visible: section.output.active && section.output.resolutions.length > 0

                Heading {
                    title: "Resolution"
                }

                // Fixed height and scrolling, so a panel with twenty modes on
                // offer is no taller than one with six. Positioned to the
                // current one whenever the list is (re)built or the panel
                // opens, so the selection is in view without scrolling.
                ListView {
                    id: resolutions

                    width: parent.width
                    height: Math.min(count, root.listRows) * root.rowHeight
                    clip: true
                    model: section.output.resolutions
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: ResolutionRow {
                        required property var modelData

                        width: ListView.view.width
                        output: section.output
                        resolution: modelData
                    }

                    function showCurrent(): void {
                        if (section.currentIndex >= 0)
                            resolutions.positionViewAtIndex(section.currentIndex, ListView.Contain);
                    }

                    onCountChanged: resolutions.showCurrent()

                    Connections {
                        target: root

                        function onExpandedChanged() {
                            if (root.expanded)
                                resolutions.showCurrent();
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4
                visible: section.output.active && (section.currentResolution?.refreshes.length ?? 0) > 1

                Heading {
                    title: "Refresh"
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: section.currentResolution?.refreshes ?? []

                        Chip {
                            required property int modelData

                            text: `${root.formatHz(modelData)} Hz`
                            selected: section.output.current?.refresh === modelData

                            onActivated: DisplayService.setMode(section.output, section.currentResolution.width, section.currentResolution.height, modelData)
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4
                visible: section.output.active

                Heading {
                    title: "Scale"
                    detail: `${section.output.logicalWidth} × ${section.output.logicalHeight} logical`
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: section.scales

                        Chip {
                            required property real modelData

                            text: root.formatScale(modelData) + (section.output.defaultScale !== null && Math.abs(modelData - section.output.defaultScale) < 0.001 ? " · default" : "")
                            selected: Math.abs(section.output.scale - modelData) < 0.001

                            onActivated: DisplayService.setScale(section.output, modelData)
                        }
                    }
                }
            }
        }
    }
}
