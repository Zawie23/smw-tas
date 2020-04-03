local M = {}

local gui, memory, bit = _G.gui, _G.memory, _G.bit

local luap = require 'luap'
local config = require 'config'
local Timer = require 'timer'
local draw = require 'draw'
local smw = require 'game.smw'
local lsnes = require 'lsnes'
local joypad = require 'joypad'
local keyinput = require 'keyinput'

local fmt = string.format
local floor = math.floor
local u8 = memory.readbyte
local s8 = memory.readsbyte
local w8 = memory.writebyte
local u16 = memory.readword
local w16 = memory.writeword
local system_time = luap.system_time
local LSNES_FONT_WIDTH = config.LSNES_FONT_WIDTH
local COLOUR = config.COLOUR
local game_coordinates = smw.game_coordinates
local WRAM = smw.WRAM
local SMW = smw.constant
local User_input = keyinput.key_state

-- This signals that some cheat is activated, or was some short time ago
M.allow_cheats = false
M.is_cheating = false
function M.is_cheat_active()
    if M.is_cheating then
        gui.textHV(draw.Buffer_middle_x - 5 * LSNES_FONT_WIDTH, 0, 'Cheat', COLOUR.warning,
                   draw.change_transparency(COLOUR.warning_bg, draw.Background_max_opacity))

        Timer.registerfunction(2500000, function()
            if not M.is_cheating then
                gui.textHV(draw.Buffer_middle_x - 5 * LSNES_FONT_WIDTH, 0, 'Cheat', COLOUR.warning,
                           draw.change_transparency(COLOUR.background, draw.Background_max_opacity))
            end
        end, 'Cheat')
    end
end

-- Called from M.beat_level()
function M.activate_next_level(secret_exit)
    if u8('WRAM', WRAM.level_exit_type) == 0x80 and u8('WRAM', WRAM.midway_point) == 1 then
        if secret_exit then
            w8('WRAM', WRAM.level_exit_type, 0x2)
        else
            w8('WRAM', WRAM.level_exit_type, 1)
        end
    end

    gui.status('Cheat(exit):', fmt('at frame %d/%s', lsnes.Framecount, system_time()))
    M.is_cheating = true
end

-- allows start + select + X to activate the normal exit
--      start + select + A to activate the secret exit
--      start + select + B to exit the level without activating any exits
function M.beat_level(is_paused, level_index, level_flag)
    if is_paused and joypad.keys['select'] and
    (joypad.keys['X'] or joypad.keys['A'] or joypad.keys['B']) then
        w8('WRAM', WRAM.level_flag_table + level_index, bit.bor(level_flag, 0x80))

        local secret_exit = joypad.keys['A']
        if not joypad.keys['B'] then
            w8('WRAM', WRAM.midway_point, 1)
        else
            w8('WRAM', WRAM.midway_point, 0)
        end

        M.activate_next_level(secret_exit)
    end
end

-- This function makes Mario's position free
-- Press L+R+up to activate and L+R+down to turn it off.
-- While active, press directionals to fly free and Y or X to boost him up
M.free_movement = {}
M.free_movement.is_applying = false
M.free_movement.display_options = false
M.free_movement.manipulate_speed = false
M.free_movement.give_invincibility = true
M.free_movement.freeze_animation = false
M.free_movement.unlock_vertical_camera = false
function M.free_movement.apply(previous)
    if (joypad.keys['L'] and joypad.keys['R'] and joypad.keys['up']) then
        M.free_movement.is_applying = true
    end
    if (joypad.keys['L'] and joypad.keys['R'] and joypad.keys['down']) then
        M.free_movement.is_applying = false
    end
    if not M.free_movement.is_applying then
        if previous.under_free_move then w8('WRAM', WRAM.frozen, 0) end
        return
    end

    local movement_mode = u8('WRAM', WRAM.player_animation_trigger)

    -- type of manipulation
    if M.free_movement.manipulate_speed then
        local x_speed = s8('WRAM', WRAM.x_speed)
        local y_speed
        local x_delta = (joypad.keys['Y'] and 16) or (joypad.keys['X'] and 5) or 2 -- how many pixels per frame
        local y_delta = (joypad.keys['Y'] and 127) or (joypad.keys['X'] and 16) or 1 -- how many pixels per frame

        if joypad.keys['left'] then
            x_speed = math.max(x_speed - x_delta, -128)
        elseif joypad.keys['right'] then
            x_speed = math.min(x_speed + x_delta, 127)
        end
        if joypad.keys['up'] then
            y_speed = -y_delta
        elseif joypad.keys['down'] then
            y_speed = y_delta
        else
            y_speed = 0
        end

        w8('WRAM', WRAM.x_speed, x_speed)
        w8('WRAM', WRAM.y_speed, y_speed)
    else
        local x_pos, y_pos = u16('WRAM', WRAM.x), u16('WRAM', WRAM.y)
        local pixels = (joypad.keys['Y'] and 7) or (joypad.keys['X'] and 4) or 1 -- how many pixels per frame

        if joypad.keys['left'] then x_pos = x_pos - pixels end
        if joypad.keys['right'] then x_pos = x_pos + pixels end
        if joypad.keys['up'] then y_pos = y_pos - pixels end
        if joypad.keys['down'] then y_pos = y_pos + pixels end

        w16('WRAM', WRAM.x, x_pos)
        w16('WRAM', WRAM.y, y_pos)
        w8('WRAM', WRAM.x_speed, 0)
        w8('WRAM', WRAM.y_speed, 0)
    end

    -- freeze player to avoid deaths
    if M.free_movement.give_invincibility then w8('WRAM', WRAM.invisibility_timer, 127) end
    if M.free_movement.freeze_animation then
        if movement_mode == 0 then
            w8('WRAM', WRAM.frozen, 1)
            -- animate sprites by incrementing the effective frame
            w8('WRAM', WRAM.effective_frame, (u8('WRAM', WRAM.effective_frame) + 1) % 256)
        else
            w8('WRAM', WRAM.frozen, 0)
        end
    end

    -- camera manipulation
    if M.free_movement.unlock_vertical_camera then
        w8('WRAM', WRAM.vertical_scroll_flag_header, 1) -- free vertical scrolling
        w8('WRAM', WRAM.vertical_scroll_enabled, 1)
    end

    gui.status('Cheat(movement):', fmt('at frame %d/%s', lsnes.Framecount, system_time()))
    M.is_cheating = true
    previous.under_free_move = true
end

-- Drag and drop sprites with the mouse, if the cheats are activated and mouse is over the sprite
-- Right clicking and holding: drags the sprite
-- Releasing: drops it over the latest spot
function M.drag_sprite(id, Game_mode, Sprites_info, Camera_x, Camera_y)
    if Game_mode ~= SMW.game_mode_level then
        M.is_dragging_sprite = false
        return
    end

    local xoff, yoff = Sprites_info[id].hitbox_xoff, Sprites_info[id].hitbox_yoff
    local xgame, ygame = game_coordinates(User_input.mouse_x - xoff, User_input.mouse_y - yoff,
                                          Camera_x, Camera_y)

    local sprite_xhigh = floor(xgame / 256)
    local sprite_xlow = xgame - 256 * sprite_xhigh
    local sprite_yhigh = floor(ygame / 256)
    local sprite_ylow = ygame - 256 * sprite_yhigh

    w8('WRAM', WRAM.sprite_x_high + id, sprite_xhigh)
    w8('WRAM', WRAM.sprite_x_low + id, sprite_xlow)
    w8('WRAM', WRAM.sprite_y_high + id, sprite_yhigh)
    w8('WRAM', WRAM.sprite_y_low + id, sprite_ylow)
end

return M
