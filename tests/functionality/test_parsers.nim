import strutils
import unittest
import c_nim_wrapper_bindr
import src/c_nim_wrapper_bindr/level3/type_mapper

proc wrapLines*(a: string): seq[string] =
  ## a: input C text
  ## Runs the default wrapper and returns generated output lines.
  result = wrapText(a, defaultConfig())

suite "parser regressions":
  test "object-like parenthesized define is not treated as function-like":
    let lines = wrapLines("""
#define GPIO_MODE_DEF_DISABLE         (0)
#define GPIO_MODE_DEF_INPUT           (BIT0)
typedef enum {
  GPIO_MODE_DISABLE = GPIO_MODE_DEF_DISABLE,
  GPIO_MODE_INPUT = GPIO_MODE_DEF_INPUT
} gpio_mode_t;
""")
    let output = lines.join("\n")
    check output.contains("const GPIO_MODE_DEF_DISABLE* = ( 0 )")
    check output.contains("template GPIO_MODE_DEF_INPUT*: untyped =")
    check not output.contains("template GPIO_MODE_DEF_DISABLE*(): untyped")
    check not output.contains("template GPIO_MODE_DEF_INPUT*(")
    check output.contains("GPIO_MODE_DISABLE")
    check output.contains("GPIO_MODE_INPUT")

  test "adjacent lparen define remains function-like":
    let lines = wrapLines("""
#define GPIO_MODE_DEF_INPUT(BIT0) (BIT0)
""")
    let output = lines.join("\n")
    check output.contains("template GPIO_MODE_DEF_INPUT*(BIT0: untyped): untyped =")
    check not output.contains("const GPIO_MODE_DEF_INPUT* =")

  test "quoted includes emit guarded sibling imports":
    let lines = wrapLines("#include \"esp_err.h\"\n")
    let output = lines.join("\n")
    check output.contains("import std/os")
    check output.contains("when fileExists(parentDir(currentSourcePath()) / \"esp_err_bindings.nim\"):")
    check output.contains("import ./esp_err_bindings")

  test "quoted includes emit prefix fallback imports for simple local headers":
    var cfg = defaultConfig()
    cfg.outputModuleStem = "freertos_task_bindings"
    let lines = wrapText("#include \"list.h\"\n", cfg)
    let output = lines.join("\n")
    check output.contains("when fileExists(parentDir(currentSourcePath()) / \"list_bindings.nim\"):")
    check output.contains("when fileExists(parentDir(currentSourcePath()) / \"freertos_list_bindings.nim\"):")

  test "typedef enum body emits enum members":
    let lines = wrapLines("""
typedef enum {
  LEDC_A = 0,
#if SOC_X
  LEDC_B = 1,
#endif
  LEDC_C
} ledc_mode_t;
""")
    let output = lines.join("\n")
    check output.contains("type ledc_mode_t*")
    check output.contains("= enum")
    check output.contains("LEDC_A")
    check output.contains("LEDC_B")
    check output.contains("LEDC_C")
    check not output.contains("distinct pointer")

  test "typedef enum keeps explicit member values":
    let lines = wrapLines("""
typedef enum {
  OQS_ERROR = -1,
  OQS_SUCCESS = 0
} OQS_STATUS;
""")
    let output = lines.join("\n")
    check output.contains("OQS_ERROR = - 1")
    check output.contains("OQS_SUCCESS = 0")

  test "typedef enum deduplicates repeated members":
    let lines = wrapLines("""
typedef enum {
  LEDC_SCLK = 0,
  LEDC_SCLK = 1,
  LEDC_X = 2
} ledc_clk_src_t;
""")
    let output = lines.join("\n")
    check output.contains("type ledc_clk_src_t*")
    check output.contains("LEDC_SCLK")
    check output.contains("LEDC_X")
    check output.find("LEDC_SCLK") == output.rfind("LEDC_SCLK")

  test "typedef enum with duplicate assigned values omits explicit assignments":
    let lines = wrapLines("""
typedef enum {
  BLAKE_A = 32,
  BLAKE_B = 32,
  BLAKE_C = 64
} blake_enum_t;
""")
    let output = lines.join("\n")
    check output.contains("BLAKE_A")
    check output.contains("BLAKE_B")
    check output.contains("BLAKE_C")
    check not output.contains("BLAKE_A = 32")
    check not output.contains("BLAKE_B = 32")

  test "typedef enum with complex C-only values omits explicit assignments":
    let lines = wrapLines("""
typedef enum {
  BLAKE2_DUMMY_1 = 1 / (int)(sizeof(blake2s_param) == BLAKE2S_OUTBYTES),
  BLAKE2_DUMMY_2 = 1 / (int)(sizeof(blake2b_param) == BLAKE2B_OUTBYTES)
} blake2_dummy_t;
""")
    let output = lines.join("\n")
    check output.contains("BLAKE2_DUMMY_1")
    check output.contains("BLAKE2_DUMMY_2")
    check not output.contains("sizeof")

  test "typedef struct skips preprocessor fields":
    let lines = wrapLines("""
typedef struct {
#if CONFIG_FOO
  int io_num;
#endif
  unsigned duty;
} led_cfg_t;
""")
    let output = lines.join("\n")
    check output.contains("type led_cfg_t*")
    check output.contains("io_num*")
    check output.contains("duty*")
    check output.contains(": cuint")
    check not output.contains("c_if")
    check not output.contains("endif")

  test "enum ignores preprocessor directives":
    let lines = wrapLines("""
enum gpio_mode {
  MODE_A = 1,
#if CONFIG_EXT
  MODE_B = 2,
#endif
  MODE_C
};
""")
    let output = lines.join("\n")
    check output.contains("type gpio_mode*")
    check output.contains("MODE_A")
    check output.contains("MODE_B")
    check output.contains("MODE_C")
    check not output.contains("c_if")
    check not output.contains("endif")

  test "enum keeps explicit member values":
    let lines = wrapLines("""
enum oqs_status {
  OQS_ERROR = -1,
  OQS_SUCCESS = 0
};
""")
    let output = lines.join("\n")
    check output.contains("OQS_ERROR = - 1")
    check output.contains("OQS_SUCCESS = 0")

  test "function pointer parameters remain intact":
    let lines = wrapLines("""
esp_err_t gpio_isr_register(void (*fn)(void *), void *arg);
""")
    let output = lines.join("\n")
    check output.contains("proc gpio_isr_register*(")
    check output.contains("fn: pointer")
    check output.contains("arg: pointer")
    check output.contains(": esp_err_t")

  test "void return emits proc without result type":
    let lines = wrapLines("void esp_restart(void);\n")
    let output = lines.join("\n")
    check output.contains("proc esp_restart*() {.importc.}")
    check not output.contains(": void")

  test "attribute-annotated function prototype parses once":
    let lines = wrapLines("void __attribute__((noreturn)) panic_now(const char *details);\n")
    let output = lines.join("\n")
    check output.contains("proc panic_now*(details: cstring) {.importc.}")
    check not output.contains("unparsed")

  test "api macro prefix does not replace return type":
    let lines = wrapLines("""
#define OQS_API __declspec(dllexport)
typedef enum {
  OQS_ERROR = 0,
  OQS_SUCCESS = 1
} OQS_STATUS;
OQS_API OQS_STATUS OQS_randombytes_switch_algorithm(const char *algorithm);
""")
    let output = lines.join("\n")
    check output.contains("proc OQS_randombytes_switch_algorithm*(algorithm: cstring): OQS_STATUS")
    check not output.contains("OQS_API_tyd")

  test "return expression function call is not parsed as prototype":
    let lines = wrapLines("""
static inline int f(int flags) {
  return (__builtin_ffs(flags));
}
""")
    let output = lines.join("\n")
    check not output.contains("proc builtin_ffs*")

  test "anonymous nested struct bitfield does not produce struct unsigned type":
    let lines = wrapLines("""
typedef struct {
  struct {
    unsigned int output_invert: 1;
  } flags;
} ledc_channel_config_t;
""")
    let output = lines.join("\n")
    check output.contains("output_invert*: cuint")
    check not output.contains(": unsigned")

  test "named inline struct field degrades to outer pointer field":
    let lines = wrapLines("""
typedef struct {
  struct etm_chan_flags {
    uint32_t allow_pd: 1;
  } flags;
} esp_etm_channel_config_t;
""")
    let output = lines.join("\n")
    check output.contains("flags*: pointer")
    check not output.contains("allow_pd*: etm_chan_flags")

suite "type mapper regressions":
  test "standalone unsigned and signed map to integer":
    check mapBuiltinType(@["unsigned"]) == "cuint"
    check mapBuiltinType(@["signed"]) == "cint"

  test "freertos runtime counter aliases map to concrete nim types":
    check mapBuiltinType(@["configRUN_TIME_COUNTER_TYPE_t"]) == "culong"
    check mapBuiltinType(@["configTLS_BLOCK_TYPE_t"]) == "pointer"
