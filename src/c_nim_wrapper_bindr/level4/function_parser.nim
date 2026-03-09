# This module parses the following C forms:
# return_type func_name(param_type param, ...);
# It splits the prototype into:
# - prototype shape detection without a body <- handled by looksLikeFunctionPrototype()
# - function name before "(" <- handled by findFunctionName()
# - parameter groups between parentheses <- handled by collectParamInfos()
# - per-parameter name/type mapping <- handled by paramInfoFromTokens(), paramTypeFromTokens()
# It emits a Nim `proc` stub with importc pragmas <- handled by tryParseFunction().
import strutils
import src/c_nim_wrapper_bindr/name_mangle
import src/c_nim_wrapper_bindr/level2/name_registry
import src/c_nim_wrapper_bindr/level3/type_mapper
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils

type ParamInfo* = object
  name*: string
  nimType*: string

proc sanitizeParamName*(a: string, b: int): string =
  ## a: original name
  ## b: parameter index
  ## Returns a Nim-safe parameter name, prefixing or using a fallback index.
  var
    name: string = stripEdgeUnderscores(a)
  if name.len == 0:
    result = "p" & $b
    return
  if isNimKeyword(name) or not isValidIdent(name):
    result = "p_" & name
  else:
    result = name

proc formatProcImportc*(a: string, b: string): string =
  ## a: Nim name
  ## b: original C name
  ## Returns a Nim importc pragma for a proc, using a name override when needed.
  if a == b:
    result = "{.importc.}"
  else:
    result = "{.importc: \"" & b & "\".}"

proc looksLikeFunctionPrototype*(s: ParserState): bool =
  ## s: parser state
  ## Checks for a function prototype shape: parens and semicolon without a body.
  var
    i: int = s.pos
    l: int = s.tokens.len
    tok: Token
    seenParen: bool = false
    seenClose: bool = false
    seenSemicolon: bool = false
    seenBrace: bool = false
  while i < l:
    tok = s.tokens[i]
    if tok.text == "{":
      seenBrace = true
      break
    if tok.text == "(":
      seenParen = true
    if tok.text == ")":
      if seenParen:
        seenClose = true
    if tok.text == ";":
      seenSemicolon = true
      break
    inc i
  result = seenParen and seenClose and seenSemicolon and not seenBrace

proc findFunctionName*(s: ParserState): string =
  ## s: parser state
  ## Finds the identifier immediately before the opening parenthesis.
  var
    i: int = s.pos
    l: int = s.tokens.len
    tok: Token
    lastIdent: string = ""
  while i < l:
    tok = s.tokens[i]
    if tok.text == "(":
      break
    if tok.kind == tkIdentifier:
      lastIdent = tok.text
    inc i
  result = lastIdent

proc findFunctionPointerParamName*(a: seq[Token]): string =
  ## a: parameter tokens
  ## Returns the identifier from a function pointer parameter when present.
  var
    i: int = 0
    l: int = a.len
  while i + 3 < l:
    if a[i].text == "(" and a[i + 1].text == "*" and a[i + 2].kind == tkIdentifier and
      a[i + 3].text == ")":
      result = a[i + 2].text
      return
    inc i
  result = ""

proc skipBalancedParenGroup*(a: seq[Token], b: int): int =
  ## a: token list
  ## b: index at opening "("
  ## Returns index immediately after the balanced parenthesis group.
  var
    i: int = b
    l: int = a.len
    depth: int = 0
    tok: Token
  if i < 0 or i >= l or a[i].text != "(":
    result = b
    return
  while i < l:
    tok = a[i]
    if tok.text == "(":
      inc depth
    elif tok.text == ")":
      dec depth
      if depth == 0:
        result = i + 1
        return
    inc i
  result = l

proc findFunctionNameInfo*(s: ParserState): tuple[name: string, nameIdx: int, openParenIdx: int] =
  ## s: parser state
  ## Finds the function name and indexes around the opening parenthesis.
  var
    i: int = s.pos
    l: int = s.tokens.len
    tok: Token
    nextTok: Token
  while i < l:
    tok = s.tokens[i]
    if tok.text == ";" or tok.text == "{":
      break
    if tok.kind == tkIdentifier and i + 1 < l:
      nextTok = s.tokens[i + 1]
      if nextTok.text == "(":
        if isIgnoredWord(tok.text):
          i = skipBalancedParenGroup(s.tokens, i + 1)
          continue
        result = (tok.text, i, i + 1)
        return
    inc i
  result = ("", -1, -1)

proc collectReturnTypeTokens*(s: ParserState, a: int): seq[Token] =
  ## s: parser state
  ## a: index of function identifier
  ## Collects tokens before the function name as return type tokens.
  var
    items: seq[Token] = @[]
    i: int = s.pos
    l: int = s.tokens.len
  if a <= s.pos:
    result = @[]
    return
  while i < a and i < l:
    items.add s.tokens[i]
    inc i
  result = items

proc hasInvalidReturnTypeContext*(a: seq[Token]): bool =
  ## a: return-type side tokens before function name
  ## Returns true when tokens look like an expression statement, not a C return type.
  var
    i: int = 0
    l: int = a.len
    tok: Token
    word: string = ""
  while i < l:
    tok = a[i]
    if tok.kind == tkNumber or tok.kind == tkString:
      result = true
      return
    if tok.kind == tkIdentifier:
      word = toLowerAscii(tok.text)
      if word == "return" or word == "if" or word == "while" or word == "for" or
          word == "switch":
        result = true
        return
    case tok.text
    of "=", "?", ":", "{", "}", "||", "&&":
      result = true
      return
    else:
      discard
    inc i
  result = false

proc hasReturnTypeIdentifier*(a: seq[Token]): bool =
  ## a: return-type side tokens before function name
  ## Returns true when there is at least one identifier-like type token.
  var
    i: int = 0
    l: int = a.len
    tok: Token
    word: string = ""
  while i < l:
    tok = a[i]
    if tok.kind == tkIdentifier:
      word = toLowerAscii(tok.text)
      if word != "return":
        result = true
        return
    inc i
  result = false

proc paramNameFromTokens*(a: seq[Token]): string =
  ## a: parameter tokens
  ## Returns the last identifier, skipping "void" only signatures.
  var
    i: int = 0
    l: int = a.len
    tok: Token
    name: string = ""
    funcPtrName: string = findFunctionPointerParamName(a)
  if funcPtrName.len > 0:
    result = funcPtrName
    return
  while i < l:
    tok = a[i]
    if tok.kind == tkIdentifier and not isBuiltinWord(tok.text) and not isIgnoredWord(tok.text):
      name = tok.text
    inc i
  if name.len == 0 and l == 1 and toLowerAscii(a[0].text) == "void":
    result = ""
  else:
    result = name

proc paramTypeFromTokens*(s: var ParserState, a: seq[Token], b: string): string =
  ## s: parser state
  ## a: parameter tokens
  ## b: parameter name to skip
  ## Returns the Nim type for the parameter.
  result = mapTokensToNimType(s, a, b)

proc paramInfoFromTokens*(s: var ParserState, a: seq[Token]): ParamInfo =
  ## s: parser state
  ## a: parameter tokens
  ## Builds a ParamInfo with a name and Nim type.
  var
    info: ParamInfo
  info.name = paramNameFromTokens(a)
  info.nimType = paramTypeFromTokens(s, a, info.name)
  result = info

proc collectParamInfos*(s: var ParserState, b: int = -1): seq[ParamInfo] =
  ## s: parser state
  ## b: optional index of the function parameter list opening parenthesis
  ## Collects parameter infos between parentheses.
  ## Example: `int foo(int a, size_t n)` yields `@["a: pointer", "n: csize_t"]`.
  var
    i: int = s.pos
    l: int = s.tokens.len
    tok: Token
    params: seq[ParamInfo] = @[]
    current: seq[Token] = @[]
    info: ParamInfo
    parenDepth: int = 0
    inParamList: bool = false
  if b >= 0 and b < l:
    i = b
  while i < l:
    tok = s.tokens[i]
    if not inParamList:
      if tok.text == "(":
        inParamList = true
        parenDepth = 1
      inc i
      continue
    if tok.text == "(":
      inc parenDepth
      current.add tok
      inc i
      continue
    if tok.text == ")":
      if parenDepth > 1:
        current.add tok
        dec parenDepth
        inc i
        continue
      if current.len > 0:
        info = paramInfoFromTokens(s, current)
        if not (info.name.len == 0 and info.nimType == "void"):
          params.add info
      break
    if tok.text == "," and parenDepth == 1:
      info = paramInfoFromTokens(s, current)
      if not (info.name.len == 0 and info.nimType == "void"):
        params.add info
      current = @[]
      inc i
      continue
    current.add tok
    inc i
  result = params

proc formatProcParams*(a: seq[ParamInfo]): string =
  ## a: parameter infos
  ## Maps parameter infos to a Nim proc signature stub.
  ## Example: `@["a: pointer", "n: csize_t"]` yields `"a: pointer, n: csize_t"`.
  var
    parts: seq[string] = @[]
    l: int = a.len
    name: string = ""
  for i in 0 ..< l:
    name = sanitizeParamName(a[i].name, i)
    if name.len > 0:
      parts.add name & ": " & a[i].nimType
  result = parts.join(", ")

proc tryParseFunction*(s: var ParserState): bool =
  ## s: parser state
  ## Parses a C function prototype and emits an importc Nim proc.
  ## Example: `int foo(void);` becomes `proc foo*(): cint {.importc.}`.
  var
    mark: int = s.pos
    name: string = ""
    origName: string = ""
    nameIdx: int = -1
    openParenIdx: int = -1
    returnTypeTokens: seq[Token] = @[]
    returnType: string = ""
    params: seq[ParamInfo] = @[]
    paramsText: string = ""
    pragmaText: string = ""
    tok: Token
    parenDepth: int = 0
    info: tuple[name: string, nameIdx: int, openParenIdx: int]
  discard skipNewlines(s)
  tok = peekToken(s)
  if tok.text == "typedef":
    s.pos = mark
    result = false
    return
  if not looksLikeFunctionPrototype(s):
    s.pos = mark
    result = false
    return
  info = findFunctionNameInfo(s)
  origName = info.name
  nameIdx = info.nameIdx
  openParenIdx = info.openParenIdx
  if origName.len == 0 or nameIdx < 0 or openParenIdx <= 0:
    s.pos = mark
    result = false
    return
  if isBuiltinWord(origName) or isIgnoredWord(origName):
    s.pos = mark
    result = false
    return
  if s.tokens[openParenIdx - 1].kind != tkIdentifier or s.tokens[openParenIdx - 1].text != origName:
    s.pos = mark
    result = false
    return
  returnTypeTokens = collectReturnTypeTokens(s, nameIdx)
  if returnTypeTokens.len == 0:
    s.pos = mark
    result = false
    return
  if hasInvalidReturnTypeContext(returnTypeTokens):
    s.pos = mark
    result = false
    return
  if not hasReturnTypeIdentifier(returnTypeTokens):
    s.pos = mark
    result = false
    return
  name = sanitizeIdent(origName, "c_")
  name = registerName(s, name, origName, "proc")
  returnType = mapTokensToNimType(s, returnTypeTokens, "")
  if returnType.len == 0:
    returnType = "cint"
  params = collectParamInfos(s, openParenIdx)
  paramsText = formatProcParams(params)
  pragmaText = formatProcImportc(name, origName)
  while not isAtEnd(s):
    tok = advanceToken(s)
    if tok.text == "(":
      inc parenDepth
    elif tok.text == ")":
      if parenDepth > 0:
        dec parenDepth
    elif tok.text == ";" and parenDepth == 0:
      break
  if paramsText.len == 0:
    if returnType == "void":
      emitLine(s, "proc " & name & "*() " & pragmaText)
    else:
      emitLine(s, "proc " & name & "*(): " & returnType & " " & pragmaText)
  else:
    if returnType == "void":
      emitLine(s, "proc " & name & "*(" & paramsText & ") " & pragmaText)
    else:
      emitLine(s, "proc " & name & "*(" & paramsText & "): " & returnType & " " & pragmaText)
  result = true
