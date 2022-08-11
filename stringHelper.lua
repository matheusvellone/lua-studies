function splitLines(str)
  local result = {}

  for line in str:gmatch '[^\n]+' do
    table.insert(result, line)
  end

  return result
end

return {
  splitLines = splitLines,
}