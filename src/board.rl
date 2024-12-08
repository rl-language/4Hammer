import bounded_arg
import stats
import vector2d

using Wounds = LinearlyDistributedInt<0, 10>
using WeaponsVector = BoundedVector<Weapon, 2>

cls Model:
    BoardPosition position
    Profile profile
    Wounds suffered_wounds
    WeaponsVector weapons

using ModelVector = BoundedVector<Model, 20>

cls ModelID:
    BInt<0, 21> id

    fun get() -> Int:
        return self.id.value

cls UnitID:
    BInt<0, 2> id

    fun get() -> Int:
        return self.id.value

cls Unit:
    ModelVector models
    Bool owned_by_player1

    fun get_unit_toughtness() -> Int:
        if self.models.size() == 0:
            return 0
        return self.models[0].profile.thoughness()

    fun translate(Int x, Int y):
        let v : Vector2D
        v.x = x
        v.y = y
        self.translate(v)


    fun move_to(BoardPosition new_position):
        if self.models.size() == 0:
            return
        let v = new_position.as_vector() - self.models[0].position.as_vector()
        self.translate(v)

    fun translate(Vector2D v):
        let i = 0
        while i != self.models.size():
            ref model = self.models[i]
            model.position = model.position + v
            i = i + 1

    fun distance(BoardPosition position) -> Float:
        return self.distance(position.as_vector()) 

    fun distance(Unit unit) -> Float:
        assert(unit.models.size() != 0, "unit cannot be empty")
        assert(self.models.size() != 0, "unit cannot be empty")
        return self.distance(unit.models[0]) 

    fun distance(Model model) -> Float:
        return self.distance(model.position.as_vector()) 

    fun distance(Vector2D position) -> Float:
        assert(self.models.size() != 0, "calculanting distance to empty unit")
        let nearest = self.models[0].position.as_vector()
        let i = 1
        while i != self.models.size():
            if (nearest - position).length() > (self.models[i].position.as_vector() - position).length():
                nearest = self.models[i].position.as_vector()
            i = i + 1
        return (nearest - position).length()

    fun get(Int model_id) -> ref Model:
        return self.models[model_id]
        


using UnitVector = BoundedVector<Unit, 2>

cls Board:
    UnitVector units
    Int current_target_unit

    fun get(Int unit_id) -> ref Unit:
        return self.units[unit_id]

fun append_to_string(ModelID to_add, String output):
    append_to_string(to_add.id, output)

fun parse_string(ModelID result, String buffer, Int index) -> Bool:
    return parse_string(result.id, buffer, index)


fun append_to_string(UnitID to_add, String output):
    append_to_string(to_add.id, output)

fun parse_string(UnitID result, String buffer, Int index) -> Bool:
    return parse_string(result.id, buffer, index)

