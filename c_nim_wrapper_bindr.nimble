import std/[os, strutils]

version       = "0.1.0"
author        = "siriuslee69"
description   = "Modular C header wrapper generator for Nim."
license       = "UNLICENSED"
srcDir        = "src"

proc activeBuildRootRel(): string =
  if dirExists(joinPath("builds", "testBuilds")):
    return joinPath("builds", "testBuilds")
  if dirExists("testBuilds"):
    return "testBuilds"
  if dirExists("builds"):
    return joinPath("builds", "testBuilds")
  result = "testBuilds"

let buildRootRel = activeBuildRootRel()

proc toSlashPath(p: string): string =
  result = p.replace('\\', '/')

task build_aes, "Generate wrapper for tiny-AES-c":
  let outFile = toSlashPath(joinPath(buildRootRel, "tiny-AES-c", "aes_wrapper.nim"))
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nim c -r c_nim_wrapper_bindr.nim submodules/tiny-AES-c/aes.h " & outFile

task build_blake2, "Generate wrapper for BLAKE2 reference code":
  let outFile = toSlashPath(joinPath(buildRootRel, "BLAKE2", "blake2_wrapper.nim"))
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nim c -r c_nim_wrapper_bindr.nim submodules/BLAKE2/ref/blake2.h " & outFile

task build_openssl, "Build OpenSSL 3 and generate wrapper":
  let outFile = toSlashPath(joinPath(buildRootRel, "openssl", "openssl_sha_wrapper.nim"))
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nim r tools/build_openssl.nim"
  exec "nim c -r c_nim_wrapper_bindr.nim submodules/openssl/include/openssl/sha.h " & outFile

task build_libsodium, "Build libsodium and generate wrapper":
  let combinedHeader = toSlashPath(joinPath(buildRootRel, "libsodium", "sodium_combined.h"))
  let outFile = toSlashPath(joinPath(buildRootRel, "libsodium", "libsodium_wrapper.nim"))
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nim r tools/build_libsodium.nim"
  exec "nim r tools/prepare_libsodium_header.nim"
  exec "nim c -r c_nim_wrapper_bindr.nim " & combinedHeader & " " & outFile

task build_liboqs, "Build liboqs and generate wrapper":
  let combinedHeader = toSlashPath(joinPath(buildRootRel, "liboqs", "oqs_full_combined.h"))
  let outFile = toSlashPath(joinPath(buildRootRel, "liboqs", "liboqs_wrapper.nim"))
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nim r tools/build_liboqs.nim"
  exec "nim r tools/prepare_liboqs_header.nim"
  exec "nim c -r c_nim_wrapper_bindr.nim " & combinedHeader & " " & outFile

task build_c_repos_basic, "Build C test repos without OpenSSL":
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nim r tools/build_libsodium.nim"
  exec "nim r tools/build_liboqs.nim"

task build_c_repos_all, "Build all C test repos":
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nim r tools/build_openssl.nim"
  exec "nim r tools/build_libsodium.nim"
  exec "nim r tools/build_liboqs.nim"

task build_repos, "Generate wrappers for all test repos":
  exec "nimble build_repos_basic"

task build_repos_basic, "Generate wrappers for test repos without OpenSSL":
  exec "nimble build_aes"
  exec "nimble build_blake2"
  exec "nimble build_libsodium"
  exec "nimble build_liboqs"

task build_repos_all, "Generate wrappers for all test repos":
  exec "nimble build_repos_basic"
  exec "nimble build_openssl"

task setup, "Fetch submodules for test repos":
  exec "nim r tools/ensure_env.nim -- --submodules"

task start, "Fetch submodules and build test wrappers":
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nimble build_c_repos_basic"
  exec "nimble build_repos_basic"

task test_functionality, "Run tokenizer and utils tests":
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nim c -r --path:. tests/functionality/test_tokenizer.nim"
  exec "nim c -r --path:. tests/functionality/test_utils.nim"
  exec "nim c -r --path:. tests/functionality/test_parsers.nim"

task test_realworld, "Run real-world wrapper tests":
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nimble build_c_repos_basic"
  exec "nimble build_repos_basic"
  exec "nim c -r tests/realworld/tiny_aes_c_runner.nim"
  exec "nim c -r tests/realworld/blake2_ref_runner.nim"
  exec "nim c -r tests/realworld/libsodium_runner.nim"
  exec "nim c -r tests/realworld/liboqs_runner.nim"

task test_realworld_all, "Run all real-world wrapper tests":
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nimble build_c_repos_all"
  exec "nimble build_repos_all"
  exec "nim c -r tests/realworld/tiny_aes_c_runner.nim"
  exec "nim c -r tests/realworld/blake2_ref_runner.nim"
  exec "nim c -r tests/realworld/openssl3_runner.nim"
  exec "nim c -r tests/realworld/libsodium_runner.nim"
  exec "nim c -r tests/realworld/liboqs_runner.nim"

task test_all, "Run all tests":
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nimble build_c_repos_basic"
  exec "nimble build_repos_basic"
  exec "nim c -r --path:. tests/functionality/test_tokenizer.nim"
  exec "nim c -r --path:. tests/functionality/test_utils.nim"
  exec "nim c -r --path:. tests/functionality/test_parsers.nim"
  exec "nim c -r tests/realworld/tiny_aes_c_runner.nim"
  exec "nim c -r tests/realworld/blake2_ref_runner.nim"
  exec "nim c -r tests/realworld/libsodium_runner.nim"
  exec "nim c -r tests/realworld/liboqs_runner.nim"

task test_all_full, "Run all tests including OpenSSL":
  exec "nim r tools/ensure_env.nim -- --submodules --builddirs"
  exec "nimble build_c_repos_all"
  exec "nimble build_repos_all"
  exec "nim c -r --path:. tests/functionality/test_tokenizer.nim"
  exec "nim c -r --path:. tests/functionality/test_utils.nim"
  exec "nim c -r --path:. tests/functionality/test_parsers.nim"
  exec "nim c -r tests/realworld/tiny_aes_c_runner.nim"
  exec "nim c -r tests/realworld/blake2_ref_runner.nim"
  exec "nim c -r tests/realworld/openssl3_runner.nim"
  exec "nim c -r tests/realworld/libsodium_runner.nim"
  exec "nim c -r tests/realworld/liboqs_runner.nim"

task autopush, "Add, commit, and push with message from iron/progress.md":
  let path = "iron/progress.md"
  var msg = ""
  if fileExists(path):
    let content = readFile(path)
    for line in content.splitLines:
      if line.startsWith("Commit Message:"):
        msg = line["Commit Message:".len .. ^1].strip()
        break
  if msg.len == 0:
    msg = "No specific commit message given."
  exec "git add -A ."
  let staged = gorge("git diff --cached --name-only").strip()
  if staged.len == 0:
    echo "No staged changes. Skipping commit."
  else:
    exec "git commit -m \"" & msg.replace("\"", "\\\"") & "\""
  exec "git push"


task find, "Use local clones for submodules in parent folder":
  let modulesPath = ".gitmodules"
  if not fileExists(modulesPath):
    echo "No .gitmodules found."
  else:
    let root = parentDir(getCurrentDir())
    var current = ""
    for line in readFile(modulesPath).splitLines:
      let s = line.strip()
      if s.startsWith("[submodule"):
        let start = s.find('"')
        let stop = s.rfind('"')
        if start >= 0 and stop > start:
          current = s[start + 1 .. stop - 1]
      elif current.len > 0 and s.startsWith("path"):
        let parts = s.split("=", maxsplit = 1)
        if parts.len == 2:
          let subPath = parts[1].strip()
          let tail = splitPath(subPath).tail
          let localDir = joinPath(root, tail)
          if dirExists(localDir):
            let localUrl = localDir.replace('\\', '/')
            exec "git config -f .gitmodules submodule." & current & ".url " & localUrl
            exec "git config submodule." & current & ".url " & localUrl
    exec "git submodule sync --recursive"


requires "nim >= 1.6.0", "owlkettle >= 3.0.0", "illwill >= 0.4.0"




