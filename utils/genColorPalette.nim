import strformat, strutils

var colorList: seq[string] = @[]
while true:
  let input = stdin.readLine
  if input == "end":
    break
  else:
    colorList.add input

var res = ""
for col in colorList:
  if col[0] == '#':
    res &= &": \"{col}\",\n"
  else:
    let tmp = col.split(' ').join(":")
    res &= &"\"{tmp}\""

echo res