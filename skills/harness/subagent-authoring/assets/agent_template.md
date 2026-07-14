---
name: <kebab-case-name>
description: <When to dispatch this agent, in the words the main agent would think. This is the router — it is the only thing seen at dispatch time.>
tools: <comma-separated allowlist — least privilege. Omit Write/Edit for read-only agents.>
model: <sonnet | opus | haiku | fable — omit to inherit the session model>
---

# <Agent Name>

<One paragraph: what this agent is for, and what it returns.>

## Your task

<Imperative instructions. The agent sees only its dispatch prompt and this file —
it has none of the main conversation's context. Say what it needs, explicitly.>

## Return

<Exactly what the final message must contain. The agent's final message IS the
return value handed back to the main agent — not a human-facing summary. Be
specific about format.>
