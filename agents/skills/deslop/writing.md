# Writing slop catalog

Loaded by the deslop skill in **Write** and **Detect** modes. Source patterns
adapted from [petergyang/no-ai-slop](https://github.com/petergyang/no-ai-slop)
(MIT).

## Words to cut

Banned outright unless quoted as examples: delve, foster, leverage, utilize,
facilitate, empower, streamline, robust, cutting-edge, paradigm shift, game
changer, this is huge, this changes everything, tapestry, realm, beacon,
multifaceted, meticulous, intricate, paramount, transformative, elevate, embark,
supercharge, harness, ever-evolving.

Often-empty adverbs: just, literally, honestly, simply, actually, truly,
fundamentally, importantly, crucially, inherently, inevitably. Cut when they
add nothing. Keep when they carry emphasis, uncertainty, contrast, or spoken
rhythm.

Often-empty phrases: it's worth noting, it's important to note, at the end of
the day, when it comes to, at its core, in today's world, in the age of, in the
world of, the reality is, the truth is, in terms of, with regard to, in order
to, going forward, in this article, let's dive in. Cut when they delay the
point. Keep an occasional phrase only if it is clearly the writer's voice and
the sentence still earns its place.

## Patterns to cut

**Binary contrasts.** "This is not X. It's Y." / "The question isn't X, it's Y."
/ "It's not just X but Y." State Y directly.

Example: "The question isn't the model. It's the eval." → "The eval matters more
than the model."

**Throat-clearing openers.** "Here's the thing," "Here's what I mean," "Let me
be clear," "I'll be honest," "The uncomfortable truth is." Cut and state the
point.

**Faux-insight setups.** "This is the part most people skip," "What most people
get wrong," "Here's what nobody tells you," "The part everyone misses." Cut the
setup; let the claim stand alone.

Example: "The part everyone misses: distribution is the real moat" →
"Distribution is the moat."

**Colon reveals.** Noun phrase, colon, then a lowercase dramatic reveal: "The
best part: it learns." Rewrite as a plain sentence. Use colons for lists,
labels, and quotes. Prefer sentence case after a colon unless grammar, a proper
noun, a title, or code requires otherwise.

**Superficial analysis.** Trailing `-ing` clauses that fake explanation:
"highlighting," "underscoring," "reflecting," "showcasing."

Example: "The launch adds file search, highlighting the team's commitment to
better workflows" → "The launch adds file search, so users can find old drafts
without leaving the editor."

**Importance puffery.** "Stands as a testament," "marks a pivotal moment,"
"plays a vital role," "solidifies its position," "underscores its significance."
State the fact; let the reader judge importance.

Example: "The launch marks a pivotal moment for the company" → "The launch is
the company's first paid product."

**Weasel attribution.** "Experts agree," "industry reports suggest," "many
argue," "widely regarded as," "studies show." Name the source or cut the claim.
If the user has no source, ask instead of inventing one.

**Fake-strong verbs.** Prefer "is" and "has" when clearer. "The app serves as a
centralized hub for sponsor management" → "The app tracks sponsors, drafts, due
dates, and approvals in one place."

**Synonym cycling.** If the clear word is right, repeat it. Do not rotate
agent/assistant/tool for style.

**Negative listing.** "Not a X. Not a Y. A Z." Just say Z.

**Dramatic fragmentation.** "X. And Y. And Z." or "That's it. That's the whole
thing." Prefer complete sentences when the fragments are decorative.

**Robotic rhythm.** Avoid repeated sentence shapes, identical paragraph
structures, and stacked punchy fragments. Vary shape only when it helps.

**Rhetorical setups.** "What if I told you...", "Think about it:", "Plot twist:",
self-answered "Question? Answer." pairs. Drop and make the point.

**Fake-profound kickers.** Delete the final "deep" line when it turns the point
into a cute metaphor, aphorism, or mic-drop. Do not rewrite into a better
metaphor. End on the clearest concrete sentence already in the draft, or a plain
takeaway / next action.

**Summary-recap endings.** "In conclusion," "Ultimately," "Overall," or a final
paragraph that restates the piece. End on the last concrete point, takeaway, or
next action.

**Formatting slop.** Emoji in headings, bold sprinkled mid-sentence for
emphasis, bullet lists where two sentences of prose would read better, headers
over two-sentence sections. Format follows content.

**Em dashes.** Not a default rhythm crutch. Short copy: none. Longer drafts:
1–2 if they clearly beat commas, periods, or parentheses. Remove clusters and
decorative dashes.

## Verb and concreteness helpers

- Weak verb phrases → direct verbs: "made a decision" → "decided"; "has the
  ability to" → "can".
- Abstract productivity claims → measurable facts when the draft supports them:
  "significantly improves engineering productivity" → "cut review time from 30
  minutes to 8" (only if that fact is present or the user provides it).
