pragma Singleton

import Quickshell

// Subsequence matching for the pickers. `score` returns -1 when the query is
// not a subsequence of the text, otherwise a number where higher is better.
Singleton {
    id: root

    readonly property var separators: [" ", "-", "_", ".", "/", ":", "("]

    function isBoundary(text: string, index: int): bool {
        if (index === 0)
            return true;

        const previous = text.charAt(index - 1);
        if (root.separators.indexOf(previous) >= 0)
            return true;

        // camelCase: a capital following a lowercase starts a word.
        const current = text.charAt(index);
        return previous !== previous.toUpperCase() && current === current.toUpperCase();
    }

    function score(query: string, text: string): real {
        if (query === "")
            return 0;
        if (text === "")
            return -1;

        const needle = query.toLowerCase();
        const haystack = text.toLowerCase();

        let total = 0;
        let previous = -2;
        let cursor = 0;

        for (let i = 0; i < needle.length; i++) {
            const at = haystack.indexOf(needle.charAt(i), cursor);
            if (at < 0)
                return -1;

            if (at === 0)
                total += 80;
            else if (root.isBoundary(text, at))
                total += 40;
            else
                total += 5;

            if (at === previous + 1)
                total += 30;
            else
                total -= Math.min(at - previous - 1, 10);

            previous = at;
            cursor = at + 1;
        }

        if (haystack === needle)
            total += 200;
        else if (haystack.startsWith(needle))
            total += 100;

        return total;
    }
}
