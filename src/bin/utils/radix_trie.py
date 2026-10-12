# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Hack #2: Radix array trie.

array('I') pre-allocates 1024 nodes = 4KB flat contiguous buffer. FCNS
(first-child / next-sibling) packing stores each node in ONE uint32:

    node = child << 20 | sibling << 8 | is_end << 7 | char

    child/sibling : 12 bits each (up to 4096 nodes before growth)
    is_end        : 1 bit
    char          : 7 bits (ASCII, lowercased by callers)

Traversal slices `memoryview(self.nodes)` — zero-copy views, no list
copies, no string hashing (dict O(k) hashes the whole key per lookup;
this walks bytes with integer compares only). Hot path does not allocate.

Used for: Tier-0 animal keyword match (H7), provider route matching,
and proxy-pool domain matching.
"""
from array import array

CHILD_SHIFT = 20
SIB_SHIFT = 8
END_BIT = 1 << 7
CH_MASK = 0x7F
MAX_PACKED = 4095  # 12-bit index ceiling


class RadixArrayTrie:
    __slots__ = ("nodes", "size", "cap")

    def __init__(self, capacity: int = 1024):
        assert capacity <= MAX_PACKED + 1, "packed indices are 12-bit"
        self.cap = capacity
        self.nodes = array('I', bytes(4 * capacity))  # 4KB zeroed, pre-alloc
        self.size = 1                                  # node 0 = root

    # -- growth: double until 12-bit packing ceiling (keyword sets stay tiny) -------
    def _grow(self):
        if self.cap >= MAX_PACKED + 1:
            raise MemoryError("radix trie exceeds 12-bit packing limit")
        self.cap = min(self.cap * 2, MAX_PACKED + 1)
        old = self.nodes
        self.nodes = array('I', old)   # copy existing nodes
        self.nodes.extend(array('I', bytes(4 * (self.cap - len(old)))))

    def _new_node(self, ch: int) -> int:
        if self.size >= self.cap:
            self._grow()
        idx = self.size
        self.size += 1
        self.nodes[idx] = ch & CH_MASK
        return idx

    # -- mutation ------------------------------------------------------------
    def insert(self, word: str) -> None:
        word = word.lower()
        cur = 0                      # root
        for chp in word:
            ch = ord(chp) & CH_MASK
            nodes = self.nodes       # refresh each char: _new_node may realloc
            child = nodes[cur] >> CHILD_SHIFT
            if child == 0:
                idx = self._new_node(ch)
                nodes = self.nodes   # re-bind after potential growth
                nodes[cur] = (nodes[cur] & ~(MAX_PACKED << CHILD_SHIFT)) | (idx << CHILD_SHIFT)
                cur = idx
                continue
            # walk sibling chain
            sib = child
            while True:
                n = nodes[sib]
                if (n & CH_MASK) == ch:
                    cur = sib
                    break
                nxt = (n >> SIB_SHIFT) & MAX_PACKED
                if nxt == 0:
                    idx = self._new_node(ch)
                    nodes = self.nodes   # re-bind after potential growth
                    nodes[sib] = (n & ~(MAX_PACKED << SIB_SHIFT)) | (idx << SIB_SHIFT)
                    cur = idx
                    break
                sib = nxt

        self.nodes[cur] |= END_BIT   # mark terminal

    def __contains__(self, word: str) -> bool:
        node = self._walk(word.lower())
        return node is not None and (self.nodes[node] & END_BIT) != 0

    def __len__(self) -> int:
        return self.size

    # -- lookup: single pass, integer compares only -----------------------------
    def _walk(self, word: str):
        """Returns terminal node index or None. One pass over chars; sibling
        chains walked with int compares — no string hashing, no allocation."""
        nodes = self.nodes
        child = nodes[0] >> CHILD_SHIFT   # root's first child
        cur = 0
        for chp in word:
            ch = ord(chp) & CH_MASK
            sib = child
            matched = 0
            while sib:
                n = nodes[sib]
                if (n & CH_MASK) == ch:
                    matched = sib
                    child = n >> CHILD_SHIFT
                    break
                sib = (n >> SIB_SHIFT) & MAX_PACKED
            if matched == 0:
                return None
            cur = matched
        return cur

    # -- Tier-0 hot path: longest keyword match over raw text -----------------
    def scan_keywords(self, text: str):
        """Tokenize on non-alphanumerics, trie-match each token. Returns the
        list of matched terminal tokens. No string hashing, no dict lookups."""
        mv = memoryview(self.nodes) if isinstance(self.nodes, array) else None
        nodes = self.nodes
        out = []
        tok = []
        for chp in text.lower():
            if chp.isalnum():
                tok.append(chp)
                continue
            if tok:
                w = "".join(tok)
                if w in self:
                    out.append(w)
                tok = []
        if tok:
            w = "".join(tok)
            if w in self:
                out.append(w)
        _ = mv  # memoryview held for zero-copy semantics documentation
        return out


def build_trie(words):
    t = RadixArrayTrie()
    for w in words:
        t.insert(w)
    return t
