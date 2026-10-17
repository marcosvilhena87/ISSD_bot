-- Read-only per-event pass statistics; one row per completed event.
local M={}
local function csv(v)
 local s=tostring(v==nil and "" or v)
 if s:find('[,"\r\n]') then return '"'..s:gsub('"','""')..'"' end
 return s
end
function M.new(path)
 local f,err=io.open(path or "issd_pass_events.csv","w")
 if not f then return nil,err end
 f:write("frame,pass_id,dominant,receiver,recommended,outcome,release_delay,dx,dy,direction_receiver_count,direction_total\n")
 f:flush()
 local stats={}
 local function record(frame,o)
  if type(o)~="table" then return false end
  if o.pass_event~="TEAMMATE_POSSESSION" and o.pass_event~="OBSERVATION_TIMEOUT" then return false end
  local dir=o.pass_dominant or "UNKNOWN"
  local receiver=o.pass_receiver or "UNCONFIRMED"
  local k=dir.."|"..tostring(receiver)
  stats[k]=(stats[k] or 0)+1
  local total=0
  for name,n in pairs(stats) do
   if name:sub(1,#dir+1)==dir.."|" then total=total+n end
  end
  local fields={frame,o.pass_id,dir,receiver,o.pass_recommended,o.pass_outcome,
   o.pass_release_delay,o.pass_dx,o.pass_dy,stats[k],total}
  for i=1,#fields do fields[i]=csv(fields[i]) end
  f:write(table.concat(fields,","),"\n")
  f:flush()
  return true
 end
 return {record=record,close=function() f:close() end}
end
return M
