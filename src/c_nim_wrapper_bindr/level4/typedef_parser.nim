# This module parses the following C forms:
# typedef ExistingType Alias;
# typedef struct { ... } Alias;
# typedef struct Name { ... } Alias;
# typedef ReturnType (*FuncPtr)(...);
# It splits the typedef into:
# - full token collection up to ";" <- handled by collectTypedefTokens()
# - struct body detection and field splitting <- handled by isStructTypedef(), splitStructFields()
# - per-field type mapping <- handled by parseStructField(), mapTokensToNimType()
# - function pointer alias detection via "(*name)" <- handled by findFunctionPointerAlias()
# It emits Nim type aliases or objects, skipping function pointer fields <- handled by tryParseTypedef().
import src/c_nim_wrapper_bindr/name_mangle
import strutils
import tables
import src/c_nim_wrapper_bindr/level2/name_registry
import src/c_nim_wrapper_bindr/level3/struct_parser
import src/c_nim_wrapper_bindr/level3/type_mapper
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils

type
  StructField* = object
    name*: string
    nimType*: string

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

proc findLastIdentifier*(a: seq[Token]): string =
  ## a: token list
  ## Returns the last identifier found in the token list.
  ## Example: tokens for `typedef struct Foo Bar;` return "Bar".
  var
    name: string = ""
    l: int = a.len
  for i in 0 ..< l:
    if a[i].kind == tkIdentifier:
      name = a[i].text
  result = name

proc findFunctionPointerAlias*(a: seq[Token]): string =
  ## a: typedef tokens
  ## Returns the alias name for function pointer typedefs like `(*name)`.
  var
    i: int = 0
    l: int = a.len
  while i + 2 < l:
    if a[i].text == "(" and a[i + 1].text == "*" and a[i + 2].kind == tkIdentifier:
      result = a[i + 2].text
      return
    inc i
  result = ""

proc hasTypeLine*(s: ParserState, b: string): bool =
  ## s: parser state
  ## b: type name
  ## Returns true when a type declaration for the name already exists.
  var
    i: int = s.output.len - 1
    needle: string = "type " & b & "*"
  if i < 0:
    result = false
    return
  while i >= 0:
    if s.output[i].len >= needle.len and s.output[i][0 ..< needle.len] == needle:
      result = true
      return
    dec i
  result = false

proc isStructTypedef*(a: seq[Token]): bool =
  ## a: typedef tokens
  ## Returns true when the typedef contains a struct body.
  var
    i: int = 0
    l: int = a.len
    sawStruct: bool = false
  while i < l:
    if a[i].text == "struct":
      sawStruct = true
    if a[i].text == "{" and sawStruct:
      result = true
      return
    inc i
  result = false

proc isEnumTypedef*(a: seq[Token]): bool =
  ## a: typedef tokens
  ## Returns true when the typedef contains an enum body.
  var
    i: int = 0
    l: int = a.len
    sawEnum: bool = false
  while i < l:
    if a[i].text == "enum":
      sawEnum = true
    if a[i].text == "{" and sawEnum:
      result = true
      return
    inc i
  result = false

proc collectStructBodyTokens*(a: seq[Token]): seq[Token] =
  ## a: typedef tokens
  ## Returns the tokens contained inside the struct body braces.
  var
    items: seq[Token] = @[]
    i: int = 0
    l: int = a.len
    depth: int = 0
    started: bool = false
    sawStruct: bool = false
  while i < l:
    if a[i].text == "struct":
      sawStruct = true
    if a[i].text == "{" and sawStruct:
      started = true
      depth = 1
      inc i
      while i < l and depth > 0:
        if a[i].text == "{":
          inc depth
          items.add a[i]
        elif a[i].text == "}":
          dec depth
          if depth > 0:
            items.add a[i]
        else:
          items.add a[i]
        inc i
      break
    inc i
  if not started:
    result = @[]
  else:
    result = items

proc collectEnumBodyTokens*(a: seq[Token]): seq[Token] =
  ## a: typedef tokens
  ## Returns the tokens contained inside the enum body braces.
  var
    items: seq[Token] = @[]
    i: int = 0
    l: int = a.len
    depth: int = 0
    started: bool = false
    sawEnum: bool = false
  while i < l:
    if a[i].text == "enum":
      sawEnum = true
    if a[i].text == "{" and sawEnum:
      started = true
      depth = 1
      inc i
      while i < l and depth > 0:
        if a[i].text == "{":
          inc depth
          items.add a[i]
        elif a[i].text == "}":
          dec depth
          if depth > 0:
            items.add a[i]
        else:
          items.add a[i]
        inc i
      break
    inc i
  if not started:
    result = @[]
  else:
    result = items

proc collectEnumMembers*(a: seq[Token]): seq[tuple[name: string, valueText: string, valueSimple: bool]] =
  ## a: enum body tokens
  ## Collects enum member identifiers and optional explicit values.
  var
    members: seq[tuple[name: string, valueText: string, valueSimple: bool]] = @[]
    seen: Table[string, bool] = initTable[string, bool]()
    currentName: string = ""
    currentValueTokens: seq[Token] = @[]
    expectingName: bool = true
    collectingValue: bool = false
    i: int = 0
    l: int = a.len
    tok: Token
  proc addMemberIfNew(c: string, d: seq[Token]) =
    var
      key: string = toLowerAscii(c)
      valueText: string = tokensToText(d).strip()
      valueSimple: bool = isSimpleEnumValueTokens(d)
    if c.len == 0:
      return
    if seen.hasKey(key):
      return
    seen[key] = true
    members.add((c, valueText, valueSimple))

  while i < l:
    tok = a[i]
    if tok.kind == tkPreprocessor or tok.text == "#":
      inc i
      while i < l and a[i].kind != tkNewline:
        inc i
      continue
    if tok.text == ",":
      if currentName.len > 0:
        addMemberIfNew(currentName, currentValueTokens)
      currentName = ""
      currentValueTokens = @[]
      expectingName = true
      collectingValue = false
      inc i
      continue
    if tok.text == "=":
      collectingValue = currentName.len > 0
      inc i
      continue
    if tok.kind == tkIdentifier and expectingName:
      currentName = tok.text
      expectingName = false
      collectingValue = false
      currentValueTokens = @[]
      inc i
      continue
    if collectingValue:
      if tok.kind != tkNewline and tok.kind != tkWhitespace:
        currentValueTokens.add tok
    inc i
  if currentName.len > 0:
    addMemberIfNew(currentName, currentValueTokens)
  result = members

proc splitStructFields*(a: seq[Token]): seq[seq[Token]] =
  ## a: struct body tokens
  ## Splits struct body tokens into field token groups.
  var
    fields: seq[seq[Token]] = @[]
    current: seq[Token] = @[]
    i: int = 0
    l: int = a.len
    parenDepth: int = 0
    braceDepth: int = 0
    tok: Token
  while i < l:
    tok = a[i]
    if tok.kind == tkPreprocessor or tok.text == "#":
      inc i
      while i < l and a[i].kind != tkNewline:
        inc i
      continue
    if tok.text == "{":
      inc braceDepth
    elif tok.text == "}":
      if braceDepth > 0:
        dec braceDepth
    elif tok.text == "(":
      inc parenDepth
    elif tok.text == ")":
      if parenDepth > 0:
        dec parenDepth
    elif tok.text == ";" and braceDepth == 0 and parenDepth == 0:
      if current.len > 0:
        fields.add current
        current = @[]
      inc i
      continue
    current.add tok
    inc i
  if current.len > 0:
    fields.add current
  result = fields

proc parseStructField*(s: var ParserState, a: seq[Token]): StructField =
  ## s: parser state
  ## a: field tokens
  ## Parses a struct field into a name and Nim type, skipping function pointers.
  var
    fieldName: string = ""
    funcName: string = ""
    fieldType: string = ""
    info: StructField
    i: int = 0
    l: int = a.len
    hasNamedInlineStruct: bool = false
    lastCloseBrace: int = -1
    tok: Token
  while i + 2 < l:
    if a[i].text == "struct" and a[i + 1].kind == tkIdentifier:
      var
        j: int = i + 2
      while j < l and a[j].text != "{":
        inc j
      if j < l and a[j].text == "{":
        hasNamedInlineStruct = true
        break
    inc i
  if hasNamedInlineStruct:
    i = 0
    while i < l:
      if a[i].text == "}":
        lastCloseBrace = i
      inc i
    if lastCloseBrace >= 0:
      i = lastCloseBrace + 1
      while i < l:
        tok = a[i]
        if tok.text == ":" or tok.text == "[":
          break
        if tok.kind == tkIdentifier:
          fieldName = tok.text
        inc i
      if fieldName.len > 0:
        info.name = fieldName
        info.nimType = "pointer"
        result = info
        return
  funcName = findFuncPtrFieldName(a)
  if funcName.len > 0:
    result = info
    return
  fieldName = fieldNameFromTokens(a)
  if fieldName.len == 0:
    result = info
    return
  fieldType = mapTokensToNimType(s, a, fieldName)
  info.name = fieldName
  info.nimType = fieldType
  result = info

proc collectStructFields*(s: var ParserState, a: seq[Token]): seq[StructField] =
  ## s: parser state
  ## a: typedef tokens
  ## Collects struct fields for a typedef struct declaration.
  var
    body: seq[Token] = collectStructBodyTokens(a)
    groups: seq[seq[Token]] = splitStructFields(body)
    items: seq[StructField] = @[]
    i: int = 0
    l: int = groups.len
    fieldInfo: StructField
  while i < l:
    fieldInfo = parseStructField(s, groups[i])
    if fieldInfo.name.len > 0 and fieldInfo.nimType.len > 0:
      items.add fieldInfo
    inc i
  result = items

proc collectTypedefTokens*(s: var ParserState): seq[Token] =
  ## s: parser state
  ## Collects typedef tokens up to the terminating semicolon, tracking braces.
  var
    items: seq[Token] = @[]
    tok: Token
    depth: int = 0
  while not isAtEnd(s):
    tok = advanceToken(s)
    if tok.text == "{":
      inc depth
      items.add tok
      continue
    if tok.text == "}":
      if depth > 0:
        dec depth
      items.add tok
      continue
    if tok.text == ";" and depth == 0:
      break
    items.add tok
  result = items

proc findTypedefAlias*(a: seq[Token]): string =
  ## a: typedef tokens
  ## Finds the alias name after a closing brace when present, otherwise uses last identifier.
  var
    i: int = 0
    l: int = a.len
    lastClose: int = -1
    name: string = ""
    funcAlias: string = ""
  while i < l:
    if a[i].text == "}":
      lastClose = i
    inc i
  if lastClose >= 0:
    i = lastClose + 1
    while i < l:
      if a[i].kind == tkIdentifier:
        name = a[i].text
      inc i
    result = name
  else:
    funcAlias = findFunctionPointerAlias(a)
    if funcAlias.len > 0:
      result = funcAlias
      return
    result = findLastIdentifier(a)

proc tryParseTypedef*(s: var ParserState): bool =
  ## s: parser state
  ## Parses a C typedef and emits a Nim type alias.
  var
    mark: int = s.pos
    bodyTokens: seq[Token] = @[]
    bodyText: string = ""
    aliasName: string = ""
    origName: string = ""
    namePragma: string = ""
    fields: seq[StructField] = @[]
    i: int = 0
    l: int = 0
    fieldName: string = ""
    fieldType: string = ""
    fieldPragma: string = ""
    enumBody: seq[Token] = @[]
    enumMembers: seq[tuple[name: string, valueText: string, valueSimple: bool]] = @[]
    enumMemberName: string = ""
    enumMemberPragma: string = ""
    enumMemberValueText: string = ""
    enumValueKey: string = ""
    enumHasDuplicateAssignedValue: bool = false
    enumHasAliasAssignedValue: bool = false
    enumSeenValues: Table[string, bool] = initTable[string, bool]()
    enumSeenMemberNames: Table[string, bool] = initTable[string, bool]()
    enumPreSeenMemberNames: Table[string, bool] = initTable[string, bool]()
    enumAliasCandidate: string = ""
    enumAliasKey: string = ""
    enumAliasAllowed: bool = false
  proc normalizeAliasCandidate(a: string): string =
    var
      text: string = a.strip()
    while text.len >= 2 and text[0] == '(' and text[^1] == ')':
      text = text[1 .. ^2].strip()
    result = text
  discard skipNewlines(s)
  if not matchText(s, "typedef"):
    s.pos = mark
    result = false
    return
  bodyTokens = collectTypedefTokens(s)
  bodyText = tokensToText(bodyTokens)
  origName = findTypedefAlias(bodyTokens)
  if origName.len == 0:
    emitLine(s, "# typedef: " & bodyText)
    result = true
    return
  aliasName = sanitizeIdent(origName, "c_")
  aliasName = registerName(s, aliasName, origName, "typedef")
  if hasTypeLine(s, aliasName):
    result = true
    return
  namePragma = formatImportcPragma(aliasName, origName)
  if isStructTypedef(bodyTokens):
    fields = collectStructFields(s, bodyTokens)
    emitLine(s, "type " & aliasName & "*" & namePragma & " = object")
    l = fields.len
    if l == 0:
      emitLine(s, "  reserved*: array[1, byte]")
    else:
      while i < l:
        fieldName = sanitizeIdent(fields[i].name, "c_")
        fieldType = fields[i].nimType
        fieldPragma = formatImportcPragma(fieldName, fields[i].name)
        if fieldPragma.len > 0:
          emitLine(s, "  " & fieldName & "*" & fieldPragma & ": " & fieldType)
        else:
          emitLine(s, "  " & fieldName & "*: " & fieldType)
        inc i
  elif isEnumTypedef(bodyTokens):
    enumBody = collectEnumBodyTokens(bodyTokens)
    enumMembers = collectEnumMembers(enumBody)
    emitLine(s, "type " & aliasName & "*" & namePragma & " = enum")
    l = enumMembers.len
    if l == 0:
      emitLine(s, "  enumPlaceholder")
    else:
      i = 0
      while i < l:
        enumValueKey = enumMembers[i].valueText
        if enumValueKey.len > 0:
          if enumSeenValues.hasKey(enumValueKey):
            enumHasDuplicateAssignedValue = true
            break
          enumSeenValues[enumValueKey] = true
        inc i
      i = 0
      while i < l:
        enumAliasCandidate = normalizeAliasCandidate(enumMembers[i].valueText)
        enumAliasKey = toLowerAscii(enumAliasCandidate)
        if enumAliasCandidate.len > 0 and enumPreSeenMemberNames.hasKey(enumAliasKey):
          enumHasAliasAssignedValue = true
          break
        enumPreSeenMemberNames[toLowerAscii(enumMembers[i].name)] = true
        inc i
      i = 0
      while i < l:
        enumMemberName = sanitizeIdent(enumMembers[i].name, "c_")
        enumMemberName = registerName(s, enumMemberName, enumMembers[i].name, "enumMember")
        enumMemberPragma = formatImportcPragma(enumMemberName, enumMembers[i].name)
        enumMemberValueText = enumMembers[i].valueText
        enumAliasCandidate = normalizeAliasCandidate(enumMemberValueText)
        enumAliasKey = toLowerAscii(enumAliasCandidate)
        enumAliasAllowed = enumAliasCandidate.len > 0 and enumSeenMemberNames.hasKey(enumAliasKey)
        if enumHasDuplicateAssignedValue or enumHasAliasAssignedValue or (not enumMembers[i].valueSimple and not enumAliasAllowed):
          enumMemberValueText = ""
        if enumMemberPragma.len > 0:
          if enumMemberValueText.len > 0:
            emitLine(s, "  " & enumMemberName & enumMemberPragma & " = " & enumMemberValueText)
          else:
            emitLine(s, "  " & enumMemberName & enumMemberPragma)
        else:
          if enumMemberValueText.len > 0:
            emitLine(s, "  " & enumMemberName & " = " & enumMemberValueText)
          else:
            emitLine(s, "  " & enumMemberName)
        enumSeenMemberNames[toLowerAscii(enumMembers[i].name)] = true
        inc i
  else:
    emitLine(s, "type " & aliasName & "*" & namePragma & " = distinct pointer")
    if s.config.emitComments and bodyText.len > 0:
      emitLine(s, "# typedef: " & bodyText)
  result = true
