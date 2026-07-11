import os
import osproc
import build_paths

const
  aesHeader* = "submodules/tiny-AES-c/aes.h"
  blakeHeader* = "submodules/BLAKE2/ref/blake2.h"
  opensslHeader* = "submodules/openssl/include/openssl/sha.h"
  libsodiumHeader* = "submodules/libsodium/src/libsodium/include/sodium/crypto_hash_sha256.h"
  liboqsHeader* = "submodules/liboqs/src/common/sha2/sha2.h"

let
  buildTargets* = @[
    "tiny-AES-c",
    "BLAKE2",
    "openssl",
    "libsodium",
    "liboqs"
  ]

proc findcNimWrapperDir*(): string =
  ## Returns the cNimWrapper base directory based on this file's location.
  var
    sourceFile: string = currentSourcePath()
    sourceDir: string = ""
    baseDir: string = ""
  sourceDir = splitFile(sourceFile).dir
  baseDir = parentDir(sourceDir)
  result = baseDir

proc buildDirs*(a: string): seq[string] =
  ## a: cNimWrapper base directory
  ## Returns build output directories under the active build root.
  var
    dirs: seq[string] = @[]
    i: int = 0
    l: int = buildTargets.len
  while i < l:
    dirs.add buildSubDir(a, [buildTargets[i]])
    inc i
  result = dirs

proc runCmd*(a: string): int =
  ## a: command line string
  ## Executes the command and returns the exit code.
  var
    res: tuple[output: string, exitCode: int] = execCmdEx(a)
  if res.output.len > 0:
    echo res.output
  result = res.exitCode

proc needSubmodules*(): bool =
  ## Returns true when required submodule headers are missing.
  var
    hasAes: bool = fileExists(aesHeader)
    hasBlake: bool = fileExists(blakeHeader)
    hasOpenSsl: bool = fileExists(opensslHeader)
    hasLibsodium: bool = fileExists(libsodiumHeader)
    hasLiboqs: bool = fileExists(liboqsHeader)
  result = not (hasAes and hasBlake and hasOpenSsl and hasLibsodium and hasLiboqs)

proc ensureSubmodules*() =
  ## Ensures submodules are present, fetching when headers are missing.
  var
    code: int = 0
  if not needSubmodules():
    return
  code = runCmd("git submodule update --init --recursive")
  if code != 0:
    quit(code)

proc ensureBuildDirs*() =
  ## Creates build directories for wrapper outputs.
  var
    baseDir: string = findcNimWrapperDir()
    dirs: seq[string] = buildDirs(baseDir)
    i: int = 0
    l: int = dirs.len
  while i < l:
    createDir(dirs[i])
    inc i

proc main*() =
  ## Runs environment setup based on CLI flags.
  var
    args: seq[string] = commandLineParams()
    doSubmodules: bool = false
    doBuildDirs: bool = false
    i: int = 0
    l: int = args.len
    arg: string = ""
  if l == 0:
    doSubmodules = true
    doBuildDirs = true
  else:
    while i < l:
      arg = args[i]
      if arg == "--submodules":
        doSubmodules = true
      elif arg == "--builddirs":
        doBuildDirs = true
      inc i
  if doSubmodules:
    ensureSubmodules()
  if doBuildDirs:
    ensureBuildDirs()

when isMainModule:
  main()
