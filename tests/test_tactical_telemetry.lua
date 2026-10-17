package.path="./lua/?.lua;"..package.path
local telemetry=require("tactical_telemetry")
local path="test_tactical_report_tmp.csv"
local writer,err=telemetry.new(path,{flush_every=1})
assert(writer,err)
assert(writer.record(39413,{active=true,possession="my",raw_owner=1536,
  raw_team=0,ball={x=123,y=333}},{mode="TIKI_TAKA",phase="ATTACK",
  decision={target_id=3,reason="safe_short_pass"}}))
assert(writer.record(4283,{reason="ball_in_flight_or_loose"},
  {mode="INACTIVE",reason="unvalidated_state"}))
assert(writer.record(4284,{possession="cpu",raw_owner=4352},
  {mode="GEGENPRESS",decision={pressers={{id=2,role="PRESS"},{id=4,role="COVER"}},elapsed=0}}))
writer.close()
local f=assert(io.open(path,"r"))
local header=f:read("*l")
local a=f:read("*l")
local b=f:read("*l")
local c=f:read("*l")
f:close();os.remove(path)
assert(header:find("ownership_source",1,true))
assert(telemetry.VERSION=="1.15.6" and telemetry.SCHEMA_VERSION==9 and telemetry.COLUMN_COUNT==107)
assert(header:find("pass_lead_frames",1,true))
local n=0 for _ in header:gmatch("[^,]+") do n=n+1 end assert(n==107)
assert(a:find("39413,0,TIKI_TAKA",1,true))
assert(b:find("4283,1,INACTIVE",1,true))
assert(c:find("2:PRESS;4:COVER",1,true))
print("tactical telemetry tests passed")
