local mod = {}

local create_command = _G.create_command
local gui, memory = _G.gui, _G.memory
local luap = require("luap")
local config = require("config")
local smw = require("smw")
local lsnes = require("lsnes")
local cheat = require("cheat")

local w8 = memory.writebyte
local w16 = memory.writeword
local w24 = memory.writehword

local WRAM = smw.WRAM
local SMW = smw.constant
local OPTIONS = config.OPTIONS
local system_time = luap.system_time
local fmt = string.format

mod.help =
  create_command(
  "help",
  function()
    print("List of valid commands:")
    for _, value in pairs(mod) do
      print(">", value)
    end
    print("Enter a specific command to know about its arguments.")
    print("Cheat-commands edit the memory and may cause desyncs. So, be careful while recording a movie.")
    return
  end
)

mod.get_property =
  create_command(
  "get",
  function(arg)
    local value = OPTIONS[arg]
    if value == nil then
      print(string.format("This option %q doesn't exit.", value))
    else
      print(value)
    end
  end
)

mod.set_property =
  create_command(
  "set",
  function(arg)
    local property, value = luap.get_arguments(arg)

    if not (property and value) then
      print("Usage:\tsmw-tas set <property> <value>")
      print("\twhere the property and the value are valid options in the config file")
      print("\tnumbers, booleans and nil are converted.")
    else
      if value == "true" then
        value = true
      end
      if value == "false" then
        value = false
      end
      if value == "nil" then
        value = nil
      end
      if tonumber(value) then
        value = tonumber(value)
      end

      OPTIONS[property] = value
      print(string.format("Setting option %q to value %q.", property, value))
      config.save_options()
      gui.repaint()
    end
  end
)

mod.score =
  create_command(
  "score",
  function(num) -- TODO: apply cheat to Luigi
    local is_hex = num:sub(1, 2):lower() == "0x"
    num = tonumber(num)

    if not num or not luap.is_integer(num) or num < 0 or num > 9999990 or (not is_hex and num % 10 ~= 0) then
      print("Enter a valid score: hexadecimal representation or decimal ending in 0.")
      return
    end

    num = is_hex and num or num / 10
    w24("WRAM", WRAM.mario_score, num)

    print(fmt("Cheat: score set to %d0.", num))
    gui.status("Cheat(score):", fmt("%d0 at frame %d/%s", num, lsnes.Framecount, system_time()))
    cheat.is_cheating = true
    gui.repaint()
  end
)

mod.coin =
  create_command(
  "coin",
  function(num)
    num = tonumber(num)

    if not num or not luap.is_integer(num) or num < 0 or num > 99 then
      print("Enter a valid integer.")
      return
    end

    w8("WRAM", WRAM.player_coin, num)

    print(fmt("Cheat: coin set to %d.", num))
    gui.status("Cheat(coin):", fmt("%d0 at frame %d/%s", num, lsnes.Framecount, system_time()))
    cheat.is_cheating = true
    gui.repaint()
  end
)

mod.powerup =
  create_command(
  "powerup",
  function(num)
    num = tonumber(num)

    if not num or not luap.is_integer(num) or num < 0 or num > 255 then
      print("Enter a valid integer.")
      return
    end

    w8("WRAM", WRAM.powerup, num)

    print(fmt("Cheat: powerup set to %d.", num))
    gui.status("Cheat(powerup):", fmt("%d at frame %d/%s", num, lsnes.Framecount, system_time()))
    cheat.is_cheating = true
    gui.repaint()
  end
)

mod.itembox =
  create_command(
  "item",
  function(num)
    num = tonumber(num)

    if not num or not luap.is_integer(num) or num < 0 or num > 255 then
      print("Enter a valid integer.")
      return
    end

    w8("WRAM", WRAM.item_box, num)

    print(fmt("Cheat: item box set to %d.", num))
    gui.status("Cheat(item):", fmt("%d at frame %d/%s", num, lsnes.Framecount, system_time()))
    cheat.is_cheating = true
    gui.repaint()
  end
)

mod.position =
  create_command(
  "position",
  function(arg)
    local x, y = luap.get_arguments(arg)
    local x_sub, y_sub

    x, x_sub = luap.get_arguments(x, "[^.,]+") -- all chars, except '.' and ','
    y, y_sub = luap.get_arguments(y, "[^.,]+")
    x = x and tonumber(x)
    y = y and tonumber(y)

    if not x and not y and not x_sub and not y_sub then
      print("Enter a valid pair <x.subpixel y.subpixel> or a single coordinate.")
      print("Examples: 'position 160.4 220', 'position 360.ff', 'position _ _.0', 'position none.0, none.f'")
      return
    end

    print(x_sub)
    if x_sub then
      local size = x_sub:len() -- convert F to F0, for instance
      x_sub = tonumber(x_sub, 16)
      x_sub = size == 1 and 0x10 * x_sub or x_sub
    end
    if y_sub then
      local size = y_sub:len()
      y_sub = tonumber(y_sub, 16)
      y_sub = size == 1 and 0x10 * y_sub or y_sub
    end

    if x then
      w16("WRAM", WRAM.x, x)
    end
    if x_sub then
      w8("WRAM", WRAM.x_sub, x_sub)
    end
    if y then
      w16("WRAM", WRAM.y, y)
    end
    if y_sub then
      w8("WRAM", WRAM.y_sub, y_sub)
    end

    local strx, stry
    if x and x_sub then
      strx = fmt("%d.%.2x", x, x_sub)
    elseif x then
      strx = fmt("%d", x)
    elseif x_sub then
      strx = fmt("previous.%.2x", x_sub)
    else
      strx = "previous"
    end

    if y and y_sub then
      stry = fmt("%d.%.2x", y, y_sub)
    elseif y then
      stry = fmt("%d", y)
    elseif y_sub then
      stry = fmt("previous.%.2x", y_sub)
    else
      stry = "previous"
    end

    print(fmt("Cheat: position set to (%s, %s).", strx, stry))
    gui.status("Cheat(position):", fmt("to (%s, %s) at frame %d/%s", strx, stry, lsnes.Framecount, system_time()))
    cheat.is_cheating = true
    gui.repaint()
  end
)

mod.xspeed =
  create_command(
  "xspeed",
  function(arg)
    local speed, subspeed = luap.get_arguments(arg, "[^.,]+") -- all chars, except '.' and ','
    print(arg, speed, subspeed)
    speed = speed and tonumber(speed)
    subspeed = subspeed and tonumber(subspeed, 16)

    if not speed or not luap.is_integer(speed) or speed < -128 or speed > 127 then
      print("speed: enter a valid integer [-128, 127].")
      return
    end
    if subspeed then
      if not luap.is_integer(subspeed) or subspeed < 0 or speed >= 0x100 then
        print("subspeed: enter a valid integer [00, FF].")
        return
      elseif subspeed ~= 0 and speed < 0 then -- negative speeds round to floor
        speed = speed - 1
        subspeed = 0x100 - subspeed
      end
    end

    w8("WRAM", WRAM.x_speed, speed)
    print(fmt("Cheat: horizontal speed set to %+d.", speed))
    if subspeed then
      w8("WRAM", WRAM.x_subspeed, subspeed)
      print(fmt("Cheat: horizontal subspeed set to %.2x.", subspeed))
    end

    gui.status("Cheat(xspeed):", fmt("%d.%s at frame %d/%s", speed, subspeed or "xx", lsnes.Framecount, system_time()))
    cheat.is_cheating = true
    gui.repaint()
  end
)

mod.yspeed =
  create_command(
  "yspeed",
  function(num)
    num = tonumber(num)

    if not num or not luap.is_integer(num) or num < -128 or num > 127 then
      print("Enter a valid integer [-128, 127].")
      return
    end

    w8("WRAM", WRAM.y_speed, num)

    print(fmt("Cheat: vertical speed set to %d.", num))
    gui.status("Cheat(yspeed):", fmt("%d at frame %d/%s", num, lsnes.Framecount, system_time()))
    cheat.is_cheating = true
    gui.repaint()
  end
)

mod.stun =
  create_command(
  "stun",
  function(num)
    num = tonumber(num)

    if not num then
      print("Usage: stun <number slot>")
      print("Make current sprite on slot <slot> be in the stunned state")
      return
    elseif not luap.is_integer(num) or num < 0 or num >= SMW.sprite_max then
      print(string.format("Enter a valid integer [0 ,%d].", SMW.sprite_max - 1))
      return
    end

    w8("WRAM", WRAM.sprite_status + num, 9)
    w8("WRAM", WRAM.sprite_stun_timer + num, 0x1f)

    print(fmt("Cheat: stunning sprite slot %d.", num))
    gui.status("Cheat(stun):", fmt("slot %d at frame %d/%s", num, lsnes.Framecount, system_time()))
    cheat.is_cheating = true
    gui.repaint()
  end
)

mod.swallow =
  create_command(
  "swallow",
  function(num)
    num = tonumber(num)

    if not num then
      print("Usage: swallow <number slot>")
      print("Make the visible Yoshi, if any, swallow the current sprite on slot <slot>")
      return
    elseif not luap.is_integer(num) or num < 0 or num >= 0x100 then
      print("Enter a valid integer [0, 255].")
      return
    end

    local yoshi_id = smw.get_yoshi_id()
    if not yoshi_id then
      print("Couldn't find any Yoshi. Aborting...")
    end

    w8("WRAM", WRAM.swallow_timer, 0xff)
    w8("WRAM", WRAM.sprite_misc_160e + yoshi_id, num)

    print(fmt("Cheat: swallowing sprite slot %d.", num))
    gui.status("Cheat(swallow):", fmt("slot %d at frame %d/%s", num, lsnes.Framecount, system_time()))
    cheat.is_cheating = true
    gui.repaint()
  end
)

mod.poke_address =
  create_command(
  "poke",
  function(arg)
    local help =
      "Usage: poke [region+]<address>[+offset-offsetEnd] <value>\n" ..
      "region: name of the memory domain (defaults to WRAM)\n" ..
        "address: hexadecimal value of the address within the domain\n" ..
          "offset: optional hexadecimal value added to address\n" ..
            "offsetEnd: optional hexadecimal value added to the later\n" ..
              "value: decimal or hexadecimal value to be poked into all previous addresses\n" ..
                "examples:\n" ..
                  "poke WRAM+13 10\t-->\tmakes WRAM's $13 be #$0A\n" ..
                    "poke OAM+8C -10\t-->\tmakes OAM's $8C be #$F6\n" ..
                      "poke SRAM+10+A 0\t-->\tmakes SRAM's $1A be #$00\n" ..
                        "poke 100+8-A 0x30\t-->\tmakes WRAM's $108 to $10A be #$30\n\n"

    local arg_address, arg_value = luap.get_arguments(arg)
    local region, address, value
    local region_tmp, address_tmp
    local start, finish
    value = tonumber(arg_value)

    if not value then
      print(help)
      print("error: no value")
      return
    end

    -- Get region: defaults to WRAM if no region is supplied
    local regions = luap.make_set {"WRAM", "APURAM", "VRAM", "OAM", "CGRAM", "SRAM"}
    region_tmp = string.match(arg_address, "^(%u+)%+.")
    if not region_tmp then
      region = "WRAM"
      address_tmp = string.match(arg_address, "^(.+)")
    elseif not regions[region_tmp] then
      print(help)
      print("Illegal region:", region_tmp)
      return
    else
      region = region_tmp
      address_tmp = string.match(arg_address, "^%u+%+(.+)")
    end

    -- Get address
    if string.match(address_tmp, "^(%x+)$") then
      address = string.match(address_tmp, "^(%x+)$")
      address = tonumber(address, 16)
      start, finish = address, address
    elseif string.match(address_tmp, "^(%x+)%+(%x+)$") then
      address, start = string.match(address_tmp, "^(%x+)%+(%x+)$")
      start = tonumber(address, 16) + tonumber(start, 16)
      finish = start
    elseif string.match(address_tmp, "^(%x+)%+(%x+)%-(%x+)$") then
      address, start, finish = string.match(address_tmp, "^(%x+)%+(%x+)%-(%x+)$")
      address = tonumber(address, 16)
      start = tonumber(start, 16) + address
      finish = tonumber(finish, 16) + address
      if start > finish then
        start, finish = finish, start
      end
    else
      print(help)
      print("Parser error")
      return
    end

    local message = string.format("Poking #$%x into %s: from $%x to $%x", value, region, start, finish)
    for i = start, finish do
      memory.writebyte(region, i, value)
    end
    cheat.is_cheating = true
    print(message)
    gui.status("Cheat(poke):", message)
    gui.repaint()
  end
)

-- commands: left-gap, right-gap, top-gap and bottom-gap
for _, name in pairs {"left", "right", "top", "bottom"} do
  mod["window_" .. name .. "_gap"] =
    create_command(
    name .. "-gap",
    function(arg)
      local value = luap.get_arguments(arg)
      if not value then
        print("Enter a valid argument: " .. name .. "-gap <value>")
        return
      end

      value = tonumber(value)
      if not luap.is_integer(value) then
        print("Enter a valid argument: " .. name .. "-gap <value>")
        return
      elseif value < 0 or value > 8192 then
        print(name .. "-gap: value must be [0, 8192]")
        return
      end

      OPTIONS[name .. "_gap"] = value
      gui.repaint()
      config.save_options()
    end
  )
end

return mod
