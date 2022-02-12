import strutils, tables, strformat, times, json, parsexml, streams

type
  RapunzelNodeKind = enum
    rapunzelDocument, rapunzelParagraph, rapunzelBlock, rapunzelText,
    rapunzelBold, rapunzelItalic, rapunzelUnderline, rapunzelStrike,
    rapunzelColor, rapunzelHeader,
    rapunzelVariable, rapunzelExpand

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

proc isHexadecimal (maybeHex: string): bool =
  result = true
  for character in maybeHex:
    if character notin {'0'..'9', 'a'..'f', 'A'..'F'}:
      return false

proc formatHtml* (rawHtml: string): string =
  var xmlParser: XmlParser
  var stream = newStringStream(rawHtml)
  open(xmlParser, stream, "header.html")
  result = ""
  var justBefore: XmlEventKind
  var indent = 0
  while true:
    xmlParser.next()
    case xmlParser.kind
    of xmlElementStart:
      if justBefore == xmlElementStart:
        result &= '\n'
      for _ in countdown(indent, 1):
        result &= "  "
      result &= &"<{xmlParser.elementName}>"
      indent += 1
    of xmlCharData:
      result &= xmlParser.charData
    of xmlElementEnd:
      indent -= 1
      if justBefore != xmlCharData:
        for _ in countdown(indent, 1):
          result &= "  "
      result &= &"</{xmlParser.elementName}>\n"
    of xmlEof: break
    else: discard
    justBefore = xmlParser.kind
  xmlParser.close()
  result = result[0..result.high-1]

func updateChildNode (src, child: RapunzelNode, openingParenthesisCount: int): RapunzelNode =
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
  var childNode = RapunzelNode(kind: rapunzelText)
  var skipCount = 0
  var openingParenthesisCount = 0 # 閉じられていない '[', '{' の個数
  for index in 0..rawRapunzel.high:
    if skipCount > 0:
      skipCount -= 1
      continue
    let rawRapunzelChar = rawRapunzel[index]
    if rawRapunzelChar == '[':
      result = result.updateChildNode(childNode, openingParenthesisCount)
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
      
    elif rawRapunzelChar == ']' or rawRapunzelChar == '}':
      result = result.updateChildNode(childNode, openingParenthesisCount)
      openingParenthesisCount -= 1
      childNode = RapunzelNode(kind: rapunzelText)
    elif rawRapunzelChar == '\n':
      if childNode.kind != rapunzelText:
        continue

      result = result.updateChildNode(childNode, openingParenthesisCount)
      if rawRapunzel.high >= index + 2:
        if rawRapunzel[index+1] == '{':
          result.children.add RapunzelNode(kind: rapunzelBlock)
        else:
          result.children.add RapunzelNode(kind: rapunzelParagraph)
    else:
      childNode.value.add rawRapunzelChar
  if childNode.value != "":
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

proc childrenValue (ast: RapunzelNode): string =
  for child in ast.children:
    result &= child.astToHtml()
