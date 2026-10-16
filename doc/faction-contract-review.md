# Core-facing faction contracts

The [passive/triggered ability specification](army-api.md) defines the corrected
replacement mechanism. Selection stays in ordinary actions; the six-family
provider proposal has been superseded. This review describes current dispatch
and the dependencies that migration must fix.

This review follows dispatch hooks into their **core consumers**. It records
the interfaces implemented now and the work still required for a core that does
not interpret particular factions' rules. Documentation changes do not perform
that refactor or certify another faction.

## Ownership and documentation rule

Core supplies reusable mechanics and controls their sequencing. Composition
supplies rule-dependent contributions or decisions at explicit boundaries.
The [dispatch contracts](../src/factions/README.md) specify inputs, results,
mutation, neutral behavior and ownership expected of any implementation.
Implementing adapters contain the named army rules, eligibility details and
their source citations. Shared catalog enums may contain faction entries; core
must not branch on their private meaning.

Pure predicates return a contribution or veto without spending resources or
altering state. Appenders preserve existing contributions and source identities.
Commands execute once at their named boundary. Ordinary action constructors
can execute before suspension; peer-menu constructors must leave shared state
untouched because both alternatives are initialized. Their `started` flag is a
routing result read after one input; completed effect results are read after
the child finishes, before shared-frame reuse.

These are implementation contracts. They do not assert that a particular
datasheet is eligible for an effect merely because the interface supports it.

## Findings requiring implementation follow-up

The following are current interface limits or remaining dependencies, not
problems that comments alone resolve.

A concrete type name in composition/generated frame storage is not itself
interpretation of an army rule. Preserve typed storage and change ownership
where needed; renaming frame types without changing dependencies is insufficient.

| Current dependency | Core's actual expectation | Required direction |
| --- | --- | --- |
| Action-returning signatures expose concrete faction frame types; timing/charge progress contains named faction fields. | Core forwards child inputs and observes `started` or remaining work. | Keep finite typed composition, but place concrete frame selection/private progress behind composition-owned types. Core must not interpret private fields. A type rename alone does not change ownership. |
| `faction_melee_sustained_rule_applies` is a Boolean; `weapon_abilities.rl` constructs Sustained Hits 1 itself. | One particular extra weapon-rule instance. | Supply the actual grant through existing general weapon-rule appenders and retire this special-case hook. Preserve duplicate-instance selection. |
| `faction_innate_hit_bonus` is a Boolean with a hardcoded +1 meaning. | An independently ignorable hit-roll contribution. | Use the existing modifier contribution path, retaining source/ignore provenance rather than a separate faction-specific bonus channel. |
| `faction_engagement_exception` drives both engaged-target shooting and unshocked escape-hazard bypass. | Two permissions happen to share one result. | Give the two mechanics independent shared permissions. An army rule granting only one must not receive the other. |
| `faction_advance_charge_status` and `faction_move_charge_permission` overlap at Advance selection. | Their OR is captured as one movement-history permission. | Consolidate the selected-mode permission query while retaining selection-time capture; changes after selection must not rewrite history. |
| `faction_before_destruction` returns legacy-named fields for one target/mortal result plus demise suppression. | Core queues that result and performs ordinary destruction order. | Return a mechanically named destruction result, using generic damage jobs when multiple effects are needed; never recursively enter the active damage resolver. |
| `faction_declarations_complete` returns one scoped effect key. | Core removes that key after all declared groups. | Support a generic collection of scoped keys so independently sourced effects can share an attack lifetime. |
| `faction_passenger_objective_control` receives no queried objective. | `Board.objective_control_level` adds the result for each scored objective containing the carrier. | Pass the queried objective so marker-specific permission is evaluated for that marker. Add a regression for a carrier in range of two markers, only one qualifying. Current home-marker checks alone cannot distinguish those calls. |
| Model stores named army flags, equipment selection, option provenance, an attachment flag and a separate named status collection. | Core copies/archives/revives the complete model and queries neutral properties. | Replace these fields with explicit ability/equipment data, shared selected-option provenance and source-owned effect storage. Keep actual effect interpretation in the adapter. |
| Captured component army-rule metadata uses one named Boolean in Unit/AttachmentComponent. | Core preserves component conferral through destruction and revival. | Capture generic rule-conferral metadata while retaining original-component identity and the retained-source window. Do not infer it from current surviving models. |
| Legacy factions still have named behavior in core. | Compatibility attack, Command, destruction and model/unit helpers directly check those abilities. | Move their eligibility/effect choices to adapters and contribute through shared mechanics/neutral hooks. Do not treat an Orks-only boundary audit as proof of all-faction independence. |

Examples of the last row include `configure_attack_info` checking
`oath_of_moment`, `fury_of_the_first`, `psychological_saboteur` and `bladeguard`;
the `feeder_tendrils` destruction path; `sacrificial_dagger` handling;
`neural_disruption` Command behavior; and named permissions in the Unit helpers.
Literal entries in legacy roster factories are data and may remain in catalogs
or faction construction modules. The issue is interpretation by core algorithms.

The current [boundary audit](../tools/check_faction_boundary.py) explicitly
checks the Orks adapter, its fields/rule codes and named effect interpretation.
Extend its scope and negative controls when extracting the other factions; a
passing current audit is useful evidence within that scope only.

## Model-field refactor remains planned

The eight fields are `has_waaagh`, `has_da_boss`, `grants_unit_riled_up`,
`blastajet_force_field`, `orks_enhancement`, `orks_upgrade_origin`,
`painboss_mounted_attachment` and `riled_source_effects`.

Use the existing ability list for explicit rule conferral, the shared weapon
catalog's nonattacking equipment support for selected wargear, a shared
selected-enhancement record for catalog identity and original recipient, and
the shared effect store for attachment/status grants. Preserve separate source
keys for overlapping effects. Generic source installation/removal/validation
can then replace bespoke named-status lifecycle callbacks.

Option provenance is a shared requirement. Keep it distinct from the model's
current original-component mapping: the existing split operation rewrites
`original_unit`, and replacement construction has its own remapping boundary.
Neither renaming a field nor replacing its identity with the current unit slot
preserves that behavior.

Use whatever adequate bounded collections these mechanics require. Removing
faction dependencies is the objective; storage reduction is not a prerequisite.
Persistent numbers remain bounded for generated ML layout, with generated
initialization/destruction and explicit save/binding schema updates.

## Reviewable implementation order

1. Generalize Model's option/ability/equipment/effect data and component-conferral
   metadata in focused commits, retaining source/provenance behavior.
2. Fold the fixed weapon/hit and duplicate selected-move permission hooks into
   existing contribution/permission mechanisms. Separate the bundled engagement
   permissions and pass the scored objective to cargo OC.
3. Generalize completed action results and composition-owned frame/progress
   types without changing controller sequencing or shared-frame non-re-entry.
4. Extract legacy non-Orks rule interpretation and broaden the boundary audit
   with negative controls for those dependencies.

Each implementation commit needs its relevant native regressions. Validate the
combined batch with matching generated bindings, source/frame/layout checks and
sanitized replay/fuzz checks. Preserve all-bank semantics, independent source
expiry and the current grid; do not optimize valid-action discovery. No runtime
implementation or full test execution is part of this documentation review.
