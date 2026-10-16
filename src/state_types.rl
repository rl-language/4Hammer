import action
import machine_learning
import bounded_arg

# These are storage schemas, not edition or mission identifiers. Finite action
# domains remain separate from bounded storage and persistent identities.
const STATE_SCHEMA_VERSION = 47
const ACTION_SCHEMA_VERSION = 27
const OBSERVATION_SCHEMA_VERSION = 47

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
# Preserve the old16 mechanical-effect slots plus8 independently owned status
# slots in the unified store. Every mechanical entry can supply a repair term.
const MAX_MODEL_RULE_EFFECTS = 24
const MAX_DATASHEET_HIT_MODIFIERS = 34
#34 unit terms +16 attack terms +16 unit-ability terms +7 core terms.
# All remain independently selectable; the last index is the completed state.
const MAX_ATTACK_MODIFIER_CHOICES = 73
const MAX_ATTACK_MODIFIER_INDEX = 74
# Validated13-profile envelope. Included Stompa needs10; current17.H1
# families need at most4. Excluded Kill Tank is not a playable-data obligation.
# Review actual copies/quotas in each remaining included54-card adapter.
const MAX_WEAPONS = 13

# One linear Weapon catalog ID; None/zero means no selector.
const MAX_WEAPON_CODE = 297
using WeaponCode = LinearlyDistributedInt<0, MAX_WEAPON_CODE>

# RLC const declarations require literals; keep this at MAX_WEAPONS+1.
const MAX_WEAPON_SCOPES = 14
# Source instance/action slots and monotonically allocated effect handles are
# distinct bounded domains (source timing infrastructure;17.E).
# Thirty-two roster units can see up to12 cards across their three packages,
# plus independent enhancement/unit/army sources. Reused rule/unit handles
# prevent growth on repeated activations. This is an implementation envelope.
const MAX_SOURCE_INSTANCES = 512
const MAX_SOURCE_EFFECT_KEY = 4097
using SourceEffectKey = LinearlyDistributedInt<0, MAX_SOURCE_EFFECT_KEY>
const MAX_CHARACTERISTIC = 257
const MAX_STAT_MODIFIER = 257
const MAX_RANDOM_STAT_RESULT = 513
const MAX_COMBAT_COUNTER = 4097
const MAX_WOUNDS = 4097
#448 selected physical weapons (including Firing Deck), up to one ordinary
# and two Supa-Hazardous tests each:448*3, plus zero sentinel, linear encoding.
const MAX_HAZARDOUS_USES = 1345
# Supported temporary declaration capacity, not a tabletop limit (p.81).
const MAX_DECK_SELECTIONS = 32
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

# Bounded metadata is observable storage, not a player selector (user requirement).
# Zero denotes unset; assigned identities and phase/turn stamps use value+1.
# Nonnegative bounds keep generated Python/Godot names valid in RLC 0.4.14.
const MAX_ENTITY_IDENTITIES = 16384
const MAX_IDENTITY_SEQUENCE = 16385
const NEXT_STATE_SCHEMA_VERSION = 48
const MAX_PHASE_SERIAL = 64
const MAX_TURN_SERIAL = 16
const MAX_PHASE_STAMP = 65
const MAX_TURN_STAMP = 17
# Returning Models01.02.03: ordinary phase-start anchors or an explicit
# nearest unengaged return; the source ability chooses which policy applies.
enum ReturnPlacementPolicy:
    phase_start
    nearest_unengaged

# Shared round resource accounting; source abilities supply their actual limit.
# Stamp+1 preserves round zero (usage infrastructure; appendix22.03.01).
cls RoundResourceBudget:
    LinearlyDistributedInt<0, MAX_ROUNDS> round_stamp
    FixedStat spent

    fun available(Int stamp, Int limit) -> Bool:
        return (self.round_stamp.value != stamp or self.spent.value < limit) and limit > 0

    fun consume(Int stamp):
        self.spent = int(self.round_stamp.value == stamp) * self.spent.value + 1
        self.round_stamp = stamp

using EntityIdentity = LinearlyDistributedInt<0, MAX_IDENTITY_SEQUENCE>
using IdentitySequence = LinearlyDistributedInt<0, MAX_IDENTITY_SEQUENCE>
using PhaseSerial = LinearlyDistributedInt<0, MAX_PHASE_SERIAL>
using TurnSerial = LinearlyDistributedInt<0, MAX_TURN_SERIAL>
using PhaseStamp = LinearlyDistributedInt<0, MAX_PHASE_STAMP>
using TurnStamp = LinearlyDistributedInt<0, MAX_TURN_STAMP>

# Shooting types have distinct eligibility and attack restrictions (pp.34–35/57).
enum ShootingKind:
    normal
    assault
    close_quarters
    indirect
    snap

    fun equal(ShootingKind other) -> Bool:
        return self.value == other.value

# p.58: one start per turn does not prohibit overlapping cross-turn actions.
# Bound records by the configured turn count; mission effects own start stamps.
cls UnitActionProgress:
    TurnStamp started_turn
    Bool failed
    Bool resolved
    Bool completed

cls UnitHistory:
    CheckedVector<EntityIdentity, MAX_UNIT_MODELS> phase_start_members
    CheckedVector<EntityIdentity, MAX_UNIT_COUNT> phase_start_engagements
    PhaseStamp embarked_phase
    TurnStamp ingress_turn
    Bool ingress_used_deep_strike
    Bool disembarked_this_turn
    Bool tactical_move_required
    Bool deck_shooting_locked
    PhaseStamp last_move_phase
    PhaseStamp selected_move_phase
    PhaseStamp declared_charge_phase
    PhaseStamp charge_move_phase
    PhaseStamp pile_in_phase
    PhaseStamp consolidation_phase
    PhaseStamp engaged_fight_start_phase
    PhaseStamp fight_eligible_phase
    PhaseStamp consolidation_fight_pending
    MovementKind move_kind
    Bool made_move_this_turn
    Bool advanced_this_turn
    # Waaagh! grants charge permission when selected to Advance; retain it
    # for that move even if riled status later changes (Orks Army Rules).
    Bool advance_allows_charge
    Bool fell_back_this_turn
    Bool fallback_allows_charge
    Bool fallback_allows_shooting
    Bool selected_move_allows_action
    Bool ingress_locked
    Bool strategic_reserve
    Bool repositioned
    Bool has_ingressed
    Bool scouts_resolved
    TurnStamp last_ranged_attack_turn
    Bool was_set_up_this_turn
    Bool used_stratagem_this_phase
    Bool[2] stratagem_targeted_by_player
    Bool shot_this_phase
    Bool wrecka_objective_selection
    Bool action_started
    Bool action_completed
    CheckedVector<UnitActionProgress, MAX_TURN_STAMP> action_records
    Bool action_pending
    Bool action_failed

    # Generated initialization sets stamps to 0, enum to stationary and
    # Booleans to false; no partial lifecycle hook is needed (pp.28–30/68).

# Keep exact grid segment lengths as bounded squared horizontal distances;
# floats are calculated on demand and are never persisted (user requirement).
const MAX_MOVEMENT_SEGMENTS = 128
const MAX_HORIZONTAL_SQUARE = 2691 # 43^2 + 29^2 + 1, the supported grid diagonal.
const MAX_VERTICAL_DISTANCE = 3841 # 128 supported segments times 30 inches, plus one.
using HorizontalSquare = LinearlyDistributedInt<0, MAX_HORIZONTAL_SQUARE>
using VerticalDistance = LinearlyDistributedInt<0, MAX_VERTICAL_DISTANCE>

cls ModelHistory:
    CheckedVector<HorizontalSquare, MAX_MOVEMENT_SEGMENTS> horizontal_segments
    VerticalDistance vertical_distance
    Bool was_set_up_this_turn
    Bool epic_challenge

    # Every straight segment contributes its length (p.12); rotations do not.
    # Store integer grid data, not rounded floating totals (user requirement).
    fun record_movement_segment(Int dx, Int dy, Int dz):
        assert(abs(dx) < BOARD_WIDTH and abs(dy) < BOARD_HEIGHT and abs(dz) <= BOARD_HEIGHT, "movement segment outside supported grid")
        if dx != 0 or dy != 0 or dz != 0:
            let square : HorizontalSquare
            square = dx * dx + dy * dy
            self.horizontal_segments.append(square)
            assert(self.vertical_distance.value + abs(dz) < MAX_VERTICAL_DISTANCE, "vertical movement history capacity exceeded")
            self.vertical_distance = self.vertical_distance.value + abs(dz)

    # Exact float calculation over bounded integer history (p.12 / Heavy p.82).
    fun distance_moved_this_turn() -> Float:
        let distance = float(self.vertical_distance.value)
        for i in range(self.horizontal_segments.size()):
            distance = distance + sqrt(float(self.horizontal_segments[i].value))
        return distance

    # Turn-limited distance history expires for both armies (pp.28–30/82).
    fun reset_movement_distance():
        self.horizontal_segments.clear()
        self.vertical_distance = 0

# Schema is singleton bounded metadata; generated init uses the current value.
using StateSchema = LinearlyDistributedInt<STATE_SCHEMA_VERSION, NEXT_STATE_SCHEMA_VERSION>

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

# At most one Leader and one Support, separate from the bodyguard component
# (p.66). Source adapters provide permissions; role is not inferred from size.
enum AttachmentRole:
    bodyguard
    leader
    support

# Big Mek has six native permissions plus at most one enhancement permission.
const MAX_BODYGUARD_TYPES = 7
using BodyguardPermissions = CheckedVector<DatasheetCode, MAX_BODYGUARD_TYPES>

# Component identity/starting strength/source data persists after its models
# die, allowing19.04 lifetime and later revival without splitting (pp.66–67/88).
cls AttachmentComponent:
    EntityIdentity identity
    StartingStrength starting_strength
    Hidden<String> name
    AttachmentRole role
    DatasheetCode datasheet
    Abilities abilities
    FixedStat psyker_level
    Bool waaagh

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
    smokescreen

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


# Stable model membership survives compaction while later saves use the next
# group (pp.19/22–23). Storage capacity mirrors the supported 32-model unit.
cls AllocationGroup:
    CheckedVector<EntityIdentity, 32> members
    FixedStat wounds
    FixedStat save
    FixedStat invulnerable
    Bool character
    Bool wounded
    Bool precision_visible

using AllocationGroups = CheckedVector<AllocationGroup, 32>

# Explicit move types retain restrictions across repositioning (pp.33/68–71).
enum MovementKind:
    stationary
    normal
    advance
    ordered_retreat
    desperate_escape
    scout
    surge
    ingress
    disembark
    emergency_disembark
    pulse_jet

    fun equal(MovementKind other) -> Bool:
        return self.value == other.value

# Zero sentinel preserves generated initialization; random M is encoded M+1.
const MOVE_M_UNSET = 0
using MovementOverride = LinearlyDistributedInt<0, 258>

# Degree choices are finite editor inputs for free circular-base rotation (p.12).
using MovementRotation = LinearlyDistributedInt<0, 360>

# Disembark modes are mandatory conditional rules, not free alternatives (p.65).
enum DisembarkMode:
    rapid
    tactical
    combat
    emergency
    assault

    fun equal(DisembarkMode other) -> Bool:
        return self.value == other.value
