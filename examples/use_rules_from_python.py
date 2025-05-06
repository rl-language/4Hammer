def main():
    try:
        import wrapper as rules
    except ModuleNotFoundError:
        print("Failed to find python rules wrapper. You can produce it by running:\nrlc src/full_rules.rl -o examples/lib.so -O2 --shared\nrlc src/full_rules.rl -o examples/wrapper.py --python")

    import wrapper as rules

    # invokes play defined in rules.rl, and starts the game
    state = rules.play()

    # prints 0, the player has not picked a faction yet
    # so he has no units
    print(state.board.reserve_units.size())

    # picks a faction for player 0
    assert state.can_pick_insidious_infiltrators()
    state.pick_insidious_infiltrators()

    # prints 5
    print(state.board.reserve_units.size())

if __name__ == "__main__":
    main()
