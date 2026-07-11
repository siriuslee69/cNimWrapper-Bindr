import strutils
import src/c_nim_wrapper_bindr/types

proc isBuiltinTypeWord*(a: string): bool =
  ## a: lower-cased identifier
  ## Returns true for builtin C type/qualifier words used in casts.
  case a
  of "void", "char", "short", "int", "long", "float", "double", "signed",
     "unsigned", "bool", "_bool", "const", "volatile", "restrict", "struct",
     "enum", "union":
    result = true
  else:
    result = false

proc isTypeToken*(a: Token): bool =
  ## a: token to inspect
  ## Returns true when the token looks like part of a C type name.
  if a.kind == tkIdentifier:
    result = true
  elif a.kind == tkSymbol and a.text == "*":
    result = true
  else:
    result = false

proc stripLeadingCastTokens*(a: seq[Token]): seq[Token] =
  ## a: token list
  ## Strips a leading C-style cast like `(long)` or `((long)0)` when detected.
  var
    l: int = a.len
    i: int = 0
    endPos: int = -1
  if l == 0:
    result = a
    return
  if a[0].text != "(":
    result = a
    return
  i = 0
  while i < l and a[i].text == "(":
    endPos = i + 1
    var
      j: int = i + 1
      sawIdentifier: bool = false
      sawTypeLikeIdentifier: bool = false
      tok: Token
      text: string
      lower: string
      hasLower: bool
    while endPos < l:
      if a[endPos].text == ")":
        break
      if not isTypeToken(a[endPos]):
        endPos = -1
        break
      inc endPos
    if endPos > i and endPos >= 0 and endPos < l and a[endPos].text == ")":
      while j < endPos:
        tok = a[j]
        if tok.kind == tkIdentifier:
          sawIdentifier = true
          text = tok.text
          lower = toLowerAscii(text)
          hasLower = text != toUpperAscii(text)
          if isBuiltinTypeWord(lower) or text.endsWith("_t") or hasLower:
            sawTypeLikeIdentifier = true
        inc j
      if not sawIdentifier or not sawTypeLikeIdentifier:
        endPos = -1
    if endPos > i:
      if endPos >= 0 and endPos < l and a[endPos].text == ")":
        result = @[]
        if i > 0:
          result.add a[0 ..< i]
        if endPos + 1 < l:
          result.add a[endPos + 1 ..< l]
        return
    inc i
  result = a
