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
| **Subagent** | Isolated work that returns a *conclusion*: research, a survey, an audit, a review | It would otherwise flood the main context with material nobody needs after the answer |
| **Slash command** | A prompt the human fires deliberately and repeatedly | The human decides when. There is no autonomous trigger to define |
| **Hook** | It must happen **every time**, without exception, AND the trigger is a mechanical event the harness can observe directly (a file was saved, a tool was called, a session started or stopped) | Instructions are probabilistic. Hooks are deterministic — but only for triggers a hook can literally see. If the trigger itself takes judgment to recognize, no hook can fire on it |

The decisive question for skill-versus-subagent: **does the main agent need the
work, or the conclusion?** If it needs the work — the files read, the edits made —
that is a skill. If it needs only the answer, dispatch a subagent and keep the
context clean.

The decisive question for anything-versus-hook has two parts, and both must hold:

1. **Is it acceptable for this to be skipped once in twenty runs?** If no,
   instructions alone will not do — you need something deterministic.
2. **Can the harness observe the trigger without judgment?** A hook fires on
   syntax — a file path, a tool name, an exit code — never on semantics. If
   recognizing *when* to act requires reading and understanding content, the
   harness cannot see that event, so no hook can be attached to it.

Both parts must hold before something is a hook. "Always/every time/whenever" in
the requirement satisfies part 1, but it is not sufficient on its own — that is
the trap. "Draft an ADR whenever we make an architectural decision" reads like
part 1 (always), but no harness event corresponds to "we made an architectural
decision" — only a reasoning agent recognizes that as it happens, mid-conversation.
It fails part 2, so it is not a hook; it is a skill. Contrast "format every file
after editing it": `PostToolUse` on `Edit`/`Write` is a mechanical event the
harness already fires on. It passes both parts — hook.

No amount of capitalization in CLAUDE.md makes a model deterministic, and no
amount of "always" in a feature request makes its trigger mechanical.

Hooks live in `settings.json` — hand off to the built-in `update-config` skill,
which owns that file. Do not hand-edit it here. If a request has no mechanical
trigger the harness can see at all — e.g. "ping the payments lead when a PR
touches payments" is a GitHub event, not a Claude Code session event — it is
outside all four rows: point the human at CI/webhook tooling instead of forcing
it into a hook that will never fire.

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

| Agent kind | Tools |
|-----------|-------|
| Research / survey / audit | `Read, Grep, Glob, Bash` — **no** `Write`, **no** `Edit` |
| Review | `Read, Grep, Glob, Bash` — reviews produce findings, not fixes |
| Implementation | `Read, Write, Edit, Bash` |

If you cannot name why an agent needs `Write`, it does not need `Write`.

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
survey or audit and hand back a conclusion, it should invoke a subagent from
within its body rather than do the work inline.

## Verify it before you rely on it

A subagent whose description never matches is dead code that looks alive. Dispatch
it once against a real case and confirm it both fires and returns the shape you
specified. For a proper trigger check — including the negative cases — use
`harness-eval`.
