local lpeg = require "lpeg"

local p = lpeg.P("hello")

print(lpeg.match(p, "hello world"))
print(lpeg.match(p, "bye hello world"))
