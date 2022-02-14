import std/[json, strformat, strutils, tables]
import node, types, utils
from color import colorJson, colorJsonKey

type
  RapunzelStream = object
    index: int
    str: string
    openingParenthesisCount: int # 閉じられていない '[', '{' の個数
    node: RapunzelNode

func initRapunzelStream (str: string): RapunzelStream =
  result = RapunzelStream(
    index: 0,
    str: str,
    openingParenthesisCount: 0,
    node: RapunzelNode(kind: rapunzelDocument)
  )

proc updateChildNode (stream: var RapunzelStream, child: RapunzelNode) =
  if child.kind == rapunzelNone:
    return
  if child.kind == rapunzelText and child.value == "": # 空のテキストノードを追加しない
    return
  var nodeSeqByDepth = @[new RapunzelNode]
  nodeSeqByDepth[0][] = stream.node
  # openingParenthesisCountが0の時、テキストノードを扱っている
  # ネスト数は閉じられていない左括弧より、1少なくなる
  var nestCount = max(stream.openingParenthesisCount-1, 0)
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
  stream.node = nodeSeqByDepth[0][]

func inlineCommandName (stream: RapunzelStream): string =
  for ch in stream.str[stream.index+1..^1]:
    if ch == ' ': return
    result.add ch

func blockCommandName (stream: RapunzelStream): string =
  for ch in stream.str[stream.index+1..^1]:
    if ch == ' ' or ch == '\n': return
    result.add ch

func isUnderAnalysis (stream: RapunzelStream): bool =
  result = stream.index < stream.str.len

proc next (stream: var RapunzelStream) =
  stream.index += 1

proc skip (stream: var RapunzelStream, charCount: int) =
  stream.index += charCount

func char (stream: RapunzelStream): char =
  result = stream.str[stream.index]

func char (stream: RapunzelStream, index: int): char =
  result = stream.str[stream.index + index]

proc genRapunzelColor (commandName: string): RapunzelNode =
  let
    color = commandName[1..^1]
    colorCode = if color in colorJsonKey:
      colorJson[color].getStr
    elif color.isHexadecimal: commandName
    else: raise newException(UndefinedColorDefect, &"{color} is undefined color or incorrect color code")
  result = RapunzelNode(kind: rapunzelColor, colorCode: colorCode)

proc genRapunzelHeader (commandName: string): RapunzelNode =
  if commandName != "" and commandName.allCharsInSet({'*'}):
    if commandName.len <= 6:
      result = RapunzelNode(kind: rapunzelHeader, headerRank: commandName.len.uint8)
    else:
      raise newException(
        UndefinedHeaderRankDefect,
        &"Only up to 6 header ranks are supported. {commandName.len} is undefined."
      )
  else:
    raise newException(UndefinedCommandDefect, &"{commandName} is undefined command.")

proc parseLeftBracket (stream: var RapunzelStream): RapunzelNode =
  stream.openingParenthesisCount += 1
  let
    commandName = stream.inlineCommandName
    nextCharacter = stream.char(+1)
  result = case nextCharacter:
    of '*': RapunzelNode(kind: rapunzelBold)
    of '/': RapunzelNode(kind: rapunzelItalic)
    of '_': RapunzelNode(kind: rapunzelUnderline)
    of '~': RapunzelNode(kind: rapunzelStrike)
    of '=': RapunzelNode(kind: rapunzelExpand)
    of '#': genRapunzelColor(commandName)
    else:
      raise newException(UndefinedCommandDefect, &"{commandName} is undefined command.")
  stream.skip(commandName.len + 1)

proc parseLeftCurlyBracket (stream: var RapunzelStream): RapunzelNode =
  stream.openingParenthesisCount += 1
  let
    commandName = stream.blockCommandName
    nextCharacter = stream.char(+1)
  result = case nextCharacter:
    of '%': RapunzelNode(kind: rapunzelVariable)
    of '=': RapunzelNode(kind: rapunzelExpand)
    of '*': genRapunzelHeader(commandName)
    else:
      raise newException(UndefinedCommandDefect, &"{commandName} is undefined command.")
  stream.skip(commandName.len + 1)

proc parseRightBracket (stream: var RapunzelStream): RapunzelNode =
  stream.openingParenthesisCount -= 1
  result = RapunzelNode(kind: rapunzelNone)

proc addBlockOrParagraph (stream: var RapunzelStream, index: int) =
  if stream.char(index) == '{':
    stream.node.children.add RapunzelNode(kind: rapunzelBlock)
  else:
    stream.node.children.add RapunzelNode(kind: rapunzelParagraph)

proc parseRightCurlyBracket (stream: var RapunzelStream): RapunzelNode =
  stream.openingParenthesisCount -= 1
  result = RapunzelNode(kind: rapunzelNone)
  if stream.str.high >= stream.index + 2:
    stream.addBlockOrParagraph(+2)
  stream.next() # ノード追加が　\n と重複するから, }直後が `\n`　であるかどうかも調べる

proc rapunzelParse* (str: string): RapunzelNode =
  var
    stream = initRapunzelStream(str)
    childNode = RapunzelNode(kind: rapunzelNone)
  stream.addBlockOrParagraph(0)
  while stream.isUnderAnalysis:
    case stream.char:
    of '[', ']', '{', '}': stream.updateChildNode(childNode)
    else: discard

    case stream.char:
    of '[':
      childNode = stream.parseLeftBracket()
    of '{':
      childNode = stream.parseLeftCurlyBracket()
    of ']':
      childNode = stream.parseRightBracket()
    of '}':
      childNode = stream.parseRightCurlyBracket()
    of '\n':
      if stream.node.children[stream.node.children.high].kind == rapunzelBlock:
        stream.next()
        continue # ブロック内の場合、改行を無視
      if (childNode.kind == rapunzelText) and (childNode.value != ""):
        stream.updateChildNode(childNode)
        childNode = RapunzelNode(kind: rapunzelNone)
      if stream.str.high >= stream.index + 2:
        stream.addBlockOrParagraph(+2)
    of '\t': discard

    else:
      if childNode.kind == rapunzelNone:
        childNode = RapunzelNode(kind: rapunzelText)
      childNode.value.add stream.char
    
    stream.next()

  if (childNode.kind == rapunzelText) and (childNode.value != ""):
    stream.node.children[stream.node.children.high].children.add childNode
  
  result = stream.node


proc readFileToEOF (path: string): string =
  block:
    var file = open(path, FileMode.fmRead)
    defer:
      file.close()
    while not file.endOfFile:
      result &= file.readLine()

proc parseRapunzelFile* (path: string): RapunzelNode =
  let rapunzel = readFileToEOF(path)
  result = rapunzel.rapunzelParse
