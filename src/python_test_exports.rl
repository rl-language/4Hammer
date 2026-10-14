import rules

# Binding infrastructure, not a tabletop rule. RLC instantiates generic
# methods/serialization only when called from Rulebook. Export these primitive
# operations in the same library Godot uses, so Python can construct fixtures,
# inspect suspended frames and test malformed saves without compiling tests.
# This function is never called by the game or test runner; it contains no
# fixtures, rule expectations or assertions. Generated lifecycle is retained.
fun export_python_test_bindings():
    let board : Board
    board.units.resize(1)
    board.units.empty()
    board.units[0].models.resize(1)
    board.units[0].models.try_append(board.units[0].models[0])
    board.units[0].models[0].transport_space = 1
    board.units[0].models[0].keywords.append(Keyword::infantry)
    board.units[0].models[0].keywords.pop()
    board.units[0].models[0].history.horizontal_segments.empty()
    board.battle_points_limit = 0
    board.source_uses.empty()
    board.source_effects.empty()
    board.active_source_events.empty()
    let bodyguards : BodyguardPermissions
    bodyguards.empty()
    let modifiers : RuleModifiers
    modifiers.empty()
    let boyz : OrksBoyzLoadouts
    boyz.resize(1)
    boyz.erase(0)
    let nobz : OrksNobLoadouts
    nobz.resize(1)
    nobz.erase(0)
    let weapon : AttackWeaponID
    weapon = 0
    let share : AttackShareChoice
    share = 1
    let phase : PhaseSerial
    phase = 0
    let turn : TurnSerial
    turn = 0
    let rotation : MovementRotation
    rotation = 0
    let paths : Vector<ModelPath>
    paths.resize(1)
    paths.erase(0)
    let points : CommandPoints
    let domain = enumerate(points)
    size_as_observation_tensor(points)
    let unchecked : BoundedVector<Int, 2>
    unchecked._data.append(1)
    unchecked._data.append(2)
    let checked : CheckedVector<Int, 2>
    checked.append(1)
    checked.try_append(2)
    checked.has_capacity()
    checked.size()
    checked[0]
    from_string(checked, to_string(unchecked))
    let unit : Unit
    from_string(unit, to_string(unit))
    let predicate : KeywordPredicate
    predicate.required_count = 0
    from_string(predicate, to_string(predicate))
    let army : ArmyConfiguration
    from_string(army, to_string(army))
    let stat : Stat
    from_string(stat, to_string(stat).to_indented_lines())
    let history : ModelHistory
    from_string(history, to_string(history))
    from_string(board, to_string(board))
    let board_index = 0
    from_string(board, to_string(board), board_index)
    let charge_frame : Charge
    let charge_index = 0
    from_string(charge_frame, to_string(charge_frame), charge_index)
    let melee_frame : MeleeMove
    let melee_index = 0
    from_string(melee_frame, to_string(melee_frame), melee_index)
    let source_frame : MovementSourceResolution
    from_string(source_frame, to_string(source_frame))
    let selection : ChooseWeaponAbilities
    from_string(selection, to_string(selection))
    let modifier_selection : ChooseAttackModifiers
    from_string(modifier_selection, to_string(modifier_selection))
