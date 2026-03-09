# This module parses the following C forms:
# struct Name { field_type field_name; ... };
# struct { field_type field_name; };
# It splits the struct into:
# - "struct" keyword + optional name <- handled by tryParseStruct()
# - fields between braces, separated by ";" <- handled by fieldNameFromTokens()
# Function pointer fields are detected and skipped <- handled by findFuncPtrFieldName().
# It emits a Nim `object` with mapped field types <- handled by tryParseStruct().
import src/c_nim_wrapper_bindr/name_mangle
import src/c_nim_wrapper_bindr/level2/name_registry
import src/c_nim_wrapper_bindr/level3/type_mapper
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils

type StructFieldInfo* = tuple[name: string, nimType: string]

proc findFuncPtrFieldName*(a: seq[Token]): string =
  ## a: field declaration tokens
  ## Returns the identifier from a function pointer field when present.
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

proc fieldNameFromTokens*(a: seq[Token]): string =
  ## a: field declaration tokens
  ## Returns the field name for a struct declaration.
  var
    i: int = 0
    l: int = a.len
    name: string = ""
    tok: Token
    funcName: string = ""
  funcName = findFuncPtrFieldName(a)
  if funcName.len > 0:
    result = funcName
    return
  while i < l:
    tok = a[i]
    if tok.kind == tkIdentifier:
      name = tok.text
    if tok.text == ":" or tok.text == "[":
      break
    inc i
  result = name

proc tryParseStruct*(s: var ParserState): bool =
  ## s: parser state
  ## Parses a C struct and emits a Nim object with placeholder fields.
  var
    mark: int = s.pos
    structName: string = "AnonymousStruct"
    structNameOrig: string = "AnonymousStruct"
    namePragma: string = ""
    fields: seq[StructFieldInfo] = @[]
    fieldName: string = ""
    fieldType: string = ""
    fieldPragma: string = ""
    tok: Token
    l: int = 0
    hasName: bool = false
    fieldTokens: seq[Token] = @[]
  discard skipNewlines(s)
  if not matchText(s, "struct"):
    s.pos = mark
    result = false
    return
  if matchKind(s, tkIdentifier):
    tok = s.tokens[s.pos - 1]
    structNameOrig = tok.text
    structName = sanitizeIdent(structNameOrig, "c_")
    hasName = true
  if not hasName:
    structNameOrig = "AnonymousStruct_" & $mark
  structName = registerName(s, structName, structNameOrig, "struct")
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
    if tok.text == ";":
      fieldName = fieldNameFromTokens(fieldTokens)
      if fieldName.len > 0:
        fieldType = mapTokensToNimType(s, fieldTokens, fieldName)
        if fieldType.len == 0:
          fieldType = "pointer"
        fields.add (fieldName, fieldType)
      fieldTokens = @[]
    else:
      fieldTokens.add tok
  discard skipNewlines(s)
  discard matchText(s, ";")
  if hasName:
    namePragma = formatImportcPragma(structName, structNameOrig)
  else:
    namePragma = ""
  emitLine(s, "type " & structName & "*" & namePragma & " = object")
  l = fields.len
  if l == 0:
    emitLine(s, "  reserved*: array[1, byte]")
  else:
    for i in 0 ..< l:
      fieldName = sanitizeIdent(fields[i].name, "c_")
      fieldPragma = formatImportcPragma(fieldName, fields[i].name)
      fieldType = fields[i].nimType
      if fieldPragma.len > 0:
        emitLine(s, "  " & fieldName & "*" & fieldPragma & ": " & fieldType)
      else:
        emitLine(s, "  " & fieldName & "*: " & fieldType)
  result = true
