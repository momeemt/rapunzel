import strutils, tables, strformat, times, json

type
  RapunzelNodeKind = enum
    rapunzelDocument, rapunzelParagraph, rapunzelBlock, rapunzelText,
    rapunzelBold, rapunzelItalic, rapunzelUnderline, rapunzelStrike,
    rapunzelColor,
    rapunzelVariable, rapunzelExpand

  RapunzelNode = object
    case kind: RapunzelNodeKind
    of rapunzelColor:
      colorCode: string
    else: discard
    children: seq[RapunzelNode]
    value: string

  ReassignmentDefect* = object of Defect
  UndefinedCommandDefect* = object of Defect
  UndefinedColorDefect* = object of Defect

let
  ColorJson = parseFile("assets/colorPalette.json").getFields
var colorJsonKey: seq[string]

for key in ColorJson.keys: colorJsonKey.add key

proc isHexadecimal (maybeHex: string): bool =
  result = true
  for character in maybeHex:
    if character notin {'0'..'9', 'a'..'f', 'A'..'F'}:
      return false

proc rapunzelParse* (rawRapunzel: string): RapunzelNode =
  result = RapunzelNode(kind: rapunzelDocument)
  if rawRapunzel.len >= 2 and rawRapunzel[0] == '{':
    result.children.add RapunzelNode(kind: rapunzelBlock)
  else:
    result.children.add RapunzelNode(kind: rapunzelParagraph)
  var childNode = RapunzelNode(kind: rapunzelText)
  var skipCount = 0
  for index in 0..rawRapunzel.high:
    if skipCount > 0:
      skipCount -= 1
      continue
    let rawRapunzelChar = rawRapunzel[index]
    if rawRapunzelChar == '[':
      result.children[result.children.high].children.add childNode
      let nextCharacter = rawRapunzel[index+1]
      skipCount = 2 # [? ...]の "? "をスキップ

      childNode = case nextCharacter:
      of '*': RapunzelNode(kind: rapunzelBold)
      of '/': RapunzelNode(kind: rapunzelItalic)
      of '_': RapunzelNode(kind: rapunzelUnderline)
      of '~': RapunzelNode(kind: rapunzelStrike)
      of '=': RapunzelNode(kind: rapunzelExpand)
      of '#':
        var
          color = ""
          colorIndex = 2 # color-command-nameを取得するためのindex
        while rawRapunzel[index+colorIndex] != ' ':
          color.add rawRapunzel[index+colorIndex]
          colorIndex += 1
        let colorCode = if color in colorJsonKey:
          ColorJson[color].getStr
        elif color.isHexadecimal:
          "#" & color
        else:
          raise newException(UndefinedColorDefect, &"{color} is undefined color or incorrect color code")
        skipCount += colorIndex - 2
        RapunzelNode(kind: rapunzelColor, colorCode: colorCode)
      else:
        var
          name = ""
          nameIndex = 2
        while rawRapunzel[index+nameIndex] != ' ':
          name.add rawRapunzel[index+nameIndex]
          nameIndex += 1
        raise newException(UndefinedCommandDefect, &"{name} is undefined command.")
    elif rawRapunzelChar == '{':
      result.children[result.children.high].children.add childNode
      if rawRapunzel[index+1] == '%':
        childNode = RapunzelNode(kind: rapunzelVariable)
      elif rawRapunzel[index+1] == '=':
        childNode = RapunzelNode(kind: rapunzelExpand)
      skipCount = 2
    elif rawRapunzelChar == ']' or rawRapunzelChar == '}':
      result.children[result.children.high].children.add childNode
      childNode = RapunzelNode(kind: rapunzelText)
    elif rawRapunzelChar == '\n':
      result.children[result.children.high].children.add childNode
      if rawRapunzel.high >= index + 2 and rawRapunzel[index+1] == '{':
        result.children.add RapunzelNode(kind: rapunzelBlock)
      else:
        result.children.add RapunzelNode(kind: rapunzelParagraph)
      childNode = RapunzelNode(kind: rapunzelText)
    else:
      childNode.value.add rawRapunzelChar
  result.children[result.children.high].children.add childNode

var mtupVarsTable = initTable[string, string]()
mtupVarsTable["now"] = ""

proc childrenValue (ast: RapunzelNode): string

proc astToHtml* (ast: RapunzelNode): string =
  result = case ast.kind:
  of rapunzelText: ast.value
  of rapunzelBold: "<b>" & ast.value & "</b>"
  of rapunzelItalic: "<em>" & ast.value & "</em>"
  of rapunzelStrike: "<span class=\"rapunzel--strike\">" & ast.value & "</span>"
  of rapunzelUnderline: "<span class=\"rapunzel--underline\">" & ast.value & "</span>"
  of rapunzelColor:
    "<span style=\"color: " & ast.colorCode & ";\">" & ast.value & "</span>"
  of rapunzelVariable:
    let
      varName = ast.value.split(',')[0].strip
      varValue = ast.value.split(',')[1].strip
    if mtupVarsTable.hasKey(varName):
      raise newException(ReassignmentDefect, &"Variable {ast.value} is already defined.")
    else:
      mtupVarsTable[varName] = varValue
    ""
  of rapunzelExpand:
    let res = if mtupVarsTable.hasKey(ast.value):
      let res = case ast.value:
      of "now": times.now().format("yyyy-MM-dd HH:mm:ss")
      else:
        mtupVarsTable[ast.value]
      res
    else:
      raise newException(KeyError, &"Variable {ast.value} is undefined.")
    res
  of rapunzelParagraph: "<p>" & ast.childrenValue & "</p>"
  of rapunzelDocument, rapunzelBlock: ast.childrenValue

proc childrenValue (ast: RapunzelNode): string =
  for child in ast.children:
    result &= child.astToHtml()
