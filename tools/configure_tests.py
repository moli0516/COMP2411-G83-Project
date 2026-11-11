"""Merge W metadata into existing tests/metadata.json. No DB or operation edits."""
from pathlib import Path
from datetime import datetime
import json,sys

def main():
    root=Path(__file__).resolve().parents[1];path=root/'tests/metadata.json'
    data=json.loads(path.read_text(encoding='utf-8-sig'))
    if not isinstance(data,dict) or data.get('version')!=1 or not isinstance(data.get('scripts'),list):raise ValueError('Keep the working 17-case tests/metadata.json; not a short description list')
    addition=json.loads((root/'tools/workflow_cases.json').read_text(encoding='utf-8'))['scripts']
    for spec in addition:
        if not (root/'tests'/spec['path']).is_file():raise ValueError('Missing '+spec['path']+'; restore W01-W10 from the original workflow test ZIP')
        if not (root/'operations'/spec['operation']).is_file():raise ValueError('Missing operation '+spec['operation'])
    paths={s['path'] for s in addition}
    data['scripts']=[s for s in data['scripts'] if s['path'] not in paths]+addition
    ids=[c['test_id'] for s in data['scripts'] for c in s['cases']]
    if len(ids)!=len(set(ids)):raise ValueError('Duplicate IDs; nothing written')
    serialized=json.dumps(data,indent=2,ensure_ascii=False)+'\n'
    if path.read_text(encoding='utf-8-sig')==serialized:print('Metadata already configured');return
    backup=path.with_name('metadata.json.bak_'+datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
    backup.write_bytes(path.read_bytes());path.write_text(serialized,encoding='utf-8')
    print('Metadata merged; existing cases/negative setup preserved. Backup:',backup)
    print('Next: python tools/run_sql_tests.py --list')
if __name__=='__main__':
    try:main()
    except Exception as exc:sys.exit('Configuration stopped: '+str(exc))
