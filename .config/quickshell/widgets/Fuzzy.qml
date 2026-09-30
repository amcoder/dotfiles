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

    function charScore(text: string, index: int): int {
        if (index === 0)
            return 80;
        return root.isBoundary(text, index) ? 40 : 5;
    }

    // Scores the best placement of the query in the text, not the leftmost
    // one. best[j] is the top score with the current query character at j;
    // gaps cost one per skipped character, capped at 10.
    function score(query: string, text: string): real {
        if (query === "")
            return 0;
        if (text === "")
            return -1;

        const needle = query.toLowerCase();
        const haystack = text.toLowerCase();
        const length = haystack.length;

        let cursor = 0;
        for (let i = 0; i < needle.length; i++) {
            const at = haystack.indexOf(needle.charAt(i), cursor);
            if (at < 0)
                return -1;
            cursor = at + 1;
        }

        let best = new Array(length).fill(-Infinity);
        for (let j = 0; j < length; j++) {
            if (haystack.charAt(j) === needle.charAt(0))
                best[j] = root.charScore(text, j) - Math.min(j + 1, 10);
        }

        for (let i = 1; i < needle.length; i++) {
            const next = new Array(length).fill(-Infinity);
            let far = -Infinity;

            for (let j = i; j < length; j++) {
                if (j >= 11)
                    far = Math.max(far, best[j - 11]);
                if (haystack.charAt(j) !== needle.charAt(i))
                    continue;

                let top = Math.max(best[j - 1] + 30, far - 10);
                for (let k = Math.max(0, j - 10); k < j - 1; k++)
                    top = Math.max(top, best[k] - (j - k - 1));

                next[j] = top + root.charScore(text, j);
            }

            best = next;
        }

        let total = Math.max(...best);

        if (haystack === needle)
            total += 200;
        else if (haystack.startsWith(needle))
            total += 100;

        return total;
    }
}
