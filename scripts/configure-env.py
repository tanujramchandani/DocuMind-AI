from getpass import getpass
from pathlib import Path
import os
import re
import secrets
import sys

root = Path(__file__).resolve().parent.parent
backend = root / 'backend'
frontend = root / 'frontend'
env_path = backend / '.env'

if not env_path.exists():
    config = (backend / '.env.example').read_text(encoding='utf-8')
    config = config.replace('SECRET_KEY=change-me-to-a-long-random-string', 'SECRET_KEY=' + secrets.token_urlsafe(48))
    descriptor = os.open(env_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w', encoding='utf-8') as env_file:
        env_file.write(config)

config = env_path.read_text(encoding='utf-8')
placeholder = 'GROQ_API_KEY=your-groq-api-key-here'
if placeholder in config and sys.stdin.isatty():
    print('Get a Groq API key at https://console.groq.com/keys. Leave blank to configure it later.')
    key = getpass('Groq API key: ').strip()
    if key:
        if not re.fullmatch(r'[A-Za-z0-9_-]+', key):
            raise SystemExit('Invalid API key format; backend/.env was not changed.')
        env_path.write_text(config.replace(placeholder, 'GROQ_API_KEY=' + key, 1), encoding='utf-8')

frontend_env = frontend / '.env'
if not frontend_env.exists():
    with frontend_env.open('x', encoding='utf-8') as env_file:
        env_file.write((frontend / '.env.example').read_text(encoding='utf-8'))
