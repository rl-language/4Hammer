# Damaged — batch17.C3

Authority: [core ability24.39, Damaged](https://wahapedia.ru/wh40k11ed/the-rules/core-rules/#Damaged), verified from the cached [Battlewagon](https://wahapedia.ru/wh40k11ed/factions/orks/Battlewagon) ability tooltip in the 2026-10-12 Orks scan. It states: “This ability always takes the form Damaged X. While a model’s remaining wounds are equal to or less than X, that model is damaged: while damaged, that model’s attacks have -1 to hit rolls.” This is website authority, not a fabricated PDF quotation/page. Cumulative modifier order/cap is the supplied appendix02.02.01; hits/criticals p.18, Torrent p.85 and Firing Deck p.81.

`Model.has_damaged` and bounded `damaged_threshold` explicitly encode supplied metadata. Legacy factories remain disabled; no current datasheet is certified or installed here. X is nonnegative within existing Wounds storage capacity; there is no invented requirement that X be positive or smaller than starting wounds. Restore validation rejects raw negative/out-of-domain thresholds.

Status is computed from current remaining wounds. Each gathered weapon group snapshots the actual bearer's status, overriding stale enclosing context. Healing above X removes the penalty at the next group. Other models in a mixed unit do not inherit it. Retained Fight on Death models at zero wounds remain affected while authorised to attack; normal eligibility is separate. Borrowed Firing Deck weapons use the carrier's status.

The penalty joins the ordinary hit-modifier sum before Heavy/engagement increments and the +/-1 cap; it changes hit rolls rather than WS/BS. Existing group identity sees the changed total. Natural1/6, six-only shooting and Torrent's automatic hits retain their existing rules. Source effects that selectively ignore modifiers remain17.C4; actual faction data remains17.H and subsequent families.

State/observation23, action14, next-state24. New storage is Bool/standard bounded Wounds and generated lifecycle methods. Action/grid domains and production Rules.gd/TraceManager.gd remain unchanged; rebuild matching native libraries/Godot headers.

Final validation passes546 assertions /548 CTest entries,12 focused native sanitizer cases, matching focused Godot checks, a completed878-action game,20 Gym steps and sanitized fixed replays. ROADMAP.md records final mutation evidence and artifact paths. Initial test runs exposed fixture errors (enum comparison syntax, duplicate copied identity and an incorrect BS assumption); those fixtures were corrected. Superseded runs are not passing evidence.
