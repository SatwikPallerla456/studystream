## Product and design contract

Tangerine combines StudyStream, Plex and Panels. Keep all three in mind for every
product, architecture and UI decision:

- StudyStream: learning, contextual notes/bookmarks and progress in courses and
  relevant media/reading screens.
- Plex: visible media categories, named libraries, sources, scanning,
  identification/matching, metadata, artwork, editions and server delivery.
- Panels: capable book/comic/PDF reading, presentation/geometry, durable positions,
  gestures, backgrounds and bounded resource ownership.

Do not leave the old StudyStream shell in place and merely add isolated Plex or
Panels controls. Review the running app as a user following complete journeys.
Save concrete screen findings before changing the design. Source code presence
is not evidence that a user can discover or complete a workflow. Finish the core
category -> add source -> scan -> identify -> browse -> play/read/study journey
before secondary UI polish. Notes must stay contextual rather than occupying an
unconditional primary media-navigation destination. Retain users' saved notes.

The decompilation work is a standing implementation reference: read the relevant
findings in docs/PLEX_TARGETED_DECOMPILATION.md and
docs/PANELS_DEEP_DECOMPILATION.md and their linked scanner/geometry/cache reports.
Connect recovered behavior to a complete visible workflow and its backend; do
not reduce the research to cosmetic inspiration or silently invent unknown
private behavior. Keep source implementation, visual review and later acceptance
evidence distinct.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.

## Execution order

The user requires the Tangerine master plan implementation to finish before a
separate testing phase. During implementation, do not execute tests, analyzers,
builds or runtime acceptance journeys. Keep implementation status distinct from
historical verification. Formatting and Graphify maintenance are implementation
work. Use Graphify whenever investigating project relationships.

On 20 October 2026 the user explicitly authorised starting the app, taking
screenshots, and using a user-role walkthrough to review and revise the UI.
Build/startup and hot reload needed for that design work are allowed. Automated
tests and analyzers remain deferred until the complete implementation is done.
The latest order is to review every screen and save the design report before
implementing its changes; retain clear source-only versus visual coverage.
