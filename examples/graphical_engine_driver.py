from engine_driver import GodotClient
import wrapper as rules


def main():
    client = GodotClient(rules)
    client.stop_rendering()

    while not client.state.is_done():
        action = client.get_random_valid_action()
        print(action)
        client.send_action(action)

    img = client.get_image()
    if img != None:
        img.save("/tmp/img.png")

if __name__ == "__main__":
    main()
