import strutils
import tables
import src/c_nim_wrapper_bindr/level1/debugger
import src/c_nim_wrapper_bindr/types

proc altNameForKind*(a: string, b: string): string =
  ## a: base Nim name
  ## b: symbol kind
  ## Returns a kind-specific suffix name when available.
  case b
  of "struct":
    result = a & "_str"
  of "typedef":
    result = a & "_tyd"
  else:
    result = ""

proc normalizeUsedName*(a: string): string =
  ## a: Nim identifier
  ## Returns a style-insensitive key for Nim identifiers.
  var
    i: int = 0
    l: int = a.len
    ch: char
  result = ""
  while i < l:
    ch = a[i]
    if ch != '_':
      result.add(toLowerAscii(ch))
    inc i

proc registerName*(s: var ParserState, a: string, b: string, c: string): string =
  ## s: parser state
  ## a: desired Nim name
  ## b: original C name
  ## c: name kind for stable mapping
  ## Reserves a unique Nim name, logging collisions when needed.
  var
    key: string = c & ":" & b
    name: string = ""
    alt: string = ""
    base: string = ""
    count: int = 0
    baseKey: string = ""
    altKey: string = ""
    nameKey: string = ""
  if s.nameMap.hasKey(key):
    result = s.nameMap[key]
    return
  baseKey = normalizeUsedName(a)
  if not s.usedNames.hasKey(baseKey):
    s.usedNames[baseKey] = 1
    s.nameMap[key] = a
    result = a
    return
  alt = altNameForKind(a, c)
  if alt.len > 0:
    altKey = normalizeUsedName(alt)
  if alt.len > 0 and not s.usedNames.hasKey(altKey):
    s.usedNames[altKey] = 1
    s.nameMap[key] = alt
    recordCollision(s, a, b, alt)
    result = alt
    return
  base = a
  if alt.len > 0:
    base = alt
  baseKey = normalizeUsedName(base)
  if s.usedNames.hasKey(baseKey):
    count = s.usedNames[baseKey]
  else:
    count = 1
  name = base & "_" & $count
  nameKey = normalizeUsedName(name)
  while s.usedNames.hasKey(nameKey):
    inc count
    name = base & "_" & $count
    nameKey = normalizeUsedName(name)
  s.usedNames[baseKey] = count + 1
  s.usedNames[nameKey] = 1
  s.nameMap[key] = name
  recordCollision(s, a, b, name)
  result = name
