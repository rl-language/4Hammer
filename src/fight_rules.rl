import board

# Release retained fighters only after their unit has attacked, or phase end;
# destruction effects then resolve before removal (supplied Fight on Death).
fun release_retained_fighters(Board board, UnitID source):
    for i in range(board[source].models.size()):
        if board[source][i].state == ModelState::fight_on_death:
            board[source][i].state = ModelState::pending_destruction
            board[source][i].destruction_released = true


# Phase end is the fallback for units that cannot/will not attack again. The
# common destruction engine retains trigger ordering and exact-once archives.
fun release_phase_retained_fighters(Board board):
    for i in range(board.units.size()):
        let source : UnitID
        source = i
        release_retained_fighters(board, source)
