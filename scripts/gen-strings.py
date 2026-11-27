#!/usr/bin/env python3
"""画面の言葉の String Catalog（App/Resources/Localizable.xcstrings）を、コードの tr("日本語", "English") / trf(...) から作る。

使い方: python3 scripts/gen-strings.py [--check]
- 日本語（元の言葉）をキー、英語を en の値にする
- 英語が空・日本語が残っている・文字列の差し込み（\\( ）があると止まる（英語の抜けを残さない）
- --check：カタログが最新でなければ exit 1（書き換えない）
"""
import json
import re
import sys
from pathlib import Path

CALL = re.compile(r'\b(?:trf?|T)\(\s*"((?:[^"\\\n]|\\.)*)"\s*,\s*"((?:[^"\\\n]|\\.)*)"')
JA = re.compile(r'[぀-ヿ一-鿿]')


def main(argv):
    root = Path(__file__).resolve().parent.parent
    catalog_path = root / 'App/Resources/Localizable.xcstrings'
    pairs, errors = {}, []
    for path in sorted((root / 'App/Sources').rglob('*.swift')):
        text = path.read_text(encoding='utf-8')
        for m in CALL.finditer(text):
            # Swift の文字列のエスケープ（\" と \\）を、実行時の文字に戻す
            ja = m.group(1).replace('\\"', '"').replace('\\\\', '\\')
            en = m.group(2).replace('\\"', '"').replace('\\\\', '\\')
            where = f'{path.relative_to(root)}:{text.count(chr(10), 0, m.start()) + 1}'
            if '\\(' in ja or '\\(' in en:
                errors.append(f'{where} 文字列の差し込み \\( は使わず trf と %d / %@ にする')
            if not en.strip() or JA.search(en):
                errors.append(f'{where} 英語がない・日本語が残っている: {en!r}')
            if not JA.search(ja):
                continue
            if ja in pairs and pairs[ja] != en:
                errors.append(f'{where} 同じ日本語に違う英語: {ja!r}')
            pairs[ja] = en
    if errors:
        print('\n'.join(errors))
        return 1
    strings = {ja: {'extractionState': 'manual', 'localizations': {'en': {'stringUnit': {'state': 'translated', 'value': en}}}} for ja, en in sorted(pairs.items())}
    out = json.dumps({'sourceLanguage': 'ja', 'strings': strings, 'version': '1.0'}, ensure_ascii=False, indent=2) + '\n'
    if '--check' in argv:
        if not catalog_path.exists() or catalog_path.read_text(encoding='utf-8') != out:
            print('Localizable.xcstrings が最新ではありません: python3 scripts/gen-strings.py')
            return 1
        print(f'ok: {len(strings)} 件（日本語と英語）')
        return 0
    catalog_path.write_text(out, encoding='utf-8')
    print(f'書き出しました: {len(strings)} 件（日本語と英語）')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
