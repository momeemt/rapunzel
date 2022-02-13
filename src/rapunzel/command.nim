import node

type
  RapunzelCommandKind = enum
    InlineCommand, BlockCommand
  
  RapunzelCommand = object
    name: string
    kind: RapunzelCommandKind
    command: string
    parseProc: proc (command: string): RapunzelNode
    generateProc: proc (node: RapunzelNode): string

proc initInlineCommand* (
  name: string,
  command: string,
  parseProc: proc (command: string): RapunzelNode,
  generateProc: proc (node: RapunzelNode): string
): RapunzelCommand =
  result = RapunzelCommand(name: name, kind: InlineCommand, command: command, parseProc: parseProc, generateProc: generateProc)

proc initBlockCommand* (
  name: string,
  command: string,
  parseProc: proc (command: string): RapunzelNode,
  generateProc: proc (node: RapunzelNode): string
): RapunzelCommand =
  result = RapunzelCommand(name: name, kind: BlockCommand, command: command, parseProc: parseProc, generateProc: generateProc)
