local lpeg = require 'lpeg'
local pt = require 'pt'

local space = lpeg.S(' \n\t')^0

local number = lpeg.R('09')^1
-- TODO: add optional lead 0 to decimal numbers
local numberExpression = (lpeg.S('+-')^-1 * (number) * ('.' * number)^-1) / tonumber * space

local openParenthesis = '(' * space
local closeParenthesis = ')' * space

local operatorsSum = lpeg.C(lpeg.S('+-')) * space
local operatorsMult = lpeg.C(lpeg.S('*/%')) * space
local operatorsExp = lpeg.C(lpeg.S('^')) * space

function mathOperation (list)
  local acc = list[1]

  for i = 2, #list, 2 do
    if list[i] == '+' then
      acc = acc + list[i + 1]
    elseif list[i] == '-' then
      acc = acc - list[i + 1]
    elseif list[i] == '*' then
      acc = acc * list[i + 1]
    elseif list[i] == '/' then
      acc = acc / list[i + 1]
    elseif list[i] == '%' then
      acc = acc % list[i + 1]
    elseif list[i] == '^' then
      acc = acc ^ list[i + 1]
    else
      error('unknown operator')
    end
  end

  return acc
end

local primary = lpeg.V('primary')
local exp = lpeg.V('exp')
local term = lpeg.V('term')
local final = lpeg.V('final')

local g = space * lpeg.P({
  [1] = 'final',
  primary = numberExpression + openParenthesis * final * closeParenthesis,
  exp = lpeg.Ct(primary * (operatorsExp * primary)^0) / mathOperation,
  term = lpeg.Ct(exp * (operatorsMult * exp)^0) / mathOperation,
  final = lpeg.Ct(term * (operatorsSum * term)^0) / mathOperation,
}) * -1

local code = '2 * 9^2 - 30'

print('Code is: ', code)
print(pt.pt(g:match(code)))
