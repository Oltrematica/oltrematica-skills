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
#
# The activity-vs-adjective lookahead below (excluding "reading", "with",
# etc.) recurs on several alternatives because the same ambiguity recurs:
# "done"/"finished"/"complete" describing a STATE of a thing ("the fix is
# complete", "the migration is done" — a claim) reads identically, out of
# context, to the same words describing an ACTIVITY the assistant is mid-way
# through or has only partly done ("done reading", "is done with the
# analysis" — not a claim). The guard is: block the activity readings
# (gerund or "with" immediately after), not the position in the sentence.
_ACTIVITY_GUARD = r"(?!\s+(?:reading|reviewing|looking|checking|analysing|analyzing|processing|running|building|testing|with))"

CLAIM_MIDSENTENCE = re.compile(
    r"""(?ix)
    \b(?:is|was|are|were)\s+(?:now\s+)?fixed\b
  | \b(?:is|was|are|were)\s+(?:now\s+)?(?:complete|finished)\b(?!\s+with)
  | \b(?:is|was|are|were)\s+(?:now\s+)?done\b"""
    + _ACTIVITY_GUARD
    + r"""
  | \beverything\s+is\s+green\b
  | \b(?:is|are)\s+working\s+now\b
  | \bnow\s+works\b
  | \bworks\s+now\b
  | \ball\s+done\b"""
    + _ACTIVITY_GUARD
    + r"""
  | \bi(?:'ve|\s+have)\s+(?:now\s+)?(?:finished|fixed|implemented|completed)\s+(?:the|a|an|this|that|its?|my|our)\b
    (?!(?:(?!["'.\n!?]).)*\b(?:but|however|though|still|yet)\b)
    (?:(?!["'.\n!?]).)*[.!]?\s*\Z
                                           # present-perfect "I've fixed/finished
                                           # THE/A thing" — a determiner right
                                           # after the verb signals a single,
                                           # specific, closed-out deliverable.
                                           # Contrast "I've fixed two of the
                                           # three failing tests" (a quantifier,
                                           # not a determiner) — that is
                                           # progress on a subset, not a claim
                                           # the item after the verb is done.
                                           # Two extra guards, because a
                                           # determiner alone isn't enough:
                                           # (1) no "but"/"however"/"still"/
                                           # "yet" before this sentence ends —
                                           # "I've fixed the login bug, but the
                                           # signup flow still throws" is one
                                           # completed sub-task, not a finished
                                           # job; (2) nothing follows this
                                           # sentence to the end of the message
                                           # — a real claim like this is the
                                           # last word, not a stepping stone
                                           # ("I've fixed the parser. Now for
                                           # the tests." fails here, same as it
                                           # fails the "i'll"/"now for" guards).
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
      | \bhaven'?t\b | \bhasn'?t\b        # an explicit admission that
                                           # something is not yet done —
                                           # guards the present-perfect
                                           # CLAIM_MIDSENTENCE alternative
                                           # above from firing on a message
                                           # that elsewhere concedes it isn't
                                           # finished
      | \bnot\s+yet\b
      | \bnot\s+(?:quite\s+)?(?:all\s+)?(?:done|fixed|complete|finished)\b
      | \bnot\b(?:(?!["'.\n!?]).){0,20}\b(?:sure|certain|confident)\b
                                           # "I think this is done, but I'm
                                           # not sure" — a hedge on the claim
                                           # itself, not a reported result
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
