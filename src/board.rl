import units
import range

# enum to set the proper state description from within godot user interface. Irrelevant for everything else.
enum CurrentStateDescription:
    none
    hit_roll
    quantity_roll 
    hazardous_roll
    wound_roll
    allocate_wound 
    save_roll
    damage_roll
    select_weapon
    select_oath_of_moment_target
    use_duty_and_honour 
    overwatch 

cls AttackSequenceInfo:
    UnitID source_unit_id # required
    UnitID target_unit_id # required
    Bool penetration_bonus
    Bool hit_roll_bonus
    # Cover changes BS, separate from the clamped hit modifier (p.50).
    Bool target_has_cover
    Bool hit_roll_malus
    CheckedVector<Profile, 8> profile_hit_roll_bonus
    CheckedVector<WeaponRule, 8> temporary_weapon_abilities
    Bool wound_roll_malus
    Bool wound_roll_bonus
    CheckedVector<Profile, 8> profile_wound_roll_bonus
    Bool reroll_hits
    Bool reroll1_hits
    Bool only_hits_on_6
    Bool reroll_wounds
    Bool reroll1_wounds
    Bool greater_strenght_wound_protection
    Bool fight_on_death
    Dice fight_on_death_roll
    Toughness target_toughness
    Weapon source
    Profile source_profile
    BInt<0, MAX_ROUNDS> current_round

    fun add_letal_hits():
        self.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::letal_hits))

    fun add_sustained_hits(Int parameter):
        self.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::sustained_hit, parameter))


    fun max_weapon_parameter(Board board, WeaponRuleKind kind) -> Int:
        return max(board[self.source_unit_id].max_weapon_parameter(self.source, kind), self._get_weapon_rule_parameter(kind))

    fun has_weapon_rule(Board board, WeaponRuleKind kind) -> Bool:
        return self.max_weapon_parameter(board, kind) != 0

    fun _get_weapon_rule_parameter(WeaponRuleKind kind) -> Int:
        let i = 0
        while i != self.temporary_weapon_abilities.size():
            if self.temporary_weapon_abilities[i].kind == kind:
                return self.temporary_weapon_abilities[i].parameter
            i = i + 1
        return 0

    fun total_hit_modifier() -> Int:
        let result = int(self.hit_roll_bonus) - int(self.hit_roll_malus)
        let i = 0
        while i != self.profile_hit_roll_bonus.size():
            if self.profile_hit_roll_bonus[i] == self.source_profile:
                result = result + 1
                break
            i = i + 1
        return result

    fun total_wound_modifier() -> Int:
        let result = int(self.wound_roll_bonus) - int(self.wound_roll_malus)
        let i = 0
        while i != self.profile_wound_roll_bonus.size():
            if self.profile_wound_roll_bonus[i] == self.source_profile:
                result = result + 1
                break
            i = i + 1
        return result


enum ObjectiveController:
    none
    army_0
    army_1

    fun equal(ObjectiveController other) -> Bool:
        return self.value == other.value

# Objectives use the existing four-slot editor domain; this is a supported
# mission configuration capacity, not a restriction imposed by p.52.
cls Objective:
    BoardPosition position
    Bool custom_position
    Bool terrain_objective
    BInt<0, 16> area_id
    ObjectiveController controller
    ObjectiveController secured_by


enum MissionScoringMode:
    none
    legacy_four_markers

    fun equal(MissionScoringMode other) -> Bool:
        return self.value == other.value

const MAX_ROUNDS = 6

using AlreadyUsedStratagems = CheckedVector<Stratagem, 32>

cls PhaseInfo:
    AlreadyUsedStratagems[2] already_used_stratagems
    
cls Board:
    StateSchema schema_version
    Int next_identity
    Int phase_serial
    Int turn_serial
    TimingState timing
    UnitVector units # required
    UnitVector reserve_units # required
    TerrainGeometryVector terrain_geometry
    TerrainAreaVector terrain_areas
    Objective[4] objectives
    MissionScoringMode mission_scoring

    UnitID oath_of_moment_target
    # Insane Bravery is once per battle, not reset by phase/turn cleanup (p.56).
    Bool[2] has_used_insane_bravery
    Bool[2] has_used_shadow_in_the_warp

    AttackSequenceInfo attack_info
    Bool[2] obtained_extra_cp_this_round
    CommandPoints[2] command_points
    LinearlyDistributedInt<0, MAX_ROUNDS> current_round
    Bool current_player
    Bool starting_player
    Bool current_decision_maker
    Faction[2] players_faction
    VictoryPoints[2] score

    PhaseInfo phase_info

    Attack attack
    Overwatch overwatch
    RerollableDice current_roll
    RerollableDicePair current_pair_roll

    CurrentStateDescription current_state

    # Implementation identity allocation: removals/returns must keep the same entity
    # behind stored references (destruction p.19; returning models p.88).
    fun identify_unit(Unit unit):
        if unit.identity.value == -1:
            unit.identity = self.next_identity
            self.next_identity = self.next_identity + 1
        let i = 0
        while i < unit.models.size():
            ref model = unit.models[i]
            if model.identity.value == -1:
                model.identity = self.next_identity
                self.next_identity = self.next_identity + 1
                model.original_unit = unit.identity
            i = i + 1

    # Assign roster identities before attachment/deployment so component provenance
    # survives transfer (Leader/Support pp.66–67; starting strength p.86).
    fun identify_units():
        let i = 0
        while i < self.reserve_units.size():
            self.identify_unit(self.reserve_units[i])
            i = i + 1
        i = 0
        while i < self.units.size():
            self.identify_unit(self.units[i])
            i = i + 1

    # Resolve an entity rather than reuse a vacated positional target; this is a
    # storage invariant supporting attack targets/destruction (pp.17/19).
    fun find_unit(EntityIdentity identity) -> Int:
        if identity.value < 0:
            return -1
        let i = 0
        while i < self.units.size():
            if self.units[i].identity == identity and !self.units[i].retired:
                return i
            i = i + 1
        return -1

    # Reset turn-local storage without erasing phase-independent usage; supports
    # turn/phase restrictions (pp.28–30, movement pp.32–33).
    fun start_turn_history():
        self.turn_serial = self.turn_serial + 1
        let i = 0
        while i < self.units.size():
            self.units[i].reset_turn_history()
            if self.units[i].owned_by_player1 == self.current_player:
                self.units[i].has_run = false
                self.units[i].has_fought = false
                self.units[i].has_shoot = false
                self.units[i].has_moved = false
                self.units[i].has_charged = false
                self.units[i].can_shoot = true
                self.units[i].can_charge = true
            i = i + 1
        i = 0
        while i < self.reserve_units.size():
            self.reserve_units[i].reset_turn_history()
            i = i + 1

    # Freeze combined model counts after attachments, before casualties change
    # current strength (starting strength p.86; attachment pp.66–67).
    fun capture_starting_strengths():
        let i = 0
        while i < self.reserve_units.size():
            self.reserve_units[i].capture_starting_strength()
            i = i + 1

    # Expire phase-local effects/usage while retaining turn/battle history
    # (phase sequence pp.28–30; stratagem duration/usage pp.54–57).
    fun clear_phase_modifiers():
        self.phase_serial = self.phase_serial + 1
        self.phase_info.already_used_stratagems[0].clear()
        self.phase_info.already_used_stratagems[1].clear()
        let i = 0
        while i != self.units.size():
            self.units[i].clear_phase_modifiers()
            # Every army may fight once in a Fight phase (pp.38–40).
            self.units[i].has_fought = false
            self.units[i].history.used_stratagem_this_phase = false
            self.units[i].history.stratagem_targeted_by_player[0] = false
            self.units[i].history.stratagem_targeted_by_player[1] = false
            i = i + 1

        i = 0
        while i < self.reserve_units.size():
            self.reserve_units[i].clear_phase_modifiers()
            self.reserve_units[i].has_fought = false
            self.reserve_units[i].history.used_stratagem_this_phase = false
            self.reserve_units[i].history.stratagem_targeted_by_player[0] = false
            self.reserve_units[i].history.stratagem_targeted_by_player[1] = false
            i = i + 1

    # A phase starts with fresh phase usage and effects, before its start window
    # (pp.28–30/54). End effects are resolved before this state is expired.
    fun begin_phase(BattlePhase phase):
        self.clear_phase_modifiers()
        self.timing.phase = phase
        self.current_decision_maker = self.current_player

    # Window controllers follow the user-supplied order: active rules first,
    # then opposing rules, each chosen by their owner (core pp.8–9/28–30).
    fun open_timing_window(TimingWindow window):
        assert(!self.timing.open, "nested timing window")
        self.timing.window = window
        self.timing.stage = TimingStage::current_player_rules
        self.timing.controller = self.timing.active_player
        self.timing.open = true

    # Mission end rules follow non-mission rules (pp.28–30); actual mission
    # achievements are unavailable and remain task 17, not invented here.
    fun close_timing_window():
        self.timing.stage = TimingStage::mission_rules
        self.timing.open = false
        self.timing.stage = TimingStage::closed
        self.current_decision_maker = self.current_player

    fun get_current_player_faction() -> Faction:
        return self.players_faction[int(self.current_player)]

    fun add_extra_cp(Int player_id):
        if self.obtained_extra_cp_this_round[player_id]:
            return
        self.obtained_extra_cp_this_round[player_id] = true
        self.command_points[player_id] = self.command_points[player_id] + 1

    fun get_current_attacking_model() -> ref Model:
        return self[self.attack.source][self.attack.model.value]

    fun get_score(Int player_id) -> Int:
        return self.score[player_id].value

    fun any_enemy_in_range_has_ability(Unit unit, Float allowed_range, AbilityKind ability) -> Bool:
        for i in range(self.units.size()):
            if self[i].owned_by_player1 == unit.owned_by_player1:
                continue
            if unit.distance(self[i]) > allowed_range:
               continue 
            if self[i].has_ability(ability):
                return true
        return false

    # Insane Bravery has a battle-long limit (p.56), independent of phase
    # records. Other stratagems retain their own printed restrictions (task 15).
    fun stratagem_battle_limit_available(Bool player, Stratagem strat) -> Bool:
        return !(strat == Stratagem::insane_bravery and self.has_used_insane_bravery[int(player)])

    # Check the requested cost and using player, not a different stratagem or
    # opponent record (stratagem use p.54). Per-unit/windows remain tasks 5/15.
    fun can_use_strat(Bool player, Stratagem strat) -> Bool:
        return self.command_points[int(player)] >= strat.cost() and !self.has_used_strat(strat, int(player)) and self.stratagem_battle_limit_available(player, strat)

    # Printed extra costs/free-use effects must still obey phase restrictions
    # (p.54). Cost overrides are explicit internal inputs, not invented rules.
    fun can_use_strat_with_cost(Bool player, Stratagem strat, Int cost) -> Bool:
        return cost >= 0 and self.command_points[int(player)] >= cost and !self.has_used_strat(strat, int(player)) and self.stratagem_battle_limit_available(player, strat)

    # Target bookkeeping belongs to each payer independently; shock blocks
    # the controlling player's stratagems on that unit (pp.9/54).
    fun can_target_strat_with_cost(Bool player, Stratagem strat, Unit target, Int cost) -> Bool:
        return self.can_use_strat_with_cost(player, strat, cost) and !target.empty() and !target.history.stratagem_targeted_by_player[int(player)] and !(target.battle_socked and target.owned_by_player1 == player)

    # Each player may target a unit only once per phase (p.54).
    fun can_target_strat(Bool player, Stratagem strat, Unit target) -> Bool:
        return self.can_target_strat_with_cost(player, strat, target, strat.cost())

    # Untargeted legacy faction options still need supplied target definitions;
    # their expenditure/phase bookkeeping is nevertheless atomic (p.54).
    fun commit_stratagem(Bool player, Stratagem strat):
        assert(self.can_use_strat(player, strat), "illegal stratagem use")
        self.pay_strat(player, strat)
        self.mark_strat_used(strat, int(player))

    # Commit a supplied target/cost before resolving the effect (p.54).
    fun commit_stratagem_with_cost(Bool player, Stratagem strat, Unit target, Int cost):
        assert(self.can_target_strat_with_cost(player, strat, target, cost), "illegal stratagem target")
        self.command_points[int(player)] = self.command_points[int(player)] - cost
        self.mark_strat_used(strat, int(player))
        target.history.stratagem_targeted_by_player[int(player)] = true
        target.history.used_stratagem_this_phase = true

    # Normal targeted use uses the printed base cost (p.54).
    fun commit_stratagem(Bool player, Stratagem strat, Unit target):
        self.commit_stratagem_with_cost(player, strat, target, strat.cost())

    # Invalid targets/costs fail without partial expenditure or history changes
    # (p.54); this recoverable primitive supports legality/rollback tests.
    fun try_use_strat(Bool player, Stratagem strat, Unit target, Int cost) -> Bool:
        if !self.can_target_strat_with_cost(player, strat, target, cost):
            return false
        self.commit_stratagem_with_cost(player, strat, target, cost)
        return true

    # Charge the player whose eligibility was checked, at the selected cost
    # (CP expenditure for stratagems p.54; reference 15.01).
    fun pay_strat(Bool player, Stratagem strat):
        assert(self.command_points[int(player)] >= strat.cost(), "insufficient CP")
        self.command_points[int(player)] = self.command_points[int(player)] - strat.cost()

    # Keep one usage entry per player/phase without duplicates filling storage
    # (stratagem-use restrictions p.54; complete targeting limits are task 15).
    fun mark_strat_used(Stratagem strat, Int player):
        # Battle-long Bravery usage must survive phase cleanup (p.56).
        if strat == Stratagem::insane_bravery:
            self.has_used_insane_bravery[player] = true
        if !self.has_used_strat(strat, player):
            self.phase_info.already_used_stratagems[player].append(strat)

    # Read the using player's phase record for repeated-use eligibility (p.54).
    fun has_used_strat(Stratagem strat, Int player) -> Bool:
        ref strats = self.phase_info.already_used_stratagems[player]
        let i = 0
        while strats.size() != i:
            if strats[i] == strat:
                return true
            i = i + 1
        return false

    fun get(Int unit_id) -> ref Unit:
        return self.units[unit_id]

    fun get(UnitID unit_id) -> ref Unit:
        return self.units[unit_id.get()]

    fun count_models(Int player_id) -> Int:
        let i = 0
        let count = 0
        while i != self.units.size():
            if self[i].owned_by_player1 == bool(player_id):
                count = count + self[i].models.size()
            i = i + 1 
        return count

    # Engagement is any opposing model pair within inclusive horizontal/vertical
    # limits, measured between bases rather than centre-only points (pp.14–15).
    fun is_in_melee(Unit u) -> Bool:
        let i = 0
        while i < self.units.size():
            if self.units[i].owned_by_player1 != u.owned_by_player1 and u.is_engaged_with(self.units[i]):
                return true
            i = i + 1
        return false

    fun faction_of_unit(UnitID id) -> Faction:
        return self.players_faction[int(self[id].owned_by_player1)]

    fun least_distance_from_player_units(BoardPosition position, Bool player) -> Float:
        let i = 0
        let least_distance = 100.0
        while i != self.units.size():
            if self.units[i].owned_by_player1 == player and !self.units[i].empty() and self.units[i].distance(position) < least_distance:
                least_distance = self.units[i].distance(position)
            i = i + 1
        return least_distance

    fun is_position_valid_for_reserve(BoardPosition position, Unit unit) -> Bool:
        if self.current_round == 0:
            return false
        if unit.all_have_ability(AbilityKind::deep_strike):
            return true
        if self.current_round < 3:
           if !self.current_decision_maker:
                return (position.x < 6 or  position.x > BOARD_WIDTH - 6 or position.y < 6) and position.y < BOARD_HEIGHT - 6
           else:
                return (position.x < 6 or  position.x > BOARD_WIDTH - 6 or position.y > BOARD_WIDTH - 6) and position.y > 6
        
        return position.x < 6 or position.y < 6 or position.x > BOARD_WIDTH - 6 or position.y > BOARD_HEIGHT - 6

    # Retire empty battlefield slots instead of shifting persistent targets after
    # destruction (p.19). Slot retention is implementation policy, not a game rule.
    fun remove_empty_units():
        let i = self.units.size() - 1
        while i >= 0:
            if self[i].models.empty():
               self.units[i].retired = true
            i = i - 1 

    # Keep default mission points separate from construction of the rest of
    # Board state. Explicitly configured points override these legacy fixtures
    # (p.52: location comes from the mission, not the core rules).
    fun objective_position(Int objective_id) -> BoardPosition:
        assert(objective_id >= 0 and objective_id < 4, "invalid objective")
        if self.objectives[objective_id].custom_position:
            return self.objectives[objective_id].position
        if objective_id == 0:
            return make_board_position(12, 15)
        if objective_id == 1:
            return make_board_position(32, 15)
        if objective_id == 2:
            return make_board_position(22, 9)
        return make_board_position(22, 21)

    # Mission/editor configuration stays on the existing whole-quad domain
    # (user constraint; objective location p.52). Control is still boundary state.
    fun set_objective_position(Int objective_id, BoardPosition position):
        assert(objective_id >= 0 and objective_id < 4, "invalid objective")
        self.objectives[objective_id].position = position
        self.objectives[objective_id].custom_position = true

    # Build a range-query value with the configured/default point (pp.52/88),
    # without replacing the stored boundary ownership and securing flags.
    fun objective_range_definition(Int objective_id) -> Objective:
        let result = self.objectives[objective_id]
        result.position = self.objective_position(objective_id)
        return result

    # Hidden depends on actual ranged attacks this/previous turn (p.50), not
    # merely being selected to shoot or declining every weapon. Keep this
    # history across phase/turn cleanup so the previous turn remains available.
    fun record_ranged_attacks(UnitID source):
        if source.get() < self.units.size() and !self[source].empty():
            self[source].history.last_ranged_attack_turn = self.turn_serial

    # Model membership uses any part of its supported circular base (p.9 and
    # the user's Within definition); terrain areas do not impose a height limit.
    fun model_in_terrain_area(Model model, Int area_id) -> Bool:
        if area_id < 0 or area_id >= self.terrain_areas.size() or model.geometry.unsupported_footprint:
            return false
        ref area = self.terrain_areas[area_id]
        let point = model.geometry_position()
        let radius = model.base_radius_micrometres()
        return valid_terrain_area(area) and point_area_distance_squared(float(point.x.value), float(point.y.value), area) <= radius * radius

    # Link mission objective points to their terrain areas before the battle
    # (p.52); outside every area they use a 40mm marker (p.88). Overlapping
    # objective areas require an explicit mission choice rather than guessing.
    fun link_objective_terrain_areas() -> Bool:
        let candidate = self.objectives
        let valid = true
        for area_index in range(self.terrain_areas.size()):
            if !valid_terrain_area(self.terrain_areas[area_index]):
                valid = false
        for i in range(4):
            ref objective = candidate[i]
            let count = 0
            for j in range(self.terrain_areas.size()):
                if point_in_terrain_area(self.objective_position(i), self.terrain_areas[j]):
                    objective.area_id = j
                    count = count + 1
            objective.terrain_objective = count > 0
            if count > 1:
                valid = false
        if valid:
            self.objectives = candidate
        return valid

    # Within a terrain objective means any part of the base in its agreed
    # area (p.52); outside terrain use closest parts of a 40mm marker and the
    # inclusive 3-inch horizontal/5-inch vertical limits (p.88).
    fun model_in_objective_range(Model model, Objective objective) -> Bool:
        if model.geometry.unsupported_footprint:
            return false
        if objective.terrain_objective:
            if objective.area_id.value >= self.terrain_areas.size():
                return false
            return self.model_in_terrain_area(model, objective.area_id.value)
        let dx = float((model.position.x.value - objective.position.x.value) * MICROMETRES_PER_INCH)
        let dy = float((model.position.y.value - objective.position.y.value) * MICROMETRES_PER_INCH)
        let range = float(3 * MICROMETRES_PER_INCH + 20000) + model.base_radius_micrometres()
        return dx * dx + dy * dy <= range * range and model.geometry.elevation.value <= 5

    # Add every eligible model's OC; shock contributes nothing (pp.9/52).
    # Raw totals are computed values, not unbounded stored ML state.
    fun objective_control_level(Objective objective, Bool player) -> Int:
        let total = 0
        for i in range(self.units.size()):
            ref unit = self[i]
            if unit.owned_by_player1 == player:
                for j in range(unit.models.size()):
                    if self.model_in_objective_range(unit[j], objective):
                        total = total + max(0, unit.model_objective_control(j))
        return total

    # Stateless marker query retained for existing diagnostic fixtures. Real
    # objective ownership uses boundary snapshots, not continuous updates (p.52).
    fun get_objective_controller(Int x, Int y) -> Int:
        let objective : Objective
        objective.position = make_board_position(x, y)
        let a = self.objective_control_level(objective, false)
        let b = self.objective_control_level(objective, true)
        if a == b:
            return -1
        if a > b:
            return 0
        return 1

    # No control at battle start; use the last phase/turn boundary result (p.52).
    fun get_objective_controller(Int objective_id) -> Int:
        if objective_id < 0 or objective_id >= 4:
            return -1
        return int(self.objectives[objective_id].controller.value) - 1

    # Snapshot all totals at phase/turn end. Secured control survives ties or
    # absence; only superior opposing OC at phase end removes it (p.52).
    fun update_objective_control(Bool phase_end):
        for i in range(4):
            ref objective = self.objectives[i]
            let definition = self.objective_range_definition(i)
            let a = self.objective_control_level(definition, false)
            let b = self.objective_control_level(definition, true)
            if phase_end:
                if (objective.secured_by == ObjectiveController::army_0 and b > a) or (objective.secured_by == ObjectiveController::army_1 and a > b):
                    objective.secured_by = ObjectiveController::none
            if !(objective.secured_by == ObjectiveController::none):
                objective.controller = objective.secured_by
            else if a == b:
                objective.controller = ObjectiveController::none
            else if a > b:
                objective.controller = ObjectiveController::army_0
            else:
                objective.controller = ObjectiveController::army_1

    # A supplied effect secures an objective already controlled by this army
    # (p.52). This does not grant any new faction/mission ability by itself.
    fun grant_secured_objective(Int objective_id, Bool player):
        assert(objective_id >= 0 and objective_id < 4, "invalid objective")
        assert(self.get_objective_controller(objective_id) == int(player), "cannot secure uncontrolled objective")
        self.objectives[objective_id].secured_by = self.objectives[objective_id].controller

    # A unit controls an objective only when its army controls it, it is within
    # range and contains at least one OC-positive model (p.53).
    fun unit_controls_objective(Unit unit, Int objective_id) -> Bool:
        if self.get_objective_controller(objective_id) != unit.owner_id() or unit.empty():
            return false
        let in_range = false
        let positive = false
        for i in range(unit.models.size()):
            in_range = in_range or self.model_in_objective_range(unit[i], self.objective_range_definition(objective_id))
            positive = positive or unit.model_objective_control(i) >= 1
        return in_range and positive

    # Render the configured objective points on existing quad coordinates;
    # area objectives use their mission point, not a newly invented grid shape.
    fun get_objectives_locations() -> Vector<BoardPosition>:
        let result : Vector<BoardPosition>
        for i in range(4):
            result.append(self.objective_position(i))
        return result

    # Legacy five-point Command scoring is an explicitly selected mission
    # fixture, not a core control rule (pp.30/52). Index each marker correctly.
    fun score():
        if self.mission_scoring == MissionScoringMode::legacy_four_markers:
            for i in range(4):
                if self.get_objective_controller(i) == int(self.current_player):
                    self.score[int(self.current_player)] = self.score[int(self.current_player)] + 5

fun append_to_string(ModelID to_add, String output):
    append_to_string(to_add.id, output)

fun parse_string(ModelID result, String buffer, Int index) -> Bool:
    return parse_string(result.id, buffer, index)


fun append_to_string(UnitID to_add, String output):
    append_to_string(to_add.id, output)

fun parse_string(UnitID result, String buffer, Int index) -> Bool:
    return parse_string(result.id, buffer, index)


# Validate saved identities globally, including destroyed models. An unassigned
# fixture entity is allowed, but must never resolve as a persistent reference.
# Save-integrity helper, not a tabletop rule: reject duplicate/out-of-range
# identities so destruction/return references remain sound (pp.19/88).
fun register_identity(EntityIdentity identity, Int next_identity, Vector<Int> seen) -> Bool:
    if identity.value == -1:
        return true
    if identity.value < 0 or identity.value >= next_identity:
        return false
    let i = 0
    while i < seen.size():
        if seen[i] == identity.value:
            return false
        i = i + 1
    seen.append(identity.value)
    return true

# Validate live, archived and attached identities together on load; supports
# the lifecycle/provenance invariants of pp.19, 66–67 and 86–88.
fun valid_unit_identities(Unit unit, Int next_identity, Vector<Int> seen) -> Bool:
    if !register_identity(unit.identity, next_identity, seen):
        return false
    let i = 0
    while i < unit.models.size():
        if !register_identity(unit.models[i].identity, next_identity, seen):
            return false
        i = i + 1
    i = 0
    while i < unit.destroyed_models.value.size():
        if !register_identity(unit.destroyed_models.value[i].identity, next_identity, seen):
            return false
        i = i + 1
    i = 0
    while i < unit.attached_units.value.size():
        if !register_identity(unit.attached_units.value[i].identity, next_identity, seen):
            return false
        i = i + 1
    return true

# Compatibility/integrity gate for saved state; versioning is implementation
# policy, while identity integrity protects the lifecycle rules (pp.19/88).
fun valid_state_foundations(Board board) -> Bool:
    if board.schema_version.value != STATE_SCHEMA_VERSION or board.next_identity < 0 or board.phase_serial < 0 or board.turn_serial < 0:
        return false
    # Terrain storage must preserve the user's quad grid and valid extents;
    # malformed saved geometry cannot become a legal path/placement (p.12).
    let terrain_index = 0
    while terrain_index < board.terrain_geometry.size():
        if !valid_terrain_geometry(board.terrain_geometry[terrain_index]):
            return false
        terrain_index = terrain_index + 1
    # Area extents/categories and objective links are save/configuration
    # invariants, supporting the agreed layout and control rules (pp.46/52).
    for index in range(board.terrain_areas.size()):
        if !valid_terrain_area(board.terrain_areas[index]):
            return false
    for index in range(4):
        ref objective = board.objectives[index]
        if objective.terrain_objective:
            if objective.area_id.value >= board.terrain_areas.size() or !point_in_terrain_area(board.objective_position(index), board.terrain_areas[objective.area_id.value]):
                return false
        else:
            for area_index in range(board.terrain_areas.size()):
                if point_in_terrain_area(board.objective_position(index), board.terrain_areas[area_index]):
                    return false
    let seen : Vector<Int>
    let i = 0
    while i < board.units.size():
        if !valid_unit_identities(board.units[i], board.next_identity, seen):
            return false
        i = i + 1
    i = 0
    while i < board.reserve_units.size():
        if !valid_unit_identities(board.reserve_units[i], board.next_identity, seen):
            return false
        i = i + 1
    return true
