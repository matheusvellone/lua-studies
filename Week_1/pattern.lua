local lpeg = require 'lpeg'
local pt = require 'pt'

local space = lpeg.S(' \n\t')^0

local number = lpeg.R('09')^1
local numberExpression = (lpeg.S('+-')^-1 * number * ('.' * number)^-1) / tonumber * space

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

local g = lpeg.P({
  [1] = 'final',
  primary = numberExpression + openParenthesis * lpeg.V('final') * closeParenthesis,
  exp = space * lpeg.Ct(lpeg.V('primary') * (operatorsExp * lpeg.V('primary'))^0) / mathOperation,
  term = space * lpeg.Ct(lpeg.V('exp') * (operatorsMult * lpeg.V('exp'))^0) / mathOperation,
  final = space * lpeg.Ct(lpeg.V('term') * (operatorsSum * lpeg.V('term'))^0) / mathOperation,
}) * -1

local code = '3 + 6.9 * 2'

print('Code is: ', code)
print(pt.pt(g:match(code)))
