---
name: subagent-authoring
description: >-
  Decide between a skill, a subagent, a slash command and a hook — then author the
  chosen artifact, in particular subagent definitions in .claude/agents/. Use when
  new agent capability is being added to a repo ("create an agent that reviews
  migrations", "I want a subagent for research", "should this be a skill or a
  command?", "make this run automatically every time", "add a /deploy command"),
  or when an existing subagent needs its tool allowlist, model tier or description
  tuned. Starts with the choice of artifact, because the most common harness
  mistake is building the wrong one.
---

# Subagent Authoring

## Start with the artifact, not the file

The most common harness mistake is not a badly written subagent — it is a subagent
that should have been a hook. Choose first.

| Build a... | When | Because |
|-----------|------|---------|
| **Skill** | A procedure the main agent should follow, in the main context, with the conversation's full history | It needs to see what happened; it should mutate the work in flight |
| **Subagent** | Isolated work that returns a *result* the main agent needs — research, a survey, an audit, a review | It would otherwise flood the main context with material nobody needs after the result lands |
| **Slash command** | A prompt the human fires deliberately and repeatedly | The human decides when. There is no autonomous trigger to define |
| **Hook** | It must happen **every time**, without exception; the trigger is a mechanical event the harness can observe directly (a file was saved, a tool was called, a session started or stopped); AND the action itself is deterministic — a script can do it without judgement | Instructions are probabilistic. Hooks are deterministic scripts — but only when *both* the trigger and the action need no judgement. Two truths and a judgement call is not a hook |

The decisive question for skill-versus-subagent: **does the main agent need the
work, or the result?** If it needs the work — the files read, the edits made, the
reasoning as it unfolds — that is a skill. If it needs only the result, dispatch a
subagent and keep the context clean. The result is not necessarily one summary
paragraph: a subagent can legitimately return a structured list — file paths, line
numbers, a ranked set of findings. What makes it a subagent is that the main
agent needs the finished result, not the exploration that produced it.

The decisive question for anything-versus-hook has **three** parts, and all
three must hold:

1. **Is it acceptable for this to be skipped once in twenty runs?** If no,
   instructions alone will not do — you need something deterministic.
2. **Can the harness observe the trigger without judgment?** A hook fires on
   syntax — a file path, a tool name, an exit code — never on semantics. If
   recognizing *when* to act requires reading and understanding content, the
   harness cannot see that event, so no hook can be attached to it.
3. **Is the action itself deterministic — can a script perform it without
   judgement?** A hook is a script, not a reasoner. If producing the right
   output requires weighing options, understanding intent, or writing content
   that could be wrong, no script can be trusted to do it, no matter how
   observable the trigger was.

All three must hold before something is a hook. "Always/every time/whenever" in
the requirement satisfies part 1, but it is not sufficient on its own — that is
the trap. "Draft an ADR whenever we make an architectural decision" reads like
part 1 (always), but no harness event corresponds to "we made an architectural
decision" — only a reasoning agent recognizes that as it happens, mid-conversation.
It fails part 2, so it is not a hook; it is a skill. Contrast "format every file
after editing it": `PostToolUse` on `Edit`/`Write` is a mechanical event the
harness already fires on, and a formatter's output is fully determined by its
input. It passes all three — hook.

Part 3 is the one that parts 1 and 2 hide, and it is where most false-positive
hooks come from: a requirement can satisfy both of the first two and still fail
the third. Take "every new Eloquent Model must get a Policy whose ability
methods match its real relationships." It must happen every time (part 1: yes),
and the trigger — a new file matching `app/Models/*.php` — is mechanically
observable (part 2: yes). A reading that stops at two-out-of-three says hook.
But writing a Policy whose ability methods correctly reflect the model's actual
relationships is a judgement call: a script can detect that a Model exists
without a matching Policy, but it cannot *write* a correct one. Part 3 fails.
This is not a hook.

**Corollary** — and this is the useful part: when parts 1 and 2 hold but part 3
fails, the right build is a pair, not a single artifact. A hook *enforces*
(blocks the commit, warns, or injects a reminder that a Policy is missing);
a skill *performs* the judgement (writes the Policy, given the Model's real
relationships). Deterministic enforcement, probabilistic execution. Do not
force the judgement into the hook — it cannot make one — and do not drop the
enforcement and rely on the skill alone being remembered, because that
reintroduces exactly the "skipped one time in twenty" failure part 1 exists to
rule out.

No amount of capitalization in CLAUDE.md makes a model deterministic, and no
amount of "always" in a feature request makes its trigger — or its action —
mechanical.

### Tie-breaker: human-initiated but must-not-be-forgotten

Some requests genuinely satisfy two rows of the table at once, and the table's
own questions do not resolve them. "Run my pre-merge checklist whenever I'm
about to open a PR" reads as a hook (`PreToolUse` on `gh pr create` is a
mechanical, observable trigger), as a slash command ("the human decides when to
run their own checklist"), and as a skill ("it needs the full conversation to
know what actually changed"). Three competent readers land on three different
rows from the same sentence, because the trigger genuinely is both
human-initiated and mechanically observable, and the work genuinely does need
context. Do not guess — ask the tie-breaker question instead:

**What happens if it is skipped?** Not "who triggers it" — **who is
accountable when it does not happen.**

- If skipping is **unacceptable** — a merge with obviously broken tests, a
  Policy-less Model reaching production — the enforcement half must be a hook:
  deterministic, cannot be forgotten, cannot be talked out of running. The
  judgement half (what the checklist actually checks, in context) is a skill
  the hook invokes or points the agent at. This is the same enforce/perform
  pairing as the corollary above.
- If skipping is merely **undesirable** — a nice-to-have habit, not a
  compliance gate — it is a slash command. The human is accountable for
  running it, and that is an acceptable answer; no enforcement is needed.

Worked example: "run my pre-merge checklist whenever I'm about to open a PR."
If the checklist exists because untested PRs have shipped and broken `main`,
skipping is unacceptable — build a `PreToolUse` hook on `gh pr create` that
blocks or warns, paired with a skill that performs the actual checklist
(reading the diff, checking test coverage, flagging breaking changes), which
the hook points the agent at. If the checklist is a personal habit ("did I
remember to update the changelog"), skipping only costs the human a forgotten
changelog entry — that is a slash command, fired on demand, no enforcement
attached.

Hooks live in `settings.json` — hand off to the built-in `update-config` skill,
which owns that file. Do not hand-edit it here.

Two shapes of request fall outside all four rows entirely. Do not force either
into a hook that will never fire:

- **No mechanical trigger the harness can see at all.** "Ping the payments
  lead when a PR touches payments" is a GitHub event, not a Claude Code
  session event. Point the human at CI/webhook tooling instead.
- **Time-based, not event-based.** "Post release notes every Friday" or "draft
  the changelog every night at 9pm" has no session event to attach to at all —
  there is no file save, tool call or session start that causes it, because
  nothing in the current session triggers it. This is scheduled/recurring
  work: point the human at Claude Code's native cron-based scheduled agents
  (routines) — see the `schedule` skill — not at a hook.

## Authoring a subagent

Definitions live in `.claude/agents/<name>.md`. Start from
`assets/agent_template.md`.

### The description is the dispatcher

The main agent sees **only** the `description:` when deciding whether to dispatch.
Write it as the condition under which delegating is right, in the words the main
agent would actually think — not as a job title.

Weak: `Reviews database migrations.`
Strong: `Use when a migration file has been added or changed and needs review for
reversibility, locking behavior and data loss, before it is committed.`

### Tools: least privilege, and mean it

Grant the minimum. A research agent that can `Write` will eventually write
something, at the worst possible moment, with no one watching.

Say this plainly rather than hiding it: **`Bash` is a write-capable tool.**
`echo > file` and `rm -rf` are both one shell call away. An allowlist that
denies `Write`/`Edit` but still grants unrestricted `Bash` has not delivered
least privilege — it has delivered the *appearance* of it, and this repo's
premise is evidence, never assertion. Do not write a table that claims a
boundary the allowlist does not actually enforce.

The honest options, in order of preference:

| Agent kind | Tools | Why |
|-----------|-------|-----|
| Pure-reading research / survey / audit | `Read, Grep, Glob` | A genuine read-only set — no shell, nothing left to constrain |
| Research / review that truly needs commands (running tests, `git log`, targeted `grep` at scale) | `Read, Grep, Glob, Bash` with a **command allowlist** in the agent definition or `settings.json` | `Bash`, scoped by allowlist to the specific commands the task requires — not a blank grant. Review agents still produce findings, not fixes, so `Write`/`Edit` stay denied regardless |
| Implementation | `Read, Write, Edit, Bash` | The agent's job is to change files; no theatre needed |

If you cannot name why an agent needs `Bash` at all, start from `Read, Grep,
Glob` and add `Bash` only when a specific command is missing from that set. If
you cannot constrain what `Bash` will be used for, granting it is equivalent to
granting `Write` and `Edit` — say so in the definition instead of implying
otherwise.

### Model tier

Omit `model:` and inherit the session's. Set it only when you are confident:
a cheaper tier for mechanical, high-volume work; a stronger one for the hardest
judgement. Guessing here costs money on every dispatch, forever.

### It has none of your context

A subagent starts cold. It cannot see the conversation, the plan, or the file you
were just looking at. Everything it needs goes in the dispatch prompt or the
definition. The single most common subagent bug is a prompt written as though the
agent were listening the whole time.

### Its final message is the return value

Say exactly what the final message must contain, and say that it is a return
value, not a status report for a human. "Return the file paths and line numbers,
one per line, no prose" beats "summarize what you found".

## Authoring a slash command

If the table above landed on **slash command**, there is no template for this —
it is the simplest of the four artifacts. Create `.claude/commands/<name>.md`:

```markdown
---
description: <one line — what this command does, shown in the command list>
argument-hint: <optional — e.g. "<ticket-id>", shown as a hint while typing>
allowed-tools: <optional allowlist, same least-privilege reasoning as subagents>
model: <optional — omit to inherit the session model>
---

<The prompt itself, as if the human typed it. Use $ARGUMENTS for everything
typed after the command name, or $1, $2 for positional arguments.>
```

Unlike a subagent, this runs **in the main conversation** with full context — it
is a saved prompt, not an isolated dispatch. If the command's job is really to
survey or audit and hand back a result, it should invoke a subagent from
within its body rather than do the work inline.

## Verify it before you rely on it

A subagent whose description never matches is dead code that looks alive. Dispatch
it once against a real case and confirm it both fires and returns the shape you
specified. For a proper trigger check — including the negative cases — use
`harness-eval`.
