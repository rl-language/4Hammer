import factions.orks.types
import bounded_arg
import stats
import vector2d
import machine_learning
import range
import state_types
import geometry
import modifiers

using Wounds = LinearlyDistributedInt<0, MAX_WOUNDS>
using WeaponsVector = CheckedVector<EquippedWeapon, MAX_WEAPONS>
using Abilities = CheckedVector<AbilityKind, 16>
using Keywords = CheckedVector<Keyword, 32>

# some rules specify that models are not to be removed after being destroyed until some other event happens, for example fight on death. We keep track of this special statuses with this enum
enum ModelState:
    normal
    fight_on_death
    pending_destruction

    fun equal(ModelState other) -> Bool:
        return self.value == other.value

cls Model:
    # Printed ordinary detachment options and source-owned timed permissions.
    # Generated lifecycle and bounded values preserve the inferred ML layout.
    # Nobz wargear, not a weapon profile: only Kustom Krumpa gains its rerolls.
    # https://wahapedia.ru/wh40k11ed/factions/orks/Nobz
    OrksEnhancement orks_enhancement
    EntityIdentity orks_upgrade_origin
    OrksEffectGrants orks_effects
    # Bank/staged offboard units have no battlefield visibility/ranges
    # (supplied appendix01.02.04, transport pp.64–65).
    Bool off_battlefield
    Bool orks_transport_permissions
    Bool beast_snagga_passengers_only
    Bool forbid_ghaz_passenger
    Bool blastajet_force_field
    Bool transport_permissions_known
    LinearlyDistributedInt<0, 33> transport_capacity
    LinearlyDistributedInt<1, 33> transport_space
    Keywords permitted_passenger_keywords
    Keywords forbidden_passenger_keywords
    LinearlyDistributedInt<0, 33> firing_deck
    # Supplied future datasheets can encode random M and duplicate Scouts
    # without changing fixed profile defaults (appendix 02.02.03; pp.78/84).
    Bool has_random_movement
    Stat random_movement
    CheckedVector<FixedStat, 8> scout_distances
    BoardPosition position # required
    ModelGeometry geometry
    Profile profile
    # Explicit source identity; legacy uncertified factories remain unknown.
    DatasheetCode datasheet
    # Model-scoped arithmetic, not implicit unit-wide grants (appendix02.02.01).
    CharacteristicModifiers characteristic_modifiers
    # Incoming AP/D grants belong to the actual allocated recipient, not its weapons.
    IncomingAttackModifiers incoming_attack_modifiers
    # Explicit scoped permissions for appendix02.02.02; sources own expiry.
    AttackModifierPermissions attack_modifier_permissions
    # Explicit current Army Rules; no legacy factory infers these from its name.
    # https://wahapedia.ru/wh40k11ed/factions/orks/ (Waaagh!/Da Boss).
    Bool has_waaagh
    # Runnin' wiv da Herd affects only the attached Painboss bearer.
    Bool painboss_mounted_attachment
    Bool has_da_boss
    # Supplied Warlord definition; Ghazghkull also requires this model.
    Bool must_be_warlord
    Bool cannot_be_warlord
    Bool grants_unit_riled_up
    CheckedVector<SourceEffectKey, 8> riled_source_effects
    Wounds suffered_wounds
    # Core ability24.39: supplied threshold only; legacy fixtures grant none.
    Bool has_damaged
    Wounds damaged_threshold
    WeaponsVector weapons
    # Explicit rule data for supplied datasheets/fixtures, by weapon slot (pp.78–85).
    CheckedVector<WeaponRule, 8>[MAX_WEAPONS] additional_weapon_rules
    Abilities abilities 
    Keywords keywords 
    ModelState state
    EntityIdentity identity
    EntityIdentity original_unit
    # Explicit core ability data for fixtures/future supplied datasheets (p.80).
    Bool has_deadly_demise
    Stat deadly_demise
    # Trigger timing is lifecycle infrastructure for destruction p.87.
    Bool destruction_pending
    PhaseStamp destroyed_phase
    # A conferred attached-unit rule survives attack destruction until all
    # that attacking unit's attacks end (p.67). This is not live-model status.
    Bool attachment_abilities_retained
    # Unit-destruction callbacks are emitted only for the whole attached unit
    # (p.66), sharing this final casualty's existing destruction timing.
    Bool destroyed_whole_unit
    # Supplied Fight on Death: keep triggers pending until own attack/phase end.
    Bool destruction_released
    Bool destruction_attack_suppressed
    Bool destroyed_by_attack
    Bool destroying_unit_known
    UnitID destroying_unit
    # Stable historical killer identity survives explicit replacement-slot reuse.
    EntityIdentity destroying_unit_identity
    Dice destruction_fight_roll
    ModelHistory history
    # Hunter target permissions and One Shot history remain per equipped slot.
    WeaponRule[MAX_WEAPONS] hunter_profile_conditions
    Bool[MAX_WEAPONS] used_once_per_battle_weapon

    # A retained corpse is physically present but not a live recipient (p.87).
    fun is_alive() -> Bool:
        return self.state == ModelState::normal and self.wounds_left() > 0

    # Core p12 measurement, using an intentional temporary circle for hulls
    # authorized by the user; Orks Use-model cards do not print dimensions.
    fun base_size_in_inches() -> Float:
        return self.base_radius_micrometres() / 12700.0

    fun is_below_half_wounds() -> Bool:
        return self.suffered_wounds * 2 > self.profile.wounds()

    # Read per-model keywords without copying owning storage (pp.67/87).
    fun has_keyword(Keyword keyword) -> Bool:
        let override = faction_keyword_override(self, keyword)
        if override != 0:
            return override > 0
        let i = 0
        ref rules = self.keywords
        while i != rules.size():
            if rules[i] == keyword: 
                return true 
            i = i + 1
        return false

    fun has_weapon_rule(WeaponRuleKind rule) -> Bool:
        let i = 0
        while i != self.weapons.size():
            if self.weapons[i].profile.has_rule(rule):
                return true 
            i = i + 1
        return false

    # Properties stay readable to explicit death hooks; active use is gated
    # by Unit.has_ability/is_alive (p.87). Avoid an owning temporary here.
    fun has_ability(AbilityKind kind) -> Bool:
        if faction_model_grants_intrinsic_ability(self, kind):
            return true
        let i = 0
        ref rules = self.abilities
        while i != rules.size():
            if rules[i] == kind: 
                return true 
            i = i + 1
        return false

    # Retain the legacy whole-quad consolidation direction without silently
    # clamping a base across the battlefield edge (p.12). Fight rules: task 14.
    fun consolidate_torward(Unit other):
        let consolidation = other.get_shortest_vector_to(self) * -1.0
    
        if consolidation.length() > 2.0:
            consolidation = (consolidation.as_float_vector().normalized() * 2.0).as_int_vector()
        let x = self.position.x.value + consolidation.x
        let y = self.position.y.value + consolidation.y
        let radius = self.base_radius_micrometres()
        if !self.geometry.unsupported_footprint and float(x * MICROMETRES_PER_INCH) >= radius and float(y * MICROMETRES_PER_INCH) >= radius and float(x * MICROMETRES_PER_INCH) + radius <= float(BOARD_WIDTH * MICROMETRES_PER_INCH) and float(y * MICROMETRES_PER_INCH) + radius <= float(BOARD_HEIGHT * MICROMETRES_PER_INCH):
            self.position.x = x
            self.position.y = y

    fun is_character() -> Bool:
        return self.has_keyword(Keyword::character)

    # Convert existing whole-inch quad coordinates to physical calculation units.
    # Bases affect measurement without allowing off-grid model positions (p.9).
    fun geometry_position() -> GeometryPoint:
        return geometry_point(self.position.x.value * MICROMETRES_PER_INCH, self.position.y.value * MICROMETRES_PER_INCH, self.geometry.elevation.value * MICROMETRES_PER_INCH)

    # Preserve whole-inch quad positions and elevation; the user's later task
    # owns any finer spatial representation. Reject invalid positions (p.12).
    fun set_geometry_position(GeometryPoint point):
        assert(point.x.value < BOARD_WIDTH * MICROMETRES_PER_INCH and point.y.value < BOARD_HEIGHT * MICROMETRES_PER_INCH, "model centre outside editor board")
        assert(geometry_point_on_grid(point), "model positions must remain on quad grid")
        self.position.x = point.x.value / MICROMETRES_PER_INCH
        self.position.y = point.y.value / MICROMETRES_PER_INCH
        self.geometry.elevation = point.z.value / MICROMETRES_PER_INCH

    # Existing profile diameters are millimetres; retain their circular fixture
    # interpretation explicitly. Hull/oval data needs a supplied footprint (p.9/62).
    fun base_radius_micrometres() -> Float:
        if self.geometry.proxy_diameter_mm.value > 0:
            return float(self.geometry.proxy_diameter_mm.value) * 500.0
        return self.profile.base_size() * 500.0

    # Nearest points of circular bases, clamped to zero for intersecting bases
    # (p.9). Unsupported footprints must not acquire fabricated round geometry.
    fun horizontal_distance_micrometres(Model model) -> Float:
        if self.geometry.unsupported_footprint or model.geometry.unsupported_footprint:
            return 1000000000.0
        let result = horizontal_length(self.geometry_position(), model.geometry_position()) - self.base_radius_micrometres() - model.base_radius_micrometres()
        if result < 0.0:
            return 0.0
        return result

    # Engagement/coherency measure horizontal and vertical separation separately
    # (pp.14–15), so height cannot be folded into the horizontal radius.
    fun vertical_distance_micrometres(Model model) -> Int:
        return abs(self.geometry.elevation.value - model.geometry.elevation.value) * MICROMETRES_PER_INCH

    # Inclusive two-inch horizontal/five-inch vertical engagement (pp.14–15).
    fun is_engaged_with(Model model) -> Bool:
        if self.off_battlefield or model.off_battlefield:
            return false
        return within_geometry_limits(self.horizontal_distance_micrometres(model), self.vertical_distance_micrometres(model), 2, 5)

    # Ordinary nearest-base range is straight-line distance; engagement uses
    # its separately prescribed horizontal/vertical limits (pp.9/14).
    fun distance(Model model) -> Float:
        # Appendix01.02.04: own unit is within its own abilities; no foreign
        # distance is available while embarked. Finite sentinel is computed.
        if self.off_battlefield or model.off_battlefield:
            if self.original_unit.value > 0 and self.original_unit == model.original_unit:
                return 0.0
            return 1000000.0
        let horizontal = self.horizontal_distance_micrometres(model)
        let vertical = float(self.vertical_distance_micrometres(model))
        return sqrt(horizontal * horizontal + vertical * vertical) / float(MICROMETRES_PER_INCH)

    # Orks/Big-ed-Bossbunka and Aircraft print M-; modifiers cannot change it.
    # Effective model characteristics retain one printed arithmetic policy
    # (appendix02.02.01); source selection and expiry are separate consumers.
    fun effective_movement(Int base) -> Int:
        return effective_characteristic_value(base, ModifiedCharacteristic::movement, self.characteristic_modifiers, self.profile.movement() == 0, faction_movement_bonus(self))

    # Multiple Toughness uses each model's effective value (appendix05.02.01).
    fun effective_toughness() -> Int:
        return effective_characteristic_value(self.profile.thoughness(), ModifiedCharacteristic::toughness, self.characteristic_modifiers, false, faction_toughness_bonus(self))

    # Save groups compare modified Sv/InSv before allocating dice (p.19).
    fun effective_save() -> Int:
        return effective_characteristic_value(self.profile.save(), ModifiedCharacteristic::save, self.characteristic_modifiers, false)

    # Legacy profiles use >6 for no InSv. This is '-', not a modifiable save
    # that a bonus can turn into an invulnerable permission (appendix02.02.01).
    # Orks/Wazbom-Blastajet Blastajet Force Field is selected equipment.
    fun effective_invulnerable_save() -> Int:
        let base = faction_invulnerable_base(self)
        return effective_characteristic_value(base, ModifiedCharacteristic::invulnerable_save, self.characteristic_modifiers, base > 6)

    # Riled-up gives a5+ InSv and ranged Assault; owned keys preserve overlapping
    # permanent/timed sources (Orks Army Rules / Waaagh!, appendix01.02.02).

    # Leadership and OC consumers use the bearer scope (p.9; appendix02.02.01).
    fun effective_leadership() -> Int:
        return effective_characteristic_value(self.profile.leadership(), ModifiedCharacteristic::leadership, self.characteristic_modifiers, false)

    # Battle-shocked '-' OC is handled by the unit before this query (p.9).
    fun effective_objective_control() -> Int:
        return effective_characteristic_value(self.profile.control(), ModifiedCharacteristic::objective_control, self.characteristic_modifiers, self.has_keyword(Keyword::aircraft))

    # Damaged X applies at equal-or-fewer remaining wounds, including retained
    # Fight on Death models. Source: core ability24.39, reproduced in the
    # Battlewagon tooltip: https://wahapedia.ru/wh40k11ed/the-rules/core-rules/#Damaged
    fun is_damaged() -> Bool:
        return self.has_damaged and self.wounds_left() <= self.damaged_threshold.value

    fun wounds_left() -> Int:
        return self.profile.wounds() - self.suffered_wounds.value

const MAX_UNIT_MODELS = 32
const MAX_UNIT_MODELS_PLUS1 = 33
using ModelVector = CheckedVector<Model, MAX_UNIT_MODELS>

cls ModelID: # required
    BInt<0, MAX_UNIT_MODELS> id

    fun get() -> Int:
        return self.id.value

    # Reject invalid positional model selectors; finite editor domains are implementation metadata.
    fun assign(Int other):
        assert(other >= 0 and other < MAX_UNIT_MODELS, "invalid model slot")
        self.id = other

using ModelIterator = LinearlyDistributedInt<0, MAX_UNIT_MODELS_PLUS1>

const MAX_UNIT_COUNT = 32
const MAX_UNIT_COUNT_PLUS1 = 33
cls UnitID: # required
    BInt<0, MAX_UNIT_COUNT> id

    fun get() -> Int:
        return self.id.value

    # Reject invalid positional unit selectors before they can address roster storage.
    # Selector layout is implementation metadata supporting target selection (p.17).
    fun assign(Int value):
        assert(value >= 0 and value < MAX_UNIT_COUNT, "invalid unit slot")
        self.id = value

using UnitIterator = BInt<0, MAX_UNIT_COUNT_PLUS1> 

fun unit_id(Int id) -> UnitID:
    let to_return :  UnitID
    to_return = id
    return to_return

cls PhaseModifiers:
    Bool greater_strenght_wound_protection 
    # Charge-roll effects are phase-scoped; appendix 02.02.01 supplies their order/cap.
    RuleModifiers charge_roll
    Bool smokescreen
    Bool counteroffensive

cls Unit:
    # Selected Big Mek Advance traverses models; clear after its move.
    # https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek
    Bool shokk_boosta_move
    # Immutable battle-start equipment for identical replacement units; not
    # current wounds/status and not a model-revival identity (Infested War Zone).
    Hidden<ModelVector> battle_start_models
    # Orks psychic expenditure survives reserves/passengers and attachment.
    FixedStat psyker_level
    OrksPsychicUsage orks_psychic_usage
    Bool is_generated_replacement
    LinearlyDistributedInt<0, 1025> orks_destroyed_attack
    PhaseStamp orks_destroyed_phase
    Bool off_battlefield
    EntityIdentity embarked_transport
    # Stable retired slot survives reserve round trips (pp.68–69/74).
    Bool has_return_slot
    UnitID return_slot
    ShootingKind shooting_kind
    UnitID snap_target
    FixedStat lone_operative_range
    ModelVector models # required
    Bool owned_by_player1 # required
    Hidden<String> name # required
    Bool has_moved
    # Per-selection M snapshot and optional flight mode (appendix 02.02.03; p.71).
    MovementOverride movement_override
    # Explicit reactive maximum is a distance, not a modifiable M characteristic.
    MovementOverride movement_distance_limit
    Bool move_takes_to_skies
    MovementKind pending_move_kind
    Bool has_run 
    Bool has_fought
    Bool has_shoot
    Bool battle_socked
    Bool has_charged
    Bool can_shoot
    Bool can_charge
    StartingStrength starting_strenght
    EntityIdentity identity
    Hidden<Vector<Model>> destroyed_models
    # Current unit datasheet/permissions are explicit source metadata. Model
    # tags/characteristics stay per-model; component rules stay unit-scoped.
    DatasheetCode roster_datasheet
    AttachmentRole attachment_role
    BodyguardPermissions permitted_bodyguards
    Abilities unit_abilities
    Bool bodyguard_waaagh
    StartingStrength bodyguard_starting_strength
    CheckedVector<AttachmentComponent, 2> attached_units
    UnitHistory history
    Bool retired
    Bool unit_destruction_event_issued
    # Unit-level mandatory Warlord wording is distinct from a named model.
    Bool must_supply_warlord
    # Points are absent from legacy rosters; enforce reserve caps only when
    # configured data is explicit, never manufacture faction costs (p.68).
    Bool points_known
    LinearlyDistributedInt<0, 10001> points
    PhaseModifiers phase_modifiers

    # Archived models retain identity, origin and once-per-battle weapon usage.
    # Return-to-unit legality is implemented by the later lifecycle tasks.
    # Archive identity, origin and weapon-use history before compacting live models
    # (destroyed models p.19; One Shot p.83; returning models p.88).
    fun remove_model(Int index):
        self.models[index].attachment_abilities_retained = false
        self.models[index].destroyed_whole_unit = false
        self.destroyed_models.value.append(self.models[index])
        self.models.erase(index)
        if self.models.empty():
            self.retired = true

    # Resolve a persistent model handle after casualty compaction, avoiding a
    # different model receiving a stored reference (damage p.19; returns p.88).
    fun find_model(EntityIdentity identity) -> Int:
        if identity.value <= 0:
            return -1
        let i = 0
        while i < self.models.size():
            if self.models[i].identity == identity:
                return i
            i = i + 1
        return -1

    # Retain setup history for later eligibility checks after reinforcement entry
    # (reserves/setup pp.68–71). This helper does not implement placement rules.
    fun mark_set_up():
        self.history.was_set_up_this_turn = true
        let i = 0
        while i < self.models.size():
            self.models[i].history.was_set_up_this_turn = true
            i = i + 1

    # Reset setup/distance carriers for the new turn without clearing battle-long
    # usage (turn pp.28–30; movement pp.32–33; One Shot p.83).
    fun reset_turn_history():
        self.history.deck_shooting_locked = false
        self.history.disembarked_this_turn = false
        self.history.tactical_move_required = false
        self.history.was_set_up_this_turn = false
        self.history.made_move_this_turn = false
        self.history.advanced_this_turn = false
        self.history.advance_allows_charge = false
        self.history.fell_back_this_turn = false
        self.history.fallback_allows_charge = false
        self.history.fallback_allows_shooting = false
        self.history.selected_move_allows_action = false
        # p.58: starting another action is a turn-local restriction; pending
        # cross-turn mission actions keep their completion/failure state.
        self.history.action_started = false
        let i = 0
        while i < self.models.size():
            self.models[i].history.was_set_up_this_turn = false
            self.models[i].history.reset_movement_distance()
            i = i + 1

    # Starting strength is the initial/combined model count, not a model index
    # (p.86; attached units pp.66–67). Strength thresholds are task 7.
    fun capture_starting_strength():
        self.battle_start_models.value = self.models
        self.starting_strenght = self.models.size()
        if self.attached_units.empty():
            self.bodyguard_starting_strength = self.models.size()
            self.bodyguard_waaagh = faction_component_has_army_rule(self, self.identity)

    fun has_greater_strenght_wound_protection() -> Bool:
        return self.phase_modifiers.greater_strenght_wound_protection 

    fun clear_phase_modifiers():
        # Phase-local shooting restrictions also expire while in reserves (pp.34–35/68).
        self.history.shot_this_phase = false
        for i in range(self.models.size()):
            self.models[i].history.epic_challenge = false
        let mod : PhaseModifiers
        self.phase_modifiers = mod

    # Attacks and Hunter profiles target a unit's complete keyword union,
    # while model-specific grants must use the explicit model query below
    # (p.78; appendix02.05.01 and Hunter appendix04.01.03).
    fun weapon_rule_applies(WeaponRule rule) -> Bool:
        return matches_keyword_predicate(self, rule.target_condition)

    # Attached units do not retain Lone Operative targeting protection (p.83).
    fun is_lone_operative() -> Bool:
        return self.attached_units.empty() and self.has_ability(AbilityKind::lone_operative)

    # Finish deferred removals including index zero and preserve archive history
    # (destroyed models pp.19/87); enabling Fight on Death still needs ability data.
    fun remove_figth_on_death_models():
        let i = self.models.size() - 1
        while i >= 0:
            if self.models[i].state == ModelState::fight_on_death:
                self.remove_model(i)
            i = i - 1

    fun can_reroll_charge() -> Bool:
        return self.has_ability(AbilityKind::unstoppable_valour)

    fun owner_id() -> Int:
        return int(self.owned_by_player1)
    
    fun get_temporary_weapon_rules() -> BoundedVector<WeaponRule, 1>:
        let to_return : BoundedVector<WeaponRule, 1>
        if self.has_ability(AbilityKind::veil_of_time)  and self.models.size() != 1:
            to_return.append(weapon_rule(WeaponRuleKind::sustained_hit, 1))
        return to_return

    fun empty() -> Bool:
        return self.models.empty()

    fun consolidate_torward(Unit other):
        let i = 0
        while i != self.models.size():
            self.models[i].consolidate_torward(other)
            i = i + 1

    # Structural transfer preserves every model/history and unit-scoped source,
    # not just one Character. Public eligibility is attachment_rules.rl (p.66).
    fun attach_to(Unit other):
        assert(self.identity.value > 0 and other.identity.value > 0 and self.identity != other.identity and attachment_role_available(other, self.attachment_role) and self.attached_units.empty(), "source must be an unattached Leader or Support")
        assert(self.models.size() > 0 and other.models.size() + self.models.size() <= MAX_UNIT_MODELS and other.attached_units.has_capacity(), "attachment model/component capacity exceeded")
        if other.attached_units.empty():
            other.bodyguard_starting_strength = other.models.size()
            other.bodyguard_waaagh = faction_component_has_army_rule(other, other.identity)
        let component : AttachmentComponent
        component.identity = self.identity
        component.starting_strength = self.models.size()
        component.name = self.name
        component.role = self.attachment_role
        component.datasheet = self.roster_datasheet
        component.abilities = self.unit_abilities
        component.psyker_level = self.psyker_level
        component.waaagh = faction_component_has_army_rule(self, self.identity)
        other.attached_units.append(component)
        for source_model in range(self.models.size()):
            faction_prepare_attached_model(self, other, self.models[source_model])
            other.models.append(self.models[source_model])
        other.starting_strenght = other.models.size()
        self.models.clear()

    # Success against any Leadership characteristic uses the lowest threshold
    # (Leadership rolls p.9, procedural A7). Empty units cannot roll.
    fun get_leadership() -> Int:
        if self.models.empty():
            return 0
        let best_leadership = self.models[0].effective_leadership()
        let i = 1
        while i != self.models.size():
            best_leadership = min(best_leadership, self.models[i].effective_leadership())
            i = i + 1

        return best_leadership
        
    # A leadership roll succeeds at or above any characteristic (p.9).
    # Callers supply the complete 2D6 total, not just the first die.
    fun leadership_roll_succeeds(Int total) -> Bool:
        return !self.empty() and total >= self.get_leadership()

    # Shock applies to every model without duplicating a status that could
    # drift from its unit; new/revived members inherit the unit's shock (p.9).
    fun model_is_battle_shocked(Int model) -> Bool:
        return model >= 0 and model < self.models.size() and self.battle_socked

    # '-' Objective Control contributes nothing while shocked (p.9).
    # Objective aggregation, marker geometry and securing remain task 8.
    fun model_objective_control(Int model) -> Int:
        assert(model >= 0 and model < self.models.size(), "invalid control model")
        if self.battle_socked or !self.models[model].is_alive():
            return 0
        return self.models[model].effective_objective_control()

    # Generic unit gates (pp.9/34–35/57–58), including every shooting type's
    # phase-local after-shooting ban. Board checks engagement/membership.
    fun allows_action_start() -> Bool:
        return !self.battle_socked and !self.has_keyword(Keyword::aircraft) and !self.has_keyword(Keyword::fortification) and (!self.history.advanced_this_turn or self.history.selected_move_allows_action) and (!self.history.fell_back_this_turn or self.history.selected_move_allows_action) and !self.history.action_started and !self.history.shot_this_phase

    # p.58: a non-exempt move/departure interrupts every unresolved action,
    # including one started in an earlier turn. Mission effects remain separate.
    fun interrupt_actions():
        for i in range(self.history.action_records.size()):
            if !self.history.action_records[i].resolved:
                self.history.action_records[i].failed = true
        if self.history.action_pending:
            self.history.action_failed = true

    # An already started action cannot complete while shocked (p.9).
    # Recovery removes this prohibition, not any other completion condition.
    fun allows_action_completion() -> Bool:
        return !self.battle_socked

    # One exit cleans up the owning temporary, including presence-only rules (p.78).
    fun has_temporary_wepon_rule(WeaponRuleKind rule) -> Bool:
        let temp_rules = self.get_temporary_weapon_rules()
        let found = false
        for i in range(temp_rules.size()):
            found = found or temp_rules[i].kind == rule
        return found

    # Compare doubled counts without rounding odd starting strengths (p.86).
    # Strict below-half is distinct from Command phase at-or-below eligibility.
    fun is_below_half_strenght() -> Bool:
        if live_attachment_strength(self) == 0 or self.starting_strenght.value == 0:
            return false
        if self.starting_strenght.value == 1:
            return self.models[0].wounds_left() * 2 < self.models[0].profile.wounds()
        return live_attachment_strength(self) * 2 < self.starting_strenght.value

    # Command rolls include exactly half-strength (p.30); one-model units use
    # remaining wounds, combined units retain their original model count (p.86).
    fun is_at_or_below_half_strength() -> Bool:
        if live_attachment_strength(self) == 0 or self.starting_strenght.value == 0:
            return false
        if self.starting_strenght.value == 1:
            return self.models[0].wounds_left() * 2 <= self.models[0].profile.wounds()
        return live_attachment_strength(self) * 2 <= self.starting_strenght.value

    fun get_temporary_weapon_parameter(WeaponRuleKind rule) -> Int: 
        let temp_rules = self.get_temporary_weapon_rules()
        let i = 0
        while i != temp_rules.size():
            if temp_rules[i].kind == rule:
                return temp_rules[i].parameter.value
            i = i + 1
        return 0

    fun max_weapon_parameter(Weapon w, WeaponRuleKind kind) -> Int:
        return max(w.get_rule_parameter(kind), self.get_temporary_weapon_parameter(kind)) 

    # Typed unit rules retain p67 conferral; intrinsic per-model all-member
    # checks require live bearers and do not pass vacuously (p.87).
    fun all_have_ability(AbilityKind kind) -> Bool:
        if faction_unit_grants_ability(self, kind):
            return true
        if scoped_unit_ability(self, kind):
            return true
        let alive = false
        let all_have = true
        for i in range(self.models.size()):
            if self.models[i].is_alive():
                alive = true
                all_have = all_have and (self.models[i].has_ability(kind) or faction_model_grants_ability(self, self.models[i], kind))
        return alive and all_have

    fun all_have_keyword(Keyword kind) -> Bool:
        let i = 0
        while i != self.models.size():
            if !self.models[i].has_keyword(kind):
                return false
            i = i + 1
        return true

    fun has_keyword(Keyword kind) -> Bool:
        let i = 0
        while i != self.models.size():
            if self.models[i].has_keyword(kind):
                return true
            i = i + 1
        return false

    # Typed unit-scope rules follow their source component until its last
    # member dies; attack destruction retains them through all attacks (p.67).
    fun has_ability(AbilityKind kind) -> Bool:
        if faction_unit_grants_ability(self, kind):
            return true
        if scoped_unit_ability(self, kind):
            return true
        let i = 0
        while i != self.models.size():
            if model_confers_attached_abilities(self.models[i]) and (self.models[i].has_ability(kind) or faction_model_grants_ability(self, self.models[i], kind)):
                return true 
            i = i + 1
        return false

    # Bodyguard-only highest battlefield T while any bodyguard is present;
    # otherwise the remaining Leaders/Supports' maximum (p.66/05.02.01).
    # Retained models remain physically on the battlefield until removal.
    fun get_unit_toughtness() -> Int:
        let maximum_toughness = 0
        let bodyguard_toughness = 0
        let bodyguard_present = false
        for model_index in range(self.models.size()):
            if !self.models[model_index].off_battlefield:
                maximum_toughness = max(maximum_toughness, self.models[model_index].effective_toughness())
                if self.models[model_index].original_unit == self.identity:
                    bodyguard_present = true
                    bodyguard_toughness = max(bodyguard_toughness, self.models[model_index].effective_toughness())
        if !self.attached_units.empty() and bodyguard_present:
            return bodyguard_toughness
        return maximum_toughness

    fun translate(Int x, Int y):
        let v : Vector2D
        v.x = x
        v.y = y
        self.translate(v)


    fun move_to(BoardPosition new_position):
        if self.models.size() == 0:
            return
        let v = new_position.as_vector() - self.models[0].position.as_vector()
        self.translate(v)

    # Translate a candidate as a rigid formation without bounded-coordinate
    # clamping. Failure preserves all models/history (battlefield edge p.12).
    fun try_translate(Vector2D v) -> Bool:
        let candidate = self
        let valid = candidate.apply_translation(v)
        if valid:
            self = candidate
        return valid

    # Work on the caller's staged unit so failed edge checks are discarded
    # (p.12). Keep owning copies in single-exit wrappers for RLC 0.4.13 cleanup.
    fun apply_translation(Vector2D v) -> Bool:
        let i = 0
        while i < self.models.size():
            ref model = self[i]
            let old = model.geometry_position()
            let x = old.x.value + v.x * MICROMETRES_PER_INCH
            let y = old.y.value + v.y * MICROMETRES_PER_INCH
            let radius = model.base_radius_micrometres()
            if model.geometry.unsupported_footprint or float(x) < radius or float(y) < radius or float(x) + radius > float(BOARD_WIDTH * MICROMETRES_PER_INCH) or float(y) + radius > float(BOARD_HEIGHT * MICROMETRES_PER_INCH):
                return false
            model.set_geometry_position(geometry_point(x, y, old.z.value))
            model.history.record_movement_segment(v.x, v.y, 0)
            i = i + 1
        return true

    # Legacy fixture/charge relocation delegates to the checked translation;
    # ordinary movement uses board-aware path validation (p.12; charge task 13).
    fun translate(Vector2D v):
        self.try_translate(v)

    fun distance(BoardPosition position) -> Float:
        return self.distance(position.as_vector()) 

    # Unit range uses the closest pair, including models beyond target index
    # zero (p.9; user's clarified Within/Closest definitions).
    fun distance(Unit unit) -> Float:
        let shortest = 100.0
        let i = 0
        while i < unit.models.size():
            if !self.models.empty():
                let distance = self.distance(unit.models[i])
                if distance < shortest:
                    shortest = distance
            i = i + 1
        return shortest

    # Any engaged model pair engages both units (pp.14–15).
    fun is_engaged_with(Unit other) -> Bool:
        let i = 0
        while i < self.models.size():
            let j = 0
            while j < other.models.size():
                if self.models[i].is_alive() and other.models[j].is_alive() and self.models[i].is_engaged_with(other.models[j]):
                    return true
                j = j + 1
            i = i + 1
        return false

    # Every member needs a neighbour within 2/5 inches and must be within 9/5
    # of every other member. A connected chain alone is insufficient (p.14).
    fun is_coherent() -> Bool:
        let live = 0
        for model in range(self.models.size()):
            if self.models[model].is_alive():
                live = live + 1
        let i = 0
        while i < self.models.size():
            if !self.models[i].is_alive():
                i = i + 1
                continue
            let has_neighbour = live == 1
            let j = 0
            while j < self.models.size():
                if i != j and self.models[j].is_alive():
                    let horizontal = self.models[i].horizontal_distance_micrometres(self.models[j])
                    let vertical = self.models[i].vertical_distance_micrometres(self.models[j])
                    if !within_geometry_limits(horizontal, vertical, 9, 5):
                        return false
                    if within_geometry_limits(horizontal, vertical, 2, 5):
                        has_neighbour = true
                j = j + 1
            if !has_neighbour:
                return false
            i = i + 1
        # User ruling2026-10-15: require one connected group in addition
        # to the printed neighbour/maximum-distance limits (core p14).
        # Connectivity uses that same2in horizontal/5in vertical relation.
        let reached : Bool[MAX_UNIT_MODELS]
        let reached_count = 0
        for seed_index in range(self.models.size()):
            if self.models[seed_index].is_alive():
                reached[seed_index] = true
                reached_count = 1
                break
        let changed = true
        while changed:
            changed = false
            for from_index in range(self.models.size()):
                if !reached[from_index]:
                    continue
                for to_index in range(self.models.size()):
                    if !reached[to_index] and self.models[to_index].is_alive() and within_geometry_limits(self.models[from_index].horizontal_distance_micrometres(self.models[to_index]), self.models[from_index].vertical_distance_micrometres(self.models[to_index]), 2, 5):
                        reached[to_index] = true
                        reached_count = reached_count + 1
                        changed = true
        return reached_count == live

    fun distance(Model model) -> Float:
        assert(self.models.size() != 0, "calculanting distance to empty unit")
        let shortest = self.models[0].distance(model)
        let i = 1
        while i != self.models.size():
            if shortest > self.models[i].distance(model):
                shortest = self.models[i].distance(model)
            i = i + 1
        return shortest 

    # Choose the closest base pair, including either first model (p.9 and
    # user's Closest definition); keep the legacy quad direction for callers.
    fun get_shortest_vector_to(Unit other) -> Vector2D:
        let their_nearest_model = 0
        let our_nearest_model = 0
        let shortest_lenght = 100.0
        assert(!self.models.empty() and !other.models.empty(), "closest vector requires populated units")
        let i = 0
        while i != self.models.size():
            let j = 0
            while j != other.models.size():
                if shortest_lenght > self[i].distance(other[j]):
                    shortest_lenght = self[i].distance(other[j])
                    their_nearest_model = j
                    our_nearest_model = i
                j = j + 1
            i = i + 1
        return other.models[their_nearest_model].position.as_vector() - self.models[our_nearest_model].position.as_vector()

    fun get_shortest_vector_to(Model model) -> Vector2D:
        let nearest_model = self.get_nearest_model_index(model)
        return model.position.as_vector() - self.models[nearest_model].position.as_vector()

    fun get_nearest_model_index(Model model) -> Int:
        assert(self.models.size() != 0, "calculanting distance to empty unit")
        let nearest_model = 0 
        let i = 1
        while i != self.models.size():
            if self.models[nearest_model].distance(model) > self.models[i].distance(model):
                nearest_model = i
            i = i + 1
        return nearest_model

    # Point ranges measure the nearest base, rather than its centre (p.9 and
    # user's Within definition). Point elevation is the battlefield ground.
    fun distance(Vector2D position) -> Float:
        assert(self.models.size() != 0, "calculanting distance to empty unit")
        let nearest = 1000000000.0
        let i = 0
        while i < self.models.size():
            if !self.models[i].geometry.unsupported_footprint:
                let horizontal = (self.models[i].position.as_vector() - position).length() - self.models[i].base_size_in_inches() / 2.0
                if horizontal < 0.0:
                    horizontal = 0.0
                let vertical = float(self.models[i].geometry.elevation.value)
                let distance = sqrt(horizontal * horizontal + vertical * vertical)
                if distance < nearest:
                    nearest = distance
            i = i + 1
        return nearest

    fun get(Int model_id) -> ref Model:
        return self.models[model_id]

    fun get(ModelID model_id) -> ref Model:
        return self.models[model_id.get()]

    # Try a quad-grid formation with whole-cell spacing large enough for every
    # base. Diagonal staggering is allowed only when bases fit (pp.12/14).
    # This preset is fixture/UI convenience, not a required tabletop formation.
    fun try_arrange_columns(BoardPosition anchor, Int columns) -> Bool:
        let candidate = self
        let valid = candidate.arrange_candidate_columns(anchor, columns)
        if valid:
            self = candidate
        return valid

    # Populate a staged formation; only the wrapper commits a valid complete
    # candidate (pp.12/14). RLC 0.4.13 owning locals require a single exit.
    fun arrange_candidate_columns(BoardPosition anchor, Int columns) -> Bool:
        if columns <= 0 or self.empty():
            return false
        # Full-base clearance depends on the two largest radii, not two
        # copies of a unique Leader's radius. Overspacing small members can
        # hide coherent mixed-base formations (pp.12/14; no attachment grant).
        let radius = 0.0
        let second_radius = 0.0
        let i = 0
        while i < self.models.size():
            if self[i].geometry.unsupported_footprint:
                return false
            let model_radius = self[i].base_radius_micrometres()
            if model_radius >= radius:
                second_radius = radius
                radius = model_radius
            else:
                if model_radius > second_radius:
                    second_radius = model_radius
            i = i + 1
        let clearance = radius + second_radius
        let spacing = 1
        while float(spacing * MICROMETRES_PER_INCH) < clearance:
            spacing = spacing + 1
        let stagger = spacing == 2 and clearance <= sqrt(2.0) * float(MICROMETRES_PER_INCH)
        # Adjacent columns need their actual pair's clearance. Using the
        # largest pair for every column can prevent a legal mixed-base row
        # from fitting between already deployed units (pp.12/14).
        let row_y = anchor.y.value
        let row_max_radius = 0.0
        let previous_row_radius = 0.0
        let row_x = anchor.x.value
        i = 0
        while i < self.models.size():
            let row = i / columns
            let column = i % columns
            if column == 0:
                previous_row_radius = row_max_radius
                row_max_radius = 0.0
                let end = min(self.models.size(), i + columns)
                let model = i
                while model < end:
                    if self[model].base_radius_micrometres() > row_max_radius:
                        row_max_radius = self[model].base_radius_micrometres()
                    model = model + 1
                if row > 0:
                    let height = 1
                    while float(height * MICROMETRES_PER_INCH) < previous_row_radius + row_max_radius:
                        height = height + 1
                    row_y = row_y + height
                row_x = anchor.x.value
            else:
                let width = 1
                while float(width * MICROMETRES_PER_INCH) < self[i - 1].base_radius_micrometres() + self[i].base_radius_micrometres():
                    width = width + 1
                row_x = row_x + width
            let x = row_x
            let y = row_y
            if stagger:
                x = x + row % 2
                y = anchor.y.value + row
            if float(x * MICROMETRES_PER_INCH) < self[i].base_radius_micrometres() or float(y * MICROMETRES_PER_INCH) < self[i].base_radius_micrometres() or float(x * MICROMETRES_PER_INCH) + self[i].base_radius_micrometres() > float(BOARD_WIDTH * MICROMETRES_PER_INCH) or float(y * MICROMETRES_PER_INCH) + self[i].base_radius_micrometres() > float(BOARD_HEIGHT * MICROMETRES_PER_INCH):
                return false
            self[i].set_geometry_position(geometry_point(x * MICROMETRES_PER_INCH, y * MICROMETRES_PER_INCH, 0))
            i = i + 1
        if !self.is_coherent():
            return false
        return true

    # Search compact whole-quad presets without clamping or partially moving
    # models. Failure preserves the original unit (setup/move rollback pp.12/14).
    fun try_arrange_at(BoardPosition anchor) -> Bool:
        if self.empty():
            return false
        let middle = int(sqrt(float(self.models.size())))
        let i = 0
        while i < self.models.size() * 2:
            let columns = middle
            if i % 2 == 1:
                columns = middle + (i + 1) / 2
            else:
                columns = middle - i / 2
            if columns > 0 and columns <= self.models.size() and self.try_arrange_columns(anchor, columns):
                return true
            i = i + 1
        return false

    # Existing fixture callers retain the coarse anchor; failure leaves the
    # formation unchanged rather than silently overlapping/clamping (pp.12/14).
    fun arrange():
        if !self.empty():
            self.try_arrange_at(self[0].position)

    # Remove/archive the allocated model when wounds reach its characteristic;
    # excess normal damage does not spill (damage sequence p.19; reference 05.04).
    fun damage(Int target_model_id, Int damage) -> Bool:
        ref target_model = self.models[target_model_id]
        target_model.suffered_wounds = target_model.suffered_wounds + damage 
        if target_model.suffered_wounds >= target_model.profile.wounds(): 
            self.remove_model(target_model_id)
            return true
        return false

    # Retain a deferred destroyed model until cleanup, otherwise archive it now
    # (damage/destruction pp.19/87). Ability-specific timing needs supplied data.
    fun damage(Int target_model_id, Int damage, Bool fight_on_death) -> Bool:
        ref target_model = self.models[target_model_id]
        target_model.suffered_wounds = target_model.suffered_wounds + damage 
        if target_model.suffered_wounds >= target_model.profile.wounds(): 
            if fight_on_death:
                target_model.state = ModelState::fight_on_death
            else:
                self.remove_model(target_model_id)
            return true
        return false

    fun damage(ModelID target_model_id) -> Bool:
        return self.damage(target_model_id.get(), 1)

    # Legacy raw storage helper for simple no-prevention fixtures. Production
    # rules use resolve_mortal_wounds for choices/FNP/triggers (pp.24/81/87).
    fun deal_mortal_wound_damage(Int wounds):
        assert(wounds >= 0, "negative mortal damage")
        if self.empty():
            return
        for i in range(wounds):
            self.damage(0, 1)
            if self.models.size() == 0:
                return
        


using UnitVector = CheckedVector<Unit, MAX_UNIT_COUNT>


# Typed data bridge keeps raw bounded keyword codes out of game consumers;
# construction follows appendix02.05.01, with no faction grant inferred.
fun append_keyword_condition(KeywordPredicate predicate, KeywordClause clause, Keyword keyword) -> Bool:
    return predicate.append(clause, keyword.value, max(keyword))

# A unit has the union of its constituent models' keywords; a model has only
# its own. T is explicitly Unit or Model at the wrappers below (appendix02.05.01).
# Empty clauses impose no condition; an ANY clause needs at least one match.
fun<T> matches_keyword_predicate(T subject, KeywordPredicate predicate) -> Bool:
    let keyword : Keyword
    if !predicate.valid(max(keyword)):
        return false
    let has_any = false
    let matches_any = false
    for term in range(predicate.size()):
        keyword.value = predicate.keywords[term].value
        let present = false
        if subject is Unit:
            present = subject.has_keyword(keyword)
        if subject is Model:
            present = subject.has_keyword(keyword)
        if predicate.clause(term) == KeywordClause::all and !present:
            return false
        if predicate.clause(term) == KeywordClause::none and present:
            return false
        if predicate.clause(term) == KeywordClause::any:
            has_any = true
            matches_any = matches_any or present
    return !has_any or matches_any

# Use for unit conditions, including mixed/attached keywords (appendix02.05.01).
fun unit_matches_keywords(Unit unit, KeywordPredicate predicate) -> Bool:
    return matches_keyword_predicate(unit, predicate)

# Use for model conditions; do not inherit a different bearer's keywords
# merely because both models share a unit (appendix02.05.01).
fun model_matches_keywords(Model model, KeywordPredicate predicate) -> Bool:
    return matches_keyword_predicate(model, predicate)

# Appendix02.02.01: bearer WS/BS modifies every equipped weapon; specific
# weapon grants affect only their slot. Firing Deck uses the carrier's grants,
# not an unrelated equipped slot with the same index (24.14 p.81).
fun model_weapon_modifiers(Model model, Int slot, ModifiedCharacteristic kind, Bool borrowed, WeaponCode name, WeaponCode profile_name) -> RuleModifiers:
    assert(valid_characteristic_modifiers(model.characteristic_modifiers), "invalid weapon characteristic modifiers")
    let result : RuleModifiers
    for i in range(model.characteristic_modifiers.size()):
        ref entry = model.characteristic_modifiers[i]
        if entry.characteristic.value == kind.value and weapon_modifier_slot_matches(model, entry, slot, borrowed) and (entry.weapon_name.value == 0 or entry.weapon_name == name) and (entry.profile_name.value == 0 or entry.profile_name == profile_name):
            result.append(entry.modifier)
    return result

fun make_tantus() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::librarian_tantus
    model.abilities.append(AbilityKind::deep_strike)
    model.abilities.append(AbilityKind::leader)
    model.abilities.append(AbilityKind::oath_of_moment)
    model.abilities.append(AbilityKind::veil_of_time)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::imperium)
    model.keywords.append(Keyword::terminator)
    model.keywords.append(Keyword::psyker)
    model.keywords.append(Keyword::octavius)
    model.keywords.append(Keyword::librarian_tantus)
    model.weapons.append(equipped_weapon(Weapon::librarian_storm_bolter))
    model.weapons.append(equipped_weapon(Weapon::smite_witchfire))
    model.weapons.append(equipped_weapon(Weapon::smite_focused_witchfire))
    model.weapons.append(equipped_weapon(Weapon::force_weapon))
    profile.name = "librarian tantus"s
    profile.models.append(model)
    return profile

fun make_infernus_squad() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::infernus_squad
    model.abilities.append(AbilityKind::oath_of_moment)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::imperium)
    model.keywords.append(Keyword::tacticus)
    model.keywords.append(Keyword::infernus_squad)
    model.weapons.append(equipped_weapon(Weapon::bolt_pistol))
    model.weapons.append(equipped_weapon(Weapon::pyreblaster))
    model.weapons.append(equipped_weapon(Weapon::close_combact_weapon))
    profile.name = "infernus squad"s
    profile.models.append(model)
    profile.models.append(model)
    profile.models.append(model)
    profile.models.append(model)
    profile.models.append(model)
    return profile

fun make_terminator_squad() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::terminator_squad
    model.abilities.append(AbilityKind::oath_of_moment)
    model.abilities.append(AbilityKind::fury_of_the_first)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::imperium)
    model.keywords.append(Keyword::terminator)
    model.keywords.append(Keyword::terminator_squad)
    model.weapons.append(equipped_weapon(Weapon::terminator_storm_bolter))
    model.weapons.append(equipped_weapon(Weapon::terminator_power_fist))
    profile.name = "terminator squad"s
    profile.models.append(model)
    profile.models.append(model)
    profile.models.append(model)

    model.weapons.clear()
    model.weapons.append(equipped_weapon(Weapon::terminator_storm_bolter))
    model.weapons.append(equipped_weapon(Weapon::terminator_power_weapon))
    profile.models.append(model)

    model.weapons.clear()
    model.weapons.append(equipped_weapon(Weapon::terminator_power_fist))
    model.weapons.append(equipped_weapon(Weapon::assault_cannon))
    profile.models.append(model)

    return profile

fun make_octavius() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::captain_octavius
    model.abilities.append(AbilityKind::deep_strike)
    model.abilities.append(AbilityKind::leader)
    model.abilities.append(AbilityKind::oath_of_moment)
    model.abilities.append(AbilityKind::unstoppable_valour)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::imperium)
    model.keywords.append(Keyword::terminator)
    model.keywords.append(Keyword::captain)
    model.keywords.append(Keyword::octavius)
    model.keywords.append(Keyword::adeptus_astartes)
    model.weapons.append(equipped_weapon(Weapon::captain_storm_bolter))
    model.weapons.append(equipped_weapon(Weapon::relic_weapon))
    profile.name = "captain octavious"s
    profile.models.append(model)
    return profile

fun make_death_shadow() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::death_shadow
    model.abilities.append(AbilityKind::infiltrators)
    model.abilities.append(AbilityKind::lone_operative)
    model.abilities.append(AbilityKind::stealth)
    model.abilities.append(AbilityKind::shadow_in_the_warp)
    model.abilities.append(AbilityKind::neural_disruption)
    model.abilities.append(AbilityKind::psychological_saboteur)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::great_devourer)
    model.keywords.append(Keyword::death_shadow)
    model.keywords.append(Keyword::vanguard_invader)
    model.keywords.append(Keyword::neurolictor)
    model.keywords.append(Keyword::tyranids)
    model.weapons.append(equipped_weapon(Weapon::death_shadow_claws_and_talons))
    profile.name = "death's shadow"s
    profile.models.append(model)
    return profile

fun make_lictor() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::lictor
    model.abilities.append(AbilityKind::infiltrators)
    model.abilities.append(AbilityKind::lone_operative)
    model.abilities.append(AbilityKind::stealth)
    model.abilities.append(AbilityKind::fight_first)
    model.abilities.append(AbilityKind::feeder_tendrils)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::great_devourer)
    model.keywords.append(Keyword::lictor)
    model.keywords.append(Keyword::vanguard_invader)
    model.keywords.append(Keyword::tyranids)
    model.weapons.append(equipped_weapon(Weapon::lictor_claws_and_talons))
    profile.name = "lictor"s
    profile.models.append(model)
    return profile

fun make_von_ryan_leaper() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::von_ryan_leaper
    model.abilities.append(AbilityKind::infiltrators)
    model.abilities.append(AbilityKind::stealth)
    model.abilities.append(AbilityKind::fight_first)
    model.abilities.append(AbilityKind::pouncing_leap)
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::von_ryan_leaper)
    model.keywords.append(Keyword::great_devourer)
    model.keywords.append(Keyword::vanguard_invader)
    model.keywords.append(Keyword::tyranids)
    model.weapons.append(equipped_weapon(Weapon::leapers_talon))
    profile.name = "von ryan's leaper"s
    profile.models.append(model)
    profile.models.append(model)
    profile.models.append(model)
    return profile

fun make_aranis_zarkan() -> Unit:
    let profile : Unit 
    let model : Model
    model.profile = Profile::aranis_zarkan
    model.abilities.append(AbilityKind::dark_pacts)
    model.abilities.append(AbilityKind::leader)

    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::character)
    model.keywords.append(Keyword::psyker)
    model.keywords.append(Keyword::chaos)
    model.keywords.append(Keyword::master_of_possession)
    model.keywords.append(Keyword::aranis_zarkan)
    model.weapons.append(equipped_weapon(Weapon::rite_of_possession))
    model.weapons.append(equipped_weapon(Weapon::rite_of_possession_focused))
    model.weapons.append(equipped_weapon(Weapon::staff_of_possession))
    profile.name = "aranis zarkan"s
    profile.models.append(model)
    return profile

fun make_possessed() -> Unit:
    let profile : Unit 
    let model : Model
    
    model.profile = Profile::possessed
    
    model.abilities.append(AbilityKind::dark_pacts)
    
    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::chaos)
    model.keywords.append(Keyword::daemon)      
    model.keywords.append(Keyword::possessed)   

    model.weapons.append(equipped_weapon(Weapon::hideous_mutations))
    
    profile.name = "Possessed"s
    for i in range(5):
        profile.models.append(model)
    return profile

fun make_cultist_mob() -> Unit:
    let profile : Unit
    let champion : Model
    champion.profile = Profile::cultist_mob
    champion.abilities.append(AbilityKind::dark_pacts)
    champion.keywords.append(Keyword::infantry)
    champion.keywords.append(Keyword::chaos)
    champion.keywords.append(Keyword::damned)
    champion.keywords.append(Keyword::cultist_mob) 
    champion.weapons.append(equipped_weapon(Weapon::cultist_bolt_pistol))
    champion.weapons.append(equipped_weapon(Weapon::brutal_assault_weapon))

    let i = 0
    while i != 9:
        let cultist : Model
        cultist.profile = Profile::cultist_mob
        cultist.abilities.append(AbilityKind::dark_pacts)
        cultist.keywords.append(Keyword::infantry)
        cultist.keywords.append(Keyword::chaos)
        cultist.keywords.append(Keyword::damned)
        cultist.keywords.append(Keyword::cultist_mob)
        cultist.weapons.append(equipped_weapon(Weapon::cultist_autopistol))
        cultist.weapons.append(equipped_weapon(Weapon::brutal_assault_weapon))
        profile.models.append(cultist)
        i = i + 1

    profile.models.append(champion)

    profile.name = "Cultist Mob"s
    return profile

fun make_legionaries() -> Unit:
    let profile : Unit
    profile.name = "Legionaries"s

    # Prepare a single Model object with shared stats, abilities, and keywords
    let model : Model
    model.profile = Profile::legionaries
    model.abilities.append(AbilityKind::dark_pacts)
    # model.abilities.append(AbilityKind::veterans_of_the_long_war)  # if you’ve defined it

    model.keywords.append(Keyword::infantry)
    model.keywords.append(Keyword::chaos)
    model.keywords.append(Keyword::damned)
    model.keywords.append(Keyword::legionaries)
    # model.keywords.append(Keyword::battleline)  # if you’ve defined it

    # 1) ASPIRING CHAMPION
    model.weapons.clear()
    model.weapons.append(equipped_weapon(Weapon::plasma_pistol_standard))
    model.weapons.append(equipped_weapon(Weapon::plasma_pistol_supercharge))
    link_weapon_profile(model, 1, 0)
    model.weapons.append(equipped_weapon(Weapon::accursed_weapon))
    profile.models.append(model)  # This copies champion’s state into the unit

    # 2) LEGIONARY with Meltagun
    model.weapons.clear()
    model.weapons.append(equipped_weapon(Weapon::bolt_pistol))
    model.weapons.append(equipped_weapon(Weapon::meltagun))
    model.weapons.append(equipped_weapon(Weapon::close_combat_weapon))
    profile.models.append(model)  # Copies meltagun loadout

    # 3) LEGIONARY with Heavy Bolter
    model.weapons.clear()
    model.weapons.append(equipped_weapon(Weapon::bolt_pistol))
    model.weapons.append(equipped_weapon(Weapon::heavy_bolter))
    model.weapons.append(equipped_weapon(Weapon::close_combat_weapon))
    profile.models.append(model)  # Copies heavy bolter loadout

    # 4) 7 LEGIONARIES with Boltgun
    for i in range(7):
        model.weapons.clear()
        model.weapons.append(equipped_weapon(Weapon::bolt_pistol))
        model.weapons.append(equipped_weapon(Weapon::boltgun))
        model.weapons.append(equipped_weapon(Weapon::close_combat_weapon))
        profile.models.append(model)  # Copies boltgun loadout each time

    return profile

fun make_beastboss_morgrim() -> Unit:
    let boss_unit : Unit
    let boss_model : Model
    
    # Use the pre-defined profile for Beastboss Morgrim
    boss_model.profile = Profile::beastboss_morgrim
    boss_model.abilities.append(AbilityKind::leader)
    boss_model.abilities.append(AbilityKind::beast_snagga)
    boss_model.abilities.append(AbilityKind::warboss)
    boss_model.abilities.append(AbilityKind::beastboss)
    boss_model.abilities.append(AbilityKind::morgrim)
    
    boss_model.keywords.append(Keyword::infantry)
    boss_model.keywords.append(Keyword::character)
    boss_model.keywords.append(Keyword::beastboss)

    boss_model.weapons.append(equipped_weapon(Weapon::beat_boss_shoota))

    boss_model.weapons.append(equipped_weapon(Weapon::beast_snagga_klaw))

    boss_model.weapons.append(equipped_weapon(Weapon::beastchoppa))

    boss_unit.models.append(boss_model)
    boss_unit.name = "Beastboss Morgrim"s
    return boss_unit

fun make_beast_snagga_boyz() -> Unit:
    let unit : Unit
    unit.name = "Beast Snagga Boyz"s
    let nob_model : Model
    nob_model.profile = Profile::beast_snagga_nob
    nob_model.abilities.append(AbilityKind::beast_snagga)
    nob_model.keywords.append(Keyword::infantry)
    nob_model.keywords.append(Keyword::mob)
    nob_model.keywords.append(Keyword::monster_hunters)
    nob_model.weapons.append(equipped_weapon(Weapon::slugga))
    nob_model.weapons.append(equipped_weapon(Weapon::power_snappa))
    unit.models.append(nob_model)
    let thumpgun_boy : Model
    thumpgun_boy.profile = Profile::beast_snagga_boy
    thumpgun_boy.abilities.append(AbilityKind::beast_snagga)
    thumpgun_boy.keywords.append(Keyword::infantry)
    thumpgun_boy.keywords.append(Keyword::mob)
    thumpgun_boy.keywords.append(Keyword::monster_hunters)

    thumpgun_boy.weapons.append(equipped_weapon(Weapon::thump_gun))
    thumpgun_boy.weapons.append(equipped_weapon(Weapon::close_combat_weapon))

    unit.models.append(thumpgun_boy)

    let boy : Model
    boy.profile = Profile::beast_snagga_boy
    boy.abilities.append(AbilityKind::beast_snagga)
    boy.keywords.append(Keyword::infantry)
    boy.keywords.append(Keyword::mob)
    boy.keywords.append(Keyword::monster_hunters)

    boy.weapons.append(equipped_weapon(Weapon::slugga))
    boy.weapons.append(equipped_weapon(Weapon::choppa))

    for i in range(8):
        unit.models.append(boy)

    return unit

fun make_squighog_boyz() -> Unit:
    let unit : Unit
    unit.name = "Squighog Boyz"s

    let nob_model : Model
    nob_model.profile = Profile::nob_on_smasha_squig
    nob_model.abilities.append(AbilityKind::beast_snagga)
    nob_model.keywords.append(Keyword::mounted)
    nob_model.keywords.append(Keyword::beast_snagga)
    nob_model.keywords.append(Keyword::squighog_boyz)
    
    # Weapons: slugga, big choppa, squighog_jaws
    nob_model.weapons.append(equipped_weapon(Weapon::slugga))
    nob_model.weapons.append(equipped_weapon(Weapon::big_choppa))
    nob_model.weapons.append(equipped_weapon(Weapon::squighog_jaws))
    
    unit.models.append(nob_model)

    # 2) 3 standard Squighog Boyz
    for i in range(3):
        let hog_boy : Model
        hog_boy.profile = Profile::squighog_boyz
        hog_boy.abilities.append(AbilityKind::beast_snagga)
        hog_boy.keywords.append(Keyword::mounted)
        hog_boy.keywords.append(Keyword::beast_snagga)
        hog_boy.keywords.append(Keyword::squighog_boyz)

        # Weapons: saddlegit_weapons, stikka_ranged, squighog_jaws
        hog_boy.weapons.append(equipped_weapon(Weapon::saddlegit_weapons))
        hog_boy.weapons.append(equipped_weapon(Weapon::stikka_ranged))
        hog_boy.weapons.append(equipped_weapon(Weapon::squighog_jaws))

        unit.models.append(hog_boy)

    return unit

fun make_tristrean() -> Unit:
    let tristraen_unit : Unit

    # Create the single model for Tristraen
    let tristraen_model : Model
    tristraen_model.profile = Profile::tristraen

    # Abilities (Martial Ka’tah is not yet defined as an AbilityKind, so we omit it here)
    # Add known abilities if you wish, or omit if they are not enumerated:
    # tristraen_model.abilities.append(AbilityKind::some_ability) 

    # Keywords
    tristraen_model.keywords.append(Keyword::infantry)
    tristraen_model.keywords.append(Keyword::character)
    tristraen_model.keywords.append(Keyword::imperium)
    tristraen_model.keywords.append(Keyword::blade_champion)
    tristraen_model.keywords.append(Keyword::tristraen)
    # (No enumerated keyword for “adeptus_custodes” currently, so we skip it.)

    # Melee Weapons
    tristraen_model.weapons.append(equipped_weapon(Weapon::vaultswords_behemor))
    tristraen_model.weapons.append(equipped_weapon(Weapon::vaultswords_hurricanus))
    tristraen_model.weapons.append(equipped_weapon(Weapon::vaultswords_victus))

    # Finish building the unit
    tristraen_unit.name = "Tristraen"s
    tristraen_unit.models.append(tristraen_model)

    return tristraen_unit

fun make_custodian_guard() -> Unit:
    let guard_unit : Unit
    guard_unit.name = "Custodian Guard"s

    # Each Guard model is Profile::custodian_guard (T=6, W=3, etc.).
    # Praesidium Shield adds +1 to Wounds (to 4), but there is no direct code mechanism to
    # modify an enum-based Profile. In a complete implementation, you might add a new Profile
    # or some special logic for the shield. For now, we’ll just note it here.

    let guard_model : Model
    guard_model.profile = Profile::custodian_guard

    # Add relevant Keywords (INFANTRY, IMPERIUM, CUSTODIAN GUARD).
    guard_model.keywords.append(Keyword::infantry)
    guard_model.keywords.append(Keyword::imperium)
    # We do not have a dedicated enum entry for “CUSTODIAN GUARD,” but we can at least note it:
    guard_model.keywords.append(Keyword::custodian_guard)

    # Sentinel Blade (ranged + melee):
    guard_model.weapons.append(equipped_weapon(Weapon::sentinel_blade_ranged))
    guard_model.weapons.append(equipped_weapon(Weapon::sentinel_blade_melee))

    # Make 3 models:
    for i in range(3):
        guard_unit.models.append(guard_model)

    return guard_unit

fun make_custodian_wardens() -> Unit:
    let wardens_unit : Unit
    wardens_unit.name = "Custodian Wardens"s

    # Profile: custodian_wardens (M=6, T=6, Sv=2+, W=3, Ld=6, OC=2, Inv=4+)

    # 1) WARDEN with Castellan Axe
    let warden_with_axe : Model
    warden_with_axe.profile = Profile::custodian_wardens
    warden_with_axe.keywords.append(Keyword::infantry)
    warden_with_axe.keywords.append(Keyword::imperium)
    warden_with_axe.keywords.append(Keyword::custodian_wardens)
    warden_with_axe.weapons.append(equipped_weapon(Weapon::castellan_axe_ranged))
    warden_with_axe.weapons.append(equipped_weapon(Weapon::castellan_axe_melee))

    # 2) WARDEN with Guardian Spear
    let warden_with_spear : Model
    warden_with_spear.profile = Profile::custodian_wardens
    warden_with_spear.keywords.append(Keyword::infantry)
    warden_with_spear.keywords.append(Keyword::imperium)
    warden_with_spear.keywords.append(Keyword::custodian_wardens)
    warden_with_spear.weapons.append(equipped_weapon(Weapon::guardian_spear_ranged))
    warden_with_spear.weapons.append(equipped_weapon(Weapon::guardian_spear_melee))

    # Add them to the unit: 1 with axe, 2 with spear
    wardens_unit.models.append(warden_with_axe)
    wardens_unit.models.append(warden_with_spear)
    wardens_unit.models.append(warden_with_spear)

    return wardens_unit

fun make_allarus_custodians() -> Unit:
    let allarus_unit : Unit
    allarus_unit.name = "Allarus Custodians"s

    # Each Allarus Custodian model:
    let allarus_model : Model
    allarus_model.profile = Profile::allarus_custodians
    allarus_model.keywords.append(Keyword::infantry)
    allarus_model.keywords.append(Keyword::terminator)
    allarus_model.keywords.append(Keyword::imperium)
    allarus_model.keywords.append(Keyword::allarus_custodians)

    # Weapons: balistus grenade launcher + guardian spear (both ranged and melee)
    allarus_model.weapons.append(equipped_weapon(Weapon::balistus_grenade_launcher))
    allarus_model.weapons.append(equipped_weapon(Weapon::guardian_spear_ranged_allarus))
    allarus_model.weapons.append(equipped_weapon(Weapon::guardian_spear_melee_allarus))

    # Add two models
    allarus_unit.models.append(allarus_model)
    allarus_unit.models.append(allarus_model)

    return allarus_unit


fun make_octavious_strike_force(UnitVector out, Bool owner) -> Faction:
    out.append(make_octavius())
    out.back().owned_by_player1 = owner
    out.append(make_tantus())
    out.back().owned_by_player1 = owner
    out.append(make_infernus_squad())
    out.back().owned_by_player1 = owner
    out.append(make_terminator_squad())
    out.back().owned_by_player1 = owner
    return Faction::strike_force_octavius

fun make_insidious_infiltrators(UnitVector out, Bool owner) -> Faction:
    out.append(make_death_shadow())
    out.back().owned_by_player1 = owner
    out.append(make_lictor())
    out.back().owned_by_player1 = owner
    for i in range(3):
        out.append(make_von_ryan_leaper())
        out.back().owned_by_player1 = owner
    return Faction::insidious_infiltrators

# Compatibility: identify this legacy Chaos roster as Chaos, not Tyranids;
# correct dispatch is independent of later supplied datasheets (core p.8).
fun make_zarkan_deamonkin(UnitVector out, Bool owner) -> Faction:
    out.append(make_aranis_zarkan())
    out.back().owned_by_player1 = owner
    out.append(make_possessed())
    out.back().owned_by_player1 = owner
    out.append(make_cultist_mob())
    out.back().owned_by_player1 = owner
    out.append(make_legionaries())
    out.back().owned_by_player1 = owner
    return Faction::zarkan_daemonkin

fun make_tristrean_gilded_blade(UnitVector out, Bool owner) -> Faction:
    # 1) Tristraen
    out.append(make_tristrean())
    out.back().owned_by_player1 = owner

    # 2) Custodian Guard (3 models)
    out.append(make_custodian_guard())
    out.back().owned_by_player1 = owner

    # 3) Custodian Wardens (3 models)
    out.append(make_custodian_wardens())
    out.back().owned_by_player1 = owner

    # 4) Allarus Custodians (2 models)
    out.append(make_allarus_custodians())
    out.back().owned_by_player1 = owner

    return Faction::tristraen_gilded_blade

fun make_master_zacharial() -> Unit:
    let zach_unit : Unit
    
    let zach_model : Model
    zach_model.profile = Profile::master_zacharial

    # Abilities
    zach_model.abilities.append(AbilityKind::oath_of_moment)
    zach_model.abilities.append(AbilityKind::refuse_to_yield)

    # Keywords
    zach_model.keywords.append(Keyword::infantry)
    zach_model.keywords.append(Keyword::character)
    zach_model.keywords.append(Keyword::imperium)
    zach_model.keywords.append(Keyword::gravis)
    zach_model.keywords.append(Keyword::captain)
    zach_model.keywords.append(Keyword::master_zacharial)
    # If you wish to note his Chapter, you can also add:
    # zach_model.keywords.append(Keyword::adeptus_astartes)
    # (No “dark_angels” keyword was enumerated, so we skip it.)

    # Weapons
    zach_model.weapons.append(equipped_weapon(Weapon::boltstorm_gauntlet))
    zach_model.weapons.append(equipped_weapon(Weapon::power_fist_zacharial))
    zach_model.weapons.append(equipped_weapon(Weapon::relic_chainsword))

    zach_unit.name = "Master Zacharial"s
    zach_unit.models.append(zach_model)

    return zach_unit


fun make_intercessor_squad() -> Unit:
    let squad : Unit
    squad.name = "Intercessor Squad"s

    let base_model : Model
    base_model.profile = Profile::intercessor_squad

    # Abilities
    base_model.abilities.append(AbilityKind::oath_of_moment)
    base_model.abilities.append(AbilityKind::patrol_squads)

    # Keywords
    base_model.keywords.append(Keyword::infantry)
    base_model.keywords.append(Keyword::imperium)
    base_model.keywords.append(Keyword::tacticus)
    base_model.keywords.append(Keyword::intercessor_squad)
    # If you wish to add “BATTLELINE” or “DARK_ANGELS,” you would first need to define them
    # in the enum Keyword, similar to:
    #
    #   battleline
    #   dark_angels
    #
    # Then you could append them here.

    # Weapons
    base_model.weapons.append(equipped_weapon(Weapon::bolt_pistol))
    base_model.weapons.append(equipped_weapon(Weapon::bolt_rifle))
    base_model.weapons.append(equipped_weapon(Weapon::close_combat_weapon))

    # Create 10 identical models
    for i in range(10):
        squad.models.append(base_model)

    return squad

fun make_hellblaster_squad() -> Unit:
    let squad : Unit
    squad.name = "Hellblaster Squad"s

    let base_model : Model
    base_model.profile = Profile::hellblaster_squad

    # Abilities
    base_model.abilities.append(AbilityKind::oath_of_moment)

    # Keywords
    base_model.keywords.append(Keyword::infantry)
    base_model.keywords.append(Keyword::imperium)
    base_model.keywords.append(Keyword::tacticus)
    base_model.keywords.append(Keyword::hellblaster_squad)
    # If you wish to add “ADEPTUS_ASTARTES” or “DARK_ANGELS,” define them similarly in enum Keyword first, then append.

    # Weapons
    base_model.weapons.append(equipped_weapon(Weapon::bolt_pistol))
    base_model.weapons.append(equipped_weapon(Weapon::plasma_incinerator_standard))
    base_model.weapons.append(equipped_weapon(Weapon::plasma_incinerator_supercharge))
    link_weapon_profile(base_model, 2, 1)
    base_model.weapons.append(equipped_weapon(Weapon::close_combat_weapon))

    # 5 identical models
    for i in range(5):
        squad.models.append(base_model)

    return squad

fun make_bladeguard_veteran_squad() -> Unit:
    let squad : Unit
    squad.name = "Bladeguard Veteran Squad"s

    # Prepare a single base Model
    let base_model : Model
    base_model.profile = Profile::bladeguard_veteran_squad

    # Abilities
    base_model.abilities.append(AbilityKind::oath_of_moment)
    base_model.abilities.append(AbilityKind::bladeguard)
    # Additional temporary “Swords of the Chapter” or “Shields of the Chapter” will be
    # selected in the Fight phase, so we do not permanently append them here.

    # Keywords
    base_model.keywords.append(Keyword::infantry)
    base_model.keywords.append(Keyword::imperium)
    base_model.keywords.append(Keyword::tacticus)
    base_model.keywords.append(Keyword::bladeguard_veteran_squad)
    # Optionally add Adeptus Astartes or Dark Angels if you define them in the Keyword enum

    # Weapons
    base_model.weapons.append(equipped_weapon(Weapon::heavy_bolt_pistol))
    base_model.weapons.append(equipped_weapon(Weapon::master_crafted_power_weapon))

    # Add 3 identical models
    for i in range(3):
        squad.models.append(base_model)

    return squad

fun make_vengeful_brethren(UnitVector out, Bool owner) -> Faction:
    # 1) Master Zacharial
    out.append(make_master_zacharial())
    out.back().owned_by_player1 = owner

    # 2) Intercessor Squad (10 models)
    out.append(make_intercessor_squad())
    out.back().owned_by_player1 = owner

    # 3) Hellblaster Squad (5 models)
    out.append(make_hellblaster_squad())
    out.back().owned_by_player1 = owner

    # 4) Bladeguard Veteran Squad (3 models)
    out.append(make_bladeguard_veteran_squad())
    out.back().owned_by_player1 = owner

    return Faction::vengeful_brethren

# Ordinary equipped profiles obtain their explicit identities; legacy direct
# borrowed helpers have no passenger identity. Real deck declarations carry it.
fun model_weapon_modifiers(Model model, Int slot, ModifiedCharacteristic kind, Bool borrowed) -> RuleModifiers:
    let name : WeaponCode
    let profile_name : WeaponCode
    if !borrowed and slot >= 0 and slot < model.weapons.size():
        name = model.weapons[slot].profile.family_id()
        profile_name = model.weapons[slot].profile.value
    return model_weapon_modifiers(model, slot, kind, borrowed, name, profile_name)

# Primary links distinguish physical copies; unrelated roots never match.
# Borrowed weapons are not one of the carrier's equipped instances (p.81).
fun weapon_modifier_slot_matches(Model model, CharacteristicModifier entry, Int slot, Bool borrowed) -> Bool:
    if entry.weapon_scope.value == 0:
        return true
    if borrowed or slot < 0 or slot >= model.weapons.size():
        return false
    let selected = entry.weapon_scope.value - 1
    if selected < 0 or selected >= model.weapons.size():
        return false
    if selected == slot:
        return true
    return entry.physical_scope and weapon_primary_slot(model, selected) == weapon_primary_slot(model, slot)

# Named unit conditions use constituent identity, not a display-string match.
# Support Shokka excludes BIG MEK WITH SHOKK ATTACK GUN units:
# https://wahapedia.ru/wh40k11ed/factions/orks/Big-Mek-With-Shokk-Attack-Gun
fun model_matches_datasheet(Model model, OrksDatasheet tag) -> Bool:
    return tag.value > 0 and tag.value < MAX_DATASHEETCODE and model.datasheet.value == tag.value

# Like unit keywords, an attached/mixed unit can contain a named constituent;
# life/battlefield/range eligibility remains the source rule's separate gate.
fun unit_matches_datasheet(Unit unit, OrksDatasheet tag) -> Bool:
    let matches = false
    for i in range(unit.models.size()):
        matches = matches or model_matches_datasheet(unit[i], tag)
    return matches

# Explicit fixture/data ingestion; this assigns names only, not certified stats.
fun set_model_datasheet(Model model, OrksDatasheet tag):
    assert(tag.value >= 0 and tag.value < MAX_DATASHEETCODE, "invalid datasheet identity")
    model.datasheet = tag.value

# A datasheet-scoped grant affects only its matching constituents, including
# mixed attachments (core pp66-67; individual source eligibility remains separate).
fun grant_datasheet_characteristic(Unit unit, OrksDatasheet tag, CharacteristicModifier modifier):
    for i in range(unit.models.size()):
        if model_matches_datasheet(unit[i], tag):
            assert(unit[i].characteristic_modifiers.has_capacity(), "characteristic grant capacity exceeded")
            unit[i].characteristic_modifiers.append(modifier)

# Typed label bridges expose compact standard codes to the editor without
# storing one-hot catalog enums or display-string gameplay selectors.
fun named_model_datasheet(Model model) -> OrksDatasheet:
    let tag : OrksDatasheet
    tag.value = model.datasheet.value
    return tag

# Resolve a physical copy in its model: a primary is its own root, while all
# alternate profiles refer to that primary (core p16; appendix04.01.03).
fun weapon_primary_slot(Model model, Int slot) -> Int:
    assert(slot >= 0 and slot < model.weapons.size(), "invalid equipped weapon slot")
    if model.weapons[slot].secondary_profile_of.value > 0:
        return model.weapons[slot].secondary_profile_of.value - 1
    return slot

# The stable snapshot uses a1-based root slot so independent copies remain
# distinct in Hazardous/One Shot bookkeeping (core p81; appendix04.01.03).
fun weapon_primary_id(Model model, Int slot) -> Int:
    return weapon_primary_slot(model, slot) + 1

# Identity comes from the actual profile, never a separately supplied name.
# Family selectors address the catalog representative shared by its profiles.
fun equipped_weapon_family(Model model, Int slot) -> Weapon:
    let result : Weapon
    result.value = model.weapons[slot].profile.family_id()
    return result

# Exact-profile selectors use the actual equipped catalog entry (04.01.03).
fun equipped_weapon_profile(Model model, Int slot) -> Weapon:
    return model.weapons[slot].profile

# Install a primary or explicit alternate; constructors supply the real
# catalog entry and same-model parent, without duplicated identity tags.
fun equip_weapon(Model model, Weapon profile, Int primary):
    assert(profile.value > 0 and profile.value < MAX_WEAPON_CODE, "invalid equipped weapon profile")
    assert(primary >= 0 and primary <= model.weapons.size(), "primary weapon must already exist")
    if primary > 0:
        assert(model.weapons[primary - 1].secondary_profile_of.value == 0 and model.weapons[primary - 1].profile.family_id() == profile.family_id(), "alternate weapon must reference its primary family")
    model.weapons.append(equipped_weapon(profile, primary))

# Hunter conditions remain equipped metadata separate from weapon abilities;
# selection checks them against the actual target (core p16/04.01.03).
fun equip_weapon(Model model, Weapon profile, Int primary, WeaponRule hunter):
    let slot = model.weapons.size()
    equip_weapon(model, profile, primary)
    model.hunter_profile_conditions[slot] = hunter

# Explicit fixture/host bridge uses0-based slot indices and rejects cycles or
# unrelated weapons; restore validation enforces the same invariant.
fun link_weapon_profile(Model model, Int slot, Int primary):
    assert(primary >= 0 and primary < slot and slot < model.weapons.size(), "alternate must follow its primary")
    assert(model.weapons[primary].secondary_profile_of.value == 0 and model.weapons[primary].profile.family_id() == model.weapons[slot].profile.family_id(), "alternate family mismatch")
    model.weapons[slot].secondary_profile_of = primary + 1

# A family grant reaches every physical copy/profile of that catalog family
# (source card restrictions; core p78/appendix04.01.03).
fun grant_weapon_family_rule(Model model, Weapon family, WeaponRule rule):
    for slot in range(model.weapons.size()):
        if model.weapons[slot].profile.family_id() == family.family_id():
            assert(model.additional_weapon_rules[slot].has_capacity(), "weapon rule grant capacity exceeded")
            model.additional_weapon_rules[slot].append(rule)

# Exact-profile grants remain narrower than family grants (04.01.03).
fun grant_weapon_profile_rule(Model model, Weapon profile, WeaponRule rule):
    for slot in range(model.weapons.size()):
        if model.weapons[slot].profile.value == profile.value:
            assert(model.additional_weapon_rules[slot].has_capacity(), "weapon rule grant capacity exceeded")
            model.additional_weapon_rules[slot].append(rule)

# Physical-instance grants follow the primary link, never another copy of
# the same catalog weapon (appendix04.01.03).
fun grant_physical_weapon_rule(Model model, Int slot, WeaponRule rule):
    let root = weapon_primary_slot(model, slot)
    for target in range(model.weapons.size()):
        if weapon_primary_slot(model, target) == root:
            assert(model.additional_weapon_rules[target].has_capacity(), "weapon rule grant capacity exceeded")
            model.additional_weapon_rules[target].append(rule)

# Godot reads the printed Nazdreg exception from the actual profile catalog.
fun permits_simultaneous_profile(Model model, Int slot) -> Bool:
    return slot >= 0 and slot < model.weapons.size() and simultaneous_weapon_profile(model.weapons[slot].profile)
