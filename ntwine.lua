-- N-TWINE
-- >> k1: exit
-- >> k2:
-- >> k3:
-- >> e1:
-- >> e2:
-- >> e3:

local Weave = require("ntwine/lib/Weave")
local grid = util.file_exists(_path.code.."midigrid") and include "midigrid/lib/mg_128" or grid
MusicUtil = require("musicutil")

local inc_table = function(n, start, step)
  if start == nil then start = 1 end
  if step == nil then step = 1 end
  local t = {}
  for i = 0, n-1 do
    table.insert(t, start + step * i)
  end
  return t
end

local index_mod = function(n,t)
  return 1 + ((n - 1) % #t)
end

-- local targets = {"note", "transpose", "trig", "model", "color", "timbre", "ampRel", }

local Twine = {}
Twine.__index = Twine
function Twine.new(values, steps, target)
  local self = setmetatable({}, Twine)
  -- TODO shoud the be values, or an index table of size values?
  self.weave = Weave.new(inc_table(#values), steps)
  self.values = values
  self.target = target
  return self
end
function Twine:reset()
  self.weave.strands = inc_table(#self.weave.strands)
end
function Twine:next()
  local i = index_mod(self.weave:next(), self.values)
  return self.values[i]
end

focus_twine = 1
focus_step = 1
focus_strand = 1

-- local notes_twine
-- local amps_twine
-- local trig_twine
engine.name = "PolyPerc"

local g = grid.connect()
local function is_grid_connected()
  return g.device ~= nil and true or false
end

function init()
  message = "NTWINE"
  -- engine.model(4)
  -- TODO add quantization / scale degrees
  twines = {}
  table.insert(twines, (Twine.new({60,65,67,57,76}, {{1,2,3,4,5},{3,5,4,1,2}}, "note_1")))
  table.insert(twines, (Twine.new({1,0,0,0},{{3,2,4,1}}, "trigger_1")))
  table.insert(twines, (Twine.new({48,72,79,52,69}, {{5,2,3,1,4},{3,5,4,1,2}}, "note_2")))
  table.insert(twines, (Twine.new({1,0,1,0},{{1,2,4,3}}, "trigger_2")))
  table.insert(twines, (Twine.new({0.5,0.5,0.75,0.25,0.5}, {{2,3,1,5,4}}, "pw")))
  screen_dirty = true
  redraw_clock_id = clock.run(redraw_clock)
  div = 1
  mult = 4
  tick = 0
  swing = 50
  sequence = clock.run(
    function()
      clock.sync(4)
      while true do
        local step_values = {}
        -- TODO implement different rates for different twines
        for i=1,#twines do
          step_values[twines[i].target] = twines[i]:next()
        end
        if step_values["note_1"] ~= nil and (step_values["trigger_1"] == nil or step_values["trigger_1"] ~= 0) then
          engine.hz(MusicUtil.note_num_to_freq(step_values["note_1"]))
        end
        if step_values["note_2"] ~= nil and (step_values["trigger_2"] == nil or step_values["trigger_2"] ~= 0) then
          engine.hz(MusicUtil.note_num_to_freq(step_values["note_2"]))
        end
        for k,v in pairs(step_values) do
          if k ~= "note_1" and k ~= "note_2" and k ~= "trigger_1" and k ~= "trigger_2" then
            if type(engine[k]) == "function" then
              engine[k](v)
            end
          end
        end
        screen_dirty = true
        -- TODO pause for duty cycle and note off before looping while
        -- 50% swing is 100% tick width all the time
        -- TODO handle div ~= 4
        -- See https://github.com/21echoes/cyrene/blob/master/lib/sequencer.lua#L388
        local tick_len = div / mult -- counterintuitive, but this matches modular notions of clock division and multiplication
        -- swing_offset = -1 * (1 - swing/100) * 2 * tick_len
        -- -- clock.sync(2 * tick_len,(tick % 2 == 1) and swing_offset or 0)
        -- clock.sync(tick_len,(tick % 2 == 1) and swing_offset / 2 or 0)
        clock.sync(tick_len )
        -- engine.noteOff(0)
        clock.sync(tick_len)
        -- clock.sync(tick_len,(tick % 2 == 1) and swing_offset / 2 or 0)
      end
    end
  )
end

function enc(e, d) --------------- enc() is automatically called by norns
  if e == 1 then 
    focus_twine = index_mod(focus_twine + d, twines)
  elseif e == 3 then
    if focus_strand ~= nil then
      local target = twines[focus_twine].target
      if target == "note_1" or target == "note_2" then
        twines[focus_twine].values[focus_strand] = util.clamp(twines[focus_twine].values[focus_strand] + d,1,127)
      elseif target == "trigger_1" or target == "trigger_2" then
        twines[focus_twine].values[focus_strand] = util.clamp(twines[focus_twine].values[focus_strand] + d,0,1)
      elseif twines[focus_twine].target == "timbre" then
        twines[focus_twine].values[focus_strand] = util.clamp(twines[focus_twine].values[focus_strand] + d*0.05,0,1)
      end
    end  
  end
  screen_dirty = true ------------ something changed
end

function turn(e, d) ----------------------------- an encoder has turned
  message = "encoder " .. e .. ", delta " .. d -- build a message
end

function key(k, z)
  if z == 0 then return end
  if k == 2 then press_down(2) end
  if k == 3 then press_down(3) end
  screen_dirty = true
end

function press_down(i)
  message = "press down " .. i
end

local keys_down = {}
local swap_step = nil
local swap_strand = nil
local swap_cur_strand = nil
local set_cur_strand = nil
g.key = function(x,y,z)
  if z == 1 then
    if keys_down[y] == nil then keys_down[y] = {} end
    keys_down[y][x] = 1
    if y == 1 then
      focus_strand = x
      set_cur_strand = x 
    elseif y == 8 then
      focus_twine = util.clamp(x,1,#twines)
    elseif y == 2 and x <= #twines[focus_twine].weave.strands then
      if set_cur_strand ~= nil then
        twines[focus_twine].weave.strands[x] = set_cur_strand 
      elseif swap_cur_strand == nil then
        swap_cur_strand = x
      else 
        local v1 = twines[focus_twine].weave.strands[swap_cur_strand]
        local v2 = twines[focus_twine].weave.strnads[x]
        twines[focus_twine].weave.strands[swap_cur_strand] = v2
        twines[focus_twine].weave.strands[x] = v1
      end
    elseif y >= 2 and x <= #twines[focus_twine].weave.strands then
      if swap_step == nil then
        swap_step = y - 2
        swap_strand = x
      elseif swap_step == y - 2 then 
        local v1 = twines[focus_twine].weave.steps[swap_step][swap_strand]
        local v2 = twines[focus_twine].weave.steps[y-2][x]
        twines[focus_twine].weave.steps[swap_step][swap_strand] = v2
        twines[focus_twine].weave.steps[y-2][x] = v1
      end
    end
  elseif z == 0 then
    keys_down[y][x] = nil
    if y == 1 then
      swap_cur_strand = nil
    elseif y >= 2 and x <= #twines[focus_twine].weave.strands then
      if y - 2 == swap_step and x == swap_strand then
        swap_step = nil
        swap_strand = nil
      end
    end
  end
end

function redraw_clock() ----- a clock that draws space
  while true do ------------- "while true do" means "do this forever"
    clock.sleep(1/15) ------- pause for a fifteenth of a second (aka 15fps)
    if screen_dirty then ---- only if something changed
      redraw() -------------- redraw space
      grid_draw()
      screen_dirty = false -- and everything is clean again
    end
  end
end

function grid_draw()
  if is_grid_connected() ~= true then return end
  local t = twines[focus_twine]
  if t == nil then return end
  g:all(0)
  for j = 1,#t.weave.strands do
    g:led(j,1, (#t.weave.strands - j + 1) * 3)
  end
  for j = 1,#t.weave.strands do
    g:led(j,2, (#t.weave.strands - t.weave.strands[j] + 1) * 3)
  end
  for i = 1,#t.weave.steps do
    for j = 1,#t.weave.strands do
      local v = t.weave:get_initial_index(i,j)
      -- print(i .. "," .. j .. ": " .. v)
      g:led(j,i + 2, (#t.weave.strands - v + 1) * 3)
    end
  end
  g:led(focus_twine,8,15)
  g:refresh()
end

function redraw()
  t = twines[focus_twine]
  if t then
    screen.clear()
    screen.aa(1)
    screen.line_width(2)
    screen.font_face(1)
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 32)
    screen.text_center(t and t.target or "")
    screen.move(64, 42)
    if focus_strand ~= nil and twines[focus_twine].values[focus_strand] ~= nil then
      screen.text_center(twines[focus_twine].values[focus_strand])
    end
    screen.fill()
    screen.move(10,10)
    print("lines")
    print(#t.weave.steps)
    for n = 1,#t.weave.steps do
      print("N")
      print(n)
      print("STEPS")
      print(t.weave.steps[n])
      print(#t.weave.steps[n])
      for k = 1,#t.weave.steps[n] do
        print("line" .. n .. " " .. k)
        screen.move(10 + 10 * k, 10 + 10 * n) 
        screen.line(10 + 10 * t.weave.steps[n][k], 20 + 10 * n)
        screen.stroke()
      end
    end
    screen.update()
  end
end


function r() ----------------------------- execute r() in the repl to quickly rerun this script
  norns.script.load(norns.state.script) -- https://github.com/monome/norns/blob/main/lua/core/state.lua
end

function cleanup() --------------- cleanup() is automatically called on script close
  clock.cancel(redraw_clock_id) -- melt our clock vie the id we noted
end