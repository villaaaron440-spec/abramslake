#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== Termux AI Compiler Setup ==="

# Update packages
pkg update -y && pkg upgrade -y

# Install dependencies
pkg install -y python libffi clang make cmake ninja \
    sdl2 sdl2-image sdl2-mixer sdl2-ttf \
    libjpeg-turbo libpng zlib openssl

# Setup storage
termux-setup-storage

# Install Python packages
pip install --upgrade pip setuptools wheel
pip install --no-cache-dir cython==0.29.36 kivy kivymd plyer pyjnius requests

# Create working directory
WORK_DIR="$HOME/ai-compiler-workspace"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Download the enhanced compiler script
cat > compiler_gui.py << 'PYEOF'
#!/usr/bin/env python3
"""Enhanced AI Compiler with Input GUI"""

import subprocess, sys, os, json, zipfile, zlib, socket
from pathlib import Path

os.environ['KIVY_WINDOW'] = 'sdl2'
os.environ['KIVY_GL_BACKEND'] = 'angle_sdl2'
os.environ['KIVY_AUDIO'] = 'sdl2'

def setup_environment():
    print("🔧 Checking environment...")
    required = {'kivy': 'kivy', 'kivymd': 'kivymd', 'plyer': 'plyer', 'jnius': 'pyjnius'}
    for module, pip_name in required.items():
        try:
            __import__(module)
            print(f"✓ {module} installed")
        except ImportError:
            print(f"📥 Installing {pip_name}...")
            subprocess.run([sys.executable, "-m", "pip", "install", "--no-cache-dir", pip_name], check=True)
    print("✅ Environment ready!\n")

class SimpleAICompiler:
    def __init__(self, repo_path):
        self.repo_path = Path(repo_path)
        self.report = []
    
    def compile(self, app_name, app_description):
        safe_name = app_name.lower().replace(" ", "-")[:30]
        package_name = ''.join(c for c in safe_name if c.isalnum() or c == '-')
        out_dir = self.repo_path / "output" / package_name
        out_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"📁 Creating: {app_name}")
        
        # agent.py
        agent_code = f'''"""AI Agent Backend"""
import json, zlib, socket
from kivy.utils import platform

if platform == 'android':
    try:
        from jnius import autoclass
        from android.permissions import request_permissions, Permission
        request_permissions([Permission.RECORD_AUDIO, Permission.WRITE_EXTERNAL_STORAGE])
    except: pass

try:
    from plyer import tts, notification
except: tts = notification = None

def ipc_send(data, port=5000):
    for i in range(5):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(2)
                s.connect(('127.0.0.1', port + i))
                s.sendall(zlib.compress(json.dumps(data).encode()))
                return True
        except: continue
    return False

class SimpleVoiceAI:
    def __init__(self):
        self.app_name = "{app_name}"
    
    def voice_action(self, message="AI activated"):
        print(f"🎤 {{message}}")
        if tts:
            try: tts.speak(message)
            except: pass
        if notification:
            try: notification.notify(title=self.app_name, message=message, timeout=3)
            except: pass
        ipc_send({{"type": "ai_result", "data": message, "status": "success"}})
'''
        (out_dir / "agent.py").write_text(agent_code)
        
        # jarvis.py
        jarvis_code = f'''"""GUI Frontend"""
from kivymd.app import MDApp
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.button import MDRaisedButton
from kivymd.uix.label import MDLabel
from kivymd.uix.textfield import MDTextField
from kivy.clock import Clock
import json, socket, zlib, threading
from agent import SimpleVoiceAI

class SimpleAIApp(MDApp):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.title = "{app_name}"
        self.theme_cls.primary_palette = "Blue"
        self.theme_cls.theme_style = "Dark"
        self.ai_agent = SimpleVoiceAI()
    
    def build(self):
        layout = MDBoxLayout(orientation='vertical', padding=20, spacing=15)
        
        title = MDLabel(text="{app_name}", font_style="H4", halign="center", size_hint_y=0.2)
        desc = MDLabel(text="{app_description}", halign="center", size_hint_y=0.15)
        
        self.input_field = MDTextField(hint_text="Enter command...", mode="rectangle", size_hint_y=0.15)
        
        btn = MDRaisedButton(text="🎤 Trigger AI", pos_hint={{'center_x': 0.5}}, 
                            size_hint=(0.8, 0.12), on_release=self.start_ai)
        
        self.status_label = MDLabel(text="Ready...", halign="center", size_hint_y=0.2)
        
        layout.add_widget(title)
        layout.add_widget(desc)
        layout.add_widget(self.input_field)
        layout.add_widget(btn)
        layout.add_widget(self.status_label)
        
        threading.Thread(target=self.ipc_listen, daemon=True).start()
        return layout
    
    def start_ai(self, instance):
        msg = self.input_field.text.strip() or "AI activated"
        self.status_label.text = f"Processing: {{msg}}"
        threading.Thread(target=self.ai_agent.voice_action, args=(msg,), daemon=True).start()
    
    def ipc_listen(self, port=5000):
        for i in range(5):
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as srv:
                    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                    srv.bind(('127.0.0.1', port + i))
                    srv.listen(5)
                    while True:
                        conn, _ = srv.accept()
                        with conn:
                            data = conn.recv(4096)
                            if data:
                                try:
                                    msg = json.loads(zlib.decompress(data).decode())
                                    Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', f"✅ {{msg.get('data', 'Done')}}"), 0)
                                except: pass
            except: continue
            break

if __name__ == '__main__':
    SimpleAIApp().run()
'''
        (out_dir / "jarvis.py").write_text(jarvis_code)
        
        # Other files
        config = {"app_name": app_name, "description": app_description, "version": "1.0.0"}
        (out_dir / "config.json").write_bytes(zlib.compress(json.dumps(config).encode()))
        
        spec = f"""[app]
title = {app_name}
package.name = {package_name.replace('-', '')}
source.dir = .
requirements = python3,kivy,kivymd,plyer,pyjnius
android.permissions = INTERNET,RECORD_AUDIO,WRITE_EXTERNAL_STORAGE
android.api = 31
android.minapi = 21
"""
        (out_dir / "buildozer.spec").write_text(spec)
        (out_dir / "requirements.txt").write_text("kivy>=2.2.0\nkivymd>=1.1.1\nplyer>=2.1.0\npyjnius>=1.4.2\n")
        
        zip_path = self.repo_path / f"{package_name}.zip"
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for fp in out_dir.rglob('*'):
                if fp.is_file():
                    zipf.write(fp, fp.relative_to(self.repo_path))
        
        self.report = ["✓ agent.py", "✓ jarvis.py", "✓ config.json", "✓ buildozer.spec", f"✓ {zip_path.name}"]
        return out_dir, zip_path

if __name__ == "__main__":
    print("🚀 Enhanced AI Compiler\n")
    setup_environment()
    
    app_name = input("App Name: ").strip() or "Simple AI App"
    app_description = input("Description: ").strip() or "AI-powered app"
    
    compiler = SimpleAICompiler(Path("./simple-ai-compiler"))
    out_dir, zip_path = compiler.compile(app_name, app_description)
    
    print("\n📊 Report:")
    for item in compiler.report:
        print(f"  {item}")
    print(f"\n📂 Output: {out_dir}")
    print(f"📦 ZIP: {zip_path}")
    print(f"\n🚀 Run: cd {out_dir} && python jarvis.py")
PYEOF

chmod +x compiler_gui.py

echo ""
echo "✅ Setup complete!"
echo "📂 Working directory: $WORK_DIR"
echo ""
echo "🚀 Run compiler:"
echo "   cd $WORK_DIR"
echo "   python compiler_gui.py"
