local lpeg = require 'lpeg'

spacePattern = lpeg.P(' ')^0
digitPattern = spacePattern * lpeg.C(lpeg.S('-+')^-1 * lpeg.R('09')^1) * spacePattern
plusPattern = lpeg.C(lpeg.S('+-*/'))

operationPattern = digitPattern * (plusPattern * digitPattern)^1 * -1

code = '123 - 33 - -9*12/4'

print('Code is: ', code)
print(operationPattern:match(code))