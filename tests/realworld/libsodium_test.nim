import unittest

when defined(bindrBuildsNested):
  import "../../builds/testBuilds/libsodium/libsodium_wrapper"
else:
  import "../../testBuilds/libsodium/libsodium_wrapper"

const
  expectedSha256*: array[32, uint8] = [
    0xba'u8, 0x78'u8, 0x16'u8, 0xbf'u8, 0x8f'u8, 0x01'u8, 0xcf'u8, 0xea'u8,
    0x41'u8, 0x41'u8, 0x40'u8, 0xde'u8, 0x5d'u8, 0xae'u8, 0x22'u8, 0x23'u8,
    0xb0'u8, 0x03'u8, 0x61'u8, 0xa3'u8, 0x96'u8, 0x17'u8, 0x7a'u8, 0x9c'u8,
    0xb4'u8, 0x10'u8, 0xff'u8, 0x61'u8, 0xf2'u8, 0x00'u8, 0x15'u8, 0xad'u8
  ]
  expectedSha512Hex*: string =
    "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a" &
    "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
  expectedBlake2b256Hex*: string =
    "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319"
  xchacha20KeyHex*: string =
    "79c99798ac67300bbb2704c95c341e3245f3dcb21761b98e52ff45b24f304fc4"
  xchacha20NonceHex*: string =
    "b33ffd3096479bcfbc9aee49417688a0a2554f8d95389419"
  xchacha20OutHex*: string =
    "c6e9758160083ac604ef90e712ce6e75d7797590744e0cf060f013739c"
  aesKeyHex*: string =
    "92ace3e348cd821092cd921aa3546374299ab46209691bc28b8752d17f123c20"
  aesNonceHex*: string = "00112233445566778899aabb"
  aesAdHex*: string = "00000000ffffffff"
  aesMessageHex*: string = "00010203040506070809"
  aesCipherHex*: string = "e27abdd2d2a53d2f136b"
  aesMacHex*: string = "9a4a2579529301bcfb71c78d4060f52c"

proc toPtr*(a: var openArray[uint8]): ptr uint8 =
  ## a: buffer to convert
  ## Returns a typed pointer to the first element.
  result = cast[ptr uint8](unsafeAddr a[0])

proc hexValue*(a: char): int =
  ## a: hex character
  ## Returns the nibble value or -1 when invalid.
  var
    v: int = -1
  if a >= '0' and a <= '9':
    v = ord(a) - ord('0')
  elif a >= 'a' and a <= 'f':
    v = ord(a) - ord('a') + 10
  elif a >= 'A' and a <= 'F':
    v = ord(a) - ord('A') + 10
  result = v

proc hexToBytes*(a: string): seq[uint8] =
  ## a: hex string
  ## Returns a byte sequence for the hex input.
  var
    outBytes: seq[uint8] = @[]
    i: int = 0
    l: int = a.len
    hi: int = 0
    lo: int = 0
  if (l mod 2) != 0:
    result = outBytes
    return
  while i < l:
    hi = hexValue(a[i])
    lo = hexValue(a[i + 1])
    if hi < 0 or lo < 0:
      result = outBytes
      return
    outBytes.add uint8((hi shl 4) or lo)
    i += 2
  result = outBytes

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

suite "libsodium hashes":
  test "sha256 abc":
    var
      outBuf: array[32, uint8]
      inputBuf: array[3, uint8] = [0x61'u8, 0x62'u8, 0x63'u8]
      code: cint = 0
    discard sodium_init()
    code = crypto_hash_sha256(toPtr(outBuf), toPtr(inputBuf), culonglong(inputBuf.len))
    check code == 0
    check bytesEqual(outBuf, expectedSha256)

  test "sha512 abc":
    var
      expected: seq[uint8] = hexToBytes(expectedSha512Hex)
      outBuf: seq[uint8] = newSeq[uint8](expected.len)
      inputBuf: array[3, uint8] = [0x61'u8, 0x62'u8, 0x63'u8]
      code: cint = 0
    discard sodium_init()
    code = crypto_hash_sha512(toPtr(outBuf), toPtr(inputBuf), culonglong(inputBuf.len))
    check code == 0
    check bytesEqual(outBuf, expected)

  test "blake2b-256 abc":
    var
      expected: seq[uint8] = hexToBytes(expectedBlake2b256Hex)
      outBuf: seq[uint8] = newSeq[uint8](expected.len)
      inputBuf: array[3, uint8] = [0x61'u8, 0x62'u8, 0x63'u8]
      code: cint = 0
    discard sodium_init()
    code = crypto_generichash(toPtr(outBuf), csize_t(outBuf.len), toPtr(inputBuf),
      culonglong(inputBuf.len), nil, csize_t(0))
    check code == 0
    check bytesEqual(outBuf, expected)

suite "libsodium xchacha20":
  test "stream vector":
    var
      key: seq[uint8] = hexToBytes(xchacha20KeyHex)
      nonce: seq[uint8] = hexToBytes(xchacha20NonceHex)
      expected: seq[uint8] = hexToBytes(xchacha20OutHex)
      outBuf: seq[uint8] = newSeq[uint8](expected.len)
      code: cint = 0
    discard sodium_init()
    code = crypto_stream_xchacha20(toPtr(outBuf), culonglong(outBuf.len), toPtr(nonce),
      toPtr(key))
    check code == 0
    check bytesEqual(outBuf, expected)

suite "libsodium aes256gcm":
  test "vector 1":
    var
      key: seq[uint8] = hexToBytes(aesKeyHex)
      nonce: seq[uint8] = hexToBytes(aesNonceHex)
      ad: seq[uint8] = hexToBytes(aesAdHex)
      message: seq[uint8] = hexToBytes(aesMessageHex)
      expectedCipher: seq[uint8] = hexToBytes(aesCipherHex)
      expectedMac: seq[uint8] = hexToBytes(aesMacHex)
      cipher: seq[uint8] = newSeq[uint8](message.len)
      mac: seq[uint8] = newSeq[uint8](expectedMac.len)
      decrypted: seq[uint8] = newSeq[uint8](message.len)
      macLen: culonglong = 0
      code: cint = 0
    discard sodium_init()
    if crypto_aead_aes256gcm_is_available() == 0:
      check true
    else:
      code = crypto_aead_aes256gcm_encrypt_detached(toPtr(cipher), toPtr(mac), addr macLen,
        toPtr(message), culonglong(message.len), toPtr(ad), culonglong(ad.len), nil,
        toPtr(nonce), toPtr(key))
      check code == 0
      check macLen == culonglong(mac.len)
      check bytesEqual(cipher, expectedCipher)
      check bytesEqual(mac, expectedMac)
      code = crypto_aead_aes256gcm_decrypt_detached(toPtr(decrypted), nil, toPtr(cipher),
        culonglong(cipher.len), toPtr(mac), toPtr(ad), culonglong(ad.len), toPtr(nonce),
        toPtr(key))
      check code == 0
      check bytesEqual(decrypted, message)

