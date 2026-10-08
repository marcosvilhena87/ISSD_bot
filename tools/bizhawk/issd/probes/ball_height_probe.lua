-- ISSD: discover candidate ball height (Z) in BizHawk WRAM.
-- Run ALONE in Lua Console, with the ROM active. Never writes game memory.
-- G=ground stationary, R=rolling pass, A=airborne, P=near apex.
-- C=rank candidates, X=reset. Capture >=3 samples per class.
-- Use visibly different field positions and ball trajectories.
local DOMAIN="WRAM"
local ORDER={"GROUND","ROLLING","AIR","APEX"}
local HOTKEY={G="GROUND",R="ROLLING",A="AIR",P="APEX"}
local samples={}
local previous={}
local frame=0
for _,name in ipairs(ORDER) do samples[name]={} end

local function edge(keys,key)
    return keys[key] and not previous[key]
end

local function snapshot()
    local size=memory.getmemorydomainsize(DOMAIN)
    local bytes={}
    for addr=0,size-1 do
        bytes[addr]=memory.read_u8(addr,DOMAIN)
    end
    return bytes,size
end

local function stat(list,addr,width)
    if #list==0 then return nil end
    local minv,maxv,first
    for _,s in ipairs(list) do
        local v=s.bytes[addr]
        if width==2 then
            if s.bytes[addr+1]==nil then return nil end
            v=v+256*s.bytes[addr+1]
        end
        if minv==nil or v<minv then minv=v end
        if maxv==nil or v>maxv then maxv=v end
        if first==nil then first=v end
    end
    return {low=minv,high=maxv,spread=maxv-minv,first=first}
end

local function rank(width,size)
    local found={}
    for addr=0,size-width do
        -- Avoid known X/Y and direct possession flags. They are not Z.
        if not (addr>=0x042A and addr<=0x042D) then
            local g=stat(samples.GROUND,addr,width)
            local r=stat(samples.ROLLING,addr,width)
            local a=stat(samples.AIR,addr,width)
            local p=stat(samples.APEX,addr,width)
            if g and r and a and p then
                local baseline_low=math.min(g.low,r.low)
                local baseline_high=math.max(g.high,r.high)
                local baseline_spread=baseline_high-baseline_low
                local airborne_above=(a.low>baseline_high and p.low>baseline_high)
                local airborne_below=(a.high<baseline_low and p.high<baseline_low)
                if (airborne_above or airborne_below) and baseline_spread<=8 then
                    local gap=airborne_above and
                        math.min(a.low,p.low)-baseline_high or
                        baseline_low-math.max(a.high,p.high)
                    local apex_bonus=airborne_above and
                        (p.low>=a.low and 1 or 0) or
                        (p.high<=a.high and 1 or 0)
                    local score=gap*4-baseline_spread*5+apex_bonus*4
                    found[#found+1]={addr=addr,score=score,
                        ground=g.first,rolling=r.first,
                        air=a.first,apex=p.first,gap=gap}
                end
            end
        end
    end
    table.sort(found,function(a,b)
        if a.score==b.score then return a.addr<b.addr end
        return a.score>b.score
    end)
    return found
end

local function report()
    for _,name in ipairs(ORDER) do
        if #samples[name]<3 then
            console.log(string.format("[BALL_Z] %s: %d/3; capture more",name,#samples[name]))
            return
        end
    end
    local _,size=snapshot()
    for _,width in ipairs({1,2}) do
        local found=rank(width,size)
        console.log(string.format("[BALL_Z] width=%d candidates=%d; top 30",width,#found))
        for i=1,math.min(30,#found) do
            local c=found[i]
            console.log(string.format(
                "  $%05X u%d score=%.1f ground=%d roll=%d air=%d apex=%d gap=%d",
                c.addr,width*8,c.score,c.ground,c.rolling,c.air,c.apex,c.gap))
        end
    end
    console.log("[BALL_Z] Candidates are hypotheses; verify live Z dynamics, landing, stadium and restart.")
end

console.log("[BALL_Z] G=ground R=rolling A=air P=apex C=rank X=reset")
while true do
    local keys=input.get()
    for key,name in pairs(HOTKEY) do
        if edge(keys,key) then
            local bytes=snapshot()
            samples[name][#samples[name]+1]={bytes=bytes,frame=frame}
            console.log(string.format("[BALL_Z] captured %s #%d frame=%d",
                name,#samples[name],frame))
        end
    end
    if edge(keys,"C") then report() end
    if edge(keys,"X") then
        for _,name in ipairs(ORDER) do samples[name]={} end
        console.log("[BALL_Z] reset")
    end
    gui.text(8,8,string.format("BALL Z PROBE  G:%d R:%d A:%d P:%d",
        #samples.GROUND,#samples.ROLLING,#samples.AIR,#samples.APEX))
    previous=keys
    frame=frame+1
    emu.frameadvance()
end
