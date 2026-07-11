# This module parses the following C forms:
# #define NAME value
# #define NAME(arg1, arg2) body
# It splits the directive into:
# - "#define" + macro name <- handled by tryParseDefine()
# - optional parameter list in "(...)" <- handled by formatTemplateParams()
# - macro body tokens, including "\" continuations <- handled by collectDefineBodyTokens()
# It emits:
# - `const NAME* = ...` for simple literals <- handled by isSimpleDefineBody(), replaceConstLine()
# - `template NAME*(...): untyped = discard` for macro bodies <- handled by emitDefineTemplate()
import strutils
import src/c_nim_wrapper_bindr/level1/cast_utils
import src/c_nim_wrapper_bindr/name_mangle
import src/c_nim_wrapper_bindr/level2/name_registry
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils

proc replaceConstLine*(s: var ParserState, b: string, c: string): bool =
  ## s: parser state
  ## b: const name
  ## c: new const line text
  ## Replaces the last emitted const with the same name and returns true when replaced.
  var
    i: int = s.output.len - 1
    needle: string = "const " & b & "*"
  if i < 0:
    result = false
    return
  while i >= 0:
    if s.output[i].startsWith(needle):
      s.output[i] = c
      result = true
      return
    dec i
  result = false

proc hasTemplateLine*(s: ParserState, b: string): bool =
  ## s: parser state
  ## b: template name
  ## Returns true when a template line for the name already exists.
  var
    i: int = s.output.len - 1
    needle: string = "template " & b & "*"
  if i < 0:
    result = false
    return
  while i >= 0:
    if s.output[i].startsWith(needle):
      result = true
      return
    dec i
  result = false

proc isAllCapsIdentifier*(a: string): bool =
  ## a: identifier text
  ## Returns true for macro-like uppercase identifiers.
  var
    i: int = 0
    l: int = a.len
    ch: char
    sawAlpha: bool = false
  if l == 0:
    result = false
    return
  while i < l:
    ch = a[i]
    if ch >= 'a' and ch <= 'z':
      result = false
      return
    if (ch >= 'A' and ch <= 'Z'):
      sawAlpha = true
    elif (ch >= '0' and ch <= '9') or ch == '_':
      discard
    else:
      result = false
      return
    inc i
  result = sawAlpha

proc isSimpleDefineBody*(a: seq[Token]): bool =
  ## a: define body tokens
  ## Returns true when the body can be safely emitted as a const expression.
  var
    i: int = 0
    l: int = a.len
    tok: Token
    sawAny: bool = false
  if l == 0:
    result = true
    return
  while i < l:
    tok = a[i]
    if tok.kind == tkNewline or tok.kind == tkWhitespace:
      inc i
      continue
    if tok.kind == tkNumber or tok.kind == tkString:
      sawAny = true
      inc i
      continue
    if tok.kind == tkIdentifier:
      result = false
      return
    if tok.kind == tkPreprocessor:
      result = false
      return
    case tok.text
    of "+", "-", "*", "/", "%", "(", ")":
      sawAny = true
    else:
      result = false
      return
    inc i
  result = sawAny

proc formatTemplateParams*(a: seq[string]): string =
  ## a: parameter names
  ## Formats names into a Nim template parameter list.
  ## Example: `@["x", "y"]` becomes `"x: untyped, y: untyped"`.
  var
    parts: seq[string] = @[]
    l: int = a.len
  for i in 0 ..< l:
    if a[i].len > 0:
      parts.add a[i] & ": untyped"
  result = parts.join(", ")

proc emitDefineTemplate*(s: var ParserState, b: string, c: seq[string], d: string,
    e: bool) =
  ## s: parser state
  ## b: template name
  ## c: template parameter names
  ## d: macro body text
  ## e: include parentheses when there are no parameters
  ## Emits a template stub for a macro definition.
  var
    paramsText: string = formatTemplateParams(c)
  if paramsText.len == 0:
    if e:
      emitLine(s, "template " & b & "*(): untyped =")
    else:
      emitLine(s, "template " & b & "*: untyped =")
  else:
    emitLine(s, "template " & b & "*(" & paramsText & "): untyped =")
  if s.config.emitComments and d.len > 0:
    emitLine(s, "  ## C macro: " & d)
  emitLine(s, "  discard")

proc collectDefineBodyTokens*(s: var ParserState): seq[Token] =
  ## s: parser state
  ## Collects macro body tokens across backslash-newline continuations.
  var
    items: seq[Token] = @[]
    tok: Token
    continueLine: bool = true
  while continueLine and not isAtEnd(s):
    continueLine = false
    tok = peekToken(s)
    while not isAtEnd(s) and tok.kind != tkNewline:
      items.add advanceToken(s)
      tok = peekToken(s)
    if tok.kind == tkNewline:
      discard advanceToken(s)
    if items.len > 0 and items[^1].text == "\\":
      discard items.pop()
      continueLine = true
  result = items

proc tryParseDefine*(s: var ParserState): bool =
  ## s: parser state
  ## Parses C #define directives into Nim consts or templates.
  ## Example: `#define FOO 1` becomes `const FOO* = 1`.
  var
    mark: int = s.pos
    nameTok: Token
    origName: string = ""
    name: string = ""
    bodyTokens: seq[Token] = @[]
    bodyText: string = ""
    constLine: string = ""
    params: seq[string] = @[]
    paramName: string = ""
    tok: Token
    isFunc: bool = false
  discard skipNewlines(s)
  if not matchText(s, "#"):
    s.pos = mark
    result = false
    return
  if not matchText(s, "define"):
    s.pos = mark
    result = false
    return
  if not matchKind(s, tkIdentifier):
    s.pos = mark
    result = false
    return
  nameTok = s.tokens[s.pos - 1]
  origName = nameTok.text
  name = sanitizeIdent(origName, "c_")
  tok = peekToken(s)
  if tok.text == "(" and tok.line == nameTok.line and tok.col == nameTok.col +
      origName.len and matchText(s, "("):
    isFunc = true
    while not isAtEnd(s):
      if matchText(s, ")"):
        break
      if matchKind(s, tkIdentifier):
        tok = s.tokens[s.pos - 1]
        paramName = sanitizeIdent(tok.text, "p_")
        params.add paramName
      else:
        discard advanceToken(s)
  bodyTokens = collectDefineBodyTokens(s)
  if not isFunc:
    bodyTokens = stripLeadingCastTokens(bodyTokens)
  bodyText = tokensToText(bodyTokens)
  if isFunc or not isSimpleDefineBody(bodyTokens):
    name = registerName(s, name, origName, "template")
    if hasTemplateLine(s, name):
      result = true
      return
    emitDefineTemplate(s, name, params, bodyText, isFunc)
  else:
    name = registerName(s, name, origName, "const")
    if bodyText.len == 0:
      bodyText = "0"
    constLine = "const " & name & "* = " & bodyText
    if not replaceConstLine(s, name, constLine):
      emitLine(s, constLine)
  result = true
