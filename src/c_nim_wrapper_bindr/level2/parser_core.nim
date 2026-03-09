# This module drives parsing over the token stream.
# It runs registered parsers for constructs like #define, enum, struct, typedef,
# and function prototypes <- handled by parseAll().
# When no parser matches, it emits "# unparsed: ..." and records debug info
# <- handled by parseAll().
import src/c_nim_wrapper_bindr/level1/debugger
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils
import tables
import algorithm
import strutils

type ParserRegistry* = object
  parsers*: seq[ParserProc]

proc initRegistry*(): ParserRegistry =
  ## returns an empty parser registry
  ## Initializes a registry with no parsers registered.
  var
    reg: ParserRegistry = ParserRegistry(parsers: @[])
  result = reg

proc addParser*(a: var ParserRegistry, b: ParserProc) =
  ## a: parser registry
  ## b: parser function
  ## Adds a parser to the registry in execution order.
  a.parsers.add b

proc extractDeclaredTypeName*(a: string): string =
  ## a: generated output line
  ## Returns declared Nim type name for lines beginning with `type `.
  var
    line: string = a.strip()
    i: int = 5
    l: int = line.len
    name: string = ""
    ch: char
  if not line.startsWith("type "):
    result = ""
    return
  while i < l:
    ch = line[i]
    if (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or
        (ch >= '0' and ch <= '9') or ch == '_':
      name.add ch
      inc i
      continue
    break
  result = name

proc emitTypeFallbackAliases*(s: var ParserState) =
  ## s: parser state
  ## Emits graceful fallback aliases for unresolved custom type references.
  var
    names: seq[string] = @[]
    declared: Table[string, bool] = initTable[string, bool]()
    merged: seq[string] = @[]
    i: int = 0
    l: int = 0
    name: string = ""
    declaredName: string = ""
  l = s.output.len
  while i < l:
    declaredName = extractDeclaredTypeName(s.output[i])
    if declaredName.len > 0:
      declared[declaredName] = true
    inc i
  i = 0
  for key in s.referencedCustomTypes.keys:
    if not declared.hasKey(key):
      names.add key
  if names.len == 0:
    return
  sort(names)
  merged.add "## fallback aliases for unresolved custom C type names"
  l = names.len
  while i < l:
    name = names[i]
    merged.add "when not declared(" & name & "):"
    merged.add "  type " & name & "* = pointer"
    inc i
  merged.add ""
  l = s.output.len
  i = 0
  while i < l:
    merged.add s.output[i]
    inc i
  s.output = merged

proc parseAll*(s: var ParserState, b: ParserRegistry) =
  ## s: parser state
  ## b: parser registry
  ## Runs all registered parsers over the token stream.
  ## When no parser matches, emits a fallback "# unparsed:" line.
  var
    matched: bool = false
    i: int = 0
    l: int = b.parsers.len
    tok: Token
  if l == 0:
    while not isAtEnd(s):
      tok = advanceToken(s)
      if tok.kind != tkNewline and tok.text.len > 0:
        emitLine(s, "# unparsed: " & tok.text)
    emitTypeFallbackAliases(s)
    return
  while not isAtEnd(s):
    discard skipNewlines(s)
    matched = false
    i = 0
    while i < l:
      if b.parsers[i](s):
        matched = true
        break
      inc i
    if not matched:
      tok = advanceToken(s)
      if tok.kind != tkNewline and tok.text.len > 0:
        emitLine(s, "# unparsed: " & tok.text)
        recordDebug(s, "unparsed", "no_parser", tok, tok.text)
  emitTypeFallbackAliases(s)
