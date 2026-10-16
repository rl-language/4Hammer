import attack_results

# Flat reaction execution reuses the one Attack frame. Faction code supplies
# eligibility, costs and a typed next request; no recursive Attack frame is
# allowed (shared lifetime infrastructure; core attacks pp16-24).
act attack_with_reactions(ctx Board board, frm UnitID source, frm UnitID target, frm Bool melee, frm Bool overwatch) -> AttackWithReactions:
    frm caller_target = board.forced_attack_target
    frm continuing = true
    frm first = true
    while continuing:
        if !first and !melee:
            act choose_reaction_shooting_kind(ShootingKind kind) {shooting_kind_valid(board, source, kind)}
            board[source].shooting_kind = kind
        board.attack = attack(board, source, target, melee, overwatch)
        subaction*(board) board.attack
        board.shared_actions.resolve_faction_post_attack = faction_post_attack(board, source, melee)
        subaction*(board) board.shared_actions.resolve_faction_post_attack
        frm request = board.shared_actions.resolve_faction_post_attack.reaction
        continuing = request.available
        if continuing:
            source = request.source
            target = request.target
            melee = request.melee
            overwatch = request.overwatch
            board.forced_attack_target = 0
            if request.restrict_target:
                board.forced_attack_target = board[target].identity
            first = false
    board.forced_attack_target = caller_target
