ctime = utime()
outprefix = "ghost" .. ctime
dumpfile = outprefix..".dump"
nomovie = false
io.output(dumpfile)

local u8 = memory.readbyte
local u16 = memory.readword

local find_yoshi = function()
  for i = 0, 11 do
    if u8(0x7e009e+i) == 0x35 then return i end
  end
  return false
end

local frame = 0
local last = 0

local function main()
  mode = u8(0x7e0100)
  power = u8(0x7e0019)
  if mode == 0xe then -- overworld
    area = u8(0x7e1f11)
    x = u16(0x7e1f17)
    y = u16(0x7e1f19)
    subx, suby = 0, 0
    vx, vy = 0, 0
    on_yoshi = u8(0x7E0dc1)
    pose = (u8(0x7e1f13) << 1) + (((u8(0x7e0013) -1) >> 3) % 3) + (on_yoshi << 7)
    ahelp, yoshi_pose, ydir, cape,dir = 0, 0, 0, 0, 0
  elseif mode == 0x14 then
    area = u8(0x7e13bf)
    ahelp = u8(0x7e00ce) --+ SHIFT(u8(0x7e00cf),8) + SHIFT(u8(0x7e00d0),16)
    x = u16(0x7e00d1)
    y = u16(0x7e00d3)
    subx = u8(0x7E13DA)
    suby = u8(0x7E13DA)
    vx = u8(0x7E007B)
    vy = u8(0x7E007D)
    pose = u8(0x7e13e0)
    dir = u8(0x7e0076)
    cape = u8(0x7e13df)
    on_yoshi = u8(0x7E187A)
    yoshi = find_yoshi()
    if yoshi then
      yoshi_pose = u8(0x7e1602+yoshi)
      ydir = 1-u8(0x7e157c+yoshi)
    else yoshi_pose = 0 ydir = 0 end
  else
    x, y, area, ahelp, ducking, pose,dir,ydir,yoshi_pose, cape, on_yoshi = 0,0,0,0,0,0,0,0,0,0,0
    subx, suby, vx, vy = 0,0,0,0
  end

  io.write(string.format("%5d %5d %5d %10d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d\n",
    frame, mode, area, ahelp, power, pose, dir, ydir, cape, on_yoshi,yoshi_pose,x,y,subx,suby,vx,vy))

  tmp = u8(0x7e0014)
  if tmp ~= last then
    last = tmp
    frame = frame+1
  end
end

--[[
function on_frame_emulated()
   main()
end

main()
]]
function on_snoop2(p, c, b, v)
  if p == 0 and c == 0 then
    main()
  end
end
