# This module parses the following C forms:
# MACRO(struct Name { field_type field_name; });
# It splits the wrapper into:
# - macro prefix + "(" <- handled by isMacroStructStart(), consumeMacroPrefix()
# - inner struct parsing <- handled by tryParseStruct()
# - trailing ")" and optional ";" <- handled by consumeMacroSuffix()
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils
import src/c_nim_wrapper_bindr/level3/struct_parser

proc isMacroStructStart*(s: ParserState): bool =
  ## s: parser state
  ## Returns true when a macro-wrapped struct declaration is ahead.
  var
    tok0: Token = peekToken(s, 0)
    tok1: Token = peekToken(s, 1)
    tok2: Token = peekToken(s, 2)
  if tok0.kind != tkIdentifier:
    result = false
    return
  if tok1.text != "(":
    result = false
    return
  if tok2.text != "struct":
    result = false
    return
  result = true

proc consumeMacroPrefix*(s: var ParserState) =
  ## s: parser state
  ## Consumes the macro name and opening parenthesis.
  discard advanceToken(s)
  discard advanceToken(s)

proc consumeMacroSuffix*(s: var ParserState) =
  ## s: parser state
  ## Consumes a trailing ")" and optional ";" after a wrapped struct.
  discard skipNewlines(s)
  if matchText(s, ")"):
    discard skipNewlines(s)
    discard matchText(s, ";")

proc tryParseMacroWrappedStruct*(s: var ParserState): bool =
  ## s: parser state
  ## Parses structs wrapped in macro calls like `MACRO(struct ...)`.
  var
    mark: int = s.pos
  discard skipNewlines(s)
  if not isMacroStructStart(s):
    s.pos = mark
    result = false
    return
  consumeMacroPrefix(s)
  if not tryParseStruct(s):
    s.pos = mark
    result = false
    return
  consumeMacroSuffix(s)
  result = true
