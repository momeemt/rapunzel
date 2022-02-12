import std/strformat

type
  RapunzelNodeKind = enum
    rapunzelDocument, rapunzelParagraph, rapunzelBlock, rapunzelText,
    rapunzelBold, rapunzelItalic, rapunzelUnderline, rapunzelStrike,
    rapunzelColor, rapunzelHeader,
    rapunzelVariable, rapunzelExpand,
    rapunzelNone

  RapunzelNode = object
    case kind: RapunzelNodeKind
    of rapunzelColor:
      colorCode: string
    of rapunzelHeader:
      headerRank: uint8
    else: discard
    value: string
    children: seq[RapunzelNode]

proc rapunzelNodeRepr (ast: RapunzelNode, nest: int): string
proc rapunzelChildrenNodeRepr (ast: RapunzelNode, nest: int): string
  
proc `$`* (ast: RapunzelNode): string =
  result = ast.rapunzelNodeRepr(0)

proc kindAndValue (ast: RapunzelNode): string =
  if ast.value.len > 0:
      result &= &"{$ast.kind} (value = {ast.value})\n"
  else:
    result &= &"{$ast.kind}\n"

proc addIndent (ast: RapunzelNode, nest: int): string =
  for index in 0..<nest:
    result &= "  "
  result &= ast.kindAndValue

proc rapunzelChildrenNodeRepr (ast: RapunzelNode, nest: int): string =
  result = ast.addIndent(nest)
  for child in ast.children:
    result &= child.rapunzelNodeRepr(nest + 1)
  
proc rapunzelNodeRepr (ast: RapunzelNode, nest: int): string =
  if ast.children.len > 0:
    result = ast.rapunzelChildrenNodeRepr(nest)
  else:
    result = ast.addIndent(nest)
