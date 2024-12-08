import bounded_arg
import math.numeric

using Coordinate = LinearlyDistributedInt<0, 40>

cls Vector2D:
    Int x
    Int y

    fun add(Vector2D other) -> Vector2D:
        let to_return : Vector2D
        to_return.x = self.x + other.x
        to_return.y = self.y + other.y
        return to_return

    fun sub(Vector2D other) -> Vector2D:
        let to_return : Vector2D
        to_return.x = self.x - other.x
        to_return.y = self.y - other.y
        return to_return

    fun distance(Vector2D other) -> Float:
        let x_distance = float(self.x - other.x)
        let y_distance = float(self.y - other.y)
        return sqrt((x_distance * x_distance) + (y_distance * y_distance))

    fun length() -> Float:
        return sqrt(float(self.x * self.x) + float(self.y* self.y))


cls BoardPosition:
    Coordinate x
    Coordinate y
    
    fun as_vector() -> Vector2D:
        let vector : Vector2D
        vector.x = self.x.value
        vector.y = self.y.value
        return vector


    fun add(Vector2D other) -> BoardPosition:
        let to_return : BoardPosition 
        to_return.x = self.x + other.x
        to_return.y = self.y + other.y
        return to_return

    fun sub(Vector2D other) -> BoardPosition:
        let to_return : BoardPosition 
        to_return.x = self.x - other.x
        to_return.y = self.y - other.y
        return to_return

