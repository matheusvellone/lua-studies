list1 = {some = 2, 'one', 'list', 4}
list2 = {1, 2, 3, 4}

for k, v in pairs(list1) do
  if (type(k) == 'number') then
    list2[#list2 + 1] = v
  elseif (type(list2[k]) ~= 'nil') then
    print('error on key', k)
  else
    list2[k] = v
  end
end

for k, v in pairs(list2) do
  print(k, v)
end
