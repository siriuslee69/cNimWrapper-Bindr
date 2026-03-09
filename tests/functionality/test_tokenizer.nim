import unittest
import src/c_nim_wrapper_bindr/level1/tokenizer
import src/c_nim_wrapper_bindr/types

proc tokenTexts*(a: seq[Token]): seq[string] =
  ## a: token list
  ## Collects token texts into a sequence for assertions.
  var
    i: int = 0
    l: int = a.len
    items: seq[string] = @[]
  while i < l:
    items.add a[i].text
    inc i
  result = items

suite "tokenizeC basics":
  test "preprocessor define tokens":
    var
      tokens: seq[Token] = tokenizeC("#define FOO 1\n")
      texts: seq[string] = tokenTexts(tokens)
      l: int = tokens.len
    check l >= 4
    check tokens[0].kind == tkPreprocessor
    check tokens[0].text == "#"
    check tokens[1].text == "define"
    check tokens[2].text == "FOO"
    check texts.contains("1")

  test "string literal token":
    var
      tokens: seq[Token] = tokenizeC("const char* s = \"hi\";\n")
      kinds: seq[TokenKind] = @[]
      i: int = 0
      l: int = tokens.len
    while i < l:
      kinds.add tokens[i].kind
      inc i
    check kinds.contains(tkString)

