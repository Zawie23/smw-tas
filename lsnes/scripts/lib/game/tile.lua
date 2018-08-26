local M = {}

print'tile start'

local memory = _G.memory

local config = require 'config'
local draw = require 'draw'
local keyinput = require 'keyinput'
local map16 = require 'game.map16'
local smw = require 'game.smw'
_G.commands = require 'commands'

local OPTIONS = config.OPTIONS
local COLOUR = config.COLOUR
local fmt = string.format
local floor = math.floor
local u8 = memory.readbyte
local s8 = memory.readsbyte
local s16 = memory.readsword
local SMW = smw.constant
local WRAM = smw.WRAM
local screen_coordinates = smw.screen_coordinates
local game_coordinates = smw.game_coordinates

M.layer1 = {} -- FIXME: stateful
M.layer2 = {} -- FIXME: stateful

-- Returns the extreme values that Mario needs to have in order to NOT touch a rectangular object
local function display_boundaries(x_game, y_game, width, height, camera_x, camera_y)
  -- Font
  draw.Font = 'snes9xluasmall'
  draw.Text_opacity = 1.0
  draw.Bg_opacity = 0.8

  -- Coordinates around the rectangle
  local left = width * floor(x_game / width)
  local top = height * floor(y_game / height)
  left,
    top = screen_coordinates(left, top, camera_x, camera_y)
  local right = left + width - 1
  local bottom = top + height - 1

  -- Reads WRAM values of the player
  local is_ducking = u8('WRAM', WRAM.is_ducking)
  local powerup = u8('WRAM', WRAM.powerup)
  local Yoshi_riding_flag = u8('WRAM', WRAM.yoshi_riding_flag) ~= 0
  local is_small = is_ducking ~= 0 or powerup == 0

  -- Left
  local left_text = string.format('%4d.0', width * floor(x_game / width) - 13)
  draw.text(draw.AR_x * left, draw.AR_y * floor((top + bottom) / 2), left_text, false, false, 1.0, 0.5)

  -- Right
  local right_text = string.format('%d.f', width * floor(x_game / width) + 12)
  draw.text(draw.AR_x * right, draw.AR_y * floor((top + bottom) / 2), right_text, false, false, 0.0, 0.5)

  -- Top
  local value = (Yoshi_riding_flag and y_game - 16) or y_game
  local top_text = fmt('%d.0', width * floor(value / width) - 32)
  draw.text(draw.AR_x * floor((left + right) / 2), draw.AR_y * top, top_text, false, false, 0.5, 1.0)

  -- Bottom
  value = height * floor(y_game / height)
  if not is_small and not Yoshi_riding_flag then
    value = value + 0x07
  elseif is_small and Yoshi_riding_flag then
    value = value - 4
  else
    value = value - 1 -- the 2 remaining cases are equal
  end

  local bottom_text = fmt('%d.f', value)
  draw.text(draw.AR_y * floor((left + right) / 2), draw.AR_y * bottom, bottom_text, false, false, 0.5, 0.0)

  return left, top
end

function M.read_screens()
  local screens_number = u8('WRAM', WRAM.screens_number)
  local vscreen_number = u8('WRAM', WRAM.vscreen_number)
  local hscreen_number = u8('WRAM', WRAM.hscreen_number) - 1
  local vscreen_current = s8('WRAM', WRAM.y + 1)
  local hscreen_current = s8('WRAM', WRAM.x + 1)
  local level_mode_settings = u8('WRAM', WRAM.level_mode_settings)

  --[[ local b1, b2, b3, b4, b5, b6, b7, b8 = bit.multidiv(level_mode_settings, 128, 64, 32, 16, 8, 4, 2)
  draw.text(draw.Buffer_middle_x, draw.Buffer_middle_y, {"%x: %x%x%x%x%x%x%x%x",
  level_mode_settings, b1, b2, b3, b4, b5, b6, b7, b8}, COLOUR.text, COLOUR.background) ]]
  local level_type
  if
    (level_mode_settings ~= 0) and
      (level_mode_settings == 0x3 or level_mode_settings == 0x4 or level_mode_settings == 0x7 or
        level_mode_settings == 0x8 or
        level_mode_settings == 0xa or
        level_mode_settings == 0xd)
   then
    level_type = 'Vertical'
  else
    level_type = 'Horizontal'
  end

  return level_type, screens_number, hscreen_current, hscreen_number, vscreen_current, vscreen_number
end

local function get_map16_value(x_game, y_game)
  local num_x = floor(x_game / 16)
  local num_y = floor(y_game / 16)
  if num_x < 0 or num_y < 0 then
    return
  end -- 1st breakpoint

  local level_type,
    _,
    _,
    hscreen_number,
    _,
    vscreen_number = M.read_screens()
  local max_x,
    max_y
  if level_type == 'Horizontal' then
    max_x = 16 * (hscreen_number + 1)
    max_y = 27
  else
    max_x = 32
    max_y = 16 * (vscreen_number + 1)
  end

  if num_x > max_x or num_y > max_y then
    return
  end -- 2nd breakpoint

  local num_id,
    kind,
    address
  if level_type == 'Horizontal' then
    num_id = 16 * 27 * floor(num_x / 16) + 16 * num_y + num_x % 16
  else
    local nx = floor(num_x / 16)
    local ny = floor(num_y / 16)
    local n = 2 * ny + nx
    num_id = 16 * 16 * n + 16 * (num_y % 16) + num_x % 16
  end
  if (num_id >= 0 and num_id <= 0x37ff) then
    address = fmt(' $%4.x', 0xc800 + num_id)
    kind = 256 * u8('WRAM', 0x1c800 + num_id) + u8('WRAM', 0xc800 + num_id)
  end

  if kind then
    return num_x, num_y, kind, address
  end
end

function M.draw_layer1(camera_x, camera_y)
  local User_input = keyinput.key_state
  local x_origin,
    y_origin = screen_coordinates(0, 0, camera_x, camera_y)
  local x_mouse,
    y_mouse = game_coordinates(User_input.mouse_x, User_input.mouse_y, camera_x, camera_y)
  x_mouse = 16 * floor(x_mouse / 16)
  y_mouse = 16 * floor(y_mouse / 16)
  -- block pushes sprites to left or right?
  local push_direction = u8('WRAM', WRAM.real_frame) % 2 == 0 and 0 or 7

  for number, positions in ipairs(M.layer1) do
    -- Calculate the Lsnes coordinates
    local left = positions[1] + x_origin
    local top = positions[2] + y_origin
    local right = left + 15
    local bottom = top + 15
    local x_game,
      y_game = game_coordinates(draw.AR_x * left, draw.AR_y * top, camera_x, camera_y)

    -- Returns if block is way too outside the screen
    if
      draw.AR_x * left > -draw.Border_left - 32 and draw.AR_y * top > -draw.Border_top - 32 and
        draw.AR_x * right < draw.Screen_width + draw.Border_right + 32 and
        draw.AR_y * bottom < draw.Screen_height + draw.Border_bottom + 32
     then
      -- Drawings
      local num_x,
        num_y,
        kind,
        address = get_map16_value(x_game, y_game)
      if kind then
        if kind >= 0x111 and kind <= 0x16d or kind == 0x2b then
          -- default solid blocks, don't know how to include custom blocks
          draw.rectangle(left + push_direction, top, 8, 15, -1, COLOUR.block_bg)
        end
        draw.rectangle(left, top, 15, 15, kind == SMW.blank_tile_map16 and COLOUR.blank_tile or COLOUR.block, -1)

        -- Custom map16 drawing
        if map16[kind] then
          map16[kind](left, top)
        end

        if M.layer1[number][3] then
          display_boundaries(x_game, y_game, 16, 16, camera_x, camera_y) -- the text around it
        end

        -- Draw Map16 id
        draw.Font = 'Uzebox6x8'
        if kind and x_mouse == positions[1] and y_mouse == positions[2] then
          draw.text(
            draw.AR_x * (left + 4),
            draw.AR_y * top - draw.font_height(),
            fmt('Map16 (%d, %d), %x%s', num_x, num_y, kind, address),
            false,
            false,
            0.5,
            1.0
          )
        end
      end
    end
  end
end

function M.draw_layer2()
  local layer2x = s16('WRAM', WRAM.layer2_x_nextframe)
  local layer2y = s16('WRAM', WRAM.layer2_y_nextframe)

  for _, positions in ipairs(M.layer2) do
    draw.rectangle(-layer2x + positions[1], -layer2y + positions[2], 15, 15, COLOUR.layer2_line, COLOUR.layer2_bg)
  end
end

-- if the user clicks in a tile, it will be be drawn
-- if click is onto drawn region, it'll be erased
-- there's a max of possible tiles
-- layer_table[n] is an array {x, y, [draw info?]}
function M.select_tile(x, y, layer_table)
  if not OPTIONS.draw_tiles_with_click then
    return
  end
  if u8('WRAM', WRAM.game_mode) ~= SMW.game_mode_level then
    return
  end

  for number, positions in ipairs(layer_table) do -- if mouse points a drawn tile, erase it
    if x == positions[1] and y == positions[2] then
      -- Layer 1
      if layer_table == M.layer1 then
        -- Layer 2
        if layer_table[number][3] == false then
          layer_table[number][3] = true
        else
          table.remove(layer_table, number)
        end
      elseif layer_table == M.layer2 then
        table.remove(layer_table, number)
      end

      return
    end
  end

  -- otherwise, draw a new tile
  if #layer_table == OPTIONS.max_tiles_drawn then
    table.remove(layer_table, 1)
    layer_table[OPTIONS.max_tiles_drawn] = {x, y, false}
  else
    table.insert(layer_table, {x, y, false})
  end
end

print'tile end'
return M
