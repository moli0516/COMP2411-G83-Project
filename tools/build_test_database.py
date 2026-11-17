"""Create a NEW seed-baseline test database; never clone live data/drop databases."""
import argparse,getpass,hashlib,json,re,sys
from datetime import datetime,timezone
from pathlib import Path
import mysql.connector
import sqlparse
FILES=['01_schema.sql','02_data.sql','03_views.sql','04_indexes.sql']
def load(root):
    result=[]
    for name in FILES:
        path=root/'sql'/name;text=path.read_text(encoding='utf-8-sig')
        if '/*!' in text or re.search(r'^\s*(DELIMITER|SOURCE)\b',text,re.I|re.M): raise ValueError('Unsupported client SQL command')
        batch=[sqlparse.format(s,strip_comments=True).strip() for s in sqlparse.split(text)]
        batch=[s for s in batch if s.strip(';').strip()]
        norm=lambda s:' '.join(s.rstrip(';').split()).upper()
        if name=='02_data.sql':
            controls=[i for i,s in enumerate(batch) if re.match(r'^(START|BEGIN|COMMIT|ROLLBACK)\b',s,re.I)]
            if controls:
                if len(batch)<3 or controls!=[0,len(batch)-1] or norm(batch[0]) not in ('START TRANSACTION','BEGIN') or norm(batch[-1])!='COMMIT': raise ValueError('Seed supports one outer START TRANSACTION/COMMIT only')
                batch=batch[1:-1]
            if any(not re.match(r'^INSERT\s+INTO\b',s,re.I) for s in batch): raise ValueError('Seed must contain INSERTs only')
        for s in batch:
            if not re.match(r'^(CREATE\s+(OR\s+REPLACE\s+)?(TABLE|VIEW|(UNIQUE\s+)?INDEX)\b|INSERT\s+INTO\b)',s,re.I): raise ValueError(f'{name}: unsupported statement: {s[:100]}')
        if not batch and name!='04_indexes.sql': raise ValueError(f'{name}: empty SQL')
        result.append((name,batch,hashlib.sha256(path.read_bytes()).hexdigest()))
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--project-root',default=str(Path(__file__).resolve().parents[1]));p.add_argument('--database',default='comp2411_test')
    p.add_argument('--host',default='127.0.0.1');p.add_argument('--port',type=int,default=3306);p.add_argument('--user',default='root');p.add_argument('--check',action='store_true')
    a=p.parse_args();root=Path(a.project_root).resolve()
    if not re.fullmatch(r'comp2411_test(?:_[A-Za-z0-9_]+)?',a.database) or len(a.database)>64: p.error('Target must be comp2411_test or comp2411_test_<suffix>')
    try: scripts=load(root)
    except Exception as exc: p.error(str(exc))
    for name,batch,digest in scripts: print(name,len(batch),'statements; sha256='+digest)
    if a.check:return 0
    print(f'NEW target {a.host}:{a.port}/{a.database}; reviewed project SQL only; no live-data copy.')
    if input('Type exact target database name: ')!=a.database:return 2
    cn=mysql.connector.connect(host=a.host,port=a.port,user=a.user,password=getpass.getpass('MySQL password: '),autocommit=True)
    log={'database':a.database,'host':a.host,'port':a.port,'created':False,'files':[]}
    dest=root/'evidence/build_runs'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');dest.mkdir(parents=True)
    try:
        with cn.cursor(buffered=True) as cur:
            cur.execute('SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=%s',(a.database,))
            if cur.fetchone():raise ValueError('Target exists; nothing changed. Choose a NEW suffix. Never auto-dropped.')
            cur.execute(f'CREATE DATABASE `{a.database}` CHARACTER SET utf8mb4');log['created']=True;cn.database=a.database
            for name,batch,digest in scripts:
                entry={'file':name,'sha256':digest,'completed':0};log['files'].append(entry)
                if name=='02_data.sql':cn.start_transaction()
                for i,s in enumerate(batch,1):
                    entry['current_statement']=i;cur.execute(s)
                    if cur.with_rows:cur.fetchall()
                    entry['completed']=i
                if name=='02_data.sql':cn.commit()
                print('OK',name)
            cur.execute('SELECT DATABASE(),VERSION(),@@port');log['environment']=cur.fetchone()
        log['status']='PASS';print('Build completed:',a.database);return 0
    except Exception as exc:
        if cn.in_transaction:cn.rollback()
        log['status']='FAIL';log['error']=str(exc);print('BUILD FAILED:',exc,file=sys.stderr)
        if log['created']:print('Partial DB remains; DDL cannot be fully rolled back. Do not test it.',file=sys.stderr)
        return 1
    finally:
        cn.close();(dest/'build_log.json').write_text(json.dumps(log,indent=2,default=str),encoding='utf-8');print('Log:',dest)
if __name__=='__main__':sys.exit(main())
