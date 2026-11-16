"""Validate Apple .strings syntax, UI coverage and printf placeholder parity."""
import json
import re
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
def read(path):
    return json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
en = read(root / 'Sources/en.lproj/Localizable.strings')
zh = read(root / 'Sources/zh-Hans.lproj/Localizable.strings')
placeholder = re.compile(r'%(?:\d+\$)?(?:ll|l)?[du@f]')
ui_source = (root / 'Sources/zh-Hans.lproj/Localizable.strings').read_text().split('// Engine messages')[0]
ui_keys = set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', ui_source, re.M))
ui_keys = {json.loads('"' + k + '"') for k in ui_keys}
ui_keys |= {'Customize SDK', 'Default SDK', 'Current SDK', 'SDK version', 'Use 27.2.0', 'Invalid SDK version'}
for code in ['en', 'zh-Hans', 'zh-Hant', 'ja', 'ko', 'es', 'fr', 'de', 'vi']:
    values = read(root / f'Sources/{code}.lproj/Localizable.strings')
    assert ui_keys <= values.keys(), (code, ui_keys - values.keys())
    for key, value in values.items():
        assert sorted(placeholder.findall(key)) == sorted(placeholder.findall(value)), (code, key)
    print(f'PASS {code}: {len(values)} strings; UI coverage and format placeholders')
