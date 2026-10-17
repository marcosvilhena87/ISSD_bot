-- Tactical telemetry for ISSD; no game controls.
local M={}
local HEADER="frame,epoch,mode,phase,possession,logical_team,raw_owner,raw_team,ownership_source,logical_conflict,carrier_id,my_controlled_id,cpu_controlled_id,target_id,pressers,reason,decision_reason,elapsed,ball_x,ball_y"
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
   local parts={}
   for i,v in ipairs(values) do parts[i]=csv(v) end
   -- ipairs stops at the first nil; always serialize the whole schema.
   for i=1,20 do parts[i]=csv(values[i]) end
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
