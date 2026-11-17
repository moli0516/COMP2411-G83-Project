"""Scan all test SQL; execute SQL, constraint and operation-template tests."""
import argparse,csv,getpass,hashlib,json,re,sys
from pathlib import Path
from datetime import datetime,timezone
import mysql.connector
import sqlparse
HEADERS=['test_id','requirement','script','initial_state','expected_result','expected_error','actual_result','status']
TABLES=['Customer','Equipment','ServiceRequest','RequestItem','Quotation','Staff','ServiceJob','Inspection','InspectionResult','Incident','CorrectiveAction','IncidentCorrectiveAction']
def encode(x): return json.dumps(x,default=str,ensure_ascii=False)
def read_sql(path,ddl=False):
    text=path.read_text(encoding='utf-8-sig')
    if '/*!' in text or re.search(r'^\s*(DELIMITER|SOURCE)\b',text,re.I|re.M): raise ValueError(f'{path}: unsupported SQL client command')
    batch=[sqlparse.format(s,strip_comments=True).strip() for s in sqlparse.split(text)]
    batch=[s for s in batch if s.strip(';').strip()]
    if not batch: raise ValueError(f'{path}: empty/comment-only SQL')
    if not ddl and any(re.match(r'^(CREATE|ALTER|DROP|TRUNCATE|USE|GRANT|REVOKE)\b',s,re.I) for s in batch): raise ValueError(f'{path}: DDL/admin forbidden in tests')
    return batch

def discover(root,data):
    if not isinstance(data,dict) or data.get('version')!=1: raise ValueError('Invalid tests/metadata.json; run configure_tests.py')
    found={p.resolve() for p in root.rglob('*') if p.is_file() and p.suffix.lower()=='.sql'}
    if not found: raise ValueError('No SQL tests found')
    specs={};ids=set()
    for spec in data['scripts']:
        path=(root/spec['path']).resolve()
        if not path.is_relative_to(root) or path.suffix.lower()!='.sql' or path in specs: raise ValueError('Invalid/duplicate metadata path')
        mode=spec.get('mode','sql')
        if mode not in ('sql','negative','workflow'): raise ValueError('Unknown mode')
        if not spec.get('cases'): raise ValueError('Missing cases')
        for c in spec['cases']:
            if any(not c.get(k) for k in ('test_id','requirement','initial_state','expected_result')): raise ValueError('Missing case description')
            if c['test_id'] in ids: raise ValueError('Duplicate Test ID')
            ids.add(c['test_id'])
        for r in spec.get('expected_errors',[]):
            re.compile(r['statement_regex'],re.I)
            if r['occurrence']<1 or not isinstance(r['errno'],int) or not r['sqlstate']: raise ValueError('Invalid error rule')
        if mode=='negative' and (len(spec['cases'])!=1 or len(spec.get('expected_errors',[]))!=1 or not data.get('negative_setup_sql')): raise ValueError('Invalid negative metadata')
        if mode=='workflow':
            if len(spec['cases'])!=1 or spec.get('expected_outcome') not in ('reject','success') or not spec.get('parameters_sql'): raise ValueError('Invalid workflow metadata')
            if spec['expected_outcome']=='success' and not spec.get('verification_sql'): raise ValueError('Missing workflow postcondition')
            op=(root.parent/'operations'/spec['operation']).resolve()
            if op.parent!=(root.parent/'operations').resolve(): raise ValueError('Invalid operation path')
            read_sql(op)
        specs[path]=spec
    missing=found-set(specs);absent=set(specs)-found
    if missing or absent: raise ValueError('SQL missing metadata: '+str([str(p.relative_to(root)) for p in sorted(missing)])+'; metadata missing SQL: '+str([str(p.relative_to(root)) for p in sorted(absent)]))
    def order(p):
        rel=p.relative_to(root).as_posix()
        first={'positive.sql':0,'transaction_commit.sql':1,'transaction_rollback.sql':2}
        return (first.get(rel,3 if rel.startswith('negative/') else 4 if rel.startswith('workflow/') else 5),rel)
    plan=[]
    for path in sorted(found,key=order):
        if not path.is_relative_to(root): raise ValueError('External SQL symlink forbidden')
        spec=dict(specs[path],path=path.relative_to(root).as_posix());batch=read_sql(path)
        if spec.get('mode')=='negative' and (len(batch)!=1 or not re.match(r'^INSERT\s+INTO\b',batch[0],re.I)): raise ValueError('Negative mode supports one INSERT only')
        if spec.get('mode')=='workflow' and any(re.match(r'^(START|BEGIN|COMMIT|ROLLBACK)\b',s,re.I) for s in batch): raise ValueError('Workflow fixture cannot control transaction')
        plan.append((path,spec))
    return plan

def snapshot(cn):
    result={}
    with cn.cursor(buffered=True) as cur:
        for table in TABLES:
            cur.execute(f'SELECT * FROM `{table}`')
            rows=sorted(encode(row) for row in cur.fetchall())
            result[table]={'rows':len(rows),'sha256':hashlib.sha256(encode(rows).encode()).hexdigest()}
    return result

def execute(cn,batch):
    with cn.cursor(buffered=True) as cur:
        for sql in batch:
            cur.execute(sql)
            if cur.with_rows: cur.fetchall()
class ValidationRejected(ValueError): pass

def operation(cn,path,params):
    batch=read_sql(path)
    if any(re.match(r'^(START|BEGIN|COMMIT|ROLLBACK)\b',s,re.I) for s in batch): raise ValueError('Operation cannot control transaction')
    required=set(re.findall(r'%\((\w+)\)s',path.read_text(encoding='utf-8')))
    if required-set(params): raise ValueError('Missing operation parameters')
    outputs=[]
    with cn.cursor(buffered=True) as cur:
        for i,sql in enumerate(batch):
            cur.execute(sql,params if re.search(r'%\(\w+\)s',sql) else None)
            if cur.description:
                columns=[c[0] for c in cur.description];rows=cur.fetchall()
                if i==0:
                    if columns!=['ok'] or len(rows)!=1: raise ValueError('Malformed validation SELECT')
                    if rows[0][0]!=1: raise ValidationRejected('Validation failed; operation cancelled')
                else: outputs.append({'columns':columns,'rows':rows})
            elif i==0: raise ValueError('First operation statement must be validation SELECT')
    return outputs

def run_sql(cn,path,spec):
    details={'events':[],'results':{},'problems':[]};rules=spec.get('expected_errors',[])
    occurrences=[0]*len(rules);hits=[0]*len(rules)
    try:
        with cn.cursor(dictionary=True,buffered=True) as cur:
            for number,sql in enumerate(read_sql(path),1):
                eligible=[]
                for k,r in enumerate(rules):
                    if re.search(r['statement_regex'],sql,re.I):
                        occurrences[k]+=1
                        if occurrences[k]==r['occurrence']: eligible.append(k)
                if len(eligible)>1: raise ValueError('Overlapping error rules')
                event={'statement':number,'sql':sql};details['events'].append(event)
                try:
                    cur.execute(sql)
                    if cur.with_rows:
                        rows=cur.fetchall();event['rows']=rows
                        for row in rows:
                            if 'test_id' in row: details['results'].setdefault(str(row['test_id']),[]).append(row)
                    else: event['rowcount']=cur.rowcount
                    if eligible: raise ValueError('Expected error not raised')
                except mysql.connector.Error as exc:
                    event['error']={'errno':exc.errno,'sqlstate':exc.sqlstate,'message':str(exc)}
                    if not eligible: raise
                    k=eligible[0];r=rules[k]
                    if (exc.errno,exc.sqlstate)!=(r['errno'],r['sqlstate']): raise
                    hits[k]+=1;event['expected']=True
        if any(n!=1 for n in hits): raise ValueError('Expected error rule not satisfied')
        if cn.in_transaction: raise ValueError('SQL script left active transaction')
    except Exception as exc: details['problems'].append(str(exc))
    finally:
        if cn.in_transaction: cn.rollback()
    checks={}
    for case in spec['cases']:
        rows=details['results'].get(case['test_id'],[])
        checks[case['test_id']]=len(rows)==1 and rows[0].get('result')=='PASS'
    return details,checks

def run_isolated(cn,path,spec,data,project):
    details={'problems':[]};mode=spec['mode']
    try:
        details['baseline']=snapshot(cn);cn.start_transaction()
        execute(cn,data['negative_setup_sql'] if mode=='negative' else read_sql(path))
        details['before']=snapshot(cn)
        if mode=='negative':
            error=None
            try: execute(cn,read_sql(path))
            except mysql.connector.Error as exc: error={'errno':exc.errno,'sqlstate':exc.sqlstate,'message':str(exc)}
            details['error']=error;r=spec['expected_errors'][0]
            if error is None or (error['errno'],error['sqlstate'])!=(r['errno'],r['sqlstate']): raise ValueError('Missing/wrong expected database error')
        else:
            with cn.cursor(dictionary=True,buffered=True) as cur:
                cur.execute(spec['parameters_sql']);rows=cur.fetchall()
            if len(rows)!=1: raise ValueError('Parameters SQL must return one row')
            params=rows[0];details['parameters']=params
            op=(project/'operations'/spec['operation']).resolve()
            details['operation_sha256']=hashlib.sha256(op.read_bytes()).hexdigest()
            rejected=False
            try: details['outputs']=operation(cn,op,params)
            except ValidationRejected as exc: rejected=True;details['rejection']=str(exc)
            if spec['expected_outcome']=='reject' and not rejected: raise ValueError('Invalid operation unexpectedly accepted')
            if spec['expected_outcome']=='success':
                if rejected: raise ValueError('Valid operation rejected')
                with cn.cursor(dictionary=True,buffered=True) as cur:
                    cur.execute(spec['verification_sql']);verification=cur.fetchall()
                details['verification']=verification
                if len(verification)!=1 or verification[0].get('result')!='PASS': raise ValueError('Business postcondition failed')
        details['after']=snapshot(cn)
        if (mode=='negative' or spec.get('expected_outcome')=='reject') and details['before']!=details['after']: raise ValueError('Rejected operation changed data')
    except Exception as exc: details['problems'].append(str(exc))
    finally:
        if cn.in_transaction: cn.rollback()
    try:
        details['restored']=snapshot(cn)
        if details.get('baseline')!=details['restored']: details['problems'].append('Fixture rollback changed baseline')
    except Exception as exc: details['problems'].append(str(exc))
    return details,{spec['cases'][0]['test_id']:not details['problems']}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--tests-dir',default=str(Path(__file__).resolve().parents[1]/'tests'))
    p.add_argument('--host',default='127.0.0.1');p.add_argument('--port',type=int,default=3306)
    p.add_argument('--user',default='root');p.add_argument('--database')
    p.add_argument('--list',action='store_true');p.add_argument('--strict',action='store_true',help='Compatibility flag: always strict')
    a=p.parse_args();root=Path(a.tests_dir).resolve();project=root.parent
    try:
        data=json.loads((root/'metadata.json').read_text(encoding='utf-8-sig'));plan=discover(root,data)
    except Exception as exc: p.error(str(exc))
    for path,spec in plan: print(f"RUN {spec['path']} [{spec.get('mode','sql')}]: {', '.join(c['test_id'] for c in spec['cases'])}")
    total=sum(len(s['cases']) for _,s in plan)
    print(f'Discovered {len(plan)} SQL files, {total} cases; none skipped.')
    if a.list: return 0
    if not a.database: p.error('--database required')
    print(f'Target {a.host}:{a.port}/{a.database}. Writes/COMMITs occur. No automatic rebuild.')
    if input('Type the exact disposable database name: ')!=a.database: return 2
    password=getpass.getpass('MySQL password: ')
    dest=project/'evidence/automated_runs'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');dest.mkdir(parents=True)
    report=[];logs=[]
    try:
        for path,spec in plan:
            cn=None
            try:
                cn=mysql.connector.connect(host=a.host,port=a.port,user=a.user,password=password,database=a.database,autocommit=True)
                detail,checks=run_isolated(cn,path,spec,data,project) if spec.get('mode') in ('negative','workflow') else run_sql(cn,path,spec)
            except Exception as exc: detail={'problems':[str(exc)]};checks={}
            finally:
                if cn is not None: cn.close()
            logs.append({'script':spec['path'],'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'details':detail})
            expected='; '.join(f"{r['errno']} / SQLSTATE {r['sqlstate']}" for r in spec.get('expected_errors',[])) or ('ValidationRejected (template protocol)' if spec.get('expected_outcome')=='reject' else 'NONE')
            failed=False
            for c in spec['cases']:
                passed=checks.get(c['test_id'],False) and not detail.get('problems')
                row=dict(c,script='tests/'+spec['path'],expected_error=expected,actual_result=encode(detail),status='PASS' if passed else 'FAIL')
                report.append({k:row[k] for k in HEADERS});print(c['test_id'],row['status']);failed|=not passed
            if failed: print('Stopped after failure. Later files are NOT RUN; see log.');break
    finally:
        ran={x['script'] for x in logs}
        with (dest/'test_cases.csv').open('w',newline='',encoding='utf-8') as f:
            w=csv.DictWriter(f,fieldnames=HEADERS);w.writeheader();w.writerows(report)
        (dest/'run_log.json').write_text(json.dumps({'target':{'host':a.host,'port':a.port,'database':a.database},'metadata_sha256':hashlib.sha256((root/'metadata.json').read_bytes()).hexdigest(),'planned':[s['path'] for _,s in plan],'not_run':[s['path'] for _,s in plan if s['path'] not in ran],'scripts':logs},indent=2,default=str,ensure_ascii=False),encoding='utf-8')
        print('Results:',dest)
    return 0 if len(report)==total and all(r['status']=='PASS' for r in report) else 1
if __name__=='__main__': sys.exit(main())
