#!/usr/bin/env python3
"""claims.py — does this message CLAIM the work is complete?

Reads the message on stdin. Exit 0 = claims completion. Exit 1 = does not.

This is the soft joint of the verification hook, and it is deliberately
isolated here so it can be tested on its own and put in front of a blind
quorum (see tests/harness/claim_corpus.json, Task 7).

Two asymmetric failure modes:
  - a MISS (a real claim not detected) leaves the hook silent — a hole.
  - a FALSE POSITIVE blocks legitimate work, and is how the whole pack
    gets uninstalled. Prefer a miss over a false positive.

Python stdlib only.
"""
import re
import sys

# Assertions that the work is finished. Present tense / past tense, not future,
# not interrogative, not hypothetical.
CLAIM = re.compile(
    r"""(?ix)
    (?:^|[.\n!]\s*|^\s*)          # start of a sentence
    (?:
        done\b(?!\s+(?:reading|reviewing|looking|checking|analysing|analyzing|with))
      | fixed\b
      | (?:that'?s|it'?s|this\s+is|work\s+is)\s+(?:done|complete|finished)
      | complete(?:d)?\b
      | finished\b
      | implemented\b
      | all\s+(?:the\s+)?tests?\s+pass
      | tests?\s+(?:now\s+)?pass(?:ing)?\b
      | everything\s+is\s+green
      | ready\s+(?:for\s+review|to\s+(?:merge|ship))
    )
    """,
)

# Verb-phrase completion assertions ("the migration issue is fixed", "...and
# everything is green") that report a result just as clearly as the
# sentence-initial forms above, but sit mid-sentence — joined to the previous
# clause by "and", an em dash, or a subject ("X is fixed" rather than a bare
# "Fixed"). CLAIM's leading sentence-boundary anchor deliberately misses these
# (Task 7 quorum finding: a 3/3-claim sample the sentence-initial-only pattern
# scored as no-claim — a MISS, the safer failure, but still a real hole).
# Unlike CLAIM, this is intentionally NOT anchored to a sentence boundary,
# because the verb ("is/was/are/were fixed") is what carries the assertion,
# not its position in the sentence. NOT_A_CLAIM's conditional guard below
# keeps this from firing on a hypothetical ("once this is fixed...").
CLAIM_MIDSENTENCE = re.compile(
    r"""(?ix)
    \b(?:is|was|are|were)\s+(?:now\s+)?fixed\b
  | \beverything\s+is\s+green\b
    """,
)

# Things that look like claims but are not: predictions, questions, intentions.
NOT_A_CLAIM = re.compile(
    r"""(?ix)
    (?:
        \bshould\s+(?:pass|work|be)\b     # a prediction, not a result
      | \bshould\b(?:(?!["'.\n!?]).){0,40}\b(?:pass(?:es|ing)?|work(?:s|ing)?|be|fix(?:ed)?)\b
                                           # "should ... fix/pass" a bit further
                                           # away in the same clause — still a
                                           # prediction, not a reported result
      | \bi'?ll\b | \bi\s+will\b | \bgoing\s+to\b | \bnext\s+i\b
      | \bnow\s+(?:for|to)\b               # "done with X, now for Y" — a
                                            # transition, not a finish line
      | \b(?:once|if|when|after)\b(?:(?!["'.\n!?]).){0,60}\b(?:is|are|was|were)\s+fixed\b
                                           # a conditional/hypothetical
                                           # ("once this is fixed..."), not a
                                           # reported result — guards
                                           # CLAIM_MIDSENTENCE above
      | \?\s*$                            # a question
    )
    """,
)


def _normalize(text: str) -> str:
    """Strip formatting noise that would otherwise hide or fake a sentence
    boundary, without touching the words themselves.

    - Fenced code blocks are quoted text, not an assertion by the author —
      drop them entirely so an example ("```\\nDone.\\n```") never counts.
    - Blockquote lines are quoted text, not an assertion by the author — drop
      them so a message quoting "Done" never counts.
    - Markdown emphasis markers (**bold**, __bold__, *em*) are stripped so a
      formatted claim ("**Done.**") still reads as sentence-initial.
    - Leading list/checkbox markers ("- [x] ", "* ", "1. ") are stripped from
      the start of each line so a checklist claim ("- [x] Fixed") still
      reads as sentence-initial.
    """
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    text = re.sub(r"(?m)^[ \t]*>.*$", " ", text)
    text = re.sub(r"[*_]{1,3}", "", text)
    text = re.sub(r"(?m)^[ \t]*(?:[-*+]|\d+\.)\s+(?:\[[ xX]\]\s*)?", "", text)
    return text


def claims_completion(text: str) -> bool:
    if not text or not text.strip():
        return False
    if NOT_A_CLAIM.search(text):
        return False
    normalized = _normalize(text)
    return bool(CLAIM.search(normalized) or CLAIM_MIDSENTENCE.search(normalized))


def main() -> None:
    try:
        text = sys.stdin.read()
    except Exception:
        sys.exit(1)          # unreadable input is not a claim — fail open
    sys.exit(0 if claims_completion(text) else 1)


if __name__ == "__main__":
    main()
