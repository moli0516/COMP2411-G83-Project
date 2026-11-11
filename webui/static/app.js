"use strict";
const $ = id => document.getElementById(id);
let cfg, lastQuery, ticket = null, previewValues = null, busy = false;
function notice(message, error=false) { $("notice").textContent=message; $("notice").className=error?"error":"success"; }
async function api(path, body={}) {
  const response=await fetch(path,{method:"POST",headers:{"Content-Type":"application/json","X-CSRF-Token":cfg.token},body:JSON.stringify(body)});
  const data=await response.json(); if(!response.ok) throw new Error(data.error||"Request failed"); return data;
}
async function task(fn) { if(busy)return; busy=true; document.body.setAttribute("aria-busy","true"); try{await fn();}catch(e){notice(e.message,true);}finally{busy=false;document.body.removeAttribute("aria-busy");} }
function table(target,data) {
  const host=$(target); host.replaceChildren();
  if(!data.columns){const p=document.createElement("p");p.textContent=JSON.stringify(data);host.append(p);return;}
  const summary=document.createElement("p");summary.className="muted";summary.textContent=`${data.rows.length} row(s)`;host.append(summary);
  const wrapper=document.createElement("div");wrapper.className="table-wrap";const t=document.createElement("table"),head=t.createTHead().insertRow();
  data.columns.forEach(c=>{const th=document.createElement("th");th.textContent=c;head.append(th);});
  const body=t.createTBody();data.rows.forEach(row=>{const tr=body.insertRow();row.forEach(v=>{const td=tr.insertCell();td.textContent=v===null?"NULL":v;if(v===null)td.className="null";});});wrapper.append(t);host.append(wrapper);
}
function renderOperation() {
  ticket=null;$("commitButton").disabled=true;$("operationResults").replaceChildren();
  const op=cfg.operations.find(o=>o.id===$("operationId").value);const fields=$("operationFields");fields.replaceChildren();
  $("previewButton").disabled=!op?.enabled;$("opReason").textContent=op?(op.reason||"Enter inputs, preview, then explicitly confirm a commit."):"No local operation scripts found.";
  if(!op?.enabled)return;
  op.fields.forEach(name=>{const label=document.createElement("label");label.className="field";label.append(document.createTextNode(name));const input=document.createElement("input");input.name=name;input.required=name!=="remarks";input.type=name.endsWith("_date")?"date":(name.endsWith("_id")||name==="quoted_amount"?"number":"text");if(input.type==="number"){input.min="1";input.step=name==="quoted_amount"?"0.01":"1";}if(name==="result")input.placeholder="PASS or FAIL";if(name==="criterion_name")input.placeholder="FUNCTION_TEST";if(name==="severity")input.placeholder="LOW, MEDIUM or HIGH";input.addEventListener("input",()=>{ticket=null;$("commitButton").disabled=true;});label.append(input);fields.append(label);});
}
function operationResult(data){$("operationResults").replaceChildren();const p=document.createElement("p");p.textContent=data.outcome;$("operationResults").append(p);data.results.forEach((r,i)=>{const box=document.createElement("div");box.id=`opResult${i}`;$("operationResults").append(box);table(box.id,r);});}
function populate(id,items){$(id).replaceChildren();items.forEach(v=>{const o=document.createElement("option");o.value=v;o.textContent=v;$(id).append(o);});}
document.querySelectorAll("nav button").forEach(b=>b.onclick=()=>{document.querySelectorAll(".pane").forEach(p=>p.classList.toggle("hidden",p.id!==b.dataset.pane));document.querySelectorAll("nav button").forEach(n=>n.classList.toggle("current",n===b));});
$("runQuery").onclick=()=>task(async()=>{lastQuery=null;$("exportCsv").disabled=true;const id=$("queryId").value;const result=await api(`/api/query/${id}`);lastQuery={id,...result};table("queryResults",result);$("exportCsv").disabled=false;notice(`${id} executed against the current database. This is not automatically baseline evidence.`);});
$("exportCsv").onclick=()=>{if(!lastQuery)return;const cell=v=>'"'+String(v===null?'\\N':v).replaceAll('"','""')+'"';const csv=[lastQuery.columns,...lastQuery.rows].map(r=>r.map(cell).join(",")).join("\r\n")+"\r\n";const url=URL.createObjectURL(new Blob([csv],{type:"text/csv;charset=utf-8"}));const a=document.createElement("a");a.href=url;a.download=`${lastQuery.id}.csv`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
$("loadTable").onclick=()=>task(async()=>{table("tableResults",await api(`/api/table/${$("tableName").value}`));notice("Loaded up to 100 records.");});
$("testConnection").onclick=()=>task(async()=>{table("connectionResults",await api("/api/connection"));notice("Connection succeeded.");});
$("operationId").onchange=renderOperation;
$("operationForm").onsubmit=e=>{e.preventDefault();task(async()=>{ticket=null;$("commitButton").disabled=true;const values={};new FormData(e.target).forEach((v,k)=>{values[k]=v===""&&k==="remarks"?null:v;});const name=$("operationId").value;const data=await api(`/api/operation/${name}/preview`,{values});ticket=data.ticket;previewValues=values;operationResult(data);$("commitButton").disabled=false;notice("Preview rolled back. Generated IDs are temporary and may differ after commit.");});};
$("commitButton").onclick=()=>task(async()=>{if(!ticket)return;const name=$("operationId").value;if(!window.confirm(`Save operation ${name} to ${cfg.database}?\n\n${JSON.stringify(previewValues,null,2)}\n\nThis reruns the operation against current data and commits changes.`))return;const saved=ticket;ticket=null;$("commitButton").disabled=true;operationResult(await api(`/api/operation/${name}/commit`,{ticket:saved}));notice("Operation committed. Refresh affected queries and records. Do not overwrite baseline evidence with mutated-state results.");});
(async()=>{try{const response=await fetch("/api/config");cfg=await response.json();if(!response.ok)throw new Error(cfg.error);$("dbBadge").textContent=cfg.database;$("connectionLabel").textContent=`${cfg.endpoint} / ${cfg.database}`;populate("queryId",cfg.queries);populate("tableName",cfg.tables);populate("operationId",cfg.operations.map(o=>o.id));renderOperation();}catch(e){notice(e.message,true);}})();
