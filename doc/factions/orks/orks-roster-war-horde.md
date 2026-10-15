# Current Orks starter and War Horde passive

The public Orks roster uses the three current datasheet adapters: one Beastboss,
one four-model Squighog Boyz unit (one Nob, three Boyz), and two ten-model Beast
Snagga Boyz units (one Nob, nine Boyz, one additional Thump Gun each). This is a
25-model starter per player, not the planned complete54-unit catalogue. The
stable Morgrim roster enum/action remains a compatibility identifier; the editor
labels its choice **Orks (current units)**. Historical factories remain explicit
core-test scaffolds and are not called by this public choice.

Sources are the cached2026-10-12 current Beastboss, Beast Snagga Boyz and Squighog
Boyz cards, linked in `orks-current-unit-data.md` and `orks-current-unit-rules.md`.
Oval bases retain both source axes and use the user-approved long-axis circle
proxy on whole-inch quad anchors. Points and detachment prices are omitted by
user instruction; actual CP costs and limits remain enforced.

Army selection assigns identities before mandatory Warlord selection. Each
player selects their Beastboss model, then both players can attach their boss to
an explicitly permitted Snagga bodyguard during battle formations. The existing
attachment pipeline compacts reserve slots while retaining model/component and
Warlord identities. Unit source registration follows formations, so Keep Huntin'
and Bomb Squig refer to the surviving components. Both saves and generated Godot
controls must use the actual current reserve IDs, including after compaction.

## Get Stuck In

Source: <https://wahapedia.ru/wh40k11ed/factions/orks/#Get-Stuck-In>. The cached
faction tooltip states: **“Friendly ORKS units’ melee attacks have [Sustained Hits1].”**

`war_horde_melee_rule_applies` checks the source unit's owner configuration,
selected War Horde package, ORKS army faction and unit keyword union, and a melee
weapon. It does not depend on whose turn it is or require each individual bearer
to have ORKS. `model_weapon_rules` adds a distinct unconditional Sustained Hits1
instance to the normal declaration snapshot. Extra Attacks melee weapons receive
it too; ranged profiles do not. Selection/eligibility helpers recognize the same
grant. No aura range, temporary duration or CP expenditure is invented.

The existing p78 duplicate-ability chooser selects one instance before target
declarations. Beastboss can choose unconditional1 or its printed Monster/Vehicle
conditional2; they never sum to3 or automatically select the largest. A chosen
conditional2 remains inactive against targets without either keyword. The
existing hit consumer generates ordinary extra hits from critical original hits;
those extra hits roll to wound normally. Saved declarations retain their choice.

This completes only17.I1, the passive. War Horde enhancements/upgrades and all six
CP cards belong to17.I2. Other selected packages retain their implementation
status in ROADMAP.md; storing a package is not evidence that its effects work.
State/observation schema31 records the changed public roster and passive
semantics. Action schema19 and the existing quad/input domains are preserved.

## Validation

See ROADMAP.md for executed results. New deterministic cases cover the actual
public selection/formation/save path and owner/keyword/package/profile gates,
duplicate choice, declaration forwarding and critical-hit resolution. The new
`godot_orks_roster.gd` exercises production roster/Warlord/attachment controls and
the generated duplicate-rule chooser. Full-game completion and sanitizer/fuzzer
runs must use freshly built libraries for this batch.


Executed results:755 assertions have passing results across the initial full
756/757-entry run and corrected19/19 affected run; all17 new native sanitizer
assertions pass with leak checking enabled. Three Godot controls, independent
HTML tables and unchanged finite ML layout pass. Actual current games complete
in1,158 and1,346 legal actions; both replay successfully through the fresh native
sanitized fuzzer, alongside preserved and zero inputs. A15-run69-second mutation
campaign reports no failures. ROADMAP.md records exact logs, corrected fixture
assumptions and validation limits. These checks certify the scoped roster and
passive; complete rendered journeys and the remaining faction work are pending.
