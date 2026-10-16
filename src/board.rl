import action_frames
import units
import source_effect_types
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
    allocation_order
    feel_no_pain_roll
    mortal_wound
    destruction_roll
    select_oath_of_moment_target
    use_duty_and_honour 
    overwatch 

cls AttackSequenceInfo:
    # Hit provenance for Squig Barrage survives identical-attack gathering.
    Bool squig_launcha_weapon
    ShootingKind shooting_kind
    Bool weapon_rules_known
    CheckedVector<WeaponRule, 32> selected_weapon_rules
    Bool indirect_stationary_visible
    Bool heavy_bonus
    # Per-bearer group snapshot of core ability24.39, before the hit-roll cap.
    Bool damaged_hit_penalty
    LinearlyDistributedInt<0, 3> engaged_hit_penalties
    UnitID source_unit_id # required
    UnitID target_unit_id # required
    Bool penetration_bonus
    LinearlyDistributedInt<0, MAX_STAT_MODIFIER> melta_damage_bonus
    Bool precision_visibility_known
    Bool[32] precision_visible_targets
    # Beastboss Dodge Dis!: separate contribution before the cumulative cap.
    Bool dodge_dis_hit_bonus
    Bool hit_roll_bonus
    RuleModifiers orks_hit_modifiers
    # Preserve each repair source in addition to the four unit-rule slots;
    # all modifiers are cumulative and individually ignorable (02.02.01/02).
    CheckedVector<RuleModifier, MAX_DATASHEET_HIT_MODIFIERS> orks_unit_hit_modifiers
    RuleModifiers orks_wound_modifiers
    Bool orks_fail_hits_three
    # Cover changes BS, separate from the clamped hit modifier (p.50).
    Bool target_has_cover
    # Printed Plunging Fire changes BS; Aircraft are excluded (pp.73–74).
    Bool plunging_fire
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
    # Gathered weapon snapshots (pp.17–19/appendix02.02.01); skill/AP
    # retain operations so later core increments enter the right arithmetic step.
    # D retains operations until its allocated per-attack random roll (02.02.03).
    Bool characteristics_known
    FixedStat weapon_strength
    RuleModifiers skill_modifiers
    Bool may_ignore_skill_modifiers
    Bool may_ignore_hit_modifiers
    RuleModifiers ap_modifiers
    RuleModifiers damage_modifiers
    Profile source_profile
    BInt<0, MAX_ROUNDS> current_round

    # Wound consumers use gathered effective S; legacy direct fixtures use
    # the raw profile until configured (p.18; appendix02.02.01).
    fun attack_strength() -> Int:
        if self.characteristics_known:
            return self.weapon_strength.value
        return self.source.strenght()

    # AP improvements are negative increments before division/subtraction,
    # not additions to the save roll (p.19; appendix02.02.01).
    fun attack_penetration() -> Int:
        return modified_characteristic(self.source.penetration(), ModifiedCharacteristic::armour_penetration, self.ap_modifiers, false, -int(self.penetration_bonus))

    # Recipient reductions share outgoing arithmetic before the AP cap
    # (p.19/appendix02.02.01), without changing invulnerable saves.
    fun attack_penetration(Model recipient) -> Int:
        let modifiers = combined_incoming_modifiers(self.ap_modifiers, recipient.incoming_attack_modifiers, ModifiedCharacteristic::armour_penetration, self.source.range() == 0)
        return modified_characteristic(self.source.penetration(), ModifiedCharacteristic::armour_penetration, modifiers, false, -int(self.penetration_bonus))

    fun add_letal_hits():
        self.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::letal_hits))

    fun add_sustained_hits(Int parameter):
        self.temporary_weapon_abilities.append(weapon_rule(WeaponRuleKind::sustained_hit, parameter))


    # A chosen duplicate is used alone, with its target-keyword condition (p.78).
    fun rule_applies(Board board, WeaponRule rule) -> Bool:
        return source_grant_active(board, rule.source_effect) and board[self.target_unit_id].weapon_rule_applies(rule)

    fun max_weapon_parameter(Board board, WeaponRuleKind kind) -> Int:
        let result = 0
        if !self.weapon_rules_known:
            result = board[self.source_unit_id].max_weapon_parameter(self.source, kind)
        for i in range(self.selected_weapon_rules.size()):
            if self.selected_weapon_rules[i].kind == kind and self.rule_applies(board, self.selected_weapon_rules[i]):
                result = max(result, effective_weapon_ability_parameter(board, self.selected_weapon_rules[i]))
        for i in range(self.temporary_weapon_abilities.size()):
            if self.temporary_weapon_abilities[i].kind == kind and self.rule_applies(board, self.temporary_weapon_abilities[i]):
                result = max(result, effective_weapon_ability_parameter(board, self.temporary_weapon_abilities[i]))
        return result

    # Presence is independent of parameter magnitude (pp.78–85).
    fun has_weapon_rule(Board board, WeaponRuleKind kind) -> Bool:
        let found = false
        if !self.weapon_rules_known:
            found = self.source.has_rule(kind) or board[self.source_unit_id].has_temporary_wepon_rule(kind)
        for i in range(self.selected_weapon_rules.size()):
            found = found or (self.selected_weapon_rules[i].kind == kind and self.rule_applies(board, self.selected_weapon_rules[i]))
        for i in range(self.temporary_weapon_abilities.size()):
            found = found or (self.temporary_weapon_abilities[i].kind == kind and self.rule_applies(board, self.temporary_weapon_abilities[i]))
        return found

    # Beastboss/Dodge Dis! is a separate +1 before the core cumulative cap,
    # so another bonus/penalty cannot overwrite it (Orks/Beastboss; core p18
    # and appendix02.02.01). Optional ignoring retains its own provenance.
    # https://wahapedia.ru/wh40k11ed/factions/orks/Beastboss
    fun total_hit_modifier() -> Int:
        let result = apply_rule_modifiers(0, self.orks_hit_modifiers, false) + apply_rule_modifiers(0, self.orks_unit_hit_modifiers, false) + int(self.hit_roll_bonus) + int(self.dodge_dis_hit_bonus) - int(self.hit_roll_malus) - int(self.damaged_hit_penalty)
        let i = 0
        while i != self.profile_hit_roll_bonus.size():
            if self.profile_hit_roll_bonus[i] == self.source_profile:
                result = result + 1
                break
            i = i + 1
        return result

    fun total_wound_modifier() -> Int:
        let result = apply_rule_modifiers(0, self.orks_wound_modifiers, false) + int(self.wound_roll_bonus) - int(self.wound_roll_malus)
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
enum ObjectiveHome:
    none
    army_0
    army_1

cls Objective:
    # Explicit mission assignment; never infer a home marker from its index.
    ObjectiveHome home
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
    # Serial action lifetimes share context storage instead of inactive copies.
    SharedActionFrames shared_actions
    # Editor labels for the suspended duplicate-ability selector (p.78).
    CheckedVector<WeaponRule, 32> pending_weapon_abilities
    StateSchema schema_version
    IdentitySequence next_identity
    PhaseSerial phase_serial
    TurnSerial turn_serial
    # Explicit mission roster limit and movement editor context (pp.68/12).
    LinearlyDistributedInt<0, 10001> battle_points_limit
    UnitID moving_unit
    # Editor context for common damage choices across real banks (p24/87).
    SourceBank damage_bank
    # Explicit exception for the supplied Fight on Death's own-unit attack.
    Bool allow_destroyed_attack
    UnitID destroyed_attack_unit
    UnitID surge_target
    Hidden<Vector<Unit>> expired_reserves
    Bool prebattle_scouts
    TimingState timing
    UnitVector units # required
    UnitVector reserve_units # required
    # Offboard whole units retain carrier-model identity (18.01 p.64).
    UnitVector embarked_units
    # Offboard model/weapon button context (Firing Deck p.81).
    UnitID selected_passenger_bank
    ModelID selected_passenger_model
    TerrainGeometryVector terrain_geometry
    TerrainAreaVector terrain_areas
    Objective[4] objectives
    MissionScoringMode mission_scoring

    UnitID oath_of_moment_target
    # Insane Bravery is once per battle, not reset by phase/turn cleanup (p.56).
    Bool[2] has_used_insane_bravery
    Bool[2] has_used_shadow_in_the_warp

    # Pending Apply/Ignore detail is editor context, not a new choice domain.
    UnitID selected_warlord_unit
    AttackModifierChoice pending_modifier_choice
    ModifierSelectionKind pending_modifier_kind
    PendingSourceEvents active_source_events
    SourceInstances source_instances
    SourceUseRecords source_uses
    SourceEffects source_effects
    SourceEffectKey next_source_effect
    SourceEffectKey next_source_generation
    AttackSequenceInfo attack_info
    # Actual hit/loss provenance for detachment post-attack reactions.
    OrksAttackRecords orks_attack_records
    LinearlyDistributedInt<0, 1025> orks_attack_serial
    Bool move_requires_objective
    UnitID constrained_mover
    EntityIdentity orks_reaction_target
    Bool orks_attack_active
    SourceBank orks_support_bank
    UnitID orks_selected_unit
    # Active group labels/target are editor infrastructure for p.19 decisions.
    AllocationGroups active_allocation_groups
    UnitID active_allocation_target
    Bool[2] obtained_extra_cp_this_round
    CommandPoints[2] command_points
    LinearlyDistributedInt<0, MAX_ROUNDS> current_round
    Bool current_player
    Bool starting_player
    Bool current_decision_maker
    Faction[2] players_faction
    # Per-player army identity/selection, independent of legacy roster IDs
    # (Orks faction page; user maximum three detachments and no points/DP).
    ArmyConfiguration[2] armies
    VictoryPoints[2] score

    PhaseInfo phase_info

    Attack attack
    RerollableDice current_roll
    RerollableDicePair current_pair_roll

    CurrentStateDescription current_state

    # Implementation identity allocation: removals/returns must keep the same entity
    # behind stored references (destruction p.19; returning models p.88).
    fun identify_unit(Unit unit):
        if unit.identity.value == 0:
            assert(self.next_identity.value < MAX_ENTITY_IDENTITIES, "entity identity capacity exceeded")
            unit.identity = self.next_identity.value + 1
            self.next_identity = self.next_identity + 1
        let i = 0
        while i < unit.models.size():
            ref model = unit.models[i]
            if model.identity.value == 0:
                assert(self.next_identity.value < MAX_ENTITY_IDENTITIES, "entity identity capacity exceeded")
                model.identity = self.next_identity.value + 1
                self.next_identity = self.next_identity + 1
                model.original_unit = unit.identity
            i = i + 1

    # Assign roster identities before attachment/deployment so component provenance
    # survives transfer (Leader/Support pp.66–67; starting strength p.86).
    fun identify_units():
        let i = 0
        while i < self.reserve_units.size():
            self.identify_unit(self.reserve_units[i])
            mark_unit_offboard(self.reserve_units[i], true)
            i = i + 1
        i = 0
        while i < self.units.size():
            self.identify_unit(self.units[i])
            i = i + 1

    # Resolve an entity rather than reuse a vacated positional target; this is a
    # storage invariant supporting attack targets/destruction (pp.17/19).
    fun find_unit(EntityIdentity identity) -> Int:
        if identity.value <= 0:
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
        assert(self.turn_serial.value + 1 < MAX_TURN_SERIAL, "turn serial capacity exceeded")
        self.turn_serial = self.turn_serial + 1
        refresh_source_effects(self, TimingWindow::none)
        # Turn-local restrictions expire identically in all storage banks;
        # embark/reserve must not preserve a stale Advance/Fall Back gate.
        let bank : SourceBank
        for bank_index in range(3):
            bank.value = bank_index
            for slot in range(source_bank_size(self, bank)):
                ref unit = source_bank_unit(self, bank, slot)
                unit.reset_turn_history()
                unit.has_run = false
                unit.has_moved = false
                unit.has_charged = false
                unit.can_shoot = true
                unit.can_charge = true
                if unit.owned_by_player1 == self.current_player:
                    unit.has_fought = false
                    unit.has_shoot = false

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
        assert(self.phase_serial.value + 1 < MAX_PHASE_SERIAL, "phase serial capacity exceeded")
        self.phase_serial = self.phase_serial + 1
        self.phase_info.already_used_stratagems[0].clear()
        self.phase_info.already_used_stratagems[1].clear()
        # Phase limits/effect expiry do not depend on battlefield presence
        # (pp28–30/54; appendix01.02.02/01.02.04).
        let bank : SourceBank
        for bank_index in range(3):
            bank.value = bank_index
            for slot in range(source_bank_size(self, bank)):
                ref unit = source_bank_unit(self, bank, slot)
                unit.clear_phase_modifiers()
                unit.has_fought = false
                unit.history.used_stratagem_this_phase = false
                unit.history.stratagem_targeted_by_player[0] = false
                unit.history.stratagem_targeted_by_player[1] = false

    # A phase starts with fresh phase usage and effects, before its start window
    # (pp.28–30/54). End effects are resolved before this state is expired.
    fun begin_phase(BattlePhase phase):
        self.clear_phase_modifiers()
        self.timing.phase = phase
        # Offboard banks have no battlefield anchors in this phase. Arrival
        # must not reuse last phase's coherency/engagement snapshot (01.02.03).
        let bank : SourceBank
        for bank_index in range(3):
            bank.value = bank_index
            for bank_slot in range(source_bank_size(self, bank)):
                ref unit = source_bank_unit(self, bank, bank_slot)
                unit.history.phase_start_members.clear()
                unit.history.phase_start_engagements.clear()
        for slot in range(self.units.size()):
            for member in range(self.units[slot].models.size()):
                if self.units[slot][member].is_alive() and !self.units[slot][member].off_battlefield:
                    self.units[slot].history.phase_start_members.append(self.units[slot][member].identity)
            for enemy in range(self.units.size()):
                if self.units[slot].owned_by_player1 != self.units[enemy].owned_by_player1 and self.units[slot].is_engaged_with(self.units[enemy]):
                    self.units[slot].history.phase_start_engagements.append(self.units[enemy].identity)
        refresh_source_effects(self, TimingWindow::none)
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
        refresh_source_effects(self, self.timing.window)
        self.timing.stage = TimingStage::mission_rules
        self.timing.open = false
        self.timing.stage = TimingStage::closed
        self.current_decision_maker = self.current_player

    fun get_current_player_faction() -> Faction:
        return self.players_faction[int(self.current_player)]

    # Editor infrastructure: fixed arrays have no generated Godot getter.
    # Expose one bounded CP entry for displays/fixtures supporting spending
    # and affordability (p.54), without changing storage or action domains.
    fun command_points_for_player(Bool player) -> ref CommandPoints:
        return self.command_points[int(player)]

    # Fixed arrays need a reference accessor for editor configuration and
    # fixtures, just like CP; no copied army may lose a selection (core p.8).
    fun army_for_player(Bool player) -> ref ArmyConfiguration:
        return self.armies[int(player)]

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
        return self.can_use_strat_with_cost(player, strat, strat.cost())

    # New Orks cards require their selected package, independently of the
    # roster and all CP restrictions (Orks detachment source sections).
    fun stratagem_selected_for_player(Bool player, Stratagem strat) -> Bool:
        let package = strat.orks_detachment()
        return package == OrksDetachment::none or (self.armies[int(player)].faction == ArmyFaction::orks and self.armies[int(player)].has_detachment(package))

    # Printed extra costs/free-use effects still obey phase restrictions (p.54)
    # and the supplied appendix02.02.01 maximum +1CP increase. An explicit
    # final-cost input must not bypass the modifier helper's cap.
    fun can_use_strat_with_cost(Bool player, Stratagem strat, Int final_cost) -> Bool:
        return self.stratagem_selected_for_player(player, strat) and final_cost >= 0 and final_cost <= strat.cost() + 1 and self.command_points[int(player)] >= final_cost and !self.has_used_strat(strat, int(player)) and self.stratagem_battle_limit_available(player, strat)

    # Target bookkeeping belongs to each payer independently (pp.9/54).
    # Only the named Orks cards override shocked/destroyed target gates;
    # their future actions still check the full printed timing/keywords.
    fun can_target_strat_with_cost(Bool player, Stratagem strat, Unit target, Int cost) -> Bool:
        if strat == Stratagem::overwatch and unit_orks_effect(self, target, OrksEffectKind::overwatch_blocked) > 0:
            return false
        let policy = strat.target_policy()
        let present = !target.empty()
        if policy == StratagemTargetPolicy::destroyed_unit:
            present = destroyed_stratagem_target(target)
        let friendly = strat.orks_detachment() == OrksDetachment::none or target.owned_by_player1 == player
        return self.can_use_strat_with_cost(player, strat, cost) and friendly and present and !target.history.stratagem_targeted_by_player[int(player)] and !(target.battle_socked and target.owned_by_player1 == player and policy != StratagemTargetPolicy::allow_shocked)

    # Each player may target a unit once per phase (p54); Orks/Hunta-Rig
    # Tramplasquig Charge applies its discount before affordability.
    fun can_target_strat(Bool player, Stratagem strat, Unit target) -> Bool:
        return self.can_target_strat_with_cost(player, strat, target, orks_datasheet_stratagem_cost(strat, target))

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

    # Targeted use pays the actual cost (p54), including Orks/Hunta-Rig
    # Tramplasquig Charge; free use still consumes phase/target limits.
    fun commit_stratagem(Bool player, Stratagem strat, Unit target):
        self.commit_stratagem_with_cost(player, strat, target, orks_datasheet_stratagem_cost(strat, target))

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
            self[source].history.last_ranged_attack_turn = self.turn_serial.value + 1

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
            if !unit.off_battlefield and unit.owned_by_player1 == player:
                for j in range(unit.models.size()):
                    if self.model_in_objective_range(unit[j], objective):
                        total = total + max(0, unit.model_objective_control(j))
                        if !unit.battle_socked:
                            total = total + orks_bunka_passenger_control(self, unit[j], player)
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
    if identity.value == 0:
        return true
    if identity.value <= 0 or identity.value > next_identity:
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
    if !valid_attachment_state(unit) or !register_identity(unit.identity, next_identity, seen):
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
    while i < unit.attached_units.size():
        if !register_identity(unit.attached_units[i].identity, next_identity, seen):
            return false
        i = i + 1
    return true

# Retained destroyed models or a real casualty archive provide evidence;
# an arbitrary empty/unidentified unit cannot receive a destroyed-unit card
# (Orks Infested War Zone / Flyin' Headbutt; destruction core p.87).
fun destroyed_stratagem_target(Unit target) -> Bool:
    if target.identity.value == 0 or (target.models.empty() and target.destroyed_models.value.empty()):
        return false
    for surviving in range(target.models.size()):
        if target[surviving].is_alive():
            return false
    return true

# Keyword conditions are source metadata, not arbitrary numeric permissions.
# Check saved roots before restoring editor choices (appendix02.05.01/p.78).
fun valid_weapon_condition(WeaponRule rule) -> Bool:
    let keyword : Keyword
    return rule.parameter_increment_source.value >= 0 and rule.parameter_increment_source.value < MAX_SOURCE_EFFECT_KEY and rule.parameter_increment_amount.value >= 0 and rule.parameter_increment_amount.value < MAX_CHARACTERISTIC and rule.source_effect.value >= 0 and rule.source_effect.value < MAX_SOURCE_EFFECT_KEY and rule.kind.value >= 0 and rule.kind.value <= WeaponRuleKind::supa_hazardous.value and rule.parameter.value >= 0 and rule.parameter.value < MAX_CHARACTERISTIC and rule.target_condition.valid(max(keyword))

# Compatibility/integrity gate: configurations cannot bypass their bounded
# policies; identity integrity protects the lifecycle rules (pp.19/88).
fun valid_state_foundations(Board board) -> Bool:
    if !valid_attack_modifier_choice(board.pending_modifier_choice) or board.pending_modifier_kind.value < 0 or board.pending_modifier_kind.value > ModifierSelectionKind::hit_roll.value:
        return false
    if !valid_orks_army_state(board) or !valid_source_foundations(board) or !valid_orks_detachment_foundations(board):
        return false
    if !valid_rule_modifiers(board.attack_info.skill_modifiers) or !valid_rule_modifiers(board.attack_info.ap_modifiers) or !valid_rule_modifiers(board.attack_info.damage_modifiers):
        return false
    for configured_player in range(2):
        if !army_configuration_valid(board.armies[configured_player]):
            return false
    for pending_rule in range(board.pending_weapon_abilities.size()):
        if !valid_weapon_condition(board.pending_weapon_abilities[pending_rule]):
            return false
    for selected_rule in range(board.attack_info.selected_weapon_rules.size()):
        if !valid_weapon_condition(board.attack_info.selected_weapon_rules[selected_rule]):
            return false
    for granted_rule in range(board.attack_info.temporary_weapon_abilities.size()):
        if !valid_weapon_condition(board.attack_info.temporary_weapon_abilities[granted_rule]):
            return false
    if !valid_passenger_links(board):
        return false
    if board.schema_version.value != STATE_SCHEMA_VERSION or board.next_identity < 0 or board.next_identity.value >= MAX_IDENTITY_SEQUENCE or board.phase_serial < 0 or board.phase_serial.value >= MAX_PHASE_SERIAL or board.turn_serial < 0 or board.turn_serial.value >= MAX_TURN_SERIAL:
        return false
    if board.destroyed_attack_unit.get() < 0 or board.destroyed_attack_unit.get() >= MAX_UNIT_COUNT or (board.allow_destroyed_attack and board.destroyed_attack_unit.get() >= board.units.size()):
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
        if objective.home.value < 0 or objective.home.value > 2:
            return false
        if objective.terrain_objective:
            if objective.area_id.value >= board.terrain_areas.size() or !point_in_terrain_area(board.objective_position(index), board.terrain_areas[objective.area_id.value]):
                return false
        else:
            for area_index in range(board.terrain_areas.size()):
                if point_in_terrain_area(board.objective_position(index), board.terrain_areas[area_index]):
                    return false
    for unit in range(board.units.size()):
        # Pending death provenance must identify the attack to which its
        # delayed trigger belongs; reject a save that could strand it (p.87).
        for model in range(board.units[unit].models.size()):
            ref casualty = board.units[unit][model]
            if casualty.destruction_pending:
                if casualty.is_alive() or casualty.state == ModelState::normal or (casualty.destroyed_by_attack and !casualty.destroying_unit_known):
                    return false
                if casualty.destroying_unit_known and casualty.destroying_unit.get() >= board.units.size():
                    return false
    let seen : Vector<Int>
    let i = 0
    while i < board.units.size():
        if !valid_unit_numeric_history(board.units[i]) or !valid_unit_identities(board.units[i], board.next_identity.value, seen):
            return false
        i = i + 1
    i = 0
    while i < board.reserve_units.size():
        if !valid_unit_numeric_history(board.reserve_units[i]) or !valid_unit_identities(board.reserve_units[i], board.next_identity.value, seen):
            return false
        i = i + 1
    i = 0
    while i < board.embarked_units.size():
        if !valid_unit_numeric_history(board.embarked_units[i]) or !valid_unit_identities(board.embarked_units[i], board.next_identity.value, seen):
            return false
        i = i + 1
    return true

# Reject malformed bounded history on load before it can change range/Heavy
# decisions or inferred observations (p.82 / user numeric-storage requirement).
fun valid_model_numeric_history(Model model) -> Bool:
    if model.profile.base_size() == 0.0 and model.geometry.proxy_diameter_mm.value == 0 and !model.geometry.unsupported_footprint:
        return false
    if model.geometry.proxy_diameter_mm.value < 0 or model.geometry.proxy_diameter_mm.value > 1000:
        return false
    if model.orks_enhancement.value < 0 or model.orks_enhancement.value > OrksEnhancement::warphead.value or model.orks_upgrade_origin.value < 0 or model.orks_upgrade_origin.value >= MAX_IDENTITY_SEQUENCE or model.destroying_unit_identity.value < 0 or model.destroying_unit_identity.value >= MAX_IDENTITY_SEQUENCE or model.destroyed_phase.value < 0 or model.destroyed_phase.value >= MAX_PHASE_STAMP:
        return false
    for ork_effect in range(model.orks_effects.size()):
        ref grant = model.orks_effects[ork_effect]
        if grant.kind.value <= 0 or grant.kind.value > max(grant.kind) or grant.source_effect.value < 0 or grant.source_effect.value >= MAX_SOURCE_EFFECT_KEY or grant.amount.value < 0 or grant.amount.value >= MAX_CHARACTERISTIC or grant.associated_unit.value < 0 or grant.associated_unit.value >= MAX_IDENTITY_SEQUENCE:
            return false
    for riled_index in range(model.riled_source_effects.size()):
        if model.riled_source_effects[riled_index].value < 0 or model.riled_source_effects[riled_index].value >= MAX_SOURCE_EFFECT_KEY:
            return false
    if !valid_attack_modifier_permissions(model.attack_modifier_permissions):
        return false
    if !valid_stat(model.random_movement) or !valid_stat(model.deadly_demise):
        return false
    if !valid_incoming_attack_modifiers(model.incoming_attack_modifiers):
        return false
    if !valid_characteristic_modifiers(model.characteristic_modifiers):
        return false
    if model.damaged_threshold.value < 0 or model.damaged_threshold.value >= MAX_WOUNDS:
        return false
    if !valid_model_equipment(model):
        return false
    if model.transport_capacity.value < 0 or model.transport_capacity.value > MAX_UNIT_MODELS or model.transport_space.value < 1 or model.transport_space.value > MAX_UNIT_MODELS or model.firing_deck.value < 0 or model.firing_deck.value > MAX_UNIT_MODELS:
        return false
    for modifier_slot in range(model.characteristic_modifiers.size()):
        if model.characteristic_modifiers[modifier_slot].weapon_scope.value > model.weapons.size():
            return false
    for condition_slot in range(MAX_WEAPONS):
        if !valid_weapon_condition(model.hunter_profile_conditions[condition_slot]):
            return false
        for granted_condition in range(model.additional_weapon_rules[condition_slot].size()):
            if !valid_weapon_condition(model.additional_weapon_rules[condition_slot][granted_condition]):
                return false
    if model.history.vertical_distance.value < 0 or model.history.vertical_distance.value >= MAX_VERTICAL_DISTANCE:
        return false
    if model.history.horizontal_segments.size() > MAX_MOVEMENT_SEGMENTS:
        return false
    for i in range(model.history.horizontal_segments.size()):
        if model.history.horizontal_segments[i].value < 0 or model.history.horizontal_segments[i].value >= MAX_HORIZONTAL_SQUARE:
            return false
    return true

# Timestamps remain within configured serial ranges, including zero sentinel.
# Live and archived bearers must both retain bounded numeric history (pp.19/88).
fun valid_unit_numeric_history(Unit unit) -> Bool:
    if unit.movement_distance_limit.value < 0 or unit.movement_distance_limit.value >= 258:
        return false
    if unit.psyker_level.value < 0 or unit.psyker_level.value >= MAX_CHARACTERISTIC or unit.orks_psychic_usage.budget.round_stamp.value < 0 or unit.orks_psychic_usage.budget.round_stamp.value >= MAX_ROUNDS or unit.orks_psychic_usage.budget.spent.value < 0 or unit.orks_psychic_usage.budget.spent.value >= MAX_CHARACTERISTIC or unit.orks_psychic_usage.roar_phase.value < 0 or unit.orks_psychic_usage.roar_phase.value >= MAX_PHASE_STAMP or unit.orks_psychic_usage.visions_phase.value < 0 or unit.orks_psychic_usage.visions_phase.value >= MAX_PHASE_STAMP:
        return false
    if unit.history.embarked_phase.value < 0 or unit.history.embarked_phase.value >= MAX_PHASE_STAMP or unit.history.ingress_turn.value < 0 or unit.history.ingress_turn.value >= MAX_TURN_STAMP:
        return false
    if unit.return_slot.get() < 0 or unit.return_slot.get() >= MAX_UNIT_COUNT:
        return false
    if !valid_fight_history(unit.history) or !valid_action_history(unit.history):
        return false
    for i in range(unit.phase_modifiers.charge_roll.size()):
        ref modifier = unit.phase_modifiers.charge_roll[i]
        if modifier.amount.value < 0 or modifier.amount.value >= MAX_RULE_MODIFIER or modifier.operation.value < 0 or modifier.operation.value > ModifierOperation::subtract.value:
            return false
    if unit.history.last_move_phase.value < 0 or unit.history.last_move_phase.value >= MAX_PHASE_STAMP or unit.history.selected_move_phase.value < 0 or unit.history.selected_move_phase.value >= MAX_PHASE_STAMP or unit.history.last_ranged_attack_turn.value < 0 or unit.history.last_ranged_attack_turn.value >= MAX_TURN_STAMP or unit.history.declared_charge_phase.value < 0 or unit.history.declared_charge_phase.value >= MAX_PHASE_STAMP or unit.history.charge_move_phase.value < 0 or unit.history.charge_move_phase.value >= MAX_PHASE_STAMP:
        return false
    let deck_capacity = 0
    for deck_model in range(unit.models.size()):
        deck_capacity = deck_capacity + unit[deck_model].firing_deck.value
    if deck_capacity > MAX_DECK_SELECTIONS:
        return false
    for i in range(unit.models.size()):
        if !valid_model_numeric_history(unit.models[i]):
            return false
    for i in range(unit.destroyed_models.value.size()):
        if !valid_model_numeric_history(unit.destroyed_models.value[i]):
            return false
    return true

# Fight phase snapshots/once-per-step guards are bounded save infrastructure
# supporting pp.38–42; no invalid stamp may bypass eligibility on load.
fun valid_fight_history(UnitHistory history) -> Bool:
    return history.pile_in_phase.value >= 0 and history.pile_in_phase.value < MAX_PHASE_STAMP and history.consolidation_phase.value >= 0 and history.consolidation_phase.value < MAX_PHASE_STAMP and history.engaged_fight_start_phase.value >= 0 and history.engaged_fight_start_phase.value < MAX_PHASE_STAMP and history.fight_eligible_phase.value >= 0 and history.fight_eligible_phase.value < MAX_PHASE_STAMP and history.consolidation_fight_pending.value >= 0 and history.consolidation_fight_pending.value < MAX_PHASE_STAMP


# p.58 infrastructure: action handles must be unique, ordered bounded turn
# stamps; contradictory completion state must not survive a saved-game load.
fun valid_action_history(UnitHistory history) -> Bool:
    let previous = 0
    let pending = false
    for i in range(history.action_records.size()):
        ref progress = history.action_records[i]
        if progress.started_turn.value <= previous or progress.started_turn.value >= MAX_TURN_STAMP or (progress.completed and (!progress.resolved or progress.failed)):
            return false
        previous = progress.started_turn.value
        pending = pending or !progress.resolved
    return pending == history.action_pending

# Actual equipment and same-model primary links must remain valid in live
# and archived models (pp.19/88; appendix04.01.03).
fun valid_model_equipment(Model model) -> Bool:
    if model.datasheet.value < 0 or model.datasheet.value >= MAX_DATASHEETCODE:
        return false
    let catalog : Weapon
    for slot in range(model.weapons.size()):
        ref equipped = model.weapons[slot]
        if equipped.profile.value < 0 or equipped.profile.value > max(catalog) or equipped.profile.value == Weapon::none.value:
            return false
        let primary = equipped.secondary_profile_of.value
        if primary < 0 or primary > slot:
            return false
        if primary > 0 and (model.weapons[primary - 1].secondary_profile_of.value != 0 or model.weapons[primary - 1].profile.family_id() != equipped.profile.family_id()):
            return false
    return true
