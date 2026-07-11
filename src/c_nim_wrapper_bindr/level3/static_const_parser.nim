# This module parses the following C forms:
# static const TYPE NAME = VALUE;
# It splits the declaration into:
# - "static const" prefix <- handled by tryParseStaticConst()
# - name on the left of "=" <- handled by findLastIdentBefore()
# - value tokens on the right of "=" <- handled by findEqualsIndex()
# It emits `const NAME* = VALUE` when the initializer is simple <- handled by tryParseStaticConst().
import src/c_nim_wrapper_bindr/level1/cast_utils
import src/c_nim_wrapper_bindr/level1/debugger
import src/c_nim_wrapper_bindr/name_mangle
import src/c_nim_wrapper_bindr/level2/name_registry
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils

proc findEqualsIndex*(a: seq[Token]): int =
  ## a: token list
  ## Returns the index of "=" when present, otherwise -1.
  var
    l: int = a.len
  for i in 0 ..< l:
    if a[i].text == "=":
      result = i
      return
  result = -1

proc findLastIdentBefore*(a: seq[Token], b: int): string =
  ## a: token list
  ## b: exclusive upper bound index
  ## Returns the last identifier before the bound.
  var
    name: string = ""
  for i in 0 ..< b:
    if a[i].kind == tkIdentifier:
      name = a[i].text
  result = name

proc hasBraceTokens*(a: seq[Token]): bool =
  ## a: token list
  ## Returns true when initializer tokens include braces.
  var
    l: int = a.len
  for i in 0 ..< l:
    if a[i].text == "{" or a[i].text == "}":
      result = true
      return
  result = false

proc tryParseStaticConst*(s: var ParserState): bool =
  ## s: parser state
  ## Parses `static const` variable declarations into Nim consts.
  var
    mark: int = s.pos
    staticTok: Token
    tokens: seq[Token] = @[]
    eqIndex: int = -1
    origName: string = ""
    name: string = ""
    valueTokens: seq[Token] = @[]
    valueText: string = ""
    contextText: string = ""
  discard skipNewlines(s)
  if not matchText(s, "static"):
    s.pos = mark
    result = false
    return
  if not matchText(s, "const"):
    s.pos = mark
    result = false
    return
  staticTok = s.tokens[s.pos - 2]
  tokens = collectUntilText(s, ";", true)
  contextText = tokensToText(tokens)
  eqIndex = findEqualsIndex(tokens)
  if eqIndex < 0:
    recordDebug(s, "skipped", "static_const_missing_init", staticTok, contextText)
    result = true
    return
  origName = findLastIdentBefore(tokens, eqIndex)
  if origName.len == 0:
    recordDebug(s, "skipped", "static_const_missing_name", staticTok, contextText)
    result = true
    return
  valueTokens = tokens[eqIndex + 1 ..< tokens.len]
  if hasBraceTokens(valueTokens):
    recordDebug(s, "skipped", "static_const_braced_init", staticTok, contextText)
    result = true
    return
  valueTokens = stripLeadingCastTokens(valueTokens)
  valueText = tokensToText(valueTokens)
  if valueText.len == 0:
    recordDebug(s, "skipped", "static_const_empty_init", staticTok, contextText)
    result = true
    return
  name = sanitizeIdent(origName, "c_")
  name = registerName(s, name, origName, "const")
  emitLine(s, "const " & name & "* = " & valueText)
  result = true
