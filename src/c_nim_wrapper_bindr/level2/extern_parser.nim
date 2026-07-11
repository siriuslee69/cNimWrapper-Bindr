# This module parses the following C forms:
# extern "C" { ... }
# extern "C" ...
# It detects the linkage string <- handled by isExternCString()
# It tracks block entry <- handled by tryParseExternBlock()
# It consumes the closing brace <- handled by tryParseExternClose()
# The contents are skipped and recorded in debug output <- handled by tryParseExternBlock(),
# tryParseExternClose().
import strutils
import src/c_nim_wrapper_bindr/level1/debugger
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils

proc hasTokenText*(a: seq[Token], b: string): bool =
  ## a: token list
  ## b: token text to look for
  ## Returns true when any token matches the given text.
  var
    l: int = a.len
  for i in 0 ..< l:
    if a[i].text == b:
      result = true
      return
  result = false

proc isExternCString*(s: ParserState): bool =
  ## s: parser state
  ## Returns true when the next token is a C/C++ linkage string.
  var
    tok: Token = peekToken(s, 0)
  if tok.kind != tkString:
    result = false
    return
  if tok.text.contains("C"):
    result = true
  else:
    result = false

proc tryParseExternBlock*(s: var ParserState): bool =
  ## s: parser state
  ## Skips `extern "C"` linkage blocks and tracks their closing brace.
  var
    mark: int = s.pos
    externTok: Token
    bodyTokens: seq[Token] = @[]
    bodyText: string = ""
  discard skipNewlines(s)
  if not matchText(s, "extern"):
    s.pos = mark
    result = false
    return
  if not isExternCString(s):
    s.pos = mark
    result = false
    return
  externTok = s.tokens[s.pos - 1]
  bodyTokens = collectUntilNewline(s)
  bodyText = tokensToText(bodyTokens)
  if hasTokenText(bodyTokens, "{"):
    s.inExternBlock = true
  recordDebug(s, "skipped", "extern_block", externTok, "extern " & bodyText)
  result = true

proc tryParseExternClose*(s: var ParserState): bool =
  ## s: parser state
  ## Closes an active extern block when a closing brace is found.
  var
    tok: Token
  discard skipNewlines(s)
  if not s.inExternBlock:
    result = false
    return
  if not matchText(s, "}"):
    result = false
    return
  s.inExternBlock = false
  tok = s.tokens[s.pos - 1]
  recordDebug(s, "skipped", "extern_block_end", tok, "}")
  result = true
