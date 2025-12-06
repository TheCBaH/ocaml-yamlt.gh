Roundtrip Encoding/Decoding Tests with Yamlt
=============================================

This test suite validates that data can be encoded and then decoded back
to the original value, ensuring no data loss in the roundtrip process.

================================================================================
SCALAR ROUNDTRIP
================================================================================

Encode and decode scalar types

  $ test_roundtrip scalar
  JSON roundtrip: PASS
  YAML Block roundtrip: PASS
  YAML Flow roundtrip: PASS

================================================================================
ARRAY ROUNDTRIP
================================================================================

Encode and decode arrays including nested arrays

  $ test_roundtrip array
  JSON array roundtrip: PASS
  YAML array roundtrip: PASS

================================================================================
OBJECT ROUNDTRIP
================================================================================

Encode and decode complex objects with nested structures

  $ test_roundtrip object
  JSON object roundtrip: PASS
  YAML object roundtrip: PASS

================================================================================
OPTIONAL FIELDS ROUNDTRIP
================================================================================

Encode and decode optional and nullable fields

  $ test_roundtrip optional
  Fatal error: exception Invalid_argument("option is None")
  [2]
