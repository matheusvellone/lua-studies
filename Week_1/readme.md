## Exercise 1.1

> Run the factorial example. What happens to your program if you enter a negative number? Modify the example to avoid this problem.

Infinite loop. Added an `if` to check for negative value before calling the function

## Exercise 1.2

> Run the `twice` example, both by loading the file with the `-l` option
and with `dofile` . Which way do you prefer?

`dofile` for sure, because it's in the code

## Exercise 1.3

> Can you name other languages that use `--` for comments?

SQL

## Exercise 1.4

> Which of the following strings are valid identifiers?

```
✔️ ___
✔️ _end
✔️ End
❌ end      reserved word
❌ until?   invalid char
❌ nil      reserved word
✔️ NULL
❌ one-step invalid char
```

## Exercise 1.5

> What is the value of the expression `type(nil)==nil` ? (You can use Lua to check your answer.) Can you explain this result?

`false`. The return of `type` is always a string, in this case `"nil"` which is not the same as `nil`

## Exercise 1.6

> How can you check whether a value is a Boolean without using the function `type`?

```lua
type(variable) == 'boolean'
```

## Exercise 1.7

> Consider the following expression: `(x and y and (not z)) or ((not y) and z)`
Are the parentheses necessary? Would you recommend their use in that expression?

None of them are required, but I would write like this to visually separate the two conditions which are executed with `or`

```lua
`(x and y and not z) or (not y and z)`
```

## Exercise 1.8

> Write a simple script that prints its own name without knowing it in advance.

```lua
print(arg[0])
```

## Exercise 5.1

> What will the following script print? Explain.
```lua
sunday = "monday"; monday = "sunday"
t = {sunday = "monday", [sunday] = monday}
print(t.sunday, t[sunday], t[t.sunday])
```

`monday sunday sunday`

## Exercise 5.7

> Write a function that inserts all elements of a given list into a given
position of another given list.

```lua
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

```