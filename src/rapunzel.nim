import strutils, tables, strformat, times, json, parsexml, streams

type
  RapunzelNodeKind = enum
    rapunzelDocument, rapunzelParagraph, rapunzelBlock, rapunzelText,
    rapunzelBold, rapunzelItalic, rapunzelUnderline, rapunzelStrike,
    rapunzelColor, rapunzelHeader,
    rapunzelVariable, rapunzelExpand,
    rapunzelNone # 未決定のノード

  RapunzelNode = object
    case kind: RapunzelNodeKind
    of rapunzelColor:
      colorCode: string
    of rapunzelHeader:
      headerRank: uint8
    else: discard
    value: string
    children: seq[RapunzelNode]

  ReassignmentDefect* = object of Defect
  UndefinedCommandDefect* = object of Defect
  UndefinedColorDefect* = object of Defect
  UndefinedHeaderRankDefect* = object of Defect

let
  ColorJson = parseFile("assets/colorPalette.json").getFields
var colorJsonKey: seq[string]

for key in ColorJson.keys: colorJsonKey.add key

proc rapunzelChildrenNodeRepr (ast: RapunzelNode, nest: int): string 

proc rapunzelNodeRepr (ast: RapunzelNode, nest: int): string =
  if ast.children.len > 0:
    result = ast.rapunzelChildrenNodeRepr(nest)
  else:
    for index in 0..<nest:
      result &= "  "
    if ast.value.len > 0:
      result &= &"{$ast.kind} (value = {ast.value})\n"
    else:
      result &= &"{$ast.kind}\n"

proc rapunzelChildrenNodeRepr (ast: RapunzelNode, nest: int): string =
  for index in 0..<nest:
    result &= "  "
  if ast.value.len > 0:
    result &= &"{$ast.kind} (value = {ast.value})\n"
  else:
    result &= &"{$ast.kind}\n"
  for child in ast.children:
    result &= child.rapunzelNodeRepr(nest + 1)

proc `$`* (ast: RapunzelNode): string =
  result = ast.rapunzelNodeRepr(0)

proc isHexadecimal (maybeHex: string): bool =
  result = true
  for character in maybeHex:
    if character notin {'0'..'9', 'a'..'f', 'A'..'F'}:
      return false

func updateChildNode (src, child: RapunzelNode, openingParenthesisCount: int): RapunzelNode =
  if child.kind == rapunzelNone:
    return src
  if child.kind == rapunzelText and child.value == "": # 空のテキストノードを追加しない
    return src
  var nodeSeqByDepth = @[new RapunzelNode]
  nodeSeqByDepth[0][] = src
  # openingParenthesisCountが0の時、テキストノードを扱っている
  # ネスト数は閉じられていない左括弧より、1少なくなる
  var nestCount = max(openingParenthesisCount-1, 0)
  # 更新する部分木とその経路を保存する
  for index in 0..nestCount:
    let
      node = nodeSeqByDepth[index][]
      subnode = node.children[node.children.high]
    nodeSeqByDepth.add new RapunzelNode
    nodeSeqByDepth[index+1][] = subnode
  nodeSeqByDepth[nodeSeqByDepth.high][].children.add child
  # 更新した部分木で経路を元に親の部分木を更新する
  for index in countdown(nestCount, 0):
    nodeSeqByDepth[index][].children[nodeSeqByDepth[index][].children.high] = nodeSeqByDepth[index+1][]
  result = nodeSeqByDepth[0][]

proc rapunzelParse* (rawRapunzel: string): RapunzelNode =
  result = RapunzelNode(kind: rapunzelDocument)
  if rawRapunzel.len >= 2 and rawRapunzel[0] == '{':
    result.children.add RapunzelNode(kind: rapunzelBlock)
  else:
    result.children.add RapunzelNode(kind: rapunzelParagraph)
  var childNode = RapunzelNode(kind: rapunzelNone)
  var skipCount = 0
  var openingParenthesisCount = 0 # 閉じられていない '[', '{' の個数
  for index in 0..rawRapunzel.high:
    if skipCount > 0:
      skipCount -= 1
      continue
    let rawRapunzelChar = rawRapunzel[index]
    if rawRapunzelChar == '[':
      result = result.updateChildNode(childNode, openingParenthesisCount)
      childNode = RapunzelNode(kind: rapunzelNone)
      openingParenthesisCount += 1

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
      result = result.updateChildNode(childNode, openingParenthesisCount)
      childNode = RapunzelNode(kind: rapunzelNone)
      openingParenthesisCount += 1

      let nextCharacter = rawRapunzel[index+1]
      skipCount = 2

      childNode = case nextCharacter:
      of '%': RapunzelNode(kind: rapunzelVariable)
      of '=': RapunzelNode(kind: rapunzelExpand)
      of '*':
        var
          headerRank = 1'u8
          headerIndex = 2 # header-rankを取得するためのindex
        while rawRapunzel[index+headerIndex] != ' ' and rawRapunzel[index+headerIndex] != '\n':
          if rawRapunzel[index+headerIndex] == '*':
            headerRank += 1
            headerIndex += 1
          else:
            var
              name = ""
              nameIndex = 1
            while rawRapunzel[index+nameIndex] != ' ':
              name.add rawRapunzel[index+nameIndex]
              nameIndex += 1
            raise newException(UndefinedCommandDefect, &"{name} is undefined command.")
        if headerRank > 6:
          raise newException(UndefinedHeaderRankDefect, &"Only up to 6 header ranks are supported. {headerRank} is undefined.")
        skipCount += headerIndex - 2
        RapunzelNode(kind: rapunzelHeader, headerRank: headerRank)
      else:
        var
          name = ""
          nameIndex = 2
        while rawRapunzel[index+nameIndex] != ' ':
          name.add rawRapunzel[index+nameIndex]
          nameIndex += 1
        raise newException(UndefinedCommandDefect, &"{name} is undefined command.")
      
    elif rawRapunzelChar == ']':
      result = result.updateChildNode(childNode, openingParenthesisCount)
      childNode = RapunzelNode(kind: rapunzelNone)
      openingParenthesisCount -= 1
    elif rawRapunzelChar == '}':
      result = result.updateChildNode(childNode, openingParenthesisCount)
      childNode = RapunzelNode(kind: rapunzelNone)
      openingParenthesisCount -= 1
      if rawRapunzel.high >= index + 2:
        if rawRapunzel[index+2] == '{':
          result.children.add RapunzelNode(kind: rapunzelBlock)
        else:
          result.children.add RapunzelNode(kind: rapunzelParagraph)
      skipCount = 1 # ここで親ノードを追加しているから \n で重複する
    elif rawRapunzelChar == '\n':
      if result.children[result.children.high].kind == rapunzelBlock:
        continue # ブロック内の場合、改行を無視
      if (childNode.kind == rapunzelText) and (childNode.value != ""):
        result = result.updateChildNode(childNode, openingParenthesisCount)
        childNode = RapunzelNode(kind: rapunzelNone)
      if rawRapunzel.high >= index + 2:
        if rawRapunzel[index+1] == '{':
          result.children.add RapunzelNode(kind: rapunzelBlock)
        else:
          result.children.add RapunzelNode(kind: rapunzelParagraph)
    else:
      if rawRapunzelChar == '\t':
        continue
      if childNode.kind == rapunzelNone:
        childNode = RapunzelNode(kind: rapunzelText)
      childNode.value.add rawRapunzelChar
  if (childNode.kind == rapunzelText) and (childNode.value != ""):
    result.children[result.children.high].children.add childNode

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
