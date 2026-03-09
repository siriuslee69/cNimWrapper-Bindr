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
    testPath: string, wrapperMain: string, useNestedBuildRoot: bool] =
  ## a: cNimWrapper base directory
  ## Builds repo, build, wrapper, and test paths for BLAKE2 reference code.
  var
    repoDir: string = joinPath(a, "submodules", "BLAKE2", "ref")
    buildDir: string = buildSubDir(a, ["BLAKE2"])
    wrapperPath: string = joinPath(buildDir, "blake2_wrapper.nim")
    testPath: string = joinPath(a, "tests", "realworld", "blake2_ref_test.nim")
    wrapperMain: string = joinPath(a, "c_nim_wrapper_bindr.nim")
    useNestedBuildRoot: bool = usingNestedBuildRoot(a)
  result = (repoDir: repoDir, buildDir: buildDir, wrapperPath: wrapperPath, testPath: testPath,
    wrapperMain: wrapperMain, useNestedBuildRoot: useNestedBuildRoot)

proc runCmd*(a: string): int =
  ## a: command line string
  ## Executes the command and returns the exit code.
  var
    res: tuple[output: string, exitCode: int] = execCmdEx(a)
  if res.output.len > 0:
    echo res.output
  result = res.exitCode

proc main*() =
  ## Builds BLAKE2 wrappers and runs keyed blake2s tests.
  var
    baseDir: string = findcNimWrapperDir()
    paths: tuple[repoDir: string, buildDir: string, wrapperPath: string, testPath: string,
      wrapperMain: string, useNestedBuildRoot: bool] = buildPaths(baseDir)
    headerPath: string = joinPath(paths.repoDir, "blake2.h")
    buildCache: string = joinPath(paths.buildDir, "nimcache_wrapper")
    testCache: string = joinPath(paths.buildDir, "nimcache_test")
    wrapperCmd: string = ""
    testCmd: string = ""
    testDefine: string = ""
    code: int = 0
  if not dirExists(paths.repoDir):
    echo "Repo not found: " & paths.repoDir
    quit(1)
  createDir(paths.buildDir)
  wrapperCmd = "nim c -r --nimcache:" & quoteShell(buildCache) & " " &
    quoteShell(paths.wrapperMain) & " " & quoteShell(headerPath) & " " &
    quoteShell(paths.wrapperPath)
  code = runCmd(wrapperCmd)
  if code != 0:
    quit(code)
  if paths.useNestedBuildRoot:
    testDefine = " -d:bindrBuildsNested"
  testCmd = "nim c -r --nimcache:" & quoteShell(testCache) & testDefine & " " &
    quoteShell(paths.testPath)
  code = runCmd(testCmd)
  if code != 0:
    quit(code)

when isMainModule:
  main()