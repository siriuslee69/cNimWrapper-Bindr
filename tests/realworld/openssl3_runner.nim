import os
import osproc
import ../../tools/build_paths

proc findcNimWrapperDir*(): string =
  ## Returns the cNimWrapper base directory based on this file's location.
  var
    sourceFile: string = currentSourcePath()
    sourceDir: string = ""
    baseDir: string = ""
  sourceDir = splitFile(sourceFile).dir
  baseDir = parentDir(parentDir(sourceDir))
  result = baseDir

proc buildPaths*(a: string): tuple[repoDir: string, buildDir: string, wrapperPath: string,
    testPath: string, wrapperMain: string, installDir: string, libDir: string, binDir: string,
    useNestedBuildRoot: bool] =
  ## a: cNimWrapper base directory
  ## Builds repo, build, wrapper, and test paths for OpenSSL SHA headers.
  var
    repoDir: string = joinPath(a, "submodules", "openssl")
    buildDir: string = buildSubDir(a, ["openssl"])
    wrapperPath: string = joinPath(buildDir, "openssl_sha_wrapper.nim")
    testPath: string = joinPath(a, "tests", "realworld", "openssl3_test.nim")
    wrapperMain: string = joinPath(a, "c_nim_wrapper_bindr.nim")
    installDir: string = joinPath(buildDir, "install")
    libDir: string = joinPath(installDir, "lib")
    binDir: string = joinPath(installDir, "bin")
    useNestedBuildRoot: bool = usingNestedBuildRoot(a)
  result = (repoDir: repoDir, buildDir: buildDir, wrapperPath: wrapperPath, testPath: testPath,
    wrapperMain: wrapperMain, installDir: installDir, libDir: libDir, binDir: binDir,
    useNestedBuildRoot: useNestedBuildRoot)

proc runCmd*(a: string): int =
  ## a: command line string
  ## Executes the command and returns the exit code.
  var
    res: tuple[output: string, exitCode: int] = execCmdEx(a)
  if res.output.len > 0:
    echo res.output
  result = res.exitCode

proc sharedLibEnvKey*(): string =
  ## Returns the environment key for shared library lookup on the platform.
  var
    key: string = ""
  when defined(windows):
    key = "PATH"
  elif defined(macosx):
    key = "DYLD_LIBRARY_PATH"
  else:
    key = "LD_LIBRARY_PATH"
  result = key

proc prependEnvPath*(a: string, b: string) =
  ## a: environment variable name
  ## b: path to prepend
  ## Prepends a path to an environment variable.
  var
    current: string = getEnv(a)
    combined: string = ""
  if current.len == 0:
    combined = b
  else:
    combined = b & $PathSep & current
  putEnv(a, combined)

proc buildLinkFlags*(a: string): string =
  ## a: library directory
  ## Builds linker flags for OpenSSL libcrypto.
  var
    flags: string = "--passL:-lcrypto"
  when defined(windows):
    flags = flags & " --passL:-lws2_32 --passL:-lcrypt32 --passL:-ladvapi32" &
      " --passL:-lgdi32 --passL:-luser32"
  elif defined(linux):
    flags = flags & " --passL:-ldl --passL:-pthread"
  result = flags

proc resolveLibDir*(a: string): string =
  ## a: install directory
  ## Returns lib64 when present, otherwise lib.
  var
    lib64Dir: string = joinPath(a, "lib64")
    libDir: string = joinPath(a, "lib")
  if dirExists(lib64Dir):
    result = lib64Dir
  else:
    result = libDir

proc main*() =
  ## Builds OpenSSL wrappers and runs SHA256 tests against known vectors.
  var
    baseDir: string = findcNimWrapperDir()
    paths: tuple[repoDir: string, buildDir: string, wrapperPath: string, testPath: string,
      wrapperMain: string, installDir: string, libDir: string, binDir: string,
      useNestedBuildRoot: bool] = buildPaths(baseDir)
    headerPath: string = joinPath(paths.repoDir, "include", "openssl", "sha.h")
    buildCache: string = joinPath(paths.buildDir, "nimcache_wrapper")
    testCache: string = joinPath(paths.buildDir, "nimcache_test")
    wrapperCmd: string = ""
    testCmd: string = ""
    buildCmd: string = ""
    envKey: string = ""
    envPath: string = ""
    linkFlags: string = ""
    libDir: string = ""
    libEnvKey: string = ""
    testDefine: string = ""
    code: int = 0
  if not dirExists(paths.repoDir):
    echo "Repo not found: " & paths.repoDir
    quit(1)
  createDir(paths.buildDir)
  buildCmd = "nim r tools/build_openssl.nim"
  code = runCmd(buildCmd)
  if code != 0:
    quit(code)
  wrapperCmd = "nim c -r --nimcache:" & quoteShell(buildCache) & " " &
    quoteShell(paths.wrapperMain) & " " & quoteShell(headerPath) & " " &
    quoteShell(paths.wrapperPath)
  code = runCmd(wrapperCmd)
  if code != 0:
    quit(code)
  envKey = sharedLibEnvKey()
  libDir = resolveLibDir(paths.installDir)
  when defined(windows):
    envPath = paths.binDir
  else:
    envPath = libDir
  prependEnvPath(envKey, envPath)
  libEnvKey = "LIBRARY_PATH"
  prependEnvPath(libEnvKey, libDir)
  linkFlags = buildLinkFlags(libDir)
  if paths.useNestedBuildRoot:
    testDefine = " -d:bindrBuildsNested"
  testCmd = "nim c -r --nimcache:" & quoteShell(testCache) & " " & linkFlags & testDefine &
    " " & quoteShell(paths.testPath)
  code = runCmd(testCmd)
  if code != 0:
    quit(code)

when isMainModule:
  main()