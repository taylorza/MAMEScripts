local exports = {}
exports.name = "dezog"
exports.version = "1.0"
exports.description = "DeZog plugin for advanced debugging"

local dezog = exports

local regmap = {
    PC=0, SP=1, 
    AF=2, BC=3, DE=4, HL=5, IX=6, IY=7,
    AF2=8, BC2=9, DE2=10, HL2=11, 
    IM=13, 
    F=14, A=15, C=16, B=17, E=18, D=19, L=20, H=21, 
    IXL=22, IXH=23, IYL=24, IYH=25, 
    F2=26, A2=27, C2=28, B2=29, E2=30, D2=31, L2=32, H2=33, 
    R=34, I=35
}
--                   0     1     2     3     4     5     6     7
local regmap_inv = {"PC", "SP", "AF", "BC", "DE", "HL", "IX", "IY",
--                   8      9      10     11    12                   
                    "AF2", "BC2", "DE2", "HL2", "",
--                   13,
                    "IM",
--                   14,  15,  16,  17,  18,  19,  20,  21,                    
                    "F", "A", "C", "B", "E", "D", "L", "H",
--                   22,    23,    24,    25,
                    "IXL", "IXH", "IYL", "IYH",
--                   26,   27,   28,   29,   30,   31,   32,   33,
                    "F2", "A2", "C2", "B2", "E2", "D2", "L2", "H2",
--                   34,  35
                    "R", "I"}  

function dezog.startplugin()
    local debugger
    local cpu
    local mem
    local nregs

    local break_reason = 0
    local last_state = nil

    local initialized = false
    local socket_open = false

    local temp_bp = {}

    print("dezog: Plugin started!")

    reset_subscription = emu.add_machine_reset_notifier(function ()
        debugger = manager.machine.debugger
        if not debugger then
            print("dezog: debugger not enabled")            
        else
            cpu = manager.machine.devices[":maincpu"]
            if not cpu then
                print("dezog: maincpu not found")
            end

            mem = cpu.spaces["program"]
            nregs = manager.machine.devices[":regs_map"].spaces["program"]

            initialized = false
            socket_open = false
            debugger.execution_state="run"            
        end
    end)

    stop_subscription = emu.add_machine_stop_notifier(function ()
        cpu = nil
        mem = nil
        nregs = nil
        debugger = nil    
        initialized = false
        socket_open = false
    end)  

    local socket = emu.file("", 7)
    
    periodic_event = emu.register_periodic(function()     
        if not cpu then
            return
        end
        
        if not socket_open then            
            socket:open("socket.127.0.0.1:11000")
            initialized = false
            socket_open = true
        end
          
        -- Read packet header 
        local packet_header = ""      
        repeat
            local read = socket:read(6 - #packet_header)
            packet_header = packet_header .. read            
        until #read == 0

        -- Process packet
        if #packet_header > 5 then
            -- Parse packet header
            local len, seq, cmdid = string.unpack("<I4I1I1", packet_header)  -- length prefix
            
            -- Read payload
            local payload = ""
            while #payload < len do
                local read = socket:read(len - #payload)
                payload = payload .. read
            end

            -- Process packet
            print("--")
            --print("dezog: received packet", len, seq, cmdid, toHex(payload))
            print("dezog: received packet", len, seq, cmdid)

            local response = nil
            if cmdid == 1 then -- CMD_INIT
                initialized = true
                print("dezog: CMD_INIT")
                response = string.pack("I1I1I1I1I1c17", 0, 2, 0, 0, 4, "mame_dzrp v0.0.1\0")       
            elseif cmdid == 2 then -- CMD_CLOSE
                print("dezog: CMD_CLOSE")
                socket_open = false
                response = nil
            elseif cmdid == 3 then -- CMD_GET_REGISTERS
                print("dezog: CMD_GET_REGISTERS")                
                local bank0 = nregs:readv_u8(0x50)
                local bank1 = nregs:readv_u8(0x51)
                local bank2 = nregs:readv_u8(0x52)
                local bank3 = nregs:readv_u8(0x53)
                local bank4 = nregs:readv_u8(0x54)
                local bank5 = nregs:readv_u8(0x55)
                local bank6 = nregs:readv_u8(0x56)
                local bank7 = nregs:readv_u8(0x57)
                
                response = string.pack("<I2<I2<I2<I2<I2<I2<I2<I2<I2<I2<I2<I2I1I1I1I1I1I1I1I1I1I1I1I1I1",
                cpu.state["PC"].value,
                cpu.state["SP"].value,
                cpu.state["AF"].value,
                cpu.state["BC"].value,
                cpu.state["DE"].value,
                cpu.state["HL"].value,
                cpu.state["IX"].value,
                cpu.state["IY"].value,
                cpu.state["AF2"].value,
                cpu.state["BC2"].value,
                cpu.state["DE2"].value,
                cpu.state["HL2"].value,
                cpu.state["R"].value,
                cpu.state["I"].value,
                cpu.state["IM"].value,
                0,8,bank0,bank1,bank2,bank3,bank4,bank5,bank6,bank7)
            elseif cmdid == 4 then -- CMD_SET_REGISTER
                print("dezog: CMD_SET_REGISTER")
                local regnum, value = string.unpack("I1I2", payload)
                local regname = regmap_inv[regnum + 1]
                if regname == "" then
                    print("dezog: unknown register number", regnum)                    
                end
                cpu.state[regname].value = value
                reponse = nil
            elseif cmdid == 5 then -- CMD_WRITE_BANK
                print("dezog: CMD_WRITE_BANK")
                local banknum = string.unpack("I1", payload)
                
                local ss=""
                for i=1, len-1 do
                    mem:writev_u8(banknum * 0x2000 + (i - 1), string.byte(payload, i + 1))                    
                end                
                response = string.pack("I1c1", 0, "\0")
            elseif cmdid == 6 then -- CMD_CONTINUE
                print("dezog: CMD_CONTINUE")
                local bp1en, bp1addr, bp2en, bp2addr, altcmd, startaddr, endaddr = string.unpack("I1<I2I1<I2I1<I2<I2", payload)
                last_state = nil
                temp_bp = {
                    {enabled = (bp1en ~= 0), addr = bp1addr},
                    {enabled = (bp2en ~= 0), addr = bp2addr}
                }
                for _, bp in ipairs(temp_bp) do
                    if bp.enabled then
                        bp.id = cpu.debug:bpset(bp.addr, "", "")                
                    end
                end
                debugger.execution_state = "run"                
                response = nil                
            elseif cmdid == 7 then -- CMD_PAUSE
                print("dezog: CMD_PAUSE")
                debugger.execution_state = "stop" 
                break_reason = 1                               
                response = nil   
            elseif cmdid == 8 then -- CMD_READ_MEM
                print("dezog: CMD_READ_MEM")
                local reserved, addr, size = string.unpack("I1I2I2", payload)
                
                local bytes = ""
                for i=0, size-1 do
                    bytes = bytes .. string.char(mem:readv_u8(addr + i))
                end
                response = bytes
            elseif cmdid == 9 then -- CMD_WRITE_MEM
                print("dezog: CMD_WRITE_MEM")
                local reserved, addr = string.unpack("I1I2", payload)
                
                local ss=""
                for i=4, len do
                    mem:writev_u8(addr + (i - 4), string.byte(payload, i))                    
                end                
                response = nil
            elseif cmdid == 10 then -- CMD_SET_SLOT
                print("dezog: CMD_SET_SLOT")
                
                local slotnum, bank = string.unpack("I1I1", payload)
                nregs:writev_u8(0x50 + slotnum, bank)                
                response = string.pack("I1", 0)
            elseif cmdid == 11 then -- CMD_GET_TBBLUE_REG
                print("dezog: CMD_GET_TBBLUE_REG")
                local regnum = string.unpack("I1", payload)
                local value = nregs:readv_u8(regnum)
                response = string.pack("I1", value)
            elseif cmdid == 12 then -- CMD_SET_BORDER
                print("dezog: CMD_SET_BORDER (not implemented)")
                local border = string.unpack("I1", payload)
                -- implement set border
                response = nil
            elseif cmdid == 40 then --CMD_ADD_BREAKPOINT
                print("dezog: CMD_ADD_BREAKPOINT")
                local bpaddr, bpbank = string.unpack("<I2I1", payload)
                local id = cpu.debug:bpset(bpaddr, "", "")
                response = string.pack("<I2", id)
            elseif cmdid == 41 then --CMD_REMOVE_BREAKPOINT
                print("dezog: CMD_REMOVE_BREAKPOINT")
                local bpid = string.unpack("<I2", payload)
                cpu.debug:bpclear(bpid)
                response = nil
            else
                print("dezog: unknown command", cmdid)
                response = nil
            end
            if initialized then
                dezog.response(socket, seq, response)  
            end
        end
        
        if initialized and last_state ~= debugger.execution_state and debugger.execution_state == "stop" then
            print("dezog: execution state changed to '" .. debugger.execution_state .. "'")
            if temp_bp then
                for _, bp in ipairs(temp_bp) do
                    if bp.enabled then
                        cpu.debug:bpclear(bp.id)
                    end
                end
                temp_bp = {}
            end
            local pc = cpu.state["PC"].value
            local bank = math.floor(pc / 0x2000)

            if break_reason == 1 then -- manual break (Pause sent)
                response = string.pack("I1I1<I2I1c1", 1, 1, 0, 0, "\0")
            else
                response = string.pack("I1I1<I2I1c1", 1, 0, pc, bank+1, "\0")
            end
            break_reason = 0
            dezog.response(socket, 0, response)
        end
        last_state = debugger.execution_state
    end)
end

-- Function to send a response packet
function dezog.response(socket, seq, payload)
    local response
    local len = 1
    if payload then
        local fmt = "<I4I1c" .. #payload
        len = #payload + 1
        response = string.pack(fmt, len, seq, payload)
    else
        response = string.pack("<I4I1", len, seq)
    end
    --print("dezog: response hex", len, seq, toHex(response))
    print("dezog: response", len, seq)
    
    socket:write(response)
end

-- Function to convert a string to a hex representation
function toHex(str)
    -- Validate input type
    if type(str) ~= "string" then
        error("toHex: input must be a string")
    end

    if #str > 128 then
        str = str:sub(1, 128)
    end
    -- Convert each byte to a two-digit hex value
    return (str:gsub(".", function(c)
        return string.format("%02X", string.byte(c))
    end))
end


return exports
