import std/[tables, strutils, strformat, times]
import node, types

var mtupVarsTable = initTable[string, string]()
mtupVarsTable["now"] = ""

proc childrenValue (ast: RapunzelNode): string

proc astToHtml* (ast: RapunzelNode): string =
  result = case ast.kind:
  of rapunzelText: ast.value.strip(true, false, {'\t'})
  of rapunzelBold:
    if ast.children.len == 0: "<b>" & ast.value.strip(true, false, {'\t'}) & "</b>"
    else: "<b>" & ast.childrenValue & "</b>"
  of rapunzelItalic:
    if ast.children.len == 0: "<em>" & ast.value.strip(true, false, {'\t'}) & "</em>"
    else: "<em>" & ast.childrenValue & "</em>"
  of rapunzelStrike:
    if ast.children.len == 0: "<span class=\"rapunzel--strike\">" & ast.value.strip(true, false, {'\t'}) & "</span>"
    else: "<span class=\"rapunzel--strike\">" & ast.childrenValue & "</span>"
  of rapunzelUnderline:
    if ast.children.len == 0: "<span class=\"rapunzel--underline\">" & ast.value.strip(true, false, {'\t'}) & "</span>"
    else: "<span class=\"rapunzel--underline\">" & ast.childrenValue & "</span>"
  of rapunzelColor:
    if ast.children.len == 0: "<span style=\"color: " & ast.colorCode & ";\">" & ast.value.strip(true, false, {'\t'}) & "</span>"
    else: "<span style=\"color: " & ast.colorCode & ";\">" & ast.childrenValue & "</span>"
  of rapunzelHeader:
    let tagName = "h" & $ast.headerRank
    if ast.children.len == 0: &"<{tagName}>" & ast.value.strip(true, false, {'\t'}) & &"</{tagName}>"
    else: &"<{tagName}>" & ast.childrenValue & &"</{tagName}>"
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
  of rapunzelNone: "" # Todo: 例外を投げる

proc childrenValue (ast: RapunzelNode): string =
  for child in ast.children:
    result &= child.astToHtml()
