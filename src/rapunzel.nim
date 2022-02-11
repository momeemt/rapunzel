import strutils, tables, strformat, times

type
  RapunzelNode = object
    kind: RapunzelNodeKind
    children: seq[RapunzelNode]
    value: string

  RapunzelNodeKind = enum
    rapunzelDocument, rapunzelParagraph, rapunzelBlock, rapunzelText, rapunzelBold, rapunzelItalic
    rapunzelVariable, rapunzelExpand

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
      if rawRapunzel[index+1] == '*':
        childNode = RapunzelNode(kind: rapunzelBold)
      elif rawRapunzel[index+1] == '/':
        childNode = RapunzelNode(kind: rapunzelItalic)
      elif rawRapunzel[index+1] == '=':
        childNode = RapunzelNode(kind: rapunzelExpand)
      skipCount = 2
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

type ReassignmentDefect* = object of Defect

proc childrenValue (ast: RapunzelNode): string

proc astToHtml* (ast: RapunzelNode): string =
  result = case ast.kind:
  of rapunzelText: ast.value
  of rapunzelBold: "<b>" & ast.value & "</b>"
  of rapunzelItalic: "<em>" & ast.value & "</em>"
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
