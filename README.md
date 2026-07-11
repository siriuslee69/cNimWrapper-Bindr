# cNimWrapper-Bindr

WARNING: Use at your own risk. This project is "vibe" coded.

Modular C header wrapper generator for Nim, with small real-world validation harnesses.

This README explains how the parser works, module order, naming rules, and debug output.

-------------------------------------------------------------------------------
Quick start
-------------------------------------------------------------------------------

```sh
nim c -r c_nim_wrapper_bindr.nim <input.h> <output.nim>
```

This writes:
- `output.nim` (bindings)
- `output.debug.json` (debug markers and collisions)

-------------------------------------------------------------------------------
High-level pipeline
-------------------------------------------------------------------------------

```
    C header text
          |
          v
      tokenizer
          |
          v
    parser registry (ordered)
          |
          v
     output lines + debug log
          |
          v
  output.nim + output.debug.json
```

-------------------------------------------------------------------------------
Module map (what each file does)
-------------------------------------------------------------------------------

Core:
- `c_nim_wrapper_bindr.nim`: CLI + file I/O; writes debug JSON.
- `src/types.nim`: token types, parser state, debug entry type.
- `src/name_mangle.nim`: sanitize identifiers, importc pragmas.
- `src/level1/tokenizer.nim`: turns C text into flat tokens with line/col.
- `src/level1/utils.nim`: token helpers and output helpers.
- `src/level1/debugger.nim`: debug entry collection + JSON writer.
- `src/level2/parser_core.nim`: runs parsers in order; logs unparsed tokens.
- `src/level3/type_mapper.nim`: maps C types to Nim types with pointer depth.
- `src/level5/default_parsers.nim`: parser registry order.

Parsers (each handles one C shape):
- `src/level2/preprocessor_parser.nim`: consumes non-define/include directives.
- `src/level2/extern_parser.nim`: consumes `extern "C" { ... }` blocks.
- `src/level2/include_parser.nim`: `#include` to output marker.
- `src/level3/define_parser.nim`: `#define` to `const` or `template`.
- `src/level3/static_const_parser.nim`: `static const` variables with simple init.
- `src/level3/enum_parser.nim`: `enum` to Nim enum.
- `src/level4/macro_struct_parser.nim`: `MACRO(struct ...)` wrappers.
- `src/level3/struct_parser.nim`: `struct` to Nim object.
- `src/level4/typedef_parser.nim`: `typedef` to Nim alias or object (struct typedefs).
- `src/level4/function_parser.nim`: function prototypes to `proc`.

Naming + debug helpers:
- `src/level2/name_registry.nim`: collision resolution + tracking.
- `src/level1/cast_utils.nim`: strips leading C casts like `((long)0)` in init/defines.

-------------------------------------------------------------------------------
Parser order (exact)
-------------------------------------------------------------------------------

The registry order is important. The default order is:

```
1) preprocessor_parser  (non-define/include directives)
2) extern_parser        (extern "C" { ... } blocks)
3) define_parser        (#define -> const/template)
4) include_parser       (#include -> comment)
5) static_const_parser  (static const vars)
6) enum_parser          (enum -> Nim enum)
7) macro_struct_parser  (MACRO(struct ...))
8) struct_parser        (struct -> object)
9) typedef_parser       (typedef -> distinct pointer or object)
10) function_parser     (prototype -> proc)
```

If no parser matches, `parser_core` consumes one token and logs it as `unparsed`.

-------------------------------------------------------------------------------
Name mangling and collisions
-------------------------------------------------------------------------------

We sanitize every emitted name, then reserve a unique Nim identifier.

Sanitization rules (in `src/name_mangle.nim`):
- Strip leading and trailing underscores: `_my_func_` -> `my_func`
- If invalid or Nim keyword, prefix with `c_`: `type` -> `c_type`
- Parameters use `p_` prefix or `p{index}` fallback

Collision rules (in `src/level2/name_registry.nim`):
1) Try base name (sanitized)
2) If taken, try kind-specific suffix:
   - `struct` -> `_str` (ex: `foo_str`)
   - `typedef` -> `_tyd` (ex: `foo_tyd`)
3) If still taken, append numeric suffixes (`_1`, `_2`, ...)

All renamed symbols preserve the original C name via `importc`.

Example:
```
// C
struct blake2s_param__ { ... };
typedef struct blake2s_param__ blake2s_param;

// Nim (collision resolution)
type
  blake2s_param_str* {.importc: "blake2s_param__".} = object ...
  blake2s_param_tyd* {.importc: "blake2s_param".} = object ...
```

-------------------------------------------------------------------------------
Debug output (output.debug.json)
-------------------------------------------------------------------------------

Every wrapper run writes a debug JSON file next to the output.

What is logged:
- `unparsed`: a token was not handled by any parser
- `skipped`: a directive was intentionally consumed
  - `preprocessor`: #if/#endif/#pragma/etc (non-define/include)
  - `extern_block`: `extern "C" {`
  - `extern_block_end`: closing brace for the extern block
- `collision`: a name was renamed to avoid duplicate Nim symbols
- `static_const_*`: static const values we skipped (missing/complex init)

Example entry:
```json
{
  "kind": "collision",
  "reason": "name_collision",
  "line": 0,
  "col": 0,
  "text": "blake2s_param",
  "context": "blake2s_param -> blake2s_param_tyd"
}
```

Tip: if you want to audit parser coverage, search for `unparsed` entries.

-------------------------------------------------------------------------------
Examples (what gets generated)
-------------------------------------------------------------------------------

Function prototype:
```
// C
int foo(const uint8_t* in, size_t n);

// Nim
proc foo*(p_in: ptr uint8, n: csize_t): cint {.importc.}
```

Struct typedef:
```
// C
typedef struct OQS_KEM { const char * method_name; size_t length_public_key; } OQS_KEM;

// Nim
type OQS_KEM* {.importc: "OQS_KEM".} = object
  method_name*: cstring
  length_public_key*: csize_t
```

Define -> const:
```
// C
#define AES_BLOCKLEN 16

// Nim
const AES_BLOCKLEN* = 16
```

Define -> template:
```
// C
#define MAX(a, b) ((a) > (b) ? (a) : (b))

// Nim
template MAX*(a: untyped, b: untyped): untyped =
  ## C macro: ((a) > (b) ? (a) : (b))
  discard
```

Static const:
```
// C
static const WGPUTextureUsage WGPUTextureUsage_None = 0x0;

// Nim
const WGPUTextureUsage_None* = 0x0
```

Macro-wrapped struct:
```
// C
BLAKE2_PACKED(struct blake2s_param__ { ... });

// Nim
type blake2s_param_str* {.importc: "blake2s_param__".} = object
  ...
```

Extern "C":
```
// C
#if defined(__cplusplus)
extern "C" {
#endif
...
#if defined(__cplusplus)
}
#endif
```
The extern block is skipped and logged in `output.debug.json`.

-------------------------------------------------------------------------------
Test coverage (realworld)
-------------------------------------------------------------------------------

- `tiny-AES-c`: ECB/CBC/CTR vectors.
- `BLAKE2`: reference blake2s keyed vector.
- `libsodium`: SHA256/SHA512/BLAKE2b-256, XChaCha20 stream, AES256-GCM (if available).
- `liboqs`: KEM roundtrips (Kyber/McEliece), SIG sign/verify (Falcon).

Each runner regenerates the wrapper before building the test binary.

Note: test repos live in git submodules under `submodules/`. See their
licenses in their respective repositories.

-------------------------------------------------------------------------------
Layout
-------------------------------------------------------------------------------

- `c_nim_wrapper_bindr.nim`: CLI entry point.
- `src/`: tokenizer, parser registry, parser modules.
- `tests/functionality/`: unit tests for tokenizer and helpers.
- `tests/realworld/`: wrapper + validation runners for real C libraries (AES, BLAKE2, libsodium, liboqs).
- `submodules/`: C repos (submodules).
- `testBuilds/`: generated wrappers, combined headers, and build artifacts.

-------------------------------------------------------------------------------
Nimble tasks
-------------------------------------------------------------------------------

- `nimble build_repos`
- `nimble test_functionality`
- `nimble test_realworld`
- `nimble test_all`
- `nimble setup`
- `nimble start`



