"""Configura Android desde el google-services.json del proyecto del equipo, sin imprimir claves."""
import json
import shutil
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
if len(sys.argv) != 2:
    raise SystemExit('Uso: python scripts/configurar_firebase.py RUTA/google-services.json')
source = Path(sys.argv[1]).expanduser().resolve()
data = json.loads(source.read_text(encoding='utf-8'))
client = next((c for c in data.get('client', []) if
    c['client_info'].get('android_client_info', {}).get('package_name') == 'bo.kantu.kantu_market'), None)
if client is None:
    raise SystemExit('El archivo no corresponde al paquete bo.kantu.kantu_market.')
target = root / 'android/app/google-services.json'
if source != target.resolve():
    shutil.copyfile(source, target)
config = {
    'FIREBASE_API_KEY': client['api_key'][0]['current_key'],
    'FIREBASE_APP_ID': client['client_info']['mobilesdk_app_id'],
    'FIREBASE_PROJECT_ID': data['project_info']['project_id'],
    'FIREBASE_MESSAGING_SENDER_ID': data['project_info']['project_number'],
}
(root / 'config').mkdir(exist_ok=True)
(root / 'config/firebase.local.json').write_text(json.dumps(config, indent=2), encoding='utf-8')
print('Configuración Android preparada para el proyecto ' + config['FIREBASE_PROJECT_ID'])
