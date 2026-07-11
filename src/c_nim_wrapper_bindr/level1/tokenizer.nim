# This module parses the following C syntax into tokens:
# - identifiers: foo, _bar123
# - numbers: 42, 0x10, 3.14
# - strings: "text"
# - symbols and operators: "(", ")", "==", "->", "##"
# - comments and whitespace are skipped
# The entry point is tokenizeC, which emits a flat token stream with newlines
# <- handled by tokenizeC().
import src/c_nim_wrapper_bindr/types

proc makeToken*(a: TokenKind, b: string, c: int, d: int): Token =
  ## a: token kind
  ## b: token text
  ## c: line number
  ## d: column number
  ## Constructs a token with the given metadata.
  var
    tok: Token = Token(kind: a, text: b, line: c, col: d)
  result = tok

proc isIdentStart*(a: char): bool =
  ## a: input character
  ## True when the character can start a C identifier.
  result = (a >= 'A' and a <= 'Z') or (a >= 'a' and a <= 'z') or a == '_'

proc isIdentChar*(a: char): bool =
  ## a: input character
  ## True when the character can appear in a C identifier.
  result = isIdentStart(a) or (a >= '0' and a <= '9')

proc isDigitChar*(a: char): bool =
  ## a: input character
  ## True when the character is an ASCII digit.
  result = a >= '0' and a <= '9'

proc isNumberChar*(a: char): bool =
  ## a: input character
  ## True when the character can appear in a C numeric literal.
  result = isDigitChar(a) or a == '.' or a == 'x' or a == 'X' or a == 'u' or
    a == 'U' or a == 'l' or a == 'L' or a == 'f' or a == 'F' or
    (a >= 'a' and a <= 'f') or (a >= 'A' and a <= 'F')

proc isWhitespaceChar*(a: char): bool =
  ## a: input character
  ## True for horizontal whitespace characters.
  result = a == ' ' or a == '\t' or a == '\r'

proc isNewlineChar*(a: char): bool =
  ## a: input character
  ## True for a newline character.
  result = a == '\n'

proc isTwoCharSymbol*(a: char, b: char): bool =
  ## a: first character
  ## b: second character
  ## Checks for two-character C operators like "==" or "->".
  ## Example: `isTwoCharSymbol('<', '=')` is true.
  var
    pair: string = $a & $b
  case pair
  of "->", "==", "!=", "<=", ">=", "&&", "||", "++", "--", "<<", ">>", "+=",
     "-=", "*=", "/=", "##":
    result = true
  else:
    result = false

proc readIdentifier*(a: string, b: var int, c: var int): string =
  ## a: input text
  ## b: index, updated in place
  ## c: column, updated in place
  ## Reads an identifier and advances index and column.
  var
    start: int = b
    l: int = a.len
  while b < l and isIdentChar(a[b]):
    inc b
    inc c
  result = a[start ..< b]

proc readNumber*(a: string, b: var int, c: var int): string =
  ## a: input text
  ## b: index, updated in place
  ## c: column, updated in place
  ## Reads a number literal and advances index and column.
  var
    start: int = b
    l: int = a.len
    ch: char
    raw: string = ""
    i: int = 0
    isHex: bool = false
    hasFloatMarkers: bool = false
  proc normalizeNumberLiteral(d: string): string =
    var
      n: string = d
      j: int = n.len
      stripFloatF: bool = false
    if n.len >= 2 and n[0] == '0' and (n[1] == 'x' or n[1] == 'X'):
      isHex = true
    else:
      isHex = false
    hasFloatMarkers = false
    i = 0
    while i < n.len:
      if n[i] == '.' or n[i] == 'e' or n[i] == 'E' or n[i] == 'p' or n[i] == 'P':
        hasFloatMarkers = true
        break
      inc i
    while j > 0 and (n[j - 1] == 'u' or n[j - 1] == 'U' or n[j - 1] == 'l' or
        n[j - 1] == 'L'):
      dec j
    if hasFloatMarkers and j > 0 and (n[j - 1] == 'f' or n[j - 1] == 'F'):
      stripFloatF = true
    if stripFloatF:
      dec j
    if j <= 0:
      result = d
    else:
      if isHex and j == 2 and n.len >= 2 and n[0] == '0' and n[1] == 'x':
        result = d
      elif isHex and j == 2 and n.len >= 2 and n[0] == '0' and n[1] == 'X':
        result = d
      else:
        result = n[0 ..< j]
  if b + 1 < l and a[b] == '0' and (a[b + 1] == 'x' or a[b + 1] == 'X'):
    b += 2
    c += 2
    while b < l:
      ch = a[b]
      if isDigitChar(ch) or (ch >= 'a' and ch <= 'f') or (ch >= 'A' and ch <=
          'F'):
        inc b
        inc c
      else:
        break
    if b < l and a[b] == '.':
      inc b
      inc c
      while b < l:
        ch = a[b]
        if isDigitChar(ch) or (ch >= 'a' and ch <= 'f') or (ch >= 'A' and ch <=
            'F'):
          inc b
          inc c
        else:
          break
    if b < l and (a[b] == 'p' or a[b] == 'P'):
      inc b
      inc c
      if b < l and (a[b] == '+' or a[b] == '-'):
        inc b
        inc c
      while b < l and isDigitChar(a[b]):
        inc b
        inc c
    while b < l:
      ch = a[b]
      if isDigitChar(ch) or ch == 'u' or ch == 'U' or ch == 'l' or ch == 'L' or
          ch == 'f' or ch == 'F':
        inc b
        inc c
      else:
        break
    raw = a[start ..< b]
    result = normalizeNumberLiteral(raw)
    return
  while b < l and isDigitChar(a[b]):
    inc b
    inc c
  if b < l and a[b] == '.':
    inc b
    inc c
    while b < l and isDigitChar(a[b]):
      inc b
      inc c
  if b < l and (a[b] == 'e' or a[b] == 'E'):
    inc b
    inc c
    if b < l and (a[b] == '+' or a[b] == '-'):
      inc b
      inc c
    while b < l and isDigitChar(a[b]):
      inc b
      inc c
  while b < l:
    ch = a[b]
    if ch == 'u' or ch == 'U' or ch == 'l' or ch == 'L' or ch == 'f' or
        ch == 'F':
      inc b
      inc c
    else:
      break
  raw = a[start ..< b]
  result = normalizeNumberLiteral(raw)

proc readStringLiteral*(a: string, b: var int, c: var int): string =
  ## a: input text
  ## b: index, updated in place
  ## c: column, updated in place
  ## Reads a quoted string literal with basic escape handling.
  var
    start: int = b
    l: int = a.len
    escaped: bool = false
    ch: char
  inc b
  inc c
  while b < l:
    ch = a[b]
    if escaped:
      escaped = false
      inc b
      inc c
    elif ch == '\\':
      escaped = true
      inc b
      inc c
    elif ch == '"':
      inc b
      inc c
      break
    else:
      inc b
      inc c
  result = a[start ..< b]

proc readSymbol*(a: string, b: var int, c: var int): string =
  ## a: input text
  ## b: index, updated in place
  ## c: column, updated in place
  ## Reads a one- or two-character symbol and advances index and column.
  var
    l: int = a.len
    ch: char = a[b]
    nextChar: char
  if b + 1 < l:
    nextChar = a[b + 1]
    if isTwoCharSymbol(ch, nextChar):
      b += 2
      c += 2
      result = $ch & $nextChar
      return
  b += 1
  c += 1
  result = $ch

proc skipLineComment*(a: string, b: var int, c: var int, d: var int) =
  ## a: input text
  ## b: index, updated in place
  ## c: line number, updated in place
  ## d: column, updated in place
  ## Skips characters in a // comment without consuming a newline.
  var
    l: int = a.len
  b += 2
  d += 2
  while b < l and not isNewlineChar(a[b]):
    inc b
    inc d

proc skipBlockComment*(a: string, b: var int, c: var int, d: var int) =
  ## a: input text
  ## b: index, updated in place
  ## c: line number, updated in place
  ## d: column, updated in place
  ## Skips a /* */ block comment, updating line and column counters.
  var
    l: int = a.len
    ch: char
  b += 2
  d += 2
  while b < l:
    ch = a[b]
    if ch == '*' and b + 1 < l and a[b + 1] == '/':
      b += 2
      d += 2
      break
    if isNewlineChar(ch):
      inc c
      d = 1
      inc b
    else:
      inc b
      inc d

proc tokenizeC*(a: string): seq[Token] =
  ## a: input C source text
  ## Tokenizes C source into a flat token stream with newline tokens.
  ## Example: `tokenizeC("int a;\n")` includes a tkNewline token.
  var
    tokens: seq[Token] = @[]
    i: int = 0
    l: int = a.len
    line: int = 1
    col: int = 1
    startCol: int = 0
    text: string = ""
    ch: char
  while i < l:
    ch = a[i]
    if isNewlineChar(ch):
      tokens.add makeToken(tkNewline, "\n", line, col)
      inc i
      inc line
      col = 1
    elif isWhitespaceChar(ch):
      inc i
      inc col
    elif ch == '/' and i + 1 < l and a[i + 1] == '/':
      skipLineComment(a, i, line, col)
    elif ch == '/' and i + 1 < l and a[i + 1] == '*':
      skipBlockComment(a, i, line, col)
    elif isIdentStart(ch):
      startCol = col
      text = readIdentifier(a, i, col)
      tokens.add makeToken(tkIdentifier, text, line, startCol)
    elif isDigitChar(ch):
      startCol = col
      text = readNumber(a, i, col)
      tokens.add makeToken(tkNumber, text, line, startCol)
    elif ch == '"':
      startCol = col
      text = readStringLiteral(a, i, col)
      tokens.add makeToken(tkString, text, line, startCol)
    elif ch == '#':
      startCol = col
      text = readSymbol(a, i, col)
      tokens.add makeToken(tkPreprocessor, text, line, startCol)
    else:
      startCol = col
      text = readSymbol(a, i, col)
      tokens.add makeToken(tkSymbol, text, line, startCol)
  result = tokens
