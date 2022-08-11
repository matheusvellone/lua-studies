local lpeg = require 'lpeg'
local pt = require 'pt'
local array = require 'array'
local stringHelper = require 'stringHelper'

local function I (msg)
  return lpeg.P(function () print(msg); return true end)
end

local function getReducer (tag)
  return function (value)
    return {
      tag = tag,
      value = value,
    }
  end
end

local function nodeAssign (id, expression)
  return {
    tag = 'assign',
    id = id,
    expression = expression,
  }
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

local function nodeReturn (expression)
  return {
    tag = 'return',
    expression = expression,
  }
end

local function nodePrint (expression)
  return {
    tag = 'print',
    expression = expression,
  }
end

local maxMatch = 0
local function updateMaxMatch (_, p)
  maxMatch = math.max(p, maxMatch)

  return true
end

local lineComment = lpeg.P('#') * (lpeg.P(1) - lpeg.P('\n'))^0

local alpha = lpeg.R('az', 'AZ')
local specialAllowedInVariable = lpeg.P('_')
local digit = lpeg.R('09')
local alphanumeric = alpha + digit
local space = lpeg.V('space')

local identifier = lpeg.C(alpha * (alphanumeric + specialAllowedInVariable)^0) * space
local variable = identifier / getReducer('variable')

local number = digit^1

local scientificNotation = lpeg.S('eE') * lpeg.S('-+')^-1 * number
local decimal = '.' * number
local completeNumber = (lpeg.S('+-')^-1 * (number * decimal^-1 + decimal) * scientificNotation^-1) / tonumber / getReducer('number') * space

local opA = lpeg.C(lpeg.S('+-')) * space
local opM = lpeg.C(lpeg.S('*/%')) * space
local opE = lpeg.C(lpeg.S('^')) * space
local operatorAssign = lpeg.P('=') * space

local openParenthesis = '(' * space
local closeParenthesis = ')' * space
local openBraces = '{' * space
local closeBraces = '}' * space
local semicolon = ';'* space * space
local ret = 'return' * space
local printChar = '@' * space

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
local statement = lpeg.V('statement')
local statements = lpeg.V('statements')
local block = lpeg.V('block')

local grammar = lpeg.P({'prog',
  prog = space * statements * -1,
  primary = completeNumber + openParenthesis * bool * closeParenthesis + variable,
  exp = lpeg.Ct(primary * (opE * primary)^0) / foldBinary,
  term = lpeg.Ct(exp * (opM * exp)^0) / foldBinary,
  sum = lpeg.Ct(term * (opA * term)^0) / foldBinary,
  bool = lpeg.Ct(sum * (comparisonOperands * sum)^-1) / foldBinary,

  statement = block
    + identifier * operatorAssign * bool / nodeAssign
    + ret * bool / nodeReturn
    + printChar * bool / nodePrint,
  statements = statement * (semicolon^-1 * statements^-1) / nodeSeq,
  block = openBraces * statements^-1 * semicolon^-1 * closeBraces,

  space = (lpeg.S(' \n\t'))^0 * lpeg.P(updateMaxMatch),
})

local function parse (input)
  return grammar:match(input)
end

--------------------

local input = io.read('a')
print('Code is: \n---------------\n' .. input .. '\n---------------')
local ast = parse(input)
pt.pt(ast)

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
    lineStr = stringHelper.insert(lineStr, '@', errorPosition),
    line = currentLine,
    position = errorPosition,
  }
end

if ast == nil then
  local err = syntaxError(input, maxMatch)
  io.stderr:write('Syntax error at line ' .. err.line .. ' and position ' .. err.position .. '.\n')
  io.stderr:write('Error at \'@\': ' .. err.lineStr .. '.\n')
  os.exit(1)
end

------------------------

local function var2num (state, id)
  local num = state.vars[id]
  if not num then
    num = state.nvars + 1
    state.nvars = num
    state.vars[id] = num
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
}

local function codeExp (state, ast)
  if ast.tag == 'number' then
    array.push(state.code, 'push')
    array.push(state.code, ast.value)
  elseif ast.tag == 'variable' then
    array.push(state.code, 'load')
    array.push(state.code, var2num(state, ast.value))
  elseif ast.tag == 'binop' then
    codeExp(state, ast.e1)
    codeExp(state, ast.e2)

    array.push(state.code, ops[ast.op])
  else
    error('Unknown tag "' .. ast.tag .. '"')
  end
end

local function codeStatement (state, ast)
  if ast.tag == 'assign' then
    codeExp(state, ast.expression)
    array.push(state.code, 'store')
    array.push(state.code, var2num(state, ast.id))
  elseif ast.tag == 'seq' then
    codeStatement(state, ast.statement1)
    codeStatement(state, ast.statement2)
  elseif ast.tag == 'return' then
    codeExp(state, ast.expression)
    array.push(state.code, 'return')
  elseif ast.tag == 'print' then
    codeExp(state, ast.expression)
    array.push(state.code, 'print')
  else
    error('Unknown tag "', ast.tag, '"')
  end
end

local function compile()
  local state = {
    code = {},
    vars = {},
    nvars = 0,
  }
  codeStatement(state, ast)
  array.push(state.code, 'push')
  array.push(state.code, 0)
  array.push(state.code, 'return')

  return state.code
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