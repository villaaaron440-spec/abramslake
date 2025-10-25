import os
import json
import zipfile
import zlib
import socket

repo_path = "./ManBot"
os.makedirs(repo_path, exist_ok=True)

class ManBotCompiler:
    def __init__(self, repo_path, target_platform='android'):
        self.repo_path = repo_path
        self.target_platform = target_platform
        self.report = ["ManBot: Permissions and backend setup"]

    def compile(self, needs):
        name = needs.lower().replace(" ", "-")[:20]
        out_dir = os.path.join(self.repo_path, "output", name)
        os.makedirs(out_dir, exist_ok=True)

        # ManBotAgent.py: Core AI with IPC send
        agent_code = """
import json, os, zlib, socket
from plyer import tts
from kivy.utils import platform

if platform == 'android':
    from jnius import autoclass
    from android.permissions import request_permissions

def ipc_send(data, port=5000):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect(('localhost', port))
        s.sendall(zlib.compress(json.dumps(data).encode()))

class ManBotVoiceAI:
    def __init__(self):
        if platform == 'android':
            request_permissions([Permission.RECORD_AUDIO])

    def voice_action(self):
        tts.speak("ManBot activated")
        ipc_send({"type": "ai_result", "data": "ManBot ready"})
"""
        with open(os.path.join(out_dir, "ManBotAgent.py"), "w") as f:
            f.write(agent_code)

        # ManBotGUI.py: Core app with IPC listen
        gui_code = """
from kivymd.app import MDApp
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
import json, socket, zlib, os, threading
from ManBotAgent import ManBotVoiceAI

os.environ['KIVY_WINDOW'] = 'sdl2'
os.environ['KIVY_GL_BACKEND'] = 'gles'

class ManBotApp(MDApp):
    def __init__(self):
        super().__init__()
        self.label = Label(text='Waiting...')
        threading.Thread(target=self.ipc_listen, daemon=True).start()

    def ipc_listen(self, port=5000):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
            server.bind(('localhost', port))
            server.listen()
            while True:
                conn, _ = server.accept()
                with conn:
                    data = conn.recv(1024)
                    decompressed = json.loads(zlib.decompress(data))
                    from kivy.clock import mainthread
                    @mainthread
                    def update(text):
                        self.label.text = text
                    update(decompressed.get('data', 'Error'))

    def build(self):
        layout = BoxLayout(orientation='vertical')
        button = Button(text='Trigger ManBot', on_press=self.start_ai)
        layout.add_widget(button)
        layout.add_widget(self.label)
        return layout

    def start_ai(self, instance):
        ManBotVoiceAI().voice_action()

if __name__ == '__main__':
    ManBotApp().run()
"""
        with open(os.path.join(out_dir, "ManBotGUI.py"), "w") as f:
            f.write(gui_code)

        # Compressed config
        config = {"mode": "manbot"}
        with open(os.path.join(out_dir, "config.json"), "wb") as f:
            f.write(zlib.compress(json.dumps(config).encode()))
        # Buildozer spec
        spec = """
[app]
title = ManBot Output
package.name = manbot
source.dir = .
requirements = python3,kivy,kivymd,plyer,jnius
android.permissions = RECORD_AUDIO
"""
        with open(os.path.join(out_dir, "buildozer.spec"), "w") as f:
            f.write(spec)

        # Compressed zip
        zip_path = os.path.join(self.repo_path, "ManBot-output.zip")
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, _, files in os.walk(out_dir):
                for file in files:
                    zipf.write(os.path.join(root, file), os.path.relpath(os.path.join(root, file), out_dir))

        print("Report:")
        for item in self.report:
            print(f"- {item}")
        return out_dir, zip_path

# Run
compiler = ManBotCompiler(repo_path)
needs = "ManBot AI-to-AI App"
out_dir, zip_path = compiler.compile(needs)
print(f"Generated at: {out_dir}")
print(f"Zip: {zip_path}")
print("Contents:", os.listdir(out_dir))
