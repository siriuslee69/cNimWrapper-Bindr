import strutils
import tables
import src/c_nim_wrapper_bindr/types

proc initState*(a: seq[Token], b: WrapperConfig): ParserState =
  ## a: token stream
  ## b: wrapper config
  ## Builds a parser state with position 0 and empty output/error buffers.
  var
    state: ParserState = ParserState(tokens: a, pos: 0, output: @[], errors: @[],
      config: b, debugEntries: @[], usedNames: initTable[string, int](),
      nameMap: initTable[string, string](),
      referencedCustomTypes: initTable[string, bool](), inExternBlock: false)
  result = state

proc isAtEnd*(s: ParserState): bool =
  ## s: parser state
  ## Checks whether the cursor has reached or passed the end of the token list.
  var
    l: int = s.tokens.len
  result = s.pos >= l

proc peekToken*(s: ParserState, b: int = 0): Token =
  ## s: parser state
  ## b: offset from current position
  ## Returns the token at current position plus offset, or an empty token when out of range.
  ## Example: `peekToken(s, 1)` looks one token ahead.
  var
    idx: int = s.pos + b
    l: int = s.tokens.len
    tok: Token = Token(kind: tkSymbol, text: "", line: 0, col: 0)
  if idx < 0 or idx >= l:
    result = tok
  else:
    result = s.tokens[idx]

proc advanceToken*(s: var ParserState): Token =
  ## s: parser state
  ## Defaults to an empty token if at the end, otherwise advances and returns current token.
  ## Example: `discard advanceToken(s)` consumes one token.
  var
    l: int = s.tokens.len
    tok: Token = Token(kind: tkSymbol, text: "", line: 0, col: 0)
  if s.pos >= l:
    result = tok
  else:
    tok = s.tokens[s.pos]
    inc s.pos
    result = tok

proc matchText*(s: var ParserState, b: string): bool =
  ## s: parser state
  ## b: token text to match
  ## Consumes and returns true when the current token text matches.
  ## Example: `if matchText(s, "("): ...`.
  var
    tok: Token = peekToken(s)
  if tok.text == b:
    discard advanceToken(s)
    result = true
  else:
    result = false

proc matchKind*(s: var ParserState, b: TokenKind): bool =
  ## s: parser state
  ## b: token kind to match
  ## Consumes and returns true when the current token kind matches.
  ## Example: `if matchKind(s, tkIdentifier): ...`.
  var
    tok: Token = peekToken(s)
  if tok.kind == b:
    discard advanceToken(s)
    result = true
  else:
    result = false

proc skipNewlines*(s: var ParserState): int =
  ## s: parser state
  ## Consumes consecutive newline tokens and returns the count skipped.
  var
    count: int = 0
    tok: Token = peekToken(s)
  while tok.kind == tkNewline:
    discard advanceToken(s)
    inc count
    tok = peekToken(s)
  result = count

proc skipWhitespace*(s: var ParserState): int =
  ## s: parser state
  ## Consumes consecutive whitespace tokens and returns the count skipped.
  var
    count: int = 0
    tok: Token = peekToken(s)
  while tok.kind == tkWhitespace:
    discard advanceToken(s)
    inc count
    tok = peekToken(s)
  result = count

proc emitLine*(s: var ParserState, b: string) =
  ## s: parser state
  ## b: output line
  ## Appends a line to the output buffer.
  s.output.add b

proc addError*(s: var ParserState, b: string, c: Token) =
  ## s: parser state
  ## b: error message
  ## c: token where the error occurred
  ## Records a parser error with line and column from the token.
  var
    err: ParserError = ParserError(message: b, line: c.line, col: c.col)
  s.errors.add err

proc collectUntilNewline*(s: var ParserState): seq[Token] =
  ## s: parser state
  ## Collects tokens until a newline, consuming the newline if present.
  ## Example: used for single-line directives like `#define`.
  var
    items: seq[Token] = @[]
    tok: Token = peekToken(s)
  while not isAtEnd(s) and tok.kind != tkNewline:
    items.add advanceToken(s)
    tok = peekToken(s)
  if tok.kind == tkNewline:
    discard advanceToken(s)
  result = items

proc collectUntilText*(s: var ParserState, b: string, c: bool): seq[Token] =
  ## s: parser state
  ## b: token text to stop on
  ## c: consume stop token when true
  ## Collects tokens up to a matching text token, optionally consuming that token.
  ## Example: `collectUntilText(s, ";", true)` reads a C statement.
  var
    items: seq[Token] = @[]
    tok: Token = peekToken(s)
  while not isAtEnd(s) and tok.text != b:
    items.add advanceToken(s)
    tok = peekToken(s)
  if tok.text == b and c:
    discard advanceToken(s)
  result = items

proc tokensToText*(a: seq[Token]): string =
  ## a: token list
  ## Joins tokens into a space-separated string, skipping newlines.
  ## Example: `tokensToText(tokens)` returns a C-like line.
  var
    parts: seq[string] = @[]
    l: int = a.len
  for i in 0 ..< l:
    if a[i].kind != tkNewline:
      parts.add a[i].text
  result = parts.join(" ")
