import socket
import numpy as np
from PIL import Image
from time import sleep
import io
from random import choice
from rlc import Program

import wrapper as rules

class GodotClient:
    # open a connection with godot and keep a
    # copy of the state locally
    def __init__(self, port=8527, host='127.0.0.1'):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((host, port))
        self.prog = Program(rules)
        self.state = None
        self.reset()

    # send the builtin command to reset
    def reset(self):
        self._send_message("_engine_reset")
        self.state = self.prog.start()

    def send_action(self, action):
        if not self.state.can_apply(action):
            return False
        self.state.step(action)
        self._send_message(self.prog.to_string(action))
        return True

    def get_random_valid_action(self):
        return self.state.actions[choice(self.state.legal_actions_indicies)]

    def _send_message(self, action):
        self.sock.sendall((action + "\n").encode('utf-8'))

    def get_image(self):
        self._send_message("_engine_get_image")
        buffer = b""
        while True:
            data = self.sock.recv(4096)
            if not data:
                break
            buffer += data
            try:
                img = Image.open(io.BytesIO(buffer))
                return img.copy()
            except:
                pass  # not enough data yet

    def get_image_numpy(self):
        return np.array(self.get_image())


def main():
    client = GodotClient()

    while not client.state.is_done():
        action = client.get_random_valid_action()
        print(client.prog.to_string(action))
        client.send_action(action)

    img = client.get_image()
    if img != None:
        img.save("/tmp/img.png")

if __name__ == "__main__":
    main()
