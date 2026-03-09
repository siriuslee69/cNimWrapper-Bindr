import unittest
import src/c_nim_wrapper_bindr/level1/tokenizer
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils

proc makeState*(a: string): ParserState =
  ## a: input C text
  ## Builds a parser state with default wrapper config.
  var
    tokens: seq[Token] = tokenizeC(a)
    config: WrapperConfig = WrapperConfig(emitTemplates: true, emitComments: true,
      emitIncludeImports: true)
    s: ParserState = initState(tokens, config)
  result = s

proc lastIdentifier*(a: seq[Token]): string =
  ## a: token list
  ## Returns the last identifier text found in the list.
  var
    i: int = 0
    l: int = a.len
    name: string = ""
  while i < l:
    if a[i].kind == tkIdentifier:
      name = a[i].text
    inc i
  result = name

suite "utils basics":
  test "tokensToText skips newlines":
    var
      tokens: seq[Token] = tokenizeC("int a;\n")
      text: string = tokensToText(tokens)
    check text == "int a ;"

  test "collectUntilText reads statement":
    var
      s: ParserState = makeState("typedef int foo;")
      ok: bool = matchText(s, "typedef")
      items: seq[Token] = collectUntilText(s, ";", true)
      name: string = lastIdentifier(items)
    check ok
    check name == "foo"

