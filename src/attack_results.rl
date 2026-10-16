import board

# Shared stable-target lookup; hits/loss/destruction are actual resolved facts
# useful to any reaction rule (core pp18-24/87).
fun attack_result_record(Board board, EntityIdentity target) -> ref AttackResultRecord:
    let found = -1
    for record in range(board.attack_records.size()):
        if board.attack_records[record].target == target:
            found = record
    if found < 0:
        let entry : AttackResultRecord
        entry.target = target
        board.attack_records.append(entry)
        found = board.attack_records.size() - 1
    return board.attack_records[found]

# Record only completed attack outcomes; declaration alone is not a hit
# or lost wound, and prevention is resolved first (core pp18-24/87).
fun begin_attack_results(Board board):
    assert(board.attack_serial.value + 1 < 1025, "attack serial capacity exceeded")
    board.attack_serial = board.attack_serial + 1
    board.attack_records.clear()
    board.attack_active = true

# Record only completed attack outcomes; declaration alone is not a hit
# or lost wound, and prevention is resolved first (core pp18-24/87).
fun record_attack_hits(Board board, UnitID target, Int count):
    if board.attack_active and count > 0:
        ref record = attack_result_record(board, board[target].identity)
        add_attack_count(record.successful_hits, count)
        record_faction_hit_tags(board, record, count)

# Record only completed attack outcomes; declaration alone is not a hit
# or lost wound, and prevention is resolved first (core pp18-24/87).
fun record_attack_wound_loss(Board board, Unit unit, ModelID model, Int lost, Bool from_attack):
    if lost > 0 and from_attack and board.attack_active:
        ref record = attack_result_record(board, unit.identity)
        add_attack_count(record.wounds_lost, min(lost, unit[model].wounds_left()))

# Record only completed attack outcomes; declaration alone is not a hit
# or lost wound, and prevention is resolved first (core pp18-24/87).
fun record_attack_unit_destruction(Board board, Unit unit):
    if board.attack_active and live_attachment_strength(unit) == 0:
        ref destruction_record = attack_result_record(board, unit.identity)
        destruction_record.destroyed = true
        unit.destroyed_attack = board.attack_serial
        unit.destroyed_phase = board.phase_serial.value + 1

# Close the activation only after all attack-end source events resolve.
fun end_attack_results(Board board):
    board.attack_active = false

# Save validation preserves generic ledger/target/modifier invariants;
# tags cannot fabricate hits beyond the activation total (pp18/87).
fun valid_attack_results(Board board) -> Bool:
    if board.attack_serial.value < 0 or board.attack_serial.value >= 1025 or board.forced_attack_target.value < 0 or board.forced_attack_target.value > board.next_identity.value:
        return false
    if !valid_rule_modifiers(board.attack_info.attack_hit_modifiers) or !valid_rule_modifiers(board.attack_info.attack_wound_modifiers) or !valid_rule_modifiers(board.attack_info.unit_ability_hit_modifiers):
        return false
    for record in range(board.attack_records.size()):
        ref entry = board.attack_records[record]
        if entry.target.value <= 0 or entry.target.value > board.next_identity.value or entry.successful_hits.value < 0 or entry.successful_hits.value >= MAX_COMBAT_COUNTER or entry.wounds_lost.value < 0 or entry.wounds_lost.value >= MAX_COMBAT_COUNTER:
            return false
        for tag_index in range(1):
            if entry.tagged_hits[tag_index].value < 0 or entry.tagged_hits[tag_index].value > entry.successful_hits.value:
                return false
        for previous in range(record):
            if board.attack_records[previous].target == entry.target:
                return false
    return true
