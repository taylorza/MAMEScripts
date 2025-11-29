# MAME Scripts

Lightweight collection of Lua helper scripts and plugins for MAME.

## Repository layout
- `scripts/`: Lua scripts you can load into MAME.
- `plugins/`: MAME plugins you can load into MAME.

## Scripts
**faststart.lua**

Temporarily speeds up the first few seconds of emulation to accelerate boot/startup.

---

### profiler.lua
A simple on-screen profiler (overlay) designed for the ZX Spectrum Next that tracks up to 8 timers using writes to NEXTREG 127 (0x7F) to control the timers.

**NextBASIC Example**
``` BASIC
  10 REG 127, 1: REM Start timer 1
  20 REM The code you want to time goes here
  20 REG 127, 256-1: REM Stop timer 1
```

**Z80 Assembly Example**
``` assembly
  nextreg $7f, 1  ; Start timer 1

  ; ... The code you want to time goes here

  nextreg $7f, -1 ; Stop timer 1
```

**NEXTREG values**

|Value|Description|
|-----|-----------|
|0|Reset all timers and remove overlay|
|1..8|Start the specified timer, if the timer is already running there is no effect|
|-1..-8*|Stop the specified timer. Stopping an already stopped timer will reset the timer to 0|

*NextBASIC's REG command does not accept negative numbers. Use `256-n` where `n` is the timer you want to stop.

**Contributing**
- Contributions, bug reports, and improvements are welcome. Please open issues or pull requests on the repository.

**License**
- This project is licensed under the MIT License. See `LICENSE` for details.