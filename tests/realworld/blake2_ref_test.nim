import unittest

const
  repoDir* = "..\\..\\submodules\\BLAKE2\\ref"
  blake2sCPath* = repoDir & "\\blake2s-ref.c"

{.compile: blake2sCPath.}
{.passC: "-I" & repoDir.}

when defined(bindrBuildsNested):
  import "../../builds/testBuilds/BLAKE2/blake2_wrapper"
else:
  import "../../testBuilds/BLAKE2/blake2_wrapper"

const
  key32*: array[32, uint8] = [
    0x00'u8, 0x01'u8, 0x02'u8, 0x03'u8, 0x04'u8, 0x05'u8, 0x06'u8, 0x07'u8,
    0x08'u8, 0x09'u8, 0x0a'u8, 0x0b'u8, 0x0c'u8, 0x0d'u8, 0x0e'u8, 0x0f'u8,
    0x10'u8, 0x11'u8, 0x12'u8, 0x13'u8, 0x14'u8, 0x15'u8, 0x16'u8, 0x17'u8,
    0x18'u8, 0x19'u8, 0x1a'u8, 0x1b'u8, 0x1c'u8, 0x1d'u8, 0x1e'u8, 0x1f'u8
  ]
  blake2sEmptyKeyed*: array[32, uint8] = [
    0x48'u8, 0xa8'u8, 0x99'u8, 0x7d'u8, 0xa4'u8, 0x07'u8, 0x87'u8, 0x6b'u8,
    0x3d'u8, 0x79'u8, 0xc0'u8, 0xd9'u8, 0x23'u8, 0x25'u8, 0xad'u8, 0x3b'u8,
    0x89'u8, 0xcb'u8, 0xb7'u8, 0x54'u8, 0xd8'u8, 0x6a'u8, 0xb7'u8, 0x1a'u8,
    0xee'u8, 0x04'u8, 0x7a'u8, 0xd3'u8, 0x45'u8, 0xfd'u8, 0x2c'u8, 0x49'u8
  ]

proc zeroBytes*(a: var openArray[uint8]) =
  ## a: buffer to zero
  ## Sets all bytes in the buffer to zero.
  var
    i: int = 0
    l: int = a.len
  while i < l:
    a[i] = 0'u8
    inc i

proc bytesEqual*(a: openArray[uint8], b: openArray[uint8]): bool =
  ## a: left buffer
  ## b: right buffer
  ## Returns true when both buffers have equal length and contents.
  var
    i: int = 0
    l: int = a.len
  if l != b.len:
    result = false
    return
  while i < l:
    if a[i] != b[i]:
      result = false
      return
    inc i
  result = true

proc toPtr*(a: var openArray[uint8]): ptr uint8 =
  ## a: buffer to convert
  ## Returns a typed pointer to the first element.
  result = cast[ptr uint8](unsafeAddr a[0])

suite "blake2s keyed vectors":
  test "empty input with 32-byte key":
    var
      outBuf: array[32, uint8]
      inputBuf: array[1, uint8]
      keyBuf: array[32, uint8] = key32
      code: cint = 0
    zeroBytes(outBuf)
    zeroBytes(inputBuf)
    code = blake2s(toPtr(outBuf), csize_t(32), toPtr(inputBuf), csize_t(0),
      toPtr(keyBuf), csize_t(32))
    check code == 0
    check bytesEqual(outBuf, blake2sEmptyKeyed)

