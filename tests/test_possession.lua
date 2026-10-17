package.path="./lua/?.lua;"..package.path
local P=require("possession")
local function sample(owner,logical)
 local ram={
 [0x0006]=1,[0x00BA]=0,[0x00A6]=owner,[0x104C]=logical,
 [0x1ACC]=0x0600,[0x1AFC]=0x1100,
 [0x042A]=850,[0x042C]=300,[0x12A2]=1920,[0x12A4]=640,
 [0x052A]=100,[0x102A]=1800
 }
 local function get(a) return ram[a] or 0 end
 return P.snapshot({u8=get,u16=get,s16=get}),ram
end
local s=sample(0x0600,0)
assert(s.active and s.possession=="my" and s.carrier_id==2)
assert(s.my_controlled_id==2 and s.cpu_controlled_id==2)
local c=sample(0x1100,1)
assert(c.active and c.possession=="cpu" and c.carrier_id==nil)
local in_flight=sample(0,0)
assert(not in_flight.active and in_flight.ownership_source=="LOGICAL_UNVERIFIED")
local conflict=sample(0x0600,1)
assert(conflict.active and conflict.possession=="my" and conflict.logical_conflict)
local unknown=sample(0x1234,0)
assert(not unknown.active and unknown.reason=="unknown_owner")
local invalid,ram=sample(0x0600,0)
ram[0x0006]=0
local function get(a) return ram[a] or 0 end
invalid=P.snapshot({u8=get,u16=get,s16=get})
assert(not invalid.active and invalid.reason=="not_live")
assert(P.base_kind(0x0501)==nil)
print("possession tests passed")
