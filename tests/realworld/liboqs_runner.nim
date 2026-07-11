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
  ## Builds repo, build, wrapper, and test paths for liboqs headers.
  var
    repoDir: string = joinPath(a, "submodules", "liboqs")
    buildDir: string = buildSubDir(a, ["liboqs"])
    wrapperPath: string = joinPath(buildDir, "liboqs_wrapper.nim")
    testPath: string = joinPath(a, "tests", "realworld", "liboqs_test.nim")
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
  ## Builds linker flags for liboqs.
  var
    flags: string = "--passL:-loqs"
  result = flags

proc main*() =
  ## Builds liboqs wrappers and runs KEM/signature tests.
  var
    baseDir: string = findcNimWrapperDir()
    paths: tuple[repoDir: string, buildDir: string, wrapperPath: string, testPath: string,
      wrapperMain: string, installDir: string, libDir: string, binDir: string,
      useNestedBuildRoot: bool] = buildPaths(baseDir)
    headerPath: string = joinPath(paths.buildDir, "oqs_full_combined.h")
    buildCache: string = joinPath(paths.buildDir, "nimcache_wrapper")
    testCache: string = joinPath(paths.buildDir, "nimcache_test")
    wrapperCmd: string = ""
    testCmd: string = ""
    buildCmd: string = ""
    headerCmd: string = ""
    envKey: string = ""
    envPath: string = ""
    libEnvKey: string = ""
    linkFlags: string = ""
    testDefine: string = ""
    code: int = 0
  if not dirExists(paths.repoDir):
    echo "Repo not found: " & paths.repoDir
    quit(1)
  createDir(paths.buildDir)
  buildCmd = "nim r tools/build_liboqs.nim"
  code = runCmd(buildCmd)
  if code != 0:
    quit(code)
  headerCmd = "nim r tools/prepare_liboqs_header.nim"
  code = runCmd(headerCmd)
  if code != 0:
    quit(code)
  if not fileExists(headerPath):
    echo "Combined header not found: " & headerPath
    quit(1)
  wrapperCmd = "nim c -r --nimcache:" & quoteShell(buildCache) & " " &
    quoteShell(paths.wrapperMain) & " " & quoteShell(headerPath) & " " &
    quoteShell(paths.wrapperPath)
  code = runCmd(wrapperCmd)
  if code != 0:
    quit(code)
  envKey = sharedLibEnvKey()
  when defined(windows):
    envPath = paths.binDir
  else:
    envPath = paths.libDir
  prependEnvPath(envKey, envPath)
  libEnvKey = "LIBRARY_PATH"
  prependEnvPath(libEnvKey, paths.libDir)
  linkFlags = buildLinkFlags(paths.libDir)
  if paths.useNestedBuildRoot:
    testDefine = " -d:bindrBuildsNested"
  testCmd = "nim c -r --nimcache:" & quoteShell(testCache) & " " & linkFlags & testDefine &
    " " & quoteShell(paths.testPath)
  code = runCmd(testCmd)
  if code != 0:
    quit(code)

when isMainModule:
  main()