-- Tactical telemetry for ISSD; no game controls.
local M={}
M.VERSION="1.12.0"
M.SCHEMA_VERSION=2
local HEADER="frame,epoch,mode,phase,possession,logical_team,raw_owner,raw_team,ownership_source,logical_conflict,carrier_id,my_controlled_id,cpu_controlled_id,target_id,pressers,reason,decision_reason,elapsed,ball_x,ball_y,pass_safe,pass_too_close,pass_too_far,pass_blocked,best_rejected_id,best_rejected_reason,best_rejected_clearance,support_move_id,support_move_x,support_move_y,bot_version,schema_version"
local function csv(v)
 if v==nil then return "" end
 local s=tostring(v)
 if s:find('[,",\r\n]') then return '"'..s:gsub('"','""')..'"' end
 return s
end
local function pressers(d)
 local out={}
 for _,p in ipairs(d and d.pressers or {}) do
   out[#out+1]=tostring(p.id or "")..":"..tostring(p.role or "")
 end
 return table.concat(out,";")
end
function M.new(path,opts)
 opts=opts or {}
 local file,err=io.open(path or "issd_tactical_report.csv","w")
 if not file then return nil,err end
 file:write(HEADER,"\n")
 file:flush()
 local epoch,last_frame,count=0,nil,0
 local flush_every=opts.flush_every or 60
 assert(type(flush_every)=="number" and flush_every>=1,"invalid flush_every")
 local closed=false
 local function record(frame,s,result)
   if closed then return false,"closed" end
   if last_frame and frame<last_frame then epoch=epoch+1 end
   last_frame=frame
   s=type(s)=="table" and s or {}
   result=result or {}
   local d=result.decision or {}
   local b=s.ball or {}
   local values={frame,epoch,result.mode,result.phase,s.possession,s.logical_team,
     s.raw_owner,s.raw_team,s.ownership_source,s.logical_conflict and 1 or 0,
     s.carrier_id,s.my_controlled_id,s.cpu_controlled_id,d.target_id,
     pressers(d),result.reason or s.reason,d.reason,d.elapsed,b.x,b.y}
   local diag=d.diagnostics or {}
   local counts=diag.counts or {}
   local rejected=diag.best_rejected or {}
   local move=diag.support_move or {}
   values[21]=counts.SAFE
   values[22]=counts.TOO_CLOSE
   values[23]=counts.TOO_FAR
   values[24]=counts.BLOCKED
   values[25]=rejected.id
   values[26]=rejected.reason
   values[27]=rejected.clearance
   values[28]=move.id
   values[29]=move.x
   values[30]=move.y
   values[31]=M.VERSION
   values[32]=M.SCHEMA_VERSION
   local parts={}
   -- ipairs stops at the first nil; always serialize the whole schema.
   for i=1,32 do parts[i]=csv(values[i]) end
   local ok,werr=file:write(table.concat(parts,","),"\n")
   if not ok then return false,werr end
   count=count+1
   if count%flush_every==0 or epoch>0 and frame==0 then file:flush() end
   return true
 end
 local function close()
   if not closed then file:flush();file:close();closed=true end
 end
 return {record=record,close=close,flush=function() if not closed then file:flush() end end}
end
return M
