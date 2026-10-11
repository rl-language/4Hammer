import action
import machine_learning
import bounded_arg

# These are storage schemas, not edition or mission identifiers. Finite action
# domains remain separate from bounded storage and persistent identities.
const STATE_SCHEMA_VERSION = 8
const ACTION_SCHEMA_VERSION = 4
const OBSERVATION_SCHEMA_VERSION = 8

# Compatibility metadata for save/replay/ML callers; no tabletop rule defines this version.
fun get_state_schema_version() -> Int:
    return STATE_SCHEMA_VERSION

# Compatibility metadata for save/replay/ML callers; no tabletop rule defines this version.
fun get_action_schema_version() -> Int:
    return ACTION_SCHEMA_VERSION

# Compatibility metadata for save/replay/ML callers; no tabletop rule defines this version.
fun get_observation_schema_version() -> Int:
    return OBSERVATION_SCHEMA_VERSION

# Half-open storage bounds use the standard library's linear ML encoding.
# These are configurable supported ranges, not tabletop restrictions.
const MAX_CP = 257
const MAX_SCORE = 201
const MAX_CHARACTERISTIC = 257
const MAX_STAT_MODIFIER = 257
const MAX_RANDOM_STAT_RESULT = 513
const MAX_COMBAT_COUNTER = 4097
const MAX_WOUNDS = 4097
const MAX_HAZARDOUS_USES = 257
const MAX_STARTING_STRENGTH = 33
using CommandPoints = LinearlyDistributedInt<0, MAX_CP>
using VictoryPoints = LinearlyDistributedInt<0, MAX_SCORE>
using FixedStat = LinearlyDistributedInt<0, MAX_CHARACTERISTIC>
using Toughness = LinearlyDistributedInt<0, MAX_CHARACTERISTIC>
using CombatCounter = LinearlyDistributedInt<0, MAX_COMBAT_COUNTER>
using HazardousUses = LinearlyDistributedInt<0, MAX_HAZARDOUS_USES>
using StartingStrength = LinearlyDistributedInt<0, MAX_STARTING_STRENGTH>

# Preserve bounded observations/action enumeration while rejecting overflow.
# The standard BoundedVector.append silently drops full-capacity appends.
cls<T, Int capacity> CheckedVector:
    BoundedVector<T, capacity> _data

    # Expose the live count for selection bounds; capacity is not current roster size (p.86).
    fun size() -> Int:
        return self._data.size()

    # Expose configured collection capacity for static layout; this is implementation metadata.
    fun max_size() -> Int:
        return capacity

    # Detect an empty roster/temporary collection without indexing it (casualty bookkeeping p.19).
    fun empty() -> Bool:
        return self._data.empty()

    # Return a mutable entry so shared-context actions update the actual state, not a copy.
    fun get(Int index) -> ref T:
        return self._data[index]

    # Access the newly appended entry for setup/initialization (reserve setup pp.68–71).
    fun back() -> ref T:
        return self._data.back()

    # Replace an existing entry without changing roster size or inferred collection layout.
    fun set(Int index, T value):
        self._data[index] = value

    # Let callers check configured storage capacity before adding a roster entry (p.86).
    fun has_capacity() -> Bool:
        return self.size() < capacity

    # Reject full-capacity insertion rather than silently lose a model/component (pp.66–67/86).
    fun append(T value):
        assert(self.has_capacity(), "game collection capacity exceeded")
        self._data.append(value)

    # Offer recoverable capacity rejection without altering existing roster entries (p.86).
    fun try_append(T value) -> Bool:
        if !self.has_capacity():
            return false
        self.append(value)
        return true

    # Reject unsupported roster sizes instead of silently shortening the requested count (p.86).
    fun resize(Int size):
        assert(size >= 0 and size <= capacity, "game collection capacity exceeded")
        self._data.resize(size)

    # Compact model/reserve entries; active unit targets instead use retired slots (p.19).
    fun erase(Int index):
        self._data.erase(index)

    # Explicitly empty temporary/roster storage; does not itself authorize a game removal.
    fun clear():
        self._data.clear()

    # Remove/return the last stored entry for generic collection consumers; implementation adapter.
    fun pop() -> T:
        return self._data.pop()

fun<T, Int capacity> write_in_observation_tensor(CheckedVector<T, capacity> obj, Int observer_id, Vector<Float> output, Int index):
    write_in_observation_tensor(obj._data, observer_id, output, index)

fun<T, Int capacity> size_as_observation_tensor(CheckedVector<T, capacity> obj) -> Int:
    return size_as_observation_tensor(obj._data)

# Persistent handles are not positional action arguments. -1 means unassigned.
# Raw identities deliberately do not appear in observation tensors.
cls EntityIdentity:
    Int value

    # Maintain persistent identity invariants for destruction/return references (pp.19/88).
    fun init():
        self.value = -1

    # Maintain persistent identity invariants for destruction/return references (pp.19/88).
    fun equal(EntityIdentity other) -> Bool:
        return self.value == other.value

    # Maintain persistent identity invariants for destruction/return references (pp.19/88).
    fun assign(Int value):
        assert(value >= -1, "invalid entity identity")
        self.value = value

cls UnitHistory:
    Int last_move_phase
    Int last_ranged_attack_turn
    Bool was_set_up_this_turn
    Bool used_stratagem_this_phase
    Bool[2] stratagem_targeted_by_player
    Bool action_started
    Bool action_completed

    # Initialize lifecycle history without implying new eligibility rules (turn pp.28–30; setup pp.68–71).
    fun init():
        self.last_move_phase = -1
        self.last_ranged_attack_turn = -1
        self.was_set_up_this_turn = false
        self.used_stratagem_this_phase = false
        self.stratagem_targeted_by_player[0] = false
        self.stratagem_targeted_by_player[1] = false
        self.action_started = false
        self.action_completed = false

cls ModelHistory:
    Hidden<Float> distance_moved_this_turn
    Bool was_set_up_this_turn

cls StateSchema:
    Int value

    # Initialize current save compatibility metadata; no tabletop rule defines the schema.
    fun init():
        self.value = STATE_SCHEMA_VERSION

# Decode into a temporary unbounded vector to detect excess entries before mutation.
# Save infrastructure preserves configured roster counts rather than silently dropping models (p.86).
fun<T, Int capacity> parse_string(CheckedVector<T, capacity> result, String buffer, Int index) -> Bool:
    let candidate : Vector<T>
    if !parse_string(candidate, buffer, index) or candidate.size() > capacity:
        return false
    result.clear()
    let i = 0
    while i < candidate.size():
        result.append(candidate[i])
        i = i + 1
    return true

cls AttachmentComponent:
    EntityIdentity identity
    StartingStrength starting_strength
    Hidden<String> name

# Serialize the bounded backing collection for save/replay round trips; implementation
# infrastructure preserves roster contents and casualties (pp.19/86).
fun<T, Int capacity> append_to_string(CheckedVector<T, capacity> value, String output):
    append_to_string(value._data, output)

# Explicit timing state supports printed round/turn/phase boundaries (pp.28–30)
# and the user's sequencing definition; these enums are bounded ML state.
enum BattlePhase:
    none
    command
    movement
    shooting
    charge
    fight

    fun equal(BattlePhase other) -> Bool:
        return self.value == other.value

enum TimingWindow:
    none
    round_start
    round_end
    turn_start
    turn_end
    command_start
    command_abilities
    command_end
    movement_start
    movement_end
    shooting_start
    shooting_end
    charge_start
    charge_end
    fight_start
    fight_end

    fun equal(TimingWindow other) -> Bool:
        return self.value == other.value

enum TimingStage:
    closed
    current_player_rules
    opposing_player_rules
    mission_rules

    fun equal(TimingStage other) -> Bool:
        return self.value == other.value

enum TimingRule:
    regain_coherency
    rapid_ingress
    fire_overwatch
    shadow_in_the_warp
    neural_disruption
    oath_of_moment
    objective_stratagem
    heroic_intervention

    fun equal(TimingRule other) -> Bool:
        return self.value == other.value

cls TimingState:
    # Active role is distinct from turn owner and from the decision/chance owner (p.8).
    Bool active_player
    BattlePhase phase
    TimingWindow window
    TimingStage stage
    Bool open
    Bool controller
