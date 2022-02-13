import ../node, ../command

proc boldParser (command: string): RapunzelNode =
  result = RapunzelNode(kind: rapunzelBold)

proc boldGenerator (node: RapunzelNode): string =
  discard

let boldCommand* = initInlineCommand("bold", "*", boldParser, boldGenerator)
