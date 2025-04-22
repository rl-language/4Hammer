def main():
    try:
        import wrapper as rules
    except ModuleNotFoundError:
        print("Failed to find python rules wrapper. You can produce it by running:\nrlc src/full_rules.rl -o examples/lib.so -O2 --shared\nrlc src/full_rules.rl -o examples/wrapper.py --python")

    import wrapper as rules

    # invokes play defined in rules.rl, and starts the game
    state = rules.functions.play()

    # prints 0, the player has not picked a faction yet
    # so he has no units
    print(rules.functions.size(state.board.reserve_units))

    # picks a faction for player 0
    rules.functions.pick_insidious_infiltrators(state)

    # prints 5
    print(rules.functions.size(state.board.reserve_units))

if __name__ == "__main__":
    main()
