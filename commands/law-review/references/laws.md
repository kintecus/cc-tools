# Law catalog for /law-review

Each entry has the law, the way coding agents typically break it, the signals to look for in a diff or spec, and when it is NOT a violation. Only cite a law when one of its signals is actually present. Canonical statements: https://github.com/dwmkerr/hacker-laws

## Simplicity and scope

### Gall's Law
A complex system that works is invariably found to have evolved from a simple system that worked.
- **Agent failure mode:** one-shots a complete multi-component system on the first pass. It works for the demo case but has no reusable primitives, so the second use case means a rebuild.
- **Signals:** several new modules, services, or tables landing at once with no earlier working slice; orchestration code before a single end-to-end path exists; a plan whose step 1 is "set up the framework".
- **Not a violation when:** the change is itself a thin end-to-end slice, or it grows an already-working system by one step.

### YAGNI (You Aren't Gonna Need It)
Don't build it until it is needed.
- **Agent failure mode:** adds backward-compatibility shims nobody asked for, config flags with one value, abstract base classes with one subclass, plugin registries, and "for future use" parameters.
- **Signals:** an interface or abstraction with a single implementation; options that no caller sets; compat layers for versions that were never released; code paths only reachable by tests; comments like "in case we later...".
- **Not a violation when:** a second concrete caller exists in the same change, or the project's docs explicitly reserve the extension point and say why deferring costs more.

### Second-System Effect
The second system someone builds tends to be overengineered, carrying every idea that was cut from the first.
- **Agent failure mode:** asked to rewrite or port, it carries over every feature and adds generalizations "while we're here".
- **Signals:** a rewrite that is larger than the original; new generality (multi-tenant, multi-provider, pluggable) with no requirement behind it; v1 scope that lists future product lines.
- **Not a violation when:** each added capability traces to a named user need or a documented lesson from the first system.

### Kernighan's Law
Debugging is twice as hard as writing the code, so if you write the code as cleverly as possible, you are by definition not smart enough to debug it.
- **Agent failure mode:** dense metaprogramming, clever generics, custom DSLs, or reflection where a plain function would do.
- **Signals:** code that needs a comment to explain *how* it works (not why); dynamic dispatch, decorators, or macros for one call site; a hand-rolled parser or state machine where a library or a switch would do.
- **Not a violation when:** the cleverness is confined behind a small, well-tested interface and buys measured performance or correctness.

### Solved-problem check (Not Invented Here / Law of the Instrument)
If the problem is already solved by a platform primitive, a managed service, or a hardened tool, use it.
- **Agent failure mode:** models are "down to build": a cache in front of a cache, a home-grown job queue, a custom auth flow, file storage on local disk when object storage exists.
- **Signals:** new infrastructure-shaped code (caching, queues, retries, rate limiting, auth, crypto, storage, scheduling) without a sentence on why the existing option doesn't fit.
- **Not a violation when:** the project has an explicit dependency policy that favours small in-house code, and the code is genuinely small.

## Interfaces and contracts

### Principle of least astonishment
A component should behave the way its users expect.
- **Agent failure mode:** invents its own RBAC model, CLI flag style, error shape, or pagination scheme instead of following the ecosystem's idiom.
- **Signals:** a new pattern with no precedent in the repo; CLI flags that differ from git, gh, or kubectl conventions (for example, missing `--dry-run` on a mutating command, or nonstandard help output); API shapes that differ from sibling endpoints.
- **Check:** can the author name three existing examples of the idiom (this repo first, then well-known tools)? If not, flag it.
- **Not a violation when:** the deviation is deliberate and documented.

### Hyrum's Law
With enough users, every observable behaviour of a system will be depended on by somebody.
- **Agent failure mode:** "harmless" changes to output format, field order, error text, default values, URL shape, or field presence.
- **Signals:** changes to anything external clients, installed artifacts, persisted data, or printed material can observe: response shapes, headers, date formats, IDs, URLs, file formats, CLI output that scripts may parse.
- **Not a violation when:** the surface is provably internal, or the PR states which existing consumers see the change and how they keep working.

### Tesler's Law (conservation of complexity)
Every application has an inherent amount of complexity that cannot be removed, only moved.
- **Signals:** a "simplification" that pushes work onto the caller or user, such as more required parameters, a manual step, or a config file the user must now write.
- **Not a violation when:** moving the complexity is the explicit goal.

## Change and legacy

### Chesterton's Fence
Don't remove a fence until you know why it was put up.
- **Agent failure mode:** deletes "dead" code, renames "badly named" things, or removes a "redundant" check that was load-bearing.
- **Signals:** deletions or renames of code that looks odd, defensive, or redundant, with no reference to its history (commit, issue, ADR, comment).
- **Check:** run `git log -S '<symbol>'` or `git blame` on the removed lines. Is there a linked issue?
- **Not a violation when:** the PR cites why the fence existed and why the reason no longer holds.

## Reliability and security

### Fallacies of distributed computing
The network is reliable; latency is zero; bandwidth is infinite; the network is secure; topology doesn't change; there is one administrator; transport cost is zero; the network is homogeneous. All false.
- **Signals:** external HTTP or RPC calls with no timeout; retries on non-idempotent operations; trusting a client library's success flag without the response; no story for a lost message; side effects sent before the local transaction commits.
- **Not a violation when:** the call goes through an existing wrapper that already handles these.

### Kerckhoffs's principle
A system should be secure even if everything about it, except the key, is public.
- **Agent failure mode:** asked for "a password", it produces symmetric encryption with a shared secret passed around, unguessable URLs as the only access control, or home-grown token formats.
- **Signals:** custom crypto; secrets compared with `==`; security that depends on an endpoint or algorithm staying unknown; missing authorization checks behind a "hidden" route.
- **Not a violation when:** standard primitives and libraries are used as documented.

### Goodhart's Law
When a measure becomes a target, it ceases to be a good measure.
- **Agent failure mode:** makes the tests pass instead of making the code correct.
- **Signals:** weakened assertions; tests rewritten to match new (wrong) output; the unit under test mocked out; skipped or deleted tests; broad exception handlers that turn failures into passes; snapshot updates with no explanation.
- **Not a violation when:** the test change is explained and the old expectation was wrong.

### Anti-guidance: the robustness principle (Postel's Law)
"Be liberal in what you accept" is NOT a goal for untrusted input. If a change loosens parsing or validation of external input in the name of robustness, flag it as a security concern, not a virtue.
