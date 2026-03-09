import tables

type
  DebugEntry* = object
    kind*: string
    reason*: string
    line*: int
    col*: int
    text*: string
    context*: string

  TokenKind* = enum
    tkIdentifier,
    tkNumber,
    tkString,
    tkSymbol,
    tkWhitespace,
    tkNewline,
    tkPreprocessor

  Token* = object
    kind*: TokenKind
    text*: string
    line*: int
    col*: int

  ParserError* = object
    message*: string
    line*: int
    col*: int

  WrapperConfig* = object
    emitTemplates*: bool
    emitComments*: bool
    emitIncludeImports*: bool
    outputModuleStem*: string

  ParserState* = object
    tokens*: seq[Token]
    pos*: int
    output*: seq[string]
    errors*: seq[ParserError]
    config*: WrapperConfig
    debugEntries*: seq[DebugEntry]
    usedNames*: Table[string, int]
    nameMap*: Table[string, string]
    referencedCustomTypes*: Table[string, bool]
    inExternBlock*: bool

  ParserProc* = proc (s: var ParserState): bool
