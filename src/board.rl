import units

cls AttackSequenceInfo:
    UnitID source_unit_id # required
    UnitID target_unit_id # required
    Bool hit_roll_bonus
    Bool wound_roll_malus
    Bool reroll_hits
    Bool only_hits_on_6
    Bool reroll_wounds
    Bool reroll1_wounds
    Bool greater_strenght_wound_protection
    Int target_toughness
    Weapon source
    BInt<0, MAX_ROUNDS> current_round

const MAX_CP = 4
const MAX_ROUNDS = 6

using AlreadyUsedStratagems = BoundedVector<Stratagem, 5>

cls PhaseInfo:
    AlreadyUsedStratagems[2] already_used_stratagems
    
cls Board:
    UnitVector units # required
    UnitVector reserve_units # required
    UnitID oath_of_moment_target
    AttackSequenceInfo attack_info
    LinearlyDistributedInt<0, MAX_CP>[2] command_points
    LinearlyDistributedInt<0, MAX_ROUNDS> current_round
    Bool current_player
    Bool starting_player
    Bool current_decision_maker
    Faction[2] players_faction
    LinearlyDistributedInt<0, 50>[2] score
    Bool[4][2] pinned_objectives

    PhaseInfo phase_info

    Attack attack
    Overwatch overwatch
    RerollableDice current_roll
    RerollableDicePair current_pair_roll

    fun clear_phase_modifiers():
        self.phase_info.already_used_stratagems[0].clear()
        self.phase_info.already_used_stratagems[1].clear()
        let i = 0
        while i != self.units.size():
            self.units[i].clear_phase_modifiers()
            i = i + 1

    fun get_score(Int player_id) -> Int:
        return self.score[player_id].value

    fun mark_strat_used(Stratagem strat, Int player):
        self.phase_info.already_used_stratagems[player].append(strat)

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

    fun count_models(Int player_id) -> Int:
        let i = 0
        let count = 0
        while i != self.units.size():
            if self[i].owned_by_player1 == bool(player_id):
                count = count + self[i].models.size()
            i = i + 1 
        return count

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

    fun remove_empty_units():
        let i = self.units.size() - 1
        while i >= 0:
            if self[i].models.empty():
               self.units.erase(i)
            i = i - 1 

    fun get_objective_controller(Int x, Int y) -> Int:
        let v : Vector2D
        v.x = x
        v.y = y
        let oc : Int[2] 
        let i = 0
        while i != self.units.size():
            ref unit = self[i]
            let j = 0
            while j != unit.models.size():
                if 3.0 >= unit[j].position.as_vector().distance(v):
                    oc[unit.owner_id()] = unit.models[j].profile.control()
                j = j + 1
            i = i + 1
        if oc[0] == 0 and oc[1] == 0: 
            return -1
        if oc[0] > oc[1]:
            return 0
        return 1

    fun score_objective(Int x, Int y, Int objective_id):
        ref pinned_objective = self.pinned_objectives[int(self.current_player)][objective_id]
        let controller = self.get_objective_controller(x, y)
        if controller == 0:
            if pinned_objective:
                self.score[int(self.current_player)] = self.score[int(self.current_player)] + 5
            return
        if controller == int(self.current_player):
            self.score[int(self.current_player)] = self.score[int(self.current_player)] + 5
        else:
            pinned_objective = false

    fun get_objective_controller(Int objective_id) -> Int:
        if objective_id == 0:
            return self.get_objective_controller(12, 15)
        if objective_id == 1:
            return self.get_objective_controller(32, 15)
        if objective_id == 2:
            return self.get_objective_controller(22, 9)
        if objective_id == 3:
            return self.get_objective_controller(22, 21)
        assert(false, "unrechable")
        return -1

    fun score():
        self.score_objective(12, 15, 0)
        self.score_objective(32, 15, 1)
        self.score_objective(22, 9, 2)
        self.score_objective(22, 21, 3)

fun append_to_string(ModelID to_add, String output):
    append_to_string(to_add.id, output)

fun parse_string(ModelID result, String buffer, Int index) -> Bool:
    return parse_string(result.id, buffer, index)


fun append_to_string(UnitID to_add, String output):
    append_to_string(to_add.id, output)

fun parse_string(UnitID result, String buffer, Int index) -> Bool:
    return parse_string(result.id, buffer, index)

