import std/[os, strutils]

const
  legacyBuildRoot* = "testBuilds"
  nestedBuildRoot* = "builds/testBuilds"

proc normalizeRel*(a: string): string =
  ## a: relative path string
  ## Normalizes path separators for stable relative path comparisons.
  result = a.replace('\\', '/')

proc detectBuildRootRel*(a: string): string =
  ## a: cNimWrapper base directory
  ## Resolves the active relative build root.
  var
    nestedAbs: string = joinPath(a, "builds", "testBuilds")
    legacyAbs: string = joinPath(a, legacyBuildRoot)
    buildsAbs: string = joinPath(a, "builds")
  if dirExists(nestedAbs):
    return nestedBuildRoot
  if dirExists(legacyAbs):
    return legacyBuildRoot
  if dirExists(buildsAbs):
    return nestedBuildRoot
  result = legacyBuildRoot

proc buildRoot*(a: string): string =
  ## a: cNimWrapper base directory
  ## Returns absolute build root path.
  result = joinPath(a, detectBuildRootRel(a))

proc buildSubDir*(a: string, b: openArray[string]): string =
  ## a: cNimWrapper base directory
  ## b: relative segments inside the active build root
  ## Returns absolute path inside the active build root.
  var
    outPath: string = buildRoot(a)
    i: int = 0
    l: int = b.len
  while i < l:
    outPath = joinPath(outPath, b[i])
    inc i
  result = outPath

proc usingNestedBuildRoot*(a: string): bool =
  ## a: cNimWrapper base directory
  ## Returns true when `builds/testBuilds` is active.
  result = detectBuildRootRel(a) == nestedBuildRoot
