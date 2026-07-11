import unittest

when defined(bindrBuildsNested):
  import "../../builds/testBuilds/liboqs/liboqs_wrapper"
else:
  import "../../testBuilds/liboqs/liboqs_wrapper"

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

suite "liboqs kem":
  test "kyber512 roundtrip":
    var
      pk: seq[uint8] = newSeq[uint8](int(OQS_KEM_kyber_512_length_public_key))
      sk: seq[uint8] = newSeq[uint8](int(OQS_KEM_kyber_512_length_secret_key))
      ct: seq[uint8] = newSeq[uint8](int(OQS_KEM_kyber_512_length_ciphertext))
      ss1: seq[uint8] = newSeq[uint8](int(OQS_KEM_kyber_512_length_shared_secret))
      ss2: seq[uint8] = newSeq[uint8](int(OQS_KEM_kyber_512_length_shared_secret))
      code: OQS_STATUS = OQS_ERROR
    code = OQS_KEM_kyber_512_keypair(toPtr(pk), toPtr(sk))
    check code == OQS_SUCCESS
    code = OQS_KEM_kyber_512_encaps(toPtr(ct), toPtr(ss1), toPtr(pk))
    check code == OQS_SUCCESS
    code = OQS_KEM_kyber_512_decaps(toPtr(ss2), toPtr(ct), toPtr(sk))
    check code == OQS_SUCCESS
    check bytesEqual(ss1, ss2)

  test "kyber1024 roundtrip":
    var
      pk: seq[uint8] = newSeq[uint8](int(OQS_KEM_kyber_1024_length_public_key))
      sk: seq[uint8] = newSeq[uint8](int(OQS_KEM_kyber_1024_length_secret_key))
      ct: seq[uint8] = newSeq[uint8](int(OQS_KEM_kyber_1024_length_ciphertext))
      ss1: seq[uint8] = newSeq[uint8](int(OQS_KEM_kyber_1024_length_shared_secret))
      ss2: seq[uint8] = newSeq[uint8](int(OQS_KEM_kyber_1024_length_shared_secret))
      code: OQS_STATUS = OQS_ERROR
    code = OQS_KEM_kyber_1024_keypair(toPtr(pk), toPtr(sk))
    check code == OQS_SUCCESS
    code = OQS_KEM_kyber_1024_encaps(toPtr(ct), toPtr(ss1), toPtr(pk))
    check code == OQS_SUCCESS
    code = OQS_KEM_kyber_1024_decaps(toPtr(ss2), toPtr(ct), toPtr(sk))
    check code == OQS_SUCCESS
    check bytesEqual(ss1, ss2)

  test "classic-mceliece-348864 roundtrip":
    var
      pk: seq[uint8] = newSeq[uint8](int(OQS_KEM_classic_mceliece_348864_length_public_key))
      sk: seq[uint8] = newSeq[uint8](int(OQS_KEM_classic_mceliece_348864_length_secret_key))
      ct: seq[uint8] = newSeq[uint8](int(OQS_KEM_classic_mceliece_348864_length_ciphertext))
      ss1: seq[uint8] = newSeq[uint8](int(OQS_KEM_classic_mceliece_348864_length_shared_secret))
      ss2: seq[uint8] = newSeq[uint8](int(OQS_KEM_classic_mceliece_348864_length_shared_secret))
      code: OQS_STATUS = OQS_ERROR
    code = OQS_KEM_classic_mceliece_348864_keypair(toPtr(pk), toPtr(sk))
    check code == OQS_SUCCESS
    code = OQS_KEM_classic_mceliece_348864_encaps(toPtr(ct), toPtr(ss1), toPtr(pk))
    check code == OQS_SUCCESS
    code = OQS_KEM_classic_mceliece_348864_decaps(toPtr(ss2), toPtr(ct), toPtr(sk))
    check code == OQS_SUCCESS
    check bytesEqual(ss1, ss2)

  test "classic-mceliece-6960119 roundtrip":
    var
      pk: seq[uint8] = newSeq[uint8](int(OQS_KEM_classic_mceliece_6960119_length_public_key))
      sk: seq[uint8] = newSeq[uint8](int(OQS_KEM_classic_mceliece_6960119_length_secret_key))
      ct: seq[uint8] = newSeq[uint8](int(OQS_KEM_classic_mceliece_6960119_length_ciphertext))
      ss1: seq[uint8] = newSeq[uint8](int(OQS_KEM_classic_mceliece_6960119_length_shared_secret))
      ss2: seq[uint8] = newSeq[uint8](int(OQS_KEM_classic_mceliece_6960119_length_shared_secret))
      code: OQS_STATUS = OQS_ERROR
    code = OQS_KEM_classic_mceliece_6960119_keypair(toPtr(pk), toPtr(sk))
    check code == OQS_SUCCESS
    code = OQS_KEM_classic_mceliece_6960119_encaps(toPtr(ct), toPtr(ss1), toPtr(pk))
    check code == OQS_SUCCESS
    code = OQS_KEM_classic_mceliece_6960119_decaps(toPtr(ss2), toPtr(ct), toPtr(sk))
    check code == OQS_SUCCESS
    check bytesEqual(ss1, ss2)

suite "liboqs signatures":
  test "falcon-512 sign/verify":
    var
      pk: seq[uint8] = newSeq[uint8](int(OQS_SIG_falcon_512_length_public_key))
      sk: seq[uint8] = newSeq[uint8](int(OQS_SIG_falcon_512_length_secret_key))
      sig: seq[uint8] = newSeq[uint8](int(OQS_SIG_falcon_512_length_signature))
      sigLen: csize_t = csize_t(sig.len)
      msg: array[3, uint8] = [0x61'u8, 0x62'u8, 0x63'u8]
      msgLen: csize_t = csize_t(msg.len)
      code: OQS_STATUS = OQS_ERROR
    code = OQS_SIG_falcon_512_keypair(toPtr(pk), toPtr(sk))
    check code == OQS_SUCCESS
    code = OQS_SIG_falcon_512_sign(toPtr(sig), addr sigLen, toPtr(msg), msgLen, toPtr(sk))
    check code == OQS_SUCCESS
    code = OQS_SIG_falcon_512_verify(toPtr(msg), msgLen, toPtr(sig), sigLen, toPtr(pk))
    check code == OQS_SUCCESS

  test "falcon-1024 sign/verify":
    var
      pk: seq[uint8] = newSeq[uint8](int(OQS_SIG_falcon_1024_length_public_key))
      sk: seq[uint8] = newSeq[uint8](int(OQS_SIG_falcon_1024_length_secret_key))
      sig: seq[uint8] = newSeq[uint8](int(OQS_SIG_falcon_1024_length_signature))
      sigLen: csize_t = csize_t(sig.len)
      msg: array[3, uint8] = [0x61'u8, 0x62'u8, 0x63'u8]
      msgLen: csize_t = csize_t(msg.len)
      code: OQS_STATUS = OQS_ERROR
    code = OQS_SIG_falcon_1024_keypair(toPtr(pk), toPtr(sk))
    check code == OQS_SUCCESS
    code = OQS_SIG_falcon_1024_sign(toPtr(sig), addr sigLen, toPtr(msg), msgLen, toPtr(sk))
    check code == OQS_SUCCESS
    code = OQS_SIG_falcon_1024_verify(toPtr(msg), msgLen, toPtr(sig), sigLen, toPtr(pk))
    check code == OQS_SUCCESS

suite "liboqs common":
  test "secure compare":
    var
      left: array[3, uint8] = [0x01'u8, 0x02'u8, 0x03'u8]
      rightSame: array[3, uint8] = [0x01'u8, 0x02'u8, 0x03'u8]
      rightDiff: array[3, uint8] = [0x01'u8, 0x02'u8, 0x04'u8]
      len: csize_t = csize_t(left.len)
      sameRes: cint = OQS_MEM_secure_bcmp(toPtr(left), toPtr(rightSame), len)
      diffRes: cint = OQS_MEM_secure_bcmp(toPtr(left), toPtr(rightDiff), len)
    check sameRes == 0
    check diffRes == 1

