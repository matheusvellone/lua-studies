local lpeg = require 'lpeg'

local patt = ('0' * lpeg.S('xX') * (lpeg.R('AF') + lpeg.R('09'))^1 / tonumber * -1):match('0xAAF')