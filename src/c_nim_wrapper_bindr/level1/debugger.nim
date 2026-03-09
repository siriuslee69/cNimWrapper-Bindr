import std/json
import std/os
import src/c_nim_wrapper_bindr/types

proc recordDebug*(s: var ParserState, a: string, b: string, c: Token, d: string) =
  ## s: parser state
  ## a: debug entry kind
  ## b: debug entry reason
  ## c: token reference
  ## d: context text
  ## Appends a debug entry to the parser state.
  var
    entry: DebugEntry
  entry.kind = a
  entry.reason = b
  entry.line = c.line
  entry.col = c.col
  entry.text = c.text
  entry.context = d
  s.debugEntries.add entry

proc recordCollision*(s: var ParserState, a: string, b: string, c: string) =
  ## s: parser state
  ## a: requested Nim name
  ## b: original C name
  ## c: unique Nim name
  ## Records a naming collision with the chosen unique name.
  var
    entry: DebugEntry
  entry.kind = "collision"
  entry.reason = "name_collision"
  entry.line = 0
  entry.col = 0
  entry.text = b
  entry.context = a & " -> " & c
  s.debugEntries.add entry

proc buildDebugJson*(a: seq[DebugEntry]): JsonNode =
  ## a: debug entries
  ## Returns a JsonNode representing the debug entries.
  var
    root: JsonNode = newJObject()
    items: JsonNode = newJArray()
    entry: DebugEntry
    node: JsonNode
    l: int = a.len
  for i in 0 ..< l:
    entry = a[i]
    node = newJObject()
    node["kind"] = %entry.kind
    node["reason"] = %entry.reason
    node["line"] = %entry.line
    node["col"] = %entry.col
    node["text"] = %entry.text
    node["context"] = %entry.context
    items.add node
  root["entries"] = items
  root["count"] = %l
  result = root

proc debugPathFor*(a: string): string =
  ## a: output path
  ## Returns the path for the debug JSON file next to the output.
  var
    base: string = a
  result = changeFileExt(base, ".debug.json")

proc writeDebugJson*(a: string, b: seq[DebugEntry]) =
  ## a: output path
  ## b: debug entries
  ## Writes the debug JSON file next to the output.
  var
    path: string = debugPathFor(a)
    node: JsonNode = buildDebugJson(b)
  writeFile(path, node.pretty())
