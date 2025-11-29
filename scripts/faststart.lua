-------------------------------------------------------------------------------
-- Accellerate the first 10 seconds of the startup
-- Include using dofile("faststart.lua") to speed through the machine startup
if not running then
    running = true
    local frameskip = manager.machine.video.frameskip
    local throttled = manager.machine.video.throttled

    if manager.machine.debugger then
        manager.machine.debugger.execution_state="run"
    end

    manager.machine.video.frameskip = 10
    manager.machine.video.throttled = false

    emu.wait(10)

    manager.machine.video.frameskip = frameskip
    manager.machine.video.throttled = throttled
end