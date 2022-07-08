function factorial (n)
  if n == 0 then
    return 1
  else
    return n * factorial(n - 1)
  end
end

print('enter a number')
a = io.read('*n')

if a < 0 then
  print('Number must be > 0')
else
  print(factorial(a))
end
