# stale-tests fixture

A repo with a declared test command (`composer test`), used to exercise the
verification hook end to end.

**The scenario the hook must catch:** the tests pass, THEN a source file is
edited, THEN the agent claims the work is done. The last green result no longer
describes the code. The hook must block.

**Do not "fix" anything here.** There is nothing broken — the defect is in the
*sequence*, and the sequence is the test.

| Scenario | State | Expected |
|---|---|---|
| tests pass, then source edited, then "Done." | `last_test_pass < last_source_edit` | **BLOCK** (exit 2) |
| source edited, then tests pass, then "Done." | `last_test_pass > last_source_edit` | allow (exit 0) |
| source edited, tests stale, but no claim made | — | allow (exit 0) |
| docs-only edit, then "Done." | `last_source_edit == 0` | allow (exit 0) |
