import unittest

const
  repoDir* = "..\\..\\submodules\\tiny-AES-c"
  aesCPath* = repoDir & "\\aes.c"

{.compile: aesCPath.}
{.passC: "-I" & repoDir.}

when defined(bindrBuildsNested):
  import "../../builds/testBuilds/tiny-AES-c/aes_wrapper"
else:
  import "../../testBuilds/tiny-AES-c/aes_wrapper"

const
  ctxBytes*: int = 512
  key128*: array[16, uint8] = [
    0x2b'u8, 0x7e'u8, 0x15'u8, 0x16'u8, 0x28'u8, 0xae'u8, 0xd2'u8, 0xa6'u8,
    0xab'u8, 0xf7'u8, 0x15'u8, 0x88'u8, 0x09'u8, 0xcf'u8, 0x4f'u8, 0x3c'u8
  ]
  ecbPlain*: array[16, uint8] = [
    0x6b'u8, 0xc1'u8, 0xbe'u8, 0xe2'u8, 0x2e'u8, 0x40'u8, 0x9f'u8, 0x96'u8,
    0xe9'u8, 0x3d'u8, 0x7e'u8, 0x11'u8, 0x73'u8, 0x93'u8, 0x17'u8, 0x2a'u8
  ]
  ecbCipher*: array[16, uint8] = [
    0x3a'u8, 0xd7'u8, 0x7b'u8, 0xb4'u8, 0x0d'u8, 0x7a'u8, 0x36'u8, 0x60'u8,
    0xa8'u8, 0x9e'u8, 0xca'u8, 0xf3'u8, 0x24'u8, 0x66'u8, 0xef'u8, 0x97'u8
  ]
  cbcIv*: array[16, uint8] = [
    0x00'u8, 0x01'u8, 0x02'u8, 0x03'u8, 0x04'u8, 0x05'u8, 0x06'u8, 0x07'u8,
    0x08'u8, 0x09'u8, 0x0a'u8, 0x0b'u8, 0x0c'u8, 0x0d'u8, 0x0e'u8, 0x0f'u8
  ]
  cbcPlain64*: array[64, uint8] = [
    0x6b'u8, 0xc1'u8, 0xbe'u8, 0xe2'u8, 0x2e'u8, 0x40'u8, 0x9f'u8, 0x96'u8,
    0xe9'u8, 0x3d'u8, 0x7e'u8, 0x11'u8, 0x73'u8, 0x93'u8, 0x17'u8, 0x2a'u8,
    0xae'u8, 0x2d'u8, 0x8a'u8, 0x57'u8, 0x1e'u8, 0x03'u8, 0xac'u8, 0x9c'u8,
    0x9e'u8, 0xb7'u8, 0x6f'u8, 0xac'u8, 0x45'u8, 0xaf'u8, 0x8e'u8, 0x51'u8,
    0x30'u8, 0xc8'u8, 0x1c'u8, 0x46'u8, 0xa3'u8, 0x5c'u8, 0xe4'u8, 0x11'u8,
    0xe5'u8, 0xfb'u8, 0xc1'u8, 0x19'u8, 0x1a'u8, 0x0a'u8, 0x52'u8, 0xef'u8,
    0xf6'u8, 0x9f'u8, 0x24'u8, 0x45'u8, 0xdf'u8, 0x4f'u8, 0x9b'u8, 0x17'u8,
    0xad'u8, 0x2b'u8, 0x41'u8, 0x7b'u8, 0xe6'u8, 0x6c'u8, 0x37'u8, 0x10'u8
  ]
  cbcCipher64*: array[64, uint8] = [
    0x76'u8, 0x49'u8, 0xab'u8, 0xac'u8, 0x81'u8, 0x19'u8, 0xb2'u8, 0x46'u8,
    0xce'u8, 0xe9'u8, 0x8e'u8, 0x9b'u8, 0x12'u8, 0xe9'u8, 0x19'u8, 0x7d'u8,
    0x50'u8, 0x86'u8, 0xcb'u8, 0x9b'u8, 0x50'u8, 0x72'u8, 0x19'u8, 0xee'u8,
    0x95'u8, 0xdb'u8, 0x11'u8, 0x3a'u8, 0x91'u8, 0x76'u8, 0x78'u8, 0xb2'u8,
    0x73'u8, 0xbe'u8, 0xd6'u8, 0xb8'u8, 0xe3'u8, 0xc1'u8, 0x74'u8, 0x3b'u8,
    0x71'u8, 0x16'u8, 0xe6'u8, 0x9e'u8, 0x22'u8, 0x22'u8, 0x95'u8, 0x16'u8,
    0x3f'u8, 0xf1'u8, 0xca'u8, 0xa1'u8, 0x68'u8, 0x1f'u8, 0xac'u8, 0x09'u8,
    0x12'u8, 0x0e'u8, 0xca'u8, 0x30'u8, 0x75'u8, 0x86'u8, 0xe1'u8, 0xa7'u8
  ]
  ctrIv*: array[16, uint8] = [
    0xf0'u8, 0xf1'u8, 0xf2'u8, 0xf3'u8, 0xf4'u8, 0xf5'u8, 0xf6'u8, 0xf7'u8,
    0xf8'u8, 0xf9'u8, 0xfa'u8, 0xfb'u8, 0xfc'u8, 0xfd'u8, 0xfe'u8, 0xff'u8
  ]
  ctrInput64*: array[64, uint8] = [
    0x87'u8, 0x4d'u8, 0x61'u8, 0x91'u8, 0xb6'u8, 0x20'u8, 0xe3'u8, 0x26'u8,
    0x1b'u8, 0xef'u8, 0x68'u8, 0x64'u8, 0x99'u8, 0x0d'u8, 0xb6'u8, 0xce'u8,
    0x98'u8, 0x06'u8, 0xf6'u8, 0x6b'u8, 0x79'u8, 0x70'u8, 0xfd'u8, 0xff'u8,
    0x86'u8, 0x17'u8, 0x18'u8, 0x7b'u8, 0xb9'u8, 0xff'u8, 0xfd'u8, 0xff'u8,
    0x5a'u8, 0xe4'u8, 0xdf'u8, 0x3e'u8, 0xdb'u8, 0xd5'u8, 0xd3'u8, 0x5e'u8,
    0x5b'u8, 0x4f'u8, 0x09'u8, 0x02'u8, 0x0d'u8, 0xb0'u8, 0x3e'u8, 0xab'u8,
    0x1e'u8, 0x03'u8, 0x1d'u8, 0xda'u8, 0x2f'u8, 0xbe'u8, 0x03'u8, 0xd1'u8,
    0x79'u8, 0x21'u8, 0x70'u8, 0xa0'u8, 0xf3'u8, 0x00'u8, 0x9c'u8, 0xee'u8
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

proc toCtxPtr*(a: var openArray[uint8]): ptr AES_ctx =
  ## a: context buffer
  ## Returns a typed pointer to the AES context.
  result = cast[ptr AES_ctx](unsafeAddr a[0])

suite "tiny-AES-c ECB":
  test "encrypt matches test.c vector":
    var
      ctxMem: array[ctxBytes, uint8]
      key: array[16, uint8] = key128
      buf: array[16, uint8] = ecbPlain
    zeroBytes(ctxMem)
    AES_init_ctx(toCtxPtr(ctxMem), toPtr(key))
    AES_ECB_encrypt(toCtxPtr(ctxMem), toPtr(buf))
    check bytesEqual(buf, ecbCipher)

  test "decrypt matches test.c vector":
    var
      ctxMem: array[ctxBytes, uint8]
      key: array[16, uint8] = key128
      buf: array[16, uint8] = ecbCipher
    zeroBytes(ctxMem)
    AES_init_ctx(toCtxPtr(ctxMem), toPtr(key))
    AES_ECB_decrypt(toCtxPtr(ctxMem), toPtr(buf))
    check bytesEqual(buf, ecbPlain)

suite "tiny-AES-c CBC":
  test "encrypt matches test.c vector":
    var
      ctxMem: array[ctxBytes, uint8]
      key: array[16, uint8] = key128
      iv: array[16, uint8] = cbcIv
      buf: array[64, uint8] = cbcPlain64
    zeroBytes(ctxMem)
    AES_init_ctx_iv(toCtxPtr(ctxMem), toPtr(key), toPtr(iv))
    AES_CBC_encrypt_buffer(toCtxPtr(ctxMem), toPtr(buf), csize_t(64))
    check bytesEqual(buf, cbcCipher64)

  test "decrypt matches test.c vector":
    var
      ctxMem: array[ctxBytes, uint8]
      key: array[16, uint8] = key128
      iv: array[16, uint8] = cbcIv
      buf: array[64, uint8] = cbcCipher64
    zeroBytes(ctxMem)
    AES_init_ctx_iv(toCtxPtr(ctxMem), toPtr(key), toPtr(iv))
    AES_CBC_decrypt_buffer(toCtxPtr(ctxMem), toPtr(buf), csize_t(64))
    check bytesEqual(buf, cbcPlain64)

suite "tiny-AES-c CTR":
  test "xcrypt matches test.c vector":
    var
      ctxMem: array[ctxBytes, uint8]
      key: array[16, uint8] = key128
      iv: array[16, uint8] = ctrIv
      buf: array[64, uint8] = ctrInput64
    zeroBytes(ctxMem)
    AES_init_ctx_iv(toCtxPtr(ctxMem), toPtr(key), toPtr(iv))
    AES_CTR_xcrypt_buffer(toCtxPtr(ctxMem), toPtr(buf), csize_t(64))
    check bytesEqual(buf, cbcPlain64)

