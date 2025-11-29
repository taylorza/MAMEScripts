-------------------------------------------------------------------------------
-- Simple Profiler for ZX Spectrum Next
-- NEXTREG 127 - controls the individual timers
-- Values:
--   0      - Disable and reset all the timers
--   1..8   - Start the specified timer
--  -1..-8  - Stop the specified timer (absolute value)
--  Stoping an already stopped timer will reset that timer 

local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local io = cpu.spaces["io"]
local screen = machine.screens[':screen']

-- Timers
local timers={
    {enabled=false, start=emu.attotime(), duration=0.0, color=0x6600bfff},
    {enabled=false, start=emu.attotime(), duration=0.0, color=0x6639ff14},
    {enabled=false, start=emu.attotime(), duration=0.0, color=0x66ff00ff},
    {enabled=false, start=emu.attotime(), duration=0.0, color=0x6600ffff},
    {enabled=false, start=emu.attotime(), duration=0.0, color=0x66ff4500},
    {enabled=false, start=emu.attotime(), duration=0.0, color=0x668a2be2},
    {enabled=false, start=emu.attotime(), duration=0.0, color=0x66ffd700},
    {enabled=false, start=emu.attotime(), duration=0.0, color=0x6640e0d0},
}

-- Selected Next Register
local reg=-1

-- Tap port $243b to track NEXTREG selection
tap_io_243B = io:install_write_tap(0x243b, 0x243b, "IO_243B", 
    function(offset, data, mask)
        reg = data
    end
)

-- Tap port $253b to track writes to NEXTREG
tap_io_253B = io:install_write_tap(0x253b, 0x253b, "IO_253B", 
    function(offset, data, mask)
        -- Check if writing to User NEXTREG 127 ($7f)
        if reg == 127 then
            if data == 0 then 
                -- Disable and reset all timers
                for i = 1, 8 do
                    local timer = timers[i]
                    timer.enabled = false
                    timer.start = emu.attotime()
                    timer.duration = 0.0
                end
            elseif data > 127 then 
                -- Disable timer at abs(value)
                local i = 256-data
                local timer = timers[i]       

                if timer.enabled then
                    local delta = machine.time - timer.start
                    timer.duration = delta:as_double()
                    timer.enabled = false  
                else
                    -- Reset the timer if already disabled
                    timer.duration = 0.0                  
                end
            else
                -- Start timer
                local i = data
                local timer = timers[i]
                if not timer.enabled then
                    timer.enabled = true
                    timer.start = machine.time
                    timer.duration = 0.0
                end
            end
        end
    end
)

-- Create profiler overlay
emu.register_frame_done(
    function()
        local line_height = 12
        local frame_x = 2
        local frame_y = 2
        local frame_width = 78
        local frame_height = (line_height * #timers) + 5
        local pad_x = 5
        local pad_y = 5

        -- Pass 1 find max duration and render timers
        local max_duration = 0.0
        for i, timer in ipairs(timers) do
            if timer.enabled then
                local delta = machine.time - timer.start
                timer.duration = delta:as_double()
            end
            if timer.duration > max_duration then
                max_duration = timer.duration
            end            
        end

        -- Exit if no timers are running
        if max_duration == 0.0 then
            return
        end

        -- Draw frame
        screen:draw_box(
            frame_x, frame_y, 
            frame_x + frame_width, 
            frame_y + frame_height, 
            0xff00ffff, 0xff000000)

        -- Pass 2 render timers and scaled profiler bar graphs
        local left = frame_x + pad_x
        for i, timer in ipairs(timers) do
            local duration = timer.duration
            local len = (duration / max_duration) * (frame_width - (2 * pad_x))            
            local top = frame_y + pad_y + (i-1) * line_height

            screen:draw_text(
                left, 
                top, 
                string.sub(string.format("%0.8f", duration), 1, 10))

            screen:draw_box(left, top, left + len, top + (line_height - 2), 0, timer.color)                
        end        
    end
)