# This module wires together the default parse order <- handled by buildDefaultRegistry().
# It registers parsers for concrete C forms in this order <- handled by buildDefaultRegistry():
# preprocessor (non-define/include), extern "C", #define, #include,
# static const, enum, macro-wrapped struct, struct, typedef, function prototype.
import src/c_nim_wrapper_bindr/level2/parser_core
import src/c_nim_wrapper_bindr/level3/define_parser
import src/c_nim_wrapper_bindr/level3/enum_parser
import src/c_nim_wrapper_bindr/level2/extern_parser
import src/c_nim_wrapper_bindr/level4/function_parser
import src/c_nim_wrapper_bindr/level2/include_parser
import src/c_nim_wrapper_bindr/level4/macro_struct_parser
import src/c_nim_wrapper_bindr/level2/preprocessor_parser
import src/c_nim_wrapper_bindr/level3/static_const_parser
import src/c_nim_wrapper_bindr/level3/struct_parser
import src/c_nim_wrapper_bindr/level4/typedef_parser

proc buildDefaultRegistry*(): ParserRegistry =
  ## returns the default parser registry
  ## Registers the standard parsers in the preferred order.
  var
    reg: ParserRegistry = initRegistry()
  addParser(reg, tryParsePreprocessorDirective)
  addParser(reg, tryParseExternBlock)
  addParser(reg, tryParseExternClose)
  addParser(reg, tryParseDefine)
  addParser(reg, tryParseInclude)
  addParser(reg, tryParseStaticConst)
  addParser(reg, tryParseEnum)
  addParser(reg, tryParseMacroWrappedStruct)
  addParser(reg, tryParseStruct)
  addParser(reg, tryParseTypedef)
  addParser(reg, tryParseFunction)
  result = reg
