# This module parses the following C forms:
# #ifdef FOO
# #ifndef BAR
# #if EXPRESSION
# #pragma ...
# #error ...
# It consumes non-define and non-include directives and records them
# for debug output <- handled by tryParsePreprocessorDirective().
import src/c_nim_wrapper_bindr/level1/debugger
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils

proc tryParsePreprocessorDirective*(s: var ParserState): bool =
  ## s: parser state
  ## Consumes non-define and non-include preprocessor directives as comments.
  var
    mark: int = s.pos
    hashTok: Token
    tok: Token
    bodyTokens: seq[Token] = @[]
    bodyText: string = ""
  discard skipNewlines(s)
  if not matchText(s, "#"):
    s.pos = mark
    result = false
    return
  hashTok = s.tokens[s.pos - 1]
  tok = peekToken(s)
  if tok.text == "define" or tok.text == "include":
    s.pos = mark
    result = false
    return
  bodyTokens = collectUntilNewline(s)
  bodyText = tokensToText(bodyTokens)
  recordDebug(s, "skipped", "preprocessor", hashTok, "#" & " " & bodyText)
  result = true
