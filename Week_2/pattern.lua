local lpeg = require 'lpeg'
local pt = require 'pt'
local array = require 'array'

local function getReducer (tag)
  return function (value)
    return {
      tag = tag,
      value = value,
    }
  end
end

local space = lpeg.S(' \n\t')^0

local number = lpeg.R('09')^1

local scientificNotation = lpeg.S('eE') * lpeg.S('-+')^-1 * number
local decimal = '.' * number
local completeNumber = (lpeg.S('+-')^-1 * (number * decimal^-1 + decimal) * scientificNotation^-1) / tonumber / getReducer('number') * space

local opA = lpeg.C(lpeg.S('+-')) * space
local opM = lpeg.C(lpeg.S('*/%')) * space
local opE = lpeg.C(lpeg.S('^')) * space

local openParenthesis = '(' * space
local closeParenthesis = ')' * space

local comparisonOperands = lpeg.C((lpeg.S('<>') * lpeg.P('=')^-1) + (lpeg.S('=!') * lpeg.P('='))) * space

local function foldBinary (list)
  local tree = list[1]

  for i = 2, #list, 2 do
    tree = {
      tag = 'binop',
      e1 = tree,
      op = list[i],
      e2 = list[i + 1],
    }
  end

  return tree
end

local exp = lpeg.V('exp')
local term = lpeg.V('term')

local primary = lpeg.V('primary')
local exp = lpeg.V('exp')
local term = lpeg.V('term')
local sum = lpeg.V('sum')
local bool = lpeg.V('bool')

local grammar = space * lpeg.P({
  [1] = 'bool',
  primary = completeNumber + openParenthesis * bool * closeParenthesis,
  exp = lpeg.Ct(primary * (opE * primary)^0) / foldBinary,
  term = lpeg.Ct(exp * (opM * exp)^0) / foldBinary,
  sum = lpeg.Ct(term * (opA * term)^0) / foldBinary,
  bool = lpeg.Ct(sum * (comparisonOperands * sum)^-1) / foldBinary,
}) * -1

function runOperation (operator, a, b)
  if operator == '+' then return a + b end
  if operator == '-' then return a - b end
  if operator == '*' then return a * b end
  if operator == '/' then return a / b end
  if operator == '%' then return a % b end
  if operator == '^' then return a ^ b end
  
  error('unknown operator "' .. operator .. '"')
end

local function parse (input)
  return grammar:match(input)
end

--------------------

-- local input = io.read('a')
local input = '.2*2==0.4'
print('Code is:', input)
local ast = parse(input)
print(pt.pt(ast))

------------------------

local code = {}

local ops = {
  ['+'] = 'add',
  ['-'] = 'sub',
  ['*'] = 'mul',
  ['/'] = 'div',
  ['%'] = 'mod',
  ['^'] = 'exp',
  ['>'] = 'g',
  ['>='] = 'gt',
  ['<'] = 'l',
  ['>='] = 'lt',
  ['=='] = 'eq',
  ['!='] = 'ne',
}

local function codeExp (ast)
  if ast.tag == 'number' then
    array.push(code, 'push')
    array.push(code, ast.value)
  elseif ast.tag == 'binop' then
    codeExp(ast.e1)
    codeExp(ast.e2)

    array.push(code, ops[ast.op])
  else
    error('Unknown tag "' .. ast.tag .. '"')
  end
end

local function compile()
  codeExp(ast)
end

compile()
print(pt.pt(code))

---------------------

local stack = {}

local function run ()
  local index = 1

  while index <= #code do
    if code[index] == 'push' then
      array.push(stack, code[index + 1])
      index = index + 2
    elseif code[index] == 'add' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a + b)
      index = index + 1
    elseif code[index] == 'sub' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a - b)
      index = index + 1
    elseif code[index] == 'mul' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a * b)
      index = index + 1
    elseif code[index] == 'div' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a / b)
      index = index + 1
    elseif code[index] == 'mod' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a % b)
      index = index + 1
    elseif code[index] == 'exp' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a ^ b)
      index = index + 1
    elseif code[index] == 'g' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a > b and 1 or 0)
      index = index + 1
    elseif code[index] == 'gt' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a >= b and 1 or 0)
      index = index + 1
    elseif code[index] == 'l' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a < b and 1 or 0)
      index = index + 1
    elseif code[index] == 'lt' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a <= b and 1 or 0)
      index = index + 1
    elseif code[index] == 'eq' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a == b and 1 or 0)
      index = index + 1
    elseif code[index] == 'ne' then
      local b = array.pop(stack)
      local a = array.pop(stack)
      
      array.push(stack, a ~= b and 1 or 0)
      index = index + 1
    else
      error('Unknown instruction "' .. code[index] .. '"')
    end
  end
end

run()
print('Final result is: ' .. stack[1])