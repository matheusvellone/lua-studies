BOARD_SIZE = 8

board = {}

function isPlaceOk (row, column)
  for i = 1, row - 1 do
    if (board[i] == column)
      or (board[i] - 1 == column - row)
      or (board[i] + 1 == column + row)
    then
      return false
    end
  end

  return true
end

function printSolution ()
  io.write('  ')
  for column = 1, BOARD_SIZE do
    io.write(column .. (column == BOARD_SIZE and '' or ' '))
  end
  io.write('\n')

  for row = 1, BOARD_SIZE do
    io.write(row .. ' ')
    for column = 1, BOARD_SIZE do
      io.write(board[row] == column and 'Q' or '.', ' ')
    end
    io.write('\n')
  end
  io.write('\n')
end

function addQueen (row)
  print('------------------------------')
  print('row', row)
  if (row > BOARD_SIZE) then
    printSolution()
    os.exit()
    return
  end

  for column = 1, BOARD_SIZE do
    print('checking coordinates', row, column)
    if isPlaceOk(row, column) then
      print('found!')
      board[row] = column
      addQueen(row + 1)
      -- break
    else
      print('not valid')
    end
  end
end

addQueen(1)