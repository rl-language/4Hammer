import factions.orks.sources
import factions.orks.queries

# Concrete timing boundaries (core pp28-30/32-38; user Rules Sequencing).
# Each hook offers ONE atomic ability choice for the supplied controller in
# that exact window. Peer construction cannot mutate Board/queues/progress;
# started becomes true on accepted input. Core orders both controllers and
# owns mandatory finish gates. Read completed results before reusing a frame.
# No applicable input means an unavailable peer; pending returns false.

# Resolve one accepted timing event for player against the original pending
# queue. Caller checked pending_source_valid; construction may index the event
# immediately. Complete its required choices/effects and mark that entry resolved,
# committing required usage once. Preserve other entries and return control to
# player; core owns controller ordering and the surrounding timing window.
fun resolve_timing_source_ability(Board board, PendingSourceEvents pending, SourceEventID event, Bool player) -> OrksTimingSource:
    return orks_resolve_timing_source(board, pending, event, player)

# Reset only the adapter-owned per-controller timing-choice progress before
# core starts that controller's group. Do not refresh army/source usage, remove
# effects or reset the pending queue. Subsequent availability and choice hooks
# must interpret the same reset record consistently.
fun reset_faction_timing_progress(FactionTimingProgress progress):
    orks_reset_timing_progress(progress)

# Only the round_start boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_round_start(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::round_start, player)

# Pure availability for round_start; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun round_start_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::round_start, player, progress, mandatory_only)

# Only the round_end boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_round_end(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::round_end, player)

# Pure availability for round_end; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun round_end_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::round_end, player, progress, mandatory_only)

# Only the turn_start boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_turn_start(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::turn_start, player)

# Pure availability for turn_start; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun turn_start_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::turn_start, player, progress, mandatory_only)

# Only the turn_end boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_turn_end(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::turn_end, player)

# Pure availability for turn_end; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun turn_end_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::turn_end, player, progress, mandatory_only)

# Only the command_phase_start boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_command_phase_start(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::command_start, player)

# Pure availability for command_phase_start; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun command_phase_start_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::command_start, player, progress, mandatory_only)

# Only the command_abilities_step boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_command_abilities_step(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::command_abilities, player)

# Pure availability for command_abilities_step; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun command_abilities_step_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::command_abilities, player, progress, mandatory_only)

# Only the command_phase_end boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_command_phase_end(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::command_end, player)

# Pure availability for command_phase_end; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun command_phase_end_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::command_end, player, progress, mandatory_only)

# Only the movement_phase_start boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_movement_phase_start(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::movement_start, player)

# Pure availability for movement_phase_start; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun movement_phase_start_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::movement_start, player, progress, mandatory_only)

# Only the movement_phase_end boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_movement_phase_end(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::movement_end, player)

# Pure availability for movement_phase_end; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun movement_phase_end_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::movement_end, player, progress, mandatory_only)

# Only the shooting_phase_start boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_shooting_phase_start(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::shooting_start, player)

# Pure availability for shooting_phase_start; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun shooting_phase_start_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::shooting_start, player, progress, mandatory_only)

# Only the shooting_phase_end boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_shooting_phase_end(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::shooting_end, player)

# Pure availability for shooting_phase_end; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun shooting_phase_end_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::shooting_end, player, progress, mandatory_only)

# Only the charge_phase_start boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_charge_phase_start(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::charge_start, player)

# Pure availability for charge_phase_start; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun charge_phase_start_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::charge_start, player, progress, mandatory_only)

# Only the charge_phase_end boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_charge_phase_end(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::charge_end, player)

# Pure availability for charge_phase_end; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun charge_phase_end_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::charge_end, player, progress, mandatory_only)

# Only the fight_phase_start boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_fight_phase_start(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::fight_start, player)

# Pure availability for fight_phase_start; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun fight_phase_start_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::fight_start, player, progress, mandatory_only)

# Only the fight_phase_end boundary. Inputs are the original controller-owned
# progress/pending contexts; action order, costs and effects finish atomically.
fun on_fight_phase_end(Board board, CoreTimingProgress core_progress, FactionTimingProgress progress, PendingSourceEvents pending, Bool player) -> OrksTimingChoice:
    return orks_timing_choice(board, core_progress, progress, pending, TimingWindow::fight_end, player)

# Pure availability for fight_phase_end; mandatory_only controls the common finish gate.
# Does not reset uses, resolve sources or reopen a completed event.
fun fight_phase_end_abilities_pending(Board board, Bool player, FactionTimingProgress progress, Bool mandatory_only) -> Bool:
    return orks_timing_options_remaining(board, TimingWindow::fight_end, player, progress, mandatory_only)
