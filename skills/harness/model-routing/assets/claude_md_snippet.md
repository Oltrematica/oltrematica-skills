<!-- Paste into this repo's CLAUDE.md. Policy only: states which tier is
     mandatory when; the model-routing skill owns how to decide. -->

## Model routing policy (this repo)
- Mechanical, fully-specified edits (rename, boilerplate, transcription): cheapest tier is mandatory, not optional
- Multi-file integration, debugging, pattern-matching: mid tier is the floor
- Architecture, design, hard review, subtle correctness: most capable tier is mandatory
- Read-heavy survey work (N files, "what does X do"): must be delegated to a subagent, never done inline in the main session
- One task per session: do not carry a finished task's conversation into the next, unrelated one
- Exceptions: [e.g. ticket ID granting a standing override]
