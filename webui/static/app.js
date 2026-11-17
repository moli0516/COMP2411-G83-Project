"use strict";
const $ = id => document.getElementById(id);
let cfg, lastQuery, ticket = null, previewValues = null, busy = false;

const QUERY_INFO = {
  Q01: ["Failure rate by hardware type", "Completed first-round inspections, 2026-03-01 through 2026-10-31. SQL file controls the period."],
  Q02: ["First-round failures by technician", "Compare failure counts alongside inspected-job totals. Check the SQL file for its reporting period."],
  Q03: ["Overdue unverified actions", "Fixed reporting date: 2026-10-31. Includes RESOLVED actions awaiting verification."],
  Q04: ["Equipment received more than once", "Counts received service jobs, not undelivered request items."],
  Q05: ["Above-average days overdue", "Overdue unverified actions exceeding their population average; reporting date 2026-10-31."],
  Q06: ["Incidents missing corrective actions", "Zero rows is expected on the verified seed. This audit detects missing links; it does not prevent them."],
  Q07: ["Technician unresolved-action workload", "Counts OPEN/IN_PROGRESS actions; retains inactive and zero-action technicians."],
  Q08: ["Currently open repeat-repair jobs", "Earlier same-equipment closed repair with a failed first inspection and return before current request; association, not causation."]
};
const FIELD_OPTIONS = {
  result: ["PASS", "FAIL"],
  criterion_name: ["POWER_ON", "FUNCTION_TEST", "TEMPERATURE_TEST", "VOLTAGE_TEST", "PHYSICAL_CONDITION", "ACCESSORY_COMPLETENESS"],
  severity: ["LOW", "MEDIUM", "HIGH"]
};
function clearQueryExport() {
  lastQuery = null;
  $("exportCsv").disabled = true;
}
function queryDescription() {
  let node = $("queryDescription");
  if (!node) {
    node = document.createElement("p");
    node.id = "queryDescription";
    node.className = "muted";
    $("queryId").insertAdjacentElement("afterend", node);
  }
  const info = QUERY_INFO[$("queryId").value];
  node.textContent = info ? info[1] : "Runs the current local SQL file.";
}
function createOperationField(name) {
  const label = document.createElement("label");
  label.className = "field";
  label.append(document.createTextNode(name));
  const options = FIELD_OPTIONS[name];
  const input = document.createElement(options ? "select" : "input");
  input.name = name;
  input.required = name !== "remarks";
  if (options) {
    options.forEach(value => {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = value;
      input.append(option);
    });
  } else {
    input.type = name.endsWith("_date") ? "date" :
      (name.endsWith("_id") || name === "quoted_amount" ? "number" : "text");
    if (input.type === "number") {
      input.min = name === "quoted_amount" ? "0.01" : "1";
      input.step = name === "quoted_amount" ? "0.01" : "1";
    }
  }
  const invalidate = () => {
    ticket = null;
    previewValues = null;
    $("commitButton").disabled = true;
  };
  input.addEventListener("input", invalidate);
  input.addEventListener("change", invalidate);
  label.append(input);
  $("operationFields").append(label);
}
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
  op.fields.forEach(createOperationField);
}
function operationResult(data){$("operationResults").replaceChildren();const p=document.createElement("p");p.textContent=data.outcome;$("operationResults").append(p);data.results.forEach((r,i)=>{const box=document.createElement("div");box.id=`opResult${i}`;$("operationResults").append(box);table(box.id,r);});}
function populate(id,items){$(id).replaceChildren();items.forEach(v=>{const o=document.createElement("option");o.value=v;o.textContent=v;$(id).append(o);});}
document.querySelectorAll("nav button").forEach(b=>b.onclick=()=>{document.querySelectorAll(".pane").forEach(p=>p.classList.toggle("hidden",p.id!==b.dataset.pane));document.querySelectorAll("nav button").forEach(n=>n.classList.toggle("current",n===b));});
$("queryId").onchange = () => {
  clearQueryExport();
  $("queryResults").replaceChildren();
  queryDescription();
};
$("runQuery").onclick = () => task(async () => {
  clearQueryExport();
  $("queryResults").replaceChildren();
  const id = $("queryId").value;
  const result = await api(`/api/query/${id}`);
  if ($("queryId").value !== id) return;
  lastQuery = {id, ...result};
  table("queryResults", result);
  $("exportCsv").disabled = false;
  const suffix = id === "Q06" && result.rows.length === 0 ?
    " Zero rows is expected on the verified seed; the header-only CSV is valid." : "";
  notice(`${id}: ${result.rows.length} row(s), database ${cfg.database}.` + suffix +
    " Current-state output is not automatically clean-seed evidence.");
});
$("exportCsv").onclick=()=>{if(!lastQuery)return;const cell=v=>'"'+String(v===null?'\\N':v).replaceAll('"','""')+'"';const csv=[lastQuery.columns,...lastQuery.rows].map(r=>r.map(cell).join(",")).join("\r\n")+"\r\n";const url=URL.createObjectURL(new Blob([csv],{type:"text/csv;charset=utf-8"}));const a=document.createElement("a");a.href=url;a.download=`${lastQuery.id}.csv`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
$("loadTable").onclick=()=>task(async()=>{table("tableResults",await api(`/api/table/${$("tableName").value}`));notice("Loaded up to 100 records.");});
$("testConnection").onclick=()=>task(async()=>{table("connectionResults",await api("/api/connection"));notice("Connection succeeded.");});
$("operationId").onchange=renderOperation;
$("operationForm").onsubmit=e=>{e.preventDefault();task(async()=>{ticket=null;$("commitButton").disabled=true;const values={};new FormData(e.target).forEach((v,k)=>{values[k]=v===""&&k==="remarks"?null:v;});const name=$("operationId").value;const data=await api(`/api/operation/${name}/preview`,{values});ticket=data.ticket;previewValues=values;operationResult(data);$("commitButton").disabled=false;notice("Preview rolled back. Generated IDs are temporary and may differ after commit.");});};
$("commitButton").onclick=()=>task(async()=>{if(!ticket)return;const name=$("operationId").value;if(!window.confirm(`Save operation ${name} to ${cfg.database}?\n\n${JSON.stringify(previewValues,null,2)}\n\nThis reruns the operation against current data and commits changes.`))return;const saved=ticket;ticket=null;$("commitButton").disabled=true;clearQueryExport();$("queryResults").replaceChildren();operationResult(await api(`/api/operation/${name}/commit`,{ticket:saved}));notice("Operation committed. Refresh affected queries and records. Do not overwrite baseline evidence with mutated-state results.");});
(async()=>{try{const response=await fetch("/api/config");cfg=await response.json();if(!response.ok)throw new Error(cfg.error);$("dbBadge").textContent=cfg.database;$("connectionLabel").textContent=`${cfg.endpoint} / ${cfg.database}`;populate("queryId",cfg.queries);Array.from($("queryId").options).forEach(option=>{const info=QUERY_INFO[option.value];if(info)option.textContent=`${option.value} — ${info[0]}`;});queryDescription();populate("tableName",cfg.tables);populate("operationId",cfg.operations.map(o=>o.id));renderOperation();}catch(e){notice(e.message,true);}})();
