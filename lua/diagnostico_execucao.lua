-- Diagnostic standalone BizHawk script. Open through Lua Console > Open Script.
print("[ISSD DIAG] script carregado")
if type(gui)=="table" and type(gui.addmessage)=="function" then
    pcall(gui.addmessage,"ISSD DIAG carregado")
end
if type(emu)~="table" or type(emu.frameadvance)~="function" then
    print("[ISSD DIAG] API emu.frameadvance indisponivel")
    return
end
local frames=0
while true do
    if type(gui)=="table" and type(gui.text)=="function" then
        gui.text(5,20,"ISSD DIAG ativo: "..tostring(frames))
    end
    if frames%120==0 then print("[ISSD DIAG] frame local "..frames) end
    frames=frames+1
    emu.frameadvance()
end
