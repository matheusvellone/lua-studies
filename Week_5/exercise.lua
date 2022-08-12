local lpeg = require 'lpeg'
local pt = require 'pt'
local array = require 'array'
local stringHelper = require 'stringHelper'

local P = lpeg.P
local R = lpeg.R
local V = lpeg.V
local C = lpeg.C
local S = lpeg.S
local Ct = lpeg.Ct

local function I (msg)
  return P(function () print(msg); return true end)
end

local function getNode (tag, ...)
  local labels = table.pack(...)

  return function (...)
    local values = table.pack(...)
    if #labels ~= #values then
      error('Length mismatch. Expecting ' .. #labels .. ' but received ' .. #values)
    end

    local result = {
      tag = tag,
    }

    for index, label in pairs(labels) do
      result[label] = values[index]
    end

    return result
  end
end

local function nodeSeq (statement1, statement2)
  if statement2 == nil then
    return statement1
  else
    return {
      tag ='seq',
      statement1=statement1,
      statement2=statement2,
    }
  end
end

local maxMatch = 0
local function updateMaxMatch (_, p)
  maxMatch = math.max(p, maxMatch)

  return true
end

local lineComment = P('#') * (P(1) - P('\n'))^0

local alpha = R('az', 'AZ')
local specialAllowedInVariable = P('_')
local digit = R('09')
local alphanumeric = alpha + digit
local space = V('space')

local reservedWords = {
  "return",
}
local excludeReservedWords = P(false)
for i = 1, #reservedWords do
  excludeReservedWords = excludeReservedWords + reservedWords[i]
end
excludeReservedWords = excludeReservedWords * -alphanumeric

local function T (pattern)
  return pattern * space
end

local function RW (pattern)
  assert(excludeReservedWords:match(pattern))
  return pattern * -alphanumeric * space
end

local identifier = (C(alpha * (alphanumeric + specialAllowedInVariable)^0) - excludeReservedWords) * space
local variable = identifier / getNode('variable', 'value')

local number = digit^1

local scientificNotation = S('eE') * S('-+')^-1 * number
local decimal = '.' * number
local completeNumber = (S('+-')^-1 * (number * decimal^-1 + decimal) * scientificNotation^-1) / tonumber / getNode('number', 'value') * space

local notOp = C('!') * space
local opA = C(S('+-')) * space
local opM = C(S('*/%')) * space
local opE = C(S('^')) * space
local operatorAssign = T('=')

local blockComment = '#{' * (P(1) - '\n')^0 * '\n}#'

local comparisonOperands = C((S('<>') * P('=')^-1) + (S('=!') * P('='))) * space

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

local function unop (statement1, statement2)
  if statement2 == nil then
    return statement1
  end

  return {
    tag = 'unop',
    op = statement1,
    expression = statement2,
  }
end

local exp = V('exp')
local term = V('term')

local primary = V('primary')
local exp = V('exp')
local term = V('term')
local sum = V('sum')
local bool = V('bool')
local statement = V('statement')
local statements = V('statements')
local block = V('block')

local grammar = P({'prog',
  prog = space * statements * -1,
  primary = completeNumber + T('(') * bool * T(')') + variable,
  exp = Ct(primary * (opE * primary)^0) / foldBinary,
  term = Ct(exp * (opM * exp)^0) / foldBinary,
  sum = Ct(term * (opA * term)^0) / foldBinary,
  bool = notOp^0 * (Ct(sum * (comparisonOperands * sum)^-1) / foldBinary) / unop,

  statement = block
    + identifier * operatorAssign * bool / getNode('assign', 'id', 'expression')
    + RW('return') * bool / getNode('return', 'expression')
    + T('@') * bool / getNode('print', 'expression'),
  statements = statement * (T(';')^-1 * statements^-1) / nodeSeq,
  block = T('{') * statements^-1 * T(';')^-1 * T('}'),

  space = ((S(' \n\t') + lineComment)^0 + blockComment) * P(updateMaxMatch),
})

local function parse (input)
  return grammar:match(input)
end

--------------------

local input = io.read('a')
print('Code is: \n---------------\n' .. input .. '\n---------------')
local ast = parse(input)

-- local file = io.open('graph.txt', 'w')
-- file:write('graph {\n')
-- local function printASTToGraphvizFile (ast)
--   print(pt.pt(ast))
--   file:write()
-- end
-- file:write('}')

local function syntaxError (code, errorPosition)
  local lines = stringHelper.splitLines(code)

  local currentLine = 1
  local lineStr = ''
  for _,line in pairs(lines) do
    lineStr = line
    if errorPosition < #line then
      break
    end

    errorPosition = errorPosition - #line - 1
    currentLine = currentLine + 1
  end

  return {
    lineStr = lineStr,
    line = currentLine,
    position = errorPosition,
  }
end

if ast == nil then
  local err = syntaxError(input, maxMatch)
  io.stderr:write('Syntax error at line ' .. err.line .. ' and position ' .. err.position .. '.\n')
  io.stderr:write('Line with error: "' .. err.lineStr .. '"\n')
  os.exit(1)
end

print(pt.pt(ast))

------------------------

local Compiler = {
  code = {},
  vars = {},
  nvars = 0,
}

function Compiler:addCode (op)
  array.push(self.code, op)
end

function Compiler:var2num (id)
  local num = self.vars[id]
  if not num then
    num = self.nvars + 1
    self.nvars = num
    self.vars[id] = num
  end

  return num
end

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
  ['!'] = 'not',
}

function Compiler:codeExp (ast)
  if ast.tag == 'number' then
    self:addCode('push')
    self:addCode(ast.value)
  elseif ast.tag == 'variable' then
    self:addCode('load')
    self:addCode(self:var2num(ast.value))
  elseif ast.tag == 'binop' then
    self:codeExp(ast.e1)
    self:codeExp(ast.e2)

    self:addCode(ops[ast.op])
  elseif ast.tag == 'unop' then
    self:codeExp(ast.expression)
    self:addCode(ops[ast.op])
  else
    error('Unknown tag "' .. ast.tag .. '"')
  end
end

function Compiler:codeStatement (ast)
  if ast.tag == 'assign' then
    self:codeExp(ast.expression)
    self:addCode('store')
    self:addCode(self:var2num(ast.id))
  elseif ast.tag == 'seq' then
    self:codeStatement(ast.statement1)
    self:codeStatement(ast.statement2)
  elseif ast.tag == 'return' then
    self:codeExp(ast.expression)
    self:addCode('return')
  elseif ast.tag == 'print' then
    self:codeExp(ast.expression)
    self:addCode('print')
  else
    error('Unknown tag "', ast.tag, '"')
  end
end

local function compile()
  Compiler:codeStatement(ast)
  Compiler:addCode('push')
  Compiler:addCode(0)
  Compiler:addCode('return')

  return Compiler.code
end

local code = compile()
print(pt.pt(code))

---------------------

local stack = {}
local memory = {}

local function run ()
  local index = 1

  while true do
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
    elseif code[index] == 'not' then
      local a = array.pop(stack)

      array.push(stack, a == 0 and 1 or 0)
      index = index + 1
    elseif code[index] == 'load' then
      local variableName = code[index + 1]
      local variableValue = memory[variableName]

      if (variableValue == nil) then
        error('Variable "' .. variableName .. '" is not defined')
      end

      array.push(stack, variableValue)

      index = index + 2
    elseif code[index] == 'store' then
      memory[code[index + 1]] = array.pop(stack)

      index = index + 2
    elseif code[index] == 'print' then
      local value = array.pop(stack)
      print('Print command result', value)

      index = index + 1
    elseif code[index] == 'return' then
      return
    else
      error('Unknown instruction "' .. code[index] .. '"')
    end
  end
end

run()
print('Final result is: ', array.pop(stack))