import QtQuick
import qs.config

// A search field over a scored, filtered list: the workhorse behind the
// launcher, the window switcher and the power menu. The caller supplies the
// items, how to read searchable text off one, and a full ListView delegate --
// which reads `ListView.isCurrentItem` for selection and sets
// `ListView.view.currentIndex` on hover.
FocusScope {
    id: root

    property var source: []

    // Searchable strings for one item, most significant first. Each field
    // after the first has its score scaled down, so a hit in an app's name
    // beats a hit buried in its description.
    property var fields: item => [String(item)]
    property real fieldFalloff: 0.55

    // Added to an item's score, higher first. With an empty query every score
    // is 0, so this alone orders the list -- which is how the launcher shows
    // frecency order and the switcher shows MRU order. Additive rather than a
    // tie-break because scores are rarely equal: typing "chr" scores a prefix
    // hit on some unrelated "Chompy Tower" above a mid-word hit on the Chrome
    // that gets launched daily, and only a used-this-often term reorders that.
    property var weight: item => 0

    // A list of a handful of fixed actions does not want a search field, and
    // giving up the field is what frees bare letters for accelerators.
    property bool searchable: true

    property string placeholder: ""
    property int rowHeight: 44
    property int maxRows: 10
    property int spacing: 10

    // Reserve the full list height even when fewer rows match, so the card
    // does not resize and re-centre on every keystroke.
    property bool fixedHeight: false

    property Component delegate: null

    readonly property alias query: field.text
    readonly property alias currentIndex: list.currentIndex
    readonly property var currentItem: root.results[list.currentIndex] ?? null

    readonly property var results: {
        const query = field.text.trim();
        const scored = [];

        for (let i = 0; i < root.source.length; i++) {
            const item = root.source[i];
            const texts = root.fields(item);
            let best = 0;
            let matched = false;

            for (let f = 0; f < texts.length; f++) {
                const raw = Fuzzy.score(query, texts[f] ?? "");
                if (raw < 0)
                    continue;

                const score = raw * Math.pow(root.fieldFalloff, f);
                if (!matched || score > best) {
                    best = score;
                    matched = true;
                }
            }

            if (matched)
                scored.push({ item, score: best + root.weight(item), order: i });
        }

        scored.sort((a, b) => b.score - a.score || a.order - b.order);
        return scored.map(entry => entry.item);
    }

    signal accepted(var item)
    signal secondary(var item)
    signal cancelled

    function reset(): void {
        field.text = "";
        list.currentIndex = 0;
    }

    function select(index: int): void {
        if (root.results.length === 0)
            return;

        const count = root.results.length;
        list.currentIndex = ((index % count) + count) % count;
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    function activate(): void {
        if (root.currentItem !== null)
            root.accepted(root.currentItem);
    }

    implicitHeight: (root.searchable ? field.height + root.spacing : 0) + list.height

    onResultsChanged: {
        if (list.currentIndex >= root.results.length)
            list.currentIndex = Math.max(0, root.results.length - 1);
    }

    Item {
        id: nav

        focus: !root.searchable

        Keys.onPressed: event => {
            const control = event.modifiers & Qt.ControlModifier;
            const shift = event.modifiers & Qt.ShiftModifier;

            switch (event.key) {
            case Qt.Key_Up:
                root.select(list.currentIndex - 1);
                break;
            case Qt.Key_Down:
                root.select(list.currentIndex + 1);
                break;
            case Qt.Key_Home:
                root.select(0);
                break;
            case Qt.Key_End:
                root.select(root.results.length - 1);
                break;
            case Qt.Key_PageUp:
                root.select(Math.max(0, list.currentIndex - root.maxRows));
                break;
            case Qt.Key_PageDown:
                root.select(Math.min(root.results.length - 1, list.currentIndex + root.maxRows));
                break;
            case Qt.Key_N:
                if (!control)
                    return;
                root.select(list.currentIndex + 1);
                break;
            case Qt.Key_P:
                if (!control)
                    return;
                root.select(list.currentIndex - 1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (root.currentItem === null)
                    return;
                if (shift)
                    root.secondary(root.currentItem);
                else
                    root.accepted(root.currentItem);
                break;
            case Qt.Key_Escape:
                root.cancelled();
                break;
            default:
                return;
            }

            event.accepted = true;
        }
    }

    TextField {
        id: field

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: root.searchable
        focus: root.searchable
        placeholder: root.placeholder
        keyHandlers: [nav]

        onTextChanged: list.currentIndex = 0
    }

    ListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.searchable ? field.bottom : parent.top
        anchors.topMargin: root.searchable ? root.spacing : 0

        height: (root.fixedHeight ? root.maxRows : Math.min(root.results.length, root.maxRows)) * root.rowHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        model: root.results
        delegate: root.delegate
    }

    Text {
        anchors.top: list.top
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.results.length === 0
        text: "No matches"
        color: Theme.popupSubtext
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
    }
}
