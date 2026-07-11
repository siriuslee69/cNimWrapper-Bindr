# This module parses the following C forms:
# enum Name { A, B, C = 3 };
# enum { A, B };
# It splits the enum into:
# - "enum" keyword + optional name <- handled by tryParseEnum()
# - members between braces, collecting identifiers only <- handled by tryParseEnum()
# It emits a Nim enum with importc pragmas and placeholder members when empty <- handled by tryParseEnum().
import src/c_nim_wrapper_bindr/name_mangle
import strutils
import tables
import src/c_nim_wrapper_bindr/level2/name_registry
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils

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

proc isSimpleEnumValueTokens*(a: seq[Token]): bool =
  ## a: enum value expression tokens
  ## Returns true when the value can be emitted as a Nim enum assignment.
  var
    i: int = 0
    l: int = a.len
    tok: Token
  if l == 0:
    result = false
    return
  while i < l:
    tok = a[i]
    if tok.kind == tkNewline or tok.kind == tkWhitespace:
      inc i
      continue
    if tok.kind == tkNumber:
      inc i
      continue
    if tok.kind == tkIdentifier:
      result = false
      return
    case tok.text
    of "+", "-", "*", "/", "%", "(", ")":
      discard
    else:
      result = false
      return
    inc i
  result = true

proc tryParseEnum*(s: var ParserState): bool =
  ## s: parser state
  ## Parses a C enum and emits a Nim enum type with placeholder members.
  var
    mark: int = s.pos
    enumName: string = "AnonymousEnum"
    enumNameOrig: string = "AnonymousEnum"
    namePragma: string = ""
    members: seq[tuple[name: string, valueText: string, valueSimple: bool]] = @[]
    seen: Table[string, bool] = initTable[string, bool]()
    currentName: string = ""
    currentValueTokens: seq[Token] = @[]
    expectingName: bool = true
    collectingValue: bool = false
    memberName: string = ""
    memberPragma: string = ""
    memberValueText: string = ""
    valueKey: string = ""
    hasDuplicateAssignedValue: bool = false
    hasAliasAssignedValue: bool = false
    seenValues: Table[string, bool] = initTable[string, bool]()
    seenMemberNames: Table[string, bool] = initTable[string, bool]()
    preSeenMemberNames: Table[string, bool] = initTable[string, bool]()
    aliasCandidate: string = ""
    aliasKey: string = ""
    aliasAllowed: bool = false
    tok: Token
    i: int = 0
    l: int = 0
    hasName: bool = false
  proc normalizeAliasCandidate(a: string): string =
    var
      text: string = a.strip()
    while text.len >= 2 and text[0] == '(' and text[^1] == ')':
      text = text[1 .. ^2].strip()
    result = text
  proc addMemberIfNew(a: string, b: seq[Token]) =
    var
      key: string = toLowerAscii(a)
      valueText: string = tokensToText(b).strip()
      valueSimple: bool = isSimpleEnumValueTokens(b)
    if a.len == 0:
      return
    if seen.hasKey(key):
      return
    seen[key] = true
    members.add((a, valueText, valueSimple))
  discard skipNewlines(s)
  if not matchText(s, "enum"):
    s.pos = mark
    result = false
    return
  if matchKind(s, tkIdentifier):
    tok = s.tokens[s.pos - 1]
    enumNameOrig = tok.text
    enumName = sanitizeIdent(enumNameOrig, "c_")
    hasName = true
  if not hasName:
    enumNameOrig = "AnonymousEnum_" & $mark
  enumName = registerName(s, enumName, enumNameOrig, "enum")
  discard skipNewlines(s)
  if not matchText(s, "{"):
    s.pos = mark
    result = false
    return
  while not isAtEnd(s):
    if matchText(s, "}"):
      break
    tok = peekToken(s)
    if tok.kind == tkPreprocessor or tok.text == "#":
      discard collectUntilNewline(s)
      continue
    tok = advanceToken(s)
    if tok.text == ",":
      if currentName.len > 0:
        addMemberIfNew(currentName, currentValueTokens)
      currentName = ""
      currentValueTokens = @[]
      expectingName = true
      collectingValue = false
      continue
    if tok.text == "=":
      collectingValue = currentName.len > 0
      continue
    if tok.kind == tkIdentifier:
      if expectingName:
        currentName = tok.text
        expectingName = false
        collectingValue = false
        currentValueTokens = @[]
        continue
    if collectingValue:
      if tok.kind != tkNewline and tok.kind != tkWhitespace:
        currentValueTokens.add(tok)
  if currentName.len > 0:
    addMemberIfNew(currentName, currentValueTokens)
  discard skipNewlines(s)
  discard matchText(s, ";")
  if hasName:
    namePragma = formatImportcPragma(enumName, enumNameOrig)
  else:
    namePragma = ""
  emitLine(s, "type " & enumName & "*" & namePragma & " = enum")
  l = members.len
  if l == 0:
    emitLine(s, "  enumPlaceholder")
  else:
    i = 0
    while i < l:
      valueKey = members[i].valueText
      if valueKey.len > 0:
        if seenValues.hasKey(valueKey):
          hasDuplicateAssignedValue = true
          break
        seenValues[valueKey] = true
      inc i
    i = 0
    while i < l:
      aliasCandidate = normalizeAliasCandidate(members[i].valueText)
      aliasKey = toLowerAscii(aliasCandidate)
      if aliasCandidate.len > 0 and preSeenMemberNames.hasKey(aliasKey):
        hasAliasAssignedValue = true
        break
      preSeenMemberNames[toLowerAscii(members[i].name)] = true
      inc i
    for i in 0 ..< l:
      memberName = sanitizeIdent(members[i].name, "c_")
      memberName = registerName(s, memberName, members[i].name, "enumMember")
      memberPragma = formatImportcPragma(memberName, members[i].name)
      memberValueText = members[i].valueText
      aliasCandidate = normalizeAliasCandidate(memberValueText)
      aliasKey = toLowerAscii(aliasCandidate)
      aliasAllowed = aliasCandidate.len > 0 and seenMemberNames.hasKey(aliasKey)
      if hasDuplicateAssignedValue or hasAliasAssignedValue or (not members[i].valueSimple and not aliasAllowed):
        memberValueText = ""
      if memberPragma.len > 0:
        if memberValueText.len > 0:
          emitLine(s, "  " & memberName & memberPragma & " = " & memberValueText)
        else:
          emitLine(s, "  " & memberName & memberPragma)
      else:
        if memberValueText.len > 0:
          emitLine(s, "  " & memberName & " = " & memberValueText)
        else:
          emitLine(s, "  " & memberName)
      seenMemberNames[toLowerAscii(members[i].name)] = true
  result = true
