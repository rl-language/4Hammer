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

cls Board:
    UnitVector units # required
    UnitVector reserve_units # required
    UnitID oath_of_moment_target
    AttackSequenceInfo attack
    LinearlyDistributedInt<0, MAX_CP>[2] command_points
    LinearlyDistributedInt<0, MAX_ROUNDS> current_round
    Bool current_player
    Bool current_decision_maker
    Faction[2] players_faction
    LinearlyDistributedInt<0, 50>[2] score

    fun clear_phase_modifiers():
        let i = 0
        while i != self.units.size():
            self.units[i].clear_phase_modifiers()
            i = i + 1

    fun get_score(Int player_id) -> Int:
        return self.score[player_id].value

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

    fun score_objective(Int x, Int y):
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
        if oc[int(self.current_player)] == 0: 
            return
        if oc[int(self.current_player)] > oc[int(!self.current_player)]:
            self.score[int(self.current_player)] = self.score[int(self.current_player)] + 5

    fun score():
        self.score_objective(12, 15)
        self.score_objective(32, 15)
        self.score_objective(22, 9)
        self.score_objective(22, 21)

fun append_to_string(ModelID to_add, String output):
    append_to_string(to_add.id, output)

fun parse_string(ModelID result, String buffer, Int index) -> Bool:
    return parse_string(result.id, buffer, index)


fun append_to_string(UnitID to_add, String output):
    append_to_string(to_add.id, output)

fun parse_string(UnitID result, String buffer, Int index) -> Bool:
    return parse_string(result.id, buffer, index)

