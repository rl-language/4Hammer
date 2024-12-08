# Skirmish

> An example implementation demonstrating how to enable machine learning in wargame design, showcasing the Rulebook language philosophy.

![RLC Logo](./imgs/skirmish.png)

**Skirmish** is an example of how one can create a generic graphical editor that automatically adapts to rules provided in a `.rl` file. This allows a designer without prior experience in machine learning or graphical engines to leverage both seamlessly.

[Wargaming](https://en.wikipedia.org/wiki/Wargame) has been chosen as the subject of this example because, in this domain, the purpose of the graphical user interface is clear: representing units of fighters divided into at least two teams that interact according to a defined ruleset. The techniques demonstrated in this repository can be applied to any similar domain where users wish to experiment with evolving program rules.

You can see the **Skirmish** example working in your browser [here](https://drblallo.github.io/skirmish.html) (best experienced on desktop).

This project will be of interest to two kinds of people:

1. **Users** who wish to analyze, design, and test wargames, with or without machine learning.
2. **UI/UX designers** interested in learning how to write generic graphical code that automatically adapts to game rules written by someone else.

The first group of users can safely ignore the **Configuring Godot** section.


### The Spirit of the Rulebook Language

The Rulebook language is designed to simplify the interoperability of rules, machine learning, graphical engines, and more. In practice, this means that from a single file describing the rules, you can generate machine learning agents capable of maximizing specific objectives of your choice.

For example, in the bottom-left corner of the browser program mentioned earlier, you will see a button labeled **"Next Trace Action"**. When pressed, an action in the game will be triggered. This action is determined by the machine learning components, which have learned to play the game autonomously.

A Rulebook (RL) program is divided into two main sections: the **state of the program** and the **rules of the program**.

#### State

In the context of wargaming, the state of the program can be thought of as all the components placed on the game board. Examples include chess pieces, 3D models, tokens, and so on. In this example, the state of the program is defined in the [board.rl](./src/board.rl) file.

Let’s take a closer look at a board definition:

```python
cls Board:
    UnitVector units  # required
```

A board consists of a vector (i.e., a list) of units.

```python
cls Unit:
    ModelVector models  # required
    Bool owned_by_player1  # required
```

A unit is composed of a vector of models and a boolean value that specifies whether it belongs to Player 1 (`True`) or Player 0 (`False`).

Now, consider a model:

```python
cls Model:
    BoardPosition position  # required
    Profile profile
    Wounds suffered_wounds
    WeaponsVector weapons
```

A model consists of:
- A **BoardPosition**, representing its 2D location,
- A number of **suffered wounds**,
- A **profile**, and
- A list of **weapons**.

The last two fields, `profile` and `weapons`, are defined in the [stats.rl](./src/stats.rl) file.

Except for fields marked as *required*—indicating that the engine depends on them to display that element—every other field can be modified freely. You can change the type, rename fields, delete them entirely, or add new ones. This flexibility allows for the introduction of additional elements to the state, such as modifiers, temporary tokens, and more.

#### Rules

The rules of the program represent the more abstract aspects of the game that define how the state evolves. For instance, in chess, moving a piece from one square to another follows specific rules.

In this project, the rules are contained in [rules.rl](./src/rules.rl). This file includes functions useful for machine learning algorithms, such as **get_current_player**, **score**, and others. While these functions are vital for the program's operation, they are not the focus of this section.

The rest of the file defines the rules of the game. Let's examine the **play** action:

```python
act play() -> Game:  # required
    frm board : Board  # required
    board.units.append(make_profile1())
    board.units.back().owned_by_player1 = true
    board.units[0].translate(0, 5)

    act pick_profile(frm ProfileToUse profile)
    act select_position(BoardPosition position)  { 10.0 > position.as_vector().length() }

    board.units.append(profile.unit())
    board.units.back().move_to(position)

    act select_target(frm UnitID source, frm UnitID target) {
        source.get() < board.units.size(),
        target.get() < board.units.size(),
        !board.units[source.get()].owned_by_player1,
        board.units[target.get()].owned_by_player1
    }

    board.current_target_unit = 0

    subaction*(board) attack = attack(board, source.get(), target.get())
```

The **play** action, which returns a `Game`, serves as the program's entry point and must always be present. This action must include the game board, defined as type `Board`.

**Everything else can be modified freely.**

#### Examining the Content of `play`

```python
board.units.append(make_profile1())
board.units.back().owned_by_player1 = true
board.units[0].translate(0, 5)
```

At the start of the action, a unit is created using **profile1**, assigned to Player 1, and then moved 5 units along the board’s y-axis.

#### Picking a Profile and Position

```python
act pick_profile(frm ProfileToUse profile)
act select_position(BoardPosition position)  { 10.0 > position.as_vector().length() }

board.units.append(profile.unit())
board.units.back().move_to(position)
```

The first line defines an action called **pick_profile**, which accepts a `ProfileToUse` argument.

`ProfileToUse` is an enum defined in the same file:

```python
enum ProfileToUse:
    use_humans:
        Unit unit = make_profile1()
    use_super_humans:
        Unit unit = make_profile2()
```

This enum represents a list of options the player can choose from. In the [Skirmish page](https://drblallo.github.io/skirmish.html), you can see this in action at the bottom of the screen, where you’re prompted to choose between "use humans" and "use super humans."

After selecting a profile, the next action is to choose a spawn location, which must be within 10.0 units of distance from the starting point. In the browser interface, this is done by right-clicking a location.

Once both decisions are made, a unit of the selected type is spawned at the specified location.

#### Selecting a Target and Attacking

```python
act select_target(frm UnitID source, frm UnitID target) {
    source.get() < board.units.size(),
    target.get() < board.units.size(),
    !board.units[source.get()].owned_by_player1,
    board.units[target.get()].owned_by_player1
}

subaction*(board) attack = attack(board, source.get(), target.get())
```

The **select_target** action specifies a source unit ID and a target unit ID. Both IDs must be valid:
- The source unit must belong to Player 0.
- The target unit must belong to Player 1.

In the GUI, this can be performed by left-clicking a highlighted unit and then clicking another valid unit. Only valid units will be highlighted.

Once a target is selected, the attack sequence begins. The attack sequence iterates over all models in the source unit and executes a **single_attack** for each model against the target unit.

#### Single Attack Definition

```python
act single_attack(ctx Unit target, frm Weapon source) -> SingleAttack:
    act hit_roll(Dice d)
    if d < source.skill():
        return

    act wound_roll(Dice d)
    if d < required_wound_roll(source, target.get_unit_toughness()):
        return

    act allocate_wound(frm ModelID id) {
        id.get() < target.models.size()
    }

    act save_roll(Dice d)
    ref target_model = target.models[id.get()]
    if d.value >= (target_model.profile.save() + source.penetration()):
        return

    target_model.suffered_wounds = target_model.suffered_wounds + source.damage()
    if target_model.suffered_wounds >= target_model.profile.wounds():
        target.models.erase(id.get())
```

A single attack consists of four steps:
1. Rolling a dice to determine if the target is hit.
2. Rolling another dice to check if the target is wounded.
3. Deciding which model in the target unit will take the damage.
4. Rolling a dice to see if the target saves the damage.

If the damage exceeds the target model’s wound threshold, the model is removed from play.
**You can modify any of these sequences however you wish, and the GUI will automatically adapt to your changes, ensuring the following behaviors:**

- If you declare an action with no parameters, it will appear in the bottom list of actions.
- If you declare an action with a single `enum` parameter, all possible actions that can be triggered will appear in the bottom list of actions.
- If you declare an action with a single `bool` parameter, a yes/no question will appear at the bottom of the screen.
- If you declare an action with a single `BoardPosition` parameter, you will be able to right-click on the screen to interact.
- If you declare an action with two parameters of type `UnitID`, you will be able to click on one unit and then another to perform the action.
- If you declare an action with one parameter of type `ModelID`, you will be able to click on a model to interact with it.

The name of the action can be arbitrary. However, reusing the same name and parameters across similar actions will enable the machine learning components to recognize them as the same action, reducing the computational resources required.

---

### Configuring Godot

In the previous sections, we saw how game rules can be written independently of the graphical engine mechanisms. Here, we will explore how these mechanisms are implemented.

---

### RLC Godot Interop

RL programs are designed to seamlessly integrate with the Godot engine, allowing for easy interoperability between rule-based logic and graphical representations.

---

### Requirements

**Mandatory:**
- A Linux distribution (the project will work on any Godot-supported platform if you modify the `CMake` file accordingly).
- Python 3.9 to 3.11.
- [RLC](https://github.com/rl-language/rlc/).
- CMake 3.10 or later.
- Godot 4.3.

**Optional (to run the project in a browser):**
- Emscripten 3.39 or later.
  *(Note: Using older versions of Emscripten will fail silently and the project will not load in the browser.)*

---

### Running It

```bash
git clone https://github.com/drblallo/skirmish.git
cd skirmish
python3 -m pip install virtualenv
python3 -m virtualenv .venv
source .venv/bin/activate.sh
mkdir build
cd build
cmake .. -DGODOT_EDITOR=/PATH/TO/GODOT/EDITOR/EXECUTABLE
make run
# Optionally, you can build the editor with:
# make editor
```

---

### Contacts

Join the community on [Discord](https://discord.gg/saSEj9PAt3).

