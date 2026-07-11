import strutils
import tables
import src/c_nim_wrapper_bindr/name_mangle
import src/c_nim_wrapper_bindr/level2/name_registry
import src/c_nim_wrapper_bindr/types

proc pointerCountFromTokens*(a: seq[Token]): int =
  ## a: token list
  ## Counts the number of pointer '*' tokens.
  var
    i: int = 0
    l: int = a.len
    count: int = 0
  while i < l:
    if a[i].text == "*":
      inc count
    inc i
  result = count

proc collectTypeWords*(a: seq[Token], b: string): seq[string] =
  ## a: token list
  ## b: identifier name to skip
  ## Collects identifier words that contribute to a C type name.
  var
    words: seq[string] = @[]
    i: int = 0
    l: int = a.len
  while i < l:
    if a[i].kind == tkIdentifier and a[i].text != b:
      words.add a[i].text
    inc i
  result = words

proc mapFixedWidthType*(a: string): string =
  ## a: identifier word
  ## Returns a Nim type for fixed-width C typedefs.
  var
    word: string = toLowerAscii(a)
  case word
  of "size_t":
    result = "csize_t"
  of "basetype_t":
    result = "cint"
  of "ubasetype_t":
    result = "cuint"
  of "ticktype_t":
    result = "cuint"
  of "stacktype_t":
    result = "cuint"
  of "taskfunction_t":
    result = "pointer"
  of "xmpu_settings":
    result = "pointer"
  of "xmemory_region":
    result = "pointer"
  of "configrun_time_counter_type_tyd":
    result = "culong"
  of "configrun_time_counter_type_t":
    result = "culong"
  of "configrun_time_counter_type":
    result = "culong"
  of "configtls_block_type_tyd":
    result = "pointer"
  of "configtls_block_type_t":
    result = "pointer"
  of "configtls_block_type":
    result = "pointer"
  of "configstack_depth_type":
    result = "cuint"
  of "listfirst_list_item_integrity_check_value_tyd":
    result = "cuint"
  of "listfirst_list_integrity_check_value_tyd":
    result = "cuint"
  of "uint8_t":
    result = "uint8"
  of "uint16_t":
    result = "uint16"
  of "uint32_t":
    result = "uint32"
  of "uint64_t":
    result = "uint64"
  of "int8_t":
    result = "int8"
  of "int16_t":
    result = "int16"
  of "int32_t":
    result = "int32"
  of "int64_t":
    result = "int64"
  else:
    result = ""

proc mapBuiltinType*(a: seq[string]): string =
  ## a: identifier words
  ## Returns the Nim type for builtin C type words.
  var
    i: int = 0
    l: int = a.len
    word: string = ""
    fixed: string = ""
    unsignedSeen: bool = false
    signedSeen: bool = false
    longCount: int = 0
    shortCount: int = 0
    hasInt: bool = false
    hasChar: bool = false
    hasFloat: bool = false
    hasDouble: bool = false
    hasBool: bool = false
    hasVoid: bool = false
  while i < l:
    word = toLowerAscii(a[i])
    fixed = mapFixedWidthType(word)
    if fixed.len > 0:
      result = fixed
      return
    case word
    of "unsigned":
      unsignedSeen = true
    of "signed":
      signedSeen = true
    of "long":
      inc longCount
    of "short":
      inc shortCount
    of "int":
      hasInt = true
    of "char":
      hasChar = true
    of "float":
      hasFloat = true
    of "double":
      hasDouble = true
    of "bool", "_bool":
      hasBool = true
    of "void":
      hasVoid = true
    else:
      discard
    inc i
  if hasVoid:
    result = "void"
    return
  if hasBool:
    result = "bool"
    return
  if hasChar:
    if unsignedSeen:
      result = "uint8"
    elif signedSeen:
      result = "int8"
    else:
      result = "cchar"
    return
  if hasFloat:
    result = "cfloat"
    return
  if hasDouble:
    result = "cdouble"
    return
  if unsignedSeen and not hasInt and longCount == 0 and shortCount == 0:
    result = "cuint"
    return
  if signedSeen and not hasInt and longCount == 0 and shortCount == 0:
    result = "cint"
    return
  if hasInt or longCount > 0 or shortCount > 0:
    if longCount >= 2:
      if unsignedSeen:
        result = "culonglong"
      else:
        result = "clonglong"
    elif longCount == 1:
      if unsignedSeen:
        result = "culong"
      else:
        result = "clong"
    elif shortCount > 0:
      if unsignedSeen:
        result = "cushort"
      else:
        result = "cshort"
    else:
      if unsignedSeen:
        result = "cuint"
      else:
        result = "cint"
    return
  result = ""

proc findTaggedName*(a: seq[string], b: string): string =
  ## a: identifier words
  ## b: tag keyword
  ## Returns the name following a struct/enum/union tag.
  var
    i: int = 0
    l: int = a.len
    tag: string = toLowerAscii(b)
    word: string = ""
  while i + 1 < l:
    word = toLowerAscii(a[i])
    if word == tag:
      result = a[i + 1]
      return
    inc i
  result = ""

proc isIgnoredWord*(a: string): bool =
  ## a: identifier word
  ## Returns true when the word is a C qualifier or noise token.
  var
    word: string = toLowerAscii(a)
  if word == "__attribute__" or word == "__declspec":
    result = true
    return
  if a.len > 0 and a == toUpperAscii(a):
    if a.endsWith("_ATTR") or a.endsWith("_DECL") or a.endsWith("_API") or
        a.startsWith("ESP_"):
      result = true
      return
  case word
  of "const", "volatile", "restrict", "register", "static", "extern", "inline",
     "__const", "__restrict", "__restrict__", "__extension__", "return", "if",
     "else", "for", "while", "switch", "case", "do", "goto", "break",
     "continue":
    result = true
  else:
    result = false

proc isBuiltinWord*(a: string): bool =
  ## a: identifier word
  ## Returns true when the word is part of a builtin C type spelling.
  var
    word: string = toLowerAscii(a)
    fixed: string = mapFixedWidthType(word)
  if fixed.len > 0:
    result = true
    return
  case word
  of "unsigned", "signed", "long", "short", "int", "char", "float", "double",
     "bool", "_bool", "void", "struct", "enum", "union":
    result = true
  else:
    result = false

proc findCustomWord*(a: seq[string]): string =
  ## a: identifier words
  ## Returns the first custom type name.
  var
    i: int = 0
    l: int = a.len
    word: string = ""
  while i < l:
    word = a[i]
    if not isIgnoredWord(word) and not isBuiltinWord(word):
      result = word
      return
    inc i
  result = ""

proc mapCustomTypeName*(s: var ParserState, a: string, b: string): string =
  ## s: parser state
  ## a: original C type name
  ## b: name kind label
  ## Returns the registered Nim type name for a custom type.
  var
    name: string = sanitizeIdent(a, "c_")
    outName: string = ""
  outName = registerName(s, name, a, b)
  if outName.len > 0:
    s.referencedCustomTypes[outName] = true
  result = outName

proc applyPointerType*(a: string, b: int): string =
  ## a: base Nim type
  ## b: pointer depth
  ## Returns the Nim type with pointer depth applied.
  var
    i: int = 0
    t: string = a
  if b <= 0:
    result = t
    return
  if t == "pointer":
    result = "pointer"
    return
  if t == "void":
    result = "pointer"
    return
  if t == "cchar":
    if b == 1:
      result = "cstring"
      return
    t = "cstring"
    i = 1
    while i < b:
      t = "ptr " & t
      inc i
    result = t
    return
  i = 0
  t = a
  while i < b:
    t = "ptr " & t
    inc i
  result = t

proc mapTokensToNimType*(s: var ParserState, a: seq[Token], b: string): string =
  ## s: parser state
  ## a: token list for a C type
  ## b: identifier name to skip
  ## Maps a C type token list into a Nim type string.
  var
    words: seq[string] = collectTypeWords(a, b)
    pointers: int = pointerCountFromTokens(a)
    structName: string = ""
    enumName: string = ""
    candidateStructName: string = findTaggedName(words, "struct")
    candidateEnumName: string = findTaggedName(words, "enum")
    baseType: string = ""
    customName: string = ""
  if candidateStructName.len > 0 and not isBuiltinWord(candidateStructName) and
      not isIgnoredWord(candidateStructName):
    structName = candidateStructName
  if candidateEnumName.len > 0 and not isBuiltinWord(candidateEnumName) and
      not isIgnoredWord(candidateEnumName):
    enumName = candidateEnumName
  if structName.len > 0:
    baseType = mapCustomTypeName(s, structName, "struct")
  elif enumName.len > 0:
    baseType = mapCustomTypeName(s, enumName, "enum")
  else:
    baseType = mapBuiltinType(words)
    if baseType.len == 0:
      customName = findCustomWord(words)
      if customName.len > 0:
        baseType = mapCustomTypeName(s, customName, "typedef")
  if baseType.len == 0:
    baseType = "pointer"
  result = applyPointerType(baseType, pointers)
