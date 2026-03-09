import os
import strutils
import src/c_nim_wrapper_bindr/level1/debugger
import src/c_nim_wrapper_bindr/types
import src/c_nim_wrapper_bindr/level1/tokenizer
import src/c_nim_wrapper_bindr/level1/utils
import src/c_nim_wrapper_bindr/level2/parser_core
import src/c_nim_wrapper_bindr/level5/default_parsers

proc defaultConfig*(): WrapperConfig =
  ## returns the default wrapper config
  ## Enables template and comment emission by default.
  var
    cfg: WrapperConfig = WrapperConfig(emitTemplates: true, emitComments: true,
      emitIncludeImports: true, outputModuleStem: "")
  result = cfg

proc wrapTextState*(a: string, b: WrapperConfig): ParserState =
  ## a: input C source text
  ## b: wrapper config
  ## Tokenizes and parses input C text into a parser state.
  ## Example: `wrapTextState("int foo(void);", defaultConfig())` yields output lines.
  var
    tokens: seq[Token] = tokenizeC(a)
    state: ParserState = initState(tokens, b)
    registry: ParserRegistry = buildDefaultRegistry()
  parseAll(state, registry)
  result = state

proc wrapText*(a: string, b: WrapperConfig): seq[string] =
  ## a: input C source text
  ## b: wrapper config
  ## Tokenizes and parses input C text into Nim output lines.
  ## Example: `wrapText("int foo(void);", defaultConfig())` yields a proc line.
  var
    state: ParserState = wrapTextState(a, b)
  result = state.output

proc wrapFile*(a: string, b: string, c: WrapperConfig) =
  ## a: input file path
  ## b: output file path
  ## c: wrapper config
  ## Reads a C header file and writes a Nim wrapper file.
  var
    inputText: string = readFile(a)
    cfg: WrapperConfig = c
    state: ParserState
    outputText: string = ""
  cfg.outputModuleStem = toLowerAscii(splitFile(b).name)
  state = wrapTextState(inputText, cfg)
  outputText = state.output.join("\n")
  writeFile(b, outputText)
  writeDebugJson(b, state.debugEntries)

proc main*() =
  ## entry point for CLI usage
  ## Parses CLI args and runs a file-to-file wrapper pass.
  ## Example: `cNimWrapper input.h output.nim`.
  var
    args: seq[string] = commandLineParams()
    inputPath: string = ""
    outputPath: string = ""
    config: WrapperConfig
  if args.len < 2:
    echo "usage: cNimWrapper <input.h> <output.nim>"
    return
  inputPath = args[0]
  outputPath = args[1]
  config = defaultConfig()
  wrapFile(inputPath, outputPath, config)
  echo "wrote: " & outputPath

when isMainModule:
  main()

