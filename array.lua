local function push (list, value)
  list[#list + 1] = value
end

local function pop (list)
  local value = list[#list]
  list[#list] = nil

  return value
end

return {
  push = push,
  pop = pop,
}