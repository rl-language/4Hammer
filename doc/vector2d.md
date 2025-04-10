# vector2d.rl

## cls Vector2Df

### Fields

* Float x
* Float y

### Methods

* fun `add(Vector2Df other)  -> Vector2Df`
* fun `mul(Float other)  -> Vector2Df`
* fun `div(Float other)  -> Vector2Df`
* fun `sub(Vector2Df other)  -> Vector2Df`
* fun `distance(Vector2Df other)  -> Float`
* fun `length()  -> Float`
* fun `normalized()  -> Vector2Df`
* fun `as_int_vector()  -> Vector2D`

## cls Vector2D

### Fields

* Int x
* Int y

### Methods

* fun `add(Vector2D other)  -> Vector2D`
* fun `mul(Float other)  -> Vector2D`
* fun `sub(Vector2D other)  -> Vector2D`
* fun `distance(Vector2D other)  -> Float`
* fun `length()  -> Float`
* fun `as_float_vector()  -> Vector2Df`

## cls BoardPosition

### Fields

* CoordinateX x
* CoordinateY y

### Methods

* fun `as_vector()  -> Vector2D`
* fun `add(Vector2D other)  -> BoardPosition`
* fun `sub(Vector2D other)  -> BoardPosition`


### Free functions

* fun `make_board_position(Int x, Int y)  -> BoardPosition`
* fun `make_board_position(CoordinateX x, CoordinateY y)  -> BoardPosition`
