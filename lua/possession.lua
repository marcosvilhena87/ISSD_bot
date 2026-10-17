-- ISSD WRAM state provider for tactical planners (read-only).
-- Player ownership is authoritative; 0x104C is diagnostic, not confirmed.
local M={}
local A={gameplay=0x0006,game_state=0x00BA,owner=0x00A6,
 team=0x104C,my_control=0x1ACC,cpu_control=0x1AFC,
 ball_x=0x042A,ball_y=0x042C,length=0x12A2,width=0x12A4}
local function base_kind(b)
 if type(b)~="number" or b%0x100~=0 then return nil end
 if b>=0x0500 and b<=0x0F00 then return "my",(b-0x0500)/0x100+1 end
 if b>=0x1000 and b<=0x1A00 then return "cpu",(b-0x1000)/0x100+1 end
 return nil
end
M.base_kind=base_kind
local function build(read)
 local u8,u16,s16=read.u8,read.u16,read.s16
 local live=u8(A.gameplay)==1 and u16(A.game_state)==0
 local owner=u16(A.owner)
 local team_byte=u8(A.team)
 local physical,slot=base_kind(owner)
 local logical=team_byte==0 and "my" or team_byte==1 and "cpu" or nil
 local observation={active=false,ownership_source="UNKNOWN",
    raw_owner=owner,raw_team=team_byte,raw_my_control=u16(A.my_control),
    raw_cpu_control=u16(A.cpu_control),logical_team=logical}
 if not live then observation.reason="not_live";return observation end
 local length,width=u16(A.length),u16(A.width)
 if length<=8 or width<=8 then observation.reason="invalid_field";return observation end
 observation.field_length=length
 observation.field_width=width
 local ball={x=s16(A.ball_x),y=s16(A.ball_y)}
 local my,cpu={},{}
 for i=0,10 do
    local mb,cb=0x0500+i*0x100,0x1000+i*0x100
    my[#my+1]={id=i+1,x=s16(mb+0x2A),y=s16(mb+0x2C),
                 is_goalkeeper=i==0}
    cpu[#cpu+1]={id=i+1,x=s16(cb+0x2A),y=s16(cb+0x2C),
                  is_goalkeeper=i==0}
 end
 -- Attacking direction follows goalkeepers, never raw side flags.
 -- Refuse to guess goals when keeper positions are ambiguous.
 local mx,cx=my[1].x,cpu[1].x
 if math.abs(mx-cx)<length*0.35 then
    observation.reason="ambiguous_goals";return observation
 end
 local own_goal={x=mx,y=width/2}
 local opponent_goal={x=cx,y=width/2}
 observation.field_length=length
 observation.field_width=width
 observation.ball=ball
 observation.my_players=my
 observation.cpu_players=cpu
 observation.own_goal=own_goal
 observation.opponent_goal=opponent_goal
 observation.my_controlled_id=select(2,base_kind(observation.raw_my_control))
 observation.cpu_controlled_id=select(2,base_kind(observation.raw_cpu_control))
 if physical then
    observation.possession=physical
    observation.carrier_id=physical=="my" and slot or nil
    observation.ownership_source="PLAYER_BALL_POSSESSION"
    observation.logical_conflict=logical~=nil and logical~=physical
    observation.active=true
 else
    observation.ownership_source=logical and "LOGICAL_UNVERIFIED" or "UNKNOWN"
    observation.reason=owner==0 and "ball_in_flight_or_loose" or "unknown_owner"
    -- Do not turn a mere team flag into a confirmed possession transition.
 end
 return observation
end
function M.snapshot(read)
 assert(type(read)=="table" and type(read.u8)=="function"
   and type(read.u16)=="function" and type(read.s16)=="function",
   "memory readers required")
 return build(read)
end
function M.bizhawk()
 assert(type(memory)=="table","BizHawk memory API required")
 local d="WRAM"
 return M.snapshot({
   u8=function(a) return memory.read_u8(a,d) end,
   u16=function(a) return memory.read_u16_le(a,d) end,
   s16=function(a) return memory.read_s16_le(a,d) end
 })
end
return M
