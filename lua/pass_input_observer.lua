-- Passive input/event observer. Never sends controller commands.
local M={}
local function finite(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
local function pos(s)
 local b=type(s)=="table" and s.ball
 if type(b)=="table" and finite(b.x) and finite(b.y) then return {x=b.x,y=b.y} end
end
local function down(t,k)
 return t["P1 "..k]==true or t["P1 "..k]==1 or t[k]==true or t[k]==1
end
local function key_diagnostics(t)
 local keys,recognized={},false
 for k in pairs(t) do
  if type(k)=="string" then
   keys[#keys+1]=k
  end
 end
 table.sort(keys)
 local recognized_keys={Up=true,Down=true,Left=true,Right=true,B=true}
 for _,k in ipairs(keys) do
  if recognized_keys[k] or (k:sub(1,3)=="P1 " and recognized_keys[k:sub(4)]) then
   recognized=true;break
  end
 end
 local raw=table.concat(keys,";")
 if #raw>450 then raw=raw:sub(1,450).."...[truncated]" end
 return recognized,raw
end
local function direction(t)
 local v=(down(t,"Up") and not down(t,"Down")) and "Up" or
         (down(t,"Down") and not down(t,"Up")) and "Down" or nil
 local h=(down(t,"Left") and not down(t,"Right")) and "Left" or
         (down(t,"Right") and not down(t,"Left")) and "Right" or nil
 return v and h and (v.."+"..h) or v or h
end
function M.new(opts)
 opts=opts or {}
 local max_follow=opts.max_follow or 120
 local previous_frame,previous_b,aim_start,aim_dir,last_dir,last_dir_frame
 local active,serial=nil,0
 local direction_counts,last_single,last_diagonal,last_direction_frame,release_frame={},nil,nil,nil,nil
 local last_key_signature
 local function reset()
  previous_frame,previous_b,aim_start,aim_dir,last_dir,last_dir_frame=nil,false,nil,nil,nil,nil
  active=nil
  last_key_signature=nil
  direction_counts={};last_single=nil;last_diagonal=nil;last_direction_frame=nil;release_frame=nil
 end
 local function update(frame,s,buttons,source)
  if not finite(frame) then reset();return {input_status="INVALID_FRAME"} end
  if previous_frame and (frame<=previous_frame or frame>previous_frame+1) then reset() end
  previous_frame=frame
  local result={input_status="UNAVAILABLE"}
  if type(buttons)~="table" then
   -- Unknown input is not equivalent to no buttons pressed.
   previous_b=false;aim_start=nil;aim_dir=nil;last_dir=nil;last_dir_frame=nil
   direction_counts={};last_single=nil;last_diagonal=nil;last_direction_frame=nil;release_frame=nil
  else
   local recognized,raw=key_diagnostics(buttons)
   if raw~=last_key_signature then
    result.pass_note="joypad_keys="..(raw~="" and raw or "[empty]")
    last_key_signature=raw
   end
   if not recognized then
    result.input_status="UNKNOWN_LAYOUT"
    previous_b=false;aim_start=nil;aim_dir=nil;last_dir=nil;last_dir_frame=nil
    direction_counts={};last_single=nil;last_diagonal=nil;last_direction_frame=nil;release_frame=nil
    return result
   end
   local dir=direction(buttons)
   local b=down(buttons,"B")
   result.input_status="OBSERVED"
   result.input_source=source or "joypad.get"
   result.input_direction=dir
   result.input_b=b and 1 or 0
   if dir then
    if dir~=aim_dir then aim_start=frame;aim_dir=dir end
    last_dir,last_dir_frame=dir,frame
    direction_counts[dir]=(direction_counts[dir] or 0)+1
    if dir:find("+",1,true) then last_diagonal=dir else last_single=dir end
    last_direction_frame=frame
    release_frame=nil
   else
    if aim_dir then release_frame=frame end
    aim_start=nil;aim_dir=nil
   end
   if b and not previous_b then
    local dominant,dcount=nil,-1
    for candidate,count in pairs(direction_counts) do
     if count>dcount or (count==dcount and (not dominant or candidate<dominant)) then
      dominant,dcount=candidate,count
     end
    end
    local since_release=not dir and last_direction_frame and (frame-last_direction_frame) or nil
    local recommended=s and (s.recommended_target_id or s.target_id)

    serial=serial+1
    local held=dir~=nil
    local chosen=dir or last_dir
    local lead=held and math.max(0,frame-(aim_start or frame)) or
       (last_dir_frame and math.max(0,last_dir_frame-(aim_start or last_dir_frame)) or nil)
    -- Prior direction cannot be recovered after release without explicit history;
    -- avoid claiming a known duration for the released-direction case.
    if not held then lead=nil end
    local kind=held and (lead>0 and "HELD_SEQUENTIAL" or "SIMULTANEOUS") or
       (chosen and "RELEASED_THEN_B" or "B_ONLY")
    active={id=serial,start=frame,origin=pos(s),direction=chosen,kind=kind,
      lead=lead,source=result.input_source,initial_carrier=s and s.carrier_id,
      recommended=recommended,last_single=last_single,last_diagonal=last_diagonal,
      dominant=dominant,release_delay=since_release}
    result.pass_event="B_EDGE"
    result.pass_kind=kind
    result.pass_lead_frames=lead
    result.pass_direction=chosen
    result.pass_last_single=last_single
    result.pass_last_diagonal=last_diagonal
    result.pass_dominant=dominant
    result.pass_release_delay=since_release
    result.pass_recommended=recommended
    direction_counts={}
   end
   previous_b=b
  end
  if active then
   result.pass_id=active.id
   result.pass_last_single=active.last_single
   result.pass_last_diagonal=active.last_diagonal
   result.pass_dominant=active.dominant
   result.pass_release_delay=active.release_delay
   result.pass_recommended=active.recommended
   result.pass_kind=result.pass_kind or active.kind
   result.pass_direction=result.pass_direction or active.direction
   result.pass_lead_frames=result.pass_lead_frames or active.lead
   local p=pos(s)
   if p and active.origin then
    result.pass_dx=p.x-active.origin.x
    result.pass_dy=p.y-active.origin.y
   end
   local age=frame-active.start
   if age>0 and s and s.possession=="my" and s.carrier_id and
      s.carrier_id~=active.initial_carrier then
     result.pass_event="TEAMMATE_POSSESSION"
     result.pass_receiver=s.carrier_id
     result.pass_outcome=active.recommended==nil and "UNCONFIRMED" or
       (tostring(active.recommended)==tostring(s.carrier_id) and "MATCH" or "MISMATCH")
     active=nil
   elseif age>=max_follow then
     result.pass_event="OBSERVATION_TIMEOUT"
     result.pass_outcome="UNCONFIRMED"
     active=nil
   end
  end
  return result
 end
 return {update=update,reset=reset}
end
return M
