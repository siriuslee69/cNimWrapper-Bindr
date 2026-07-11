import unittest

when defined(bindrBuildsNested):
  import "../../builds/testBuilds/openssl/openssl_sha_wrapper"
else:
  import "../../testBuilds/openssl/openssl_sha_wrapper"

const
  expectedSha256*: array[32, uint8] = [
    0xba'u8, 0x78'u8, 0x16'u8, 0xbf'u8, 0x8f'u8, 0x01'u8, 0xcf'u8, 0xea'u8,
    0x41'u8, 0x41'u8, 0x40'u8, 0xde'u8, 0x5d'u8, 0xae'u8, 0x22'u8, 0x23'u8,
    0xb0'u8, 0x03'u8, 0x61'u8, 0xa3'u8, 0x96'u8, 0x17'u8, 0x7a'u8, 0x9c'u8,
    0xb4'u8, 0x10'u8, 0xff'u8, 0x61'u8, 0xf2'u8, 0x00'u8, 0x15'u8, 0xad'u8
  ]

proc toPtr*(a: var openArray[uint8]): ptr uint8 =
  ## a: buffer to convert
  ## Returns a typed pointer to the first element.
  result = cast[ptr uint8](unsafeAddr a[0])

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

suite "openssl sha256":
  test "abc":
    var
      outBuf: array[32, uint8]
      inputBuf: array[3, uint8] = [0x61'u8, 0x62'u8, 0x63'u8]
    discard SHA256(toPtr(inputBuf), csize_t(inputBuf.len), toPtr(outBuf))
    check bytesEqual(outBuf, expectedSha256)

