-- Tactical telemetry for ISSD; no game controls.
local M={}
M.VERSION="1.15.4"
M.SCHEMA_VERSION=8
M.COLUMN_COUNT=101
local HEADER="frame,epoch,mode,phase,possession,logical_team,raw_owner,raw_team,ownership_source,logical_conflict,carrier_id,my_controlled_id,cpu_controlled_id,target_id,pressers,reason,decision_reason,elapsed,ball_x,ball_y,pass_safe,pass_too_close,pass_too_far,pass_blocked,best_rejected_id,best_rejected_reason,best_rejected_clearance,support_move_id,support_move_x,support_move_y,bot_version,schema_version,action,dribble_x,dribble_y,open_passes,triangle_via,triangle_next,triangle_score,pass_type,pass_score,pass_clearance,pass_progression,near1_id,near1_carrier_distance,near1_ball_distance,near1_reason,near1_blocker_id,near2_id,near2_carrier_distance,near2_ball_distance,near2_reason,near2_blocker_id,near3_id,near3_carrier_distance,near3_ball_distance,near3_reason,near3_blocker_id,gk1_id,gk1_ball_distance,gk1_keeper_distance,gk1_clearance,gk1_blocker_id,gk2_id,gk2_ball_distance,gk2_keeper_distance,gk2_clearance,gk2_blocker_id,gk3_id,gk3_ball_distance,gk3_keeper_distance,gk3_clearance,gk3_blocker_id,gk1_direction,gk1_command,gk1_dx,gk1_dy,gk1_calibration_status,gk2_direction,gk2_command,gk2_dx,gk2_dy,gk2_calibration_status,gk3_direction,gk3_command,gk3_dx,gk3_dy,gk3_calibration_status,input_status,input_source,input_direction,input_b,pass_id,pass_event,pass_kind,pass_direction,pass_lead_frames,pass_dx,pass_dy,pass_receiver,pass_note"
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
 local function record(frame,s,result,observation)
   if closed then return false,"closed" end
   if last_frame and frame<last_frame then epoch=epoch+1 end
   last_frame=frame
   s=type(s)=="table" and s or {}
   result=result or {}
   local action=result.decision or {}
   local d=action.base or action
   local b=s.ball or {}
   local values={frame,epoch,result.mode,result.phase,s.possession,s.logical_team,
     s.raw_owner,s.raw_team,s.ownership_source,s.logical_conflict and 1 or 0,
     s.carrier_id,s.my_controlled_id,s.cpu_controlled_id,action.target_id or d.target_id,
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
   local motion=action.dribble or {}
   local triangle=action.triangle or {}
   values[33]=action.mode
   values[34]=motion.x
   values[35]=motion.y
   values[36]=motion.open_passes
   values[37]=triangle.via
   values[38]=triangle.next_id
   values[39]=triangle.score
   values[40]=action.pass_type or d.pass_type
   values[41]=action.pass_score or d.pass_score
   values[42]=action.pass_clearance or d.pass_clearance
   values[43]=action.pass_progression or d.pass_progression
   local nearest=diag.nearest or {}
   for i=1,3 do
      local n=nearest[i] or {}
      local k=43+(i-1)*5
      values[k+1]=n.id
      values[k+2]=n.distance
      values[k+3]=n.ball_distance
      values[k+4]=n.reason
      values[k+5]=n.blocking_enemy_id
   end
   if result.mode=="GK_DISTRIBUTION" then
      for i=1,3 do
         local option=action.options and action.options[i] or {}
         local k=58+(i-1)*5
         values[k+1]=option.id
         values[k+2]=option.distance
         values[k+3]=option.keeper_distance
         values[k+4]=option.clearance
         values[k+5]=option.blocker_id
      end
   end
   if result.mode=="GK_DISTRIBUTION" then
      for i=1,3 do
         local option=action.options and action.options[i] or {}
         local k=73+(i-1)*5
         values[k+1]=option.direction
         values[k+2]=option.command
         values[k+3]=option.dx
         values[k+4]=option.dy
         values[k+5]=option.status
      end
   end
   observation=type(observation)=="table" and observation or {}
   local extra={"input_status","input_source","input_direction","input_b","pass_id",
     "pass_event","pass_kind","pass_direction","pass_lead_frames",
     "pass_dx","pass_dy","pass_receiver","pass_note"}
   for i,key in ipairs(extra) do values[88+i]=observation[key] end
   local parts={}
   -- ipairs stops at the first nil; always serialize the whole schema.
   for i=1,M.COLUMN_COUNT do parts[i]=csv(values[i]) end
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
