# This module parses the following C forms:
# #include <stdio.h>
# #include "local.h"
# It captures everything after "include" and emits a comment marker in the
# output stream <- handled by tryParseInclude().
import strutils
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/utils

proc hasOutputLine*(s: ParserState, b: string): bool =
  ## s: parser state
  ## b: exact output line
  ## Returns true if the exact output line has already been emitted.
  var
    i: int = 0
    l: int = s.output.len
  while i < l:
    if s.output[i] == b:
      result = true
      return
    inc i
  result = false

proc normalizeHeaderToModule*(a: string): string =
  ## a: include path like `driver/gpio.h`
  ## Returns a best-effort Nim module stem like `driver_gpio_bindings`.
  var
    path: string = toLowerAscii(a)
    body: string = ""
    i: int = 0
    l: int = 0
    ch: char
    outName: string = ""
    startIdx: int = 0
  if not path.endsWith(".h"):
    result = ""
    return
  body = path[0 ..< path.len - 2]
  l = body.len
  while i < l:
    ch = body[i]
    if (ch >= 'a' and ch <= 'z') or (ch >= '0' and ch <= '9'):
      outName.add ch
    else:
      if outName.len == 0 or outName[^1] != '_':
        outName.add '_'
    inc i
  while outName.len > 0 and outName[^1] == '_':
    outName.setLen(outName.len - 1)
  while startIdx < outName.len and outName[startIdx] == '_':
    inc startIdx
  if startIdx > 0:
    outName = outName[startIdx .. ^1]
  if outName.len == 0:
    result = ""
    return
  if (outName[0] >= '0' and outName[0] <= '9') or outName[0] == '_':
    outName = "c_" & outName
  result = outName & "_bindings"

proc parseIncludeTarget*(a: seq[Token]): tuple[path: string, isQuoted: bool] =
  ## a: include body tokens after the `include` keyword
  ## Extracts header path and whether include used quotes.
  var
    l: int = a.len
    text: string = ""
    i: int = 0
  if l == 1 and a[0].kind == tkString:
    text = a[0].text
    if text.len >= 2 and text[0] == '"' and text[^1] == '"':
      result = (text[1 ..< text.len - 1], true)
    else:
      result = (text, true)
    return
  if l >= 3 and a[0].text == "<" and a[l - 1].text == ">":
    while i < l - 1:
      if i > 0:
        text.add a[i].text
      inc i
    result = (text, false)
    return
  result = ("", false)

proc emitConditionalImport*(s: var ParserState, a: string) =
  ## s: parser state
  ## a: module stem without `.nim`
  ## Emits a file-exists-guarded relative import for generated sibling bindings.
  var
    importOs: string = "import std/os"
    condLine: string = "when fileExists(parentDir(currentSourcePath()) / \"" & a & ".nim\"):"
    importLine: string = "  import ./" & a
    exportLine: string = "  export " & a
  if not hasOutputLine(s, importOs):
    emitLine(s, importOs)
  if not hasOutputLine(s, condLine):
    emitLine(s, condLine)
    emitLine(s, importLine)
    emitLine(s, exportLine)

proc hasText*(a: seq[string], b: string): bool =
  ## a: sequence of strings
  ## b: candidate string
  ## Returns true when b already exists in a.
  var
    i: int = 0
    l: int = a.len
  while i < l:
    if a[i] == b:
      result = true
      return
    inc i
  result = false

proc addCandidate*(a: var seq[string], b: string) =
  ## a: mutable candidate list
  ## b: candidate module stem
  ## Adds a non-empty candidate once.
  if b.len == 0:
    return
  if not hasText(a, b):
    a.add b

proc removeBindingsSuffix*(a: string): string =
  ## a: module stem
  ## Strips trailing `_bindings` when present.
  if a.endsWith("_bindings") and a.len > "_bindings".len:
    result = a[0 ..< a.len - "_bindings".len]
  else:
    result = a

proc inferPrimaryPrefix*(a: string): string =
  ## a: output module stem
  ## Returns the first segment before `_`, or empty when absent.
  var
    stem: string = removeBindingsSuffix(toLowerAscii(a))
    idx: int = stem.find('_')
  if idx <= 0:
    result = ""
  else:
    result = stem[0 ..< idx]

proc collectIncludeImportCandidates*(s: ParserState, a: string, b: string): seq[string] =
  ## s: parser state
  ## a: include path
  ## b: normalized module name (with `_bindings` suffix)
  ## Returns import candidates, including optional prefixed fallback.
  var
    candidates: seq[string] = @[]
    prefix: string = inferPrimaryPrefix(s.config.outputModuleStem)
    prefixed: string = ""
    includeLower: string = toLowerAscii(a)
  addCandidate(candidates, b)
  if prefix.len > 0 and includeLower.find('/') < 0 and includeLower.find('\\') < 0:
    if not b.startsWith(prefix & "_"):
      prefixed = prefix & "_" & b
      addCandidate(candidates, prefixed)
  result = candidates

proc tryParseInclude*(s: var ParserState): bool =
  ## s: parser state
  ## Parses C #include lines and emits a Nim comment marker.
  ## Example: `#include <stdio.h>` becomes `# c include: <stdio.h>`.
  var
    mark: int = s.pos
    bodyTokens: seq[Token] = @[]
    bodyText: string = ""
    includePath: string = ""
    isQuoted: bool = false
    moduleName: string = ""
    moduleCandidates: seq[string] = @[]
    i: int = 0
    info: tuple[path: string, isQuoted: bool]
  discard skipNewlines(s)
  if not matchText(s, "#"):
    s.pos = mark
    result = false
    return
  if not matchText(s, "include"):
    s.pos = mark
    result = false
    return
  bodyTokens = collectUntilNewline(s)
  bodyText = tokensToText(bodyTokens)
  info = parseIncludeTarget(bodyTokens)
  includePath = info.path
  isQuoted = info.isQuoted
  if s.config.emitIncludeImports and isQuoted and includePath.len > 0:
    moduleName = normalizeHeaderToModule(includePath)
    if moduleName.len > 0:
      moduleCandidates = collectIncludeImportCandidates(s, includePath, moduleName)
      while i < moduleCandidates.len:
        emitConditionalImport(s, moduleCandidates[i])
        inc i
  emitLine(s, "# c include: " & bodyText)
  result = true
