local Weave = {
  strands = {},
  steps = {},
}
Weave.__index = Weave

local index_mod = function(n,t)
  return 1 + ((n - 1) % #t)
end

function Weave.new(strands, steps)
  if steps == nil then steps = {} end
  local self = setmetatable({}, Weave)
  -- TODO better to store actual strands in state, or original sequence and index?
  self.strands = strands
  self.steps = steps
  self.cur_step = 1
  self.cur_strand = 1
  return self
end

function Weave:add_step(s)
  if #s ~= #self.strands then return end
  table.insert(self.steps, s)
end

function Weave:inc_pos(n)
  if n == nil then n = 1 end
  self.cur_strand = index_mod(self.cur_strand + n, self.strands)
  if self.cur_strand == 1 then
    self.cur_step = index_mod(self.cur_step + 1, self.steps)
  end
end

function Weave:warp() 
  if self.cur_strand == 1 then
    local current_transform = self.steps[self.cur_step]
    local new_strands = {}
    for k,v in pairs(current_transform) do
      new_strands[k] = self.strands[v]  
    end
    self.strands = new_strands
  end
end

function Weave:next()
  local val = self.strands[index_mod(self.cur_strand,self.strands)]
  self:inc_pos()
  self:warp()
  return val
end

function Weave:get_initial_index(step, strand)
  if step == 1 then
    return self.steps[1][strand]
  else
    return self.get_initial_index(self, step - 1, self.steps[step][strand])
  end
end

function Weave:get_steps()
  return self.steps
end

return Weave