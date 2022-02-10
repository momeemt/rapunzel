import strutils, tables, strformat, times

type
  OzNode = object
    kind: OzNodeKind
    children: seq[OzNode]
    value: string

  OzNodeKind = enum
    ozDocument, ozParagraph, ozBlock, ozText, ozBold, ozItalic
    ozVariable, ozExpand

proc ozParse* (rawOz: string): OzNode =
  result = OzNode(kind: ozDocument)
  if rawOz.len >= 2 and rawOz[0] == '{':
    result.children.add OzNode(kind: ozBlock)
  else:
    result.children.add OzNode(kind: ozParagraph)
  var childNode = OzNode(kind: ozText)
  var skipCount = 0
  for index in 0..rawOz.high:
    if skipCount > 0:
      skipCount -= 1
      continue
    let rawOzChar = rawOz[index]
    if rawOzChar == '[':
      result.children[result.children.high].children.add childNode
      if rawOz[index+1] == '*':
        childNode = OzNode(kind: ozBold)
      elif rawOz[index+1] == '/':
        childNode = OzNode(kind: ozItalic)
      elif rawOz[index+1] == '=':
        childNode = OzNode(kind: ozExpand)
      skipCount = 2
    elif rawOzChar == '{':
      result.children[result.children.high].children.add childNode
      if rawOz[index+1] == '%':
        childNode = OzNode(kind: ozVariable)
      elif rawOz[index+1] == '=':
        childNode = OzNode(kind: ozExpand)
      skipCount = 2
    elif rawOzChar == ']' or rawOzChar == '}':
      result.children[result.children.high].children.add childNode
      childNode = OzNode(kind: ozText)
    elif rawOzChar == '\n':
      result.children[result.children.high].children.add childNode
      if rawOz.high >= index + 2 and rawOz[index+1] == '{':
        result.children.add OzNode(kind: ozBlock)
      else:
        result.children.add OzNode(kind: ozParagraph)
      childNode = OzNode(kind: ozText)
    else:
      childNode.value.add rawOzChar
  result.children[result.children.high].children.add childNode

var mtupVarsTable = initTable[string, string]()
mtupVarsTable["now"] = ""

type ReassignmentDefect* = object of Defect

proc childrenValue (ast: OzNode): string

proc astToHtml* (ast: OzNode): string =
  result = case ast.kind:
  of ozText: ast.value
  of ozBold: "<b>" & ast.value & "</b>"
  of ozItalic: "<em>" & ast.value & "</em>"
  of ozVariable:
    let
      varName = ast.value.split(',')[0].strip
      varValue = ast.value.split(',')[1].strip
    if mtupVarsTable.hasKey(varName):
      raise newException(ReassignmentDefect, &"Variable {ast.value} is already defined.")
    else:
      mtupVarsTable[varName] = varValue
    ""
  of ozExpand:
    let res = if mtupVarsTable.hasKey(ast.value):
      let res = case ast.value:
      of "now": times.now().format("yyyy-MM-dd HH:mm:ss")
      else:
        mtupVarsTable[ast.value]
      res
    else:
      raise newException(KeyError, &"Variable {ast.value} is undefined.")
    res
  of ozParagraph: "<p>" & ast.childrenValue & "</p>"
  of ozDocument, ozBlock: ast.childrenValue

proc childrenValue (ast: OzNode): string =
  for child in ast.children:
    result &= child.astToHtml()
