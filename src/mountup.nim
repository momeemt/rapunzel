import strutils, tables, strformat

type
  MtupNode = object
    kind: MtupNodeKind
    children: seq[MtupNode]
    value: string

  MtupNodeKind = enum
    mkDocument, mkParagraph, mkBlock, mkText, mkBold, mkItalic
    mkVariable, mkExpand

proc mtupParse* (rawMtup: string): MtupNode =
  result = MtupNode(kind: mkDocument)
  if rawMtup.len >= 2 and rawMtup[0] == '{':
    result.children.add MtupNode(kind: mkBlock)
  else:
    result.children.add MtupNode(kind: mkParagraph)
  var childNode = MtupNode(kind: mkText)
  var skipCount = 0
  for index in 0..rawMtup.high:
    if skipCount > 0:
      skipCount -= 1
      continue
    let rawMtupChar = rawMtup[index]
    if rawMtupChar == '[' or rawMtupChar == '{':
      result.children[result.children.high].children.add childNode
      if rawMtup[index+1] == '*':
        childNode = MtupNode(kind: mkBold)
      elif rawMtup[index+1] == '/':
        childNode = MtupNode(kind: mkItalic)
      elif rawMtup[index+1] == '%':
        childNode = MtupNode(kind: mkVariable)
      elif rawMtup[index+1] == '=':
        childNode = MtupNode(kind: mkExpand)
      skipCount = 2
    elif rawMtupChar == ']' or rawMtupChar == '}':
      result.children[result.children.high].children.add childNode
      childNode = MtupNode(kind: mkText)
    elif rawMtupChar == '\n':
      result.children[result.children.high].children.add childNode
      if rawMtup.high >= index + 2 and rawMtup[index+1] == '{':
        result.children.add MtupNode(kind: mkBlock)
      else:
        result.children.add MtupNode(kind: mkParagraph)
      childNode = MtupNode(kind: mkText)
    else:
      childNode.value.add rawMtupChar
  result.children[result.children.high].children.add childNode

var mtupVarsTable = initTable[string, string]()

type ReassignmentDefect* = object of Defect

proc childrenValue (ast: MtupNode): string

proc astToHtml* (ast: MtupNode): string =
  result = case ast.kind:
  of mkText: ast.value
  of mkBold: "<b>" & ast.value & "</b>"
  of mkItalic: "<em>" & ast.value & "</em>"
  of mkVariable:
    let
      varName = ast.value.split(',')[0].strip
      varValue = ast.value.split(',')[1].strip
    if mtupVarsTable.hasKey(varName):
      raise newException(ReassignmentDefect, &"Variable {ast.value} is already defined.")
    else:
      mtupVarsTable[varName] = varValue
    ""
  of mkExpand:
    let res = if mtupVarsTable.hasKey(ast.value):
      mtupVarsTable[ast.value]
    else:
      raise newException(KeyError, &"Variable {ast.value} is undefined.")
    res
  of mkParagraph: "<p>" & ast.childrenValue & "</p>"
  of mkDocument, mkBlock: ast.childrenValue

proc childrenValue (ast: MtupNode): string =
  for child in ast.children:
    result &= child.astToHtml()