-- Passive raw Team_Ball_Possession edge monitor. Changes are NOT confirmed touches.
local M={}
function M.new(config,mem,players)
 local o={previous=nil,last_frame=nil,last_shots_cpu=nil,last_shots_my=nil}
 function o.update(frame,gameplay,gs,owner,last_owner,last_owner_frame)
  local raw=mem.u8(config.ADDR.team_possession)
  local sc=mem.u16(config.ADDR.shots_cpu)
  local sm=mem.u16(config.ADDR.shots_my)
  local before=o.previous
  local before_frame=o.last_frame
  local prev_cpu=o.last_shots_cpu
  local prev_my=o.last_shots_my
  o.previous=raw;o.last_frame=frame
  o.last_shots_cpu=sc;o.last_shots_my=sm
  if before==nil or raw==before then return nil end
  local bx=mem.s16(config.ADDR.ball_x)
  local by=mem.s16(config.ADDR.ball_y)
  local height=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
  local mx,my=players.xy(config.MY_FIRST)
  local cx,cy=players.xy(config.CPU_FIRST)
  local function dist(x,y)return math.sqrt((bx-x)^2+(by-y)^2) end
  return {from=before,to=raw,frame_gap=before_frame and frame-before_frame,
    owner=owner,last_owner=last_owner,
    frames_since_owner=last_owner_frame and frame-last_owner_frame,
    height=height,dist_my_gk=dist(mx,my),dist_cpu_gk=dist(cx,cy),
    shots_cpu=sc,shots_cpu_delta=prev_cpu and sc-prev_cpu,
    shots_my=sm,shots_my_delta=prev_my and sm-prev_my,
    gameplay=gameplay,game_state=gs}
 end
 return o
end
return M
