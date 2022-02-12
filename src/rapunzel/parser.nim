import std/[json, strformat, tables]
import node, types

let colorJson = parseFile("assets/colorPalette.json").getFields
var colorJsonKey: seq[string]
for key in colorJson.keys: colorJsonKey.add key

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
          colorJson[color].getStr
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