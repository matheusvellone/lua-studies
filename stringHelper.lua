function splitLines(str)
  local result = {}
  
  for line in str:gmatch '[^\n]+' do
    table.insert(result, line)
  end

  return result
end

function insert(str1, str2, pos)
  return str1:sub(1, pos) .. str2 .. str1:sub(pos + 1)
end

return {
  splitLines = splitLines,
  insert = insert,
}