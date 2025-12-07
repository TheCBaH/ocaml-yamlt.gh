Multi-Document YAML Streams with Yamlt
========================================

This test suite validates multi-document YAML stream decoding using decode_all,
including error handling, location tracking, and JSON roundtripping.

================================================================================
BASIC MULTIDOC DECODING
================================================================================

Simple multi-document stream with person objects

  $ test_multidoc simple ../data/multidoc/simple.yml
  Documents:
    [0] : Alice (age 30)
    [1] : Bob (age 25)
    [2] : Charlie (age 35)

Count documents in a stream

  $ test_multidoc count ../data/multidoc/simple.yml
  Document count: 3

================================================================================
ERROR HANDLING - MIXED VALID AND INVALID DOCUMENTS
================================================================================

When some documents succeed and others fail, decode_all continues processing
and returns results for each document individually.

Stream with one error in the middle

  $ test_multidoc errors ../data/multidoc/mixed_errors.yml
  Document results:
    [0] OK: Alice (age 30)
    [1] ERROR: String "not-a-number" does not parse to OCaml int value
  File "-":
  File "-": in member age of
  File "-": Person object
    [2] OK: Charlie (age 35)

Summary statistics for mixed documents

  $ test_multidoc summary ../data/multidoc/mixed_errors.yml
  Summary: 3 documents (2 ok, 1 error)

Stream where all documents fail

  $ test_multidoc errors ../data/multidoc/all_errors.yml
  Document results:
    [0] ERROR: String "invalid1" does not parse to OCaml int value
  File "-":
  File "-": in member age of
  File "-": Person object
    [1] ERROR: String "invalid2" does not parse to OCaml int value
  File "-":
  File "-": in member age of
  File "-": Person object
    [2] ERROR: String "invalid3" does not parse to OCaml int value
  File "-":
  File "-": in member age of
  File "-": Person object

Summary for all-error stream

  $ test_multidoc summary ../data/multidoc/all_errors.yml
  Summary: 3 documents (0 ok, 3 error)

================================================================================
LOCATION TRACKING WITH locs=true
================================================================================

Location tracking helps identify exactly where errors occur in each document
of a multi-document stream.

Without locs (default) - basic error information

  $ test_multidoc locations ../data/multidoc/mixed_errors.yml
  === Without locs (default) ===
    [0] OK
    [1] ERROR:
  String "not-a-number" does not parse to OCaml int value
  File "-":
  File "-": in member age of
  File "-": Person object
    [2] OK
  
  === With locs=true ===
    [0] OK
    [1] ERROR:
  String "not-a-number" does not parse to OCaml int value
  File "test.yml", line 6, characters 5-18:
  File "test.yml", line 6, characters 0-3: in member age of
  File "test.yml", line 5, characters 0-1: Person object
    [2] OK

================================================================================
MISSING FIELDS IN MULTIDOC
================================================================================

Documents with missing required fields generate errors but don't stop
processing of subsequent documents.

  $ test_multidoc errors ../data/multidoc/missing_fields.yml
  Document results:
    [0] OK: Alice (age 30)
    [1] ERROR: Missing member age in Person object
  File "-":
    [2] OK: Charlie (age 35)

Summary of missing fields test

  $ test_multidoc summary ../data/multidoc/missing_fields.yml
  Summary: 3 documents (2 ok, 1 error)

================================================================================
JSON ROUNDTRIPPING
================================================================================

Decode YAML multi-document streams and encode each document as JSON.
This validates that the data model conversion is correct.

Simple documents to JSON

  $ test_multidoc json ../data/multidoc/simple.yml
  JSON outputs:
    [0] {"name":"Alice","age":30}
    [1] {"name":"Bob","age":25}
    [2] {"name":"Charlie","age":35}

Nested objects to JSON

  $ test_multidoc json ../data/multidoc/nested.yml
  JSON outputs:
    [0] {"name":"Alice","age":30,"address":{"street":"123 Main St","city":"Boston"}}
    [1] {"name":"Bob","age":25,"address":{"street":"456 Oak Ave","city":"Seattle"}}
    [2] {"name":"Charlie","age":35,"address":{"street":"789 Pine Rd","city":"Portland"}}

Arrays to JSON

  $ test_multidoc json ../data/multidoc/arrays.yml
  JSON outputs:
    [0] [1,2,3]
    [1] ["apple","banana","cherry"]
    [2] [true,false,true]

Scalar values to JSON

  $ test_multidoc json ../data/multidoc/scalars.yml
  JSON outputs:
    [0] "hello world"
    [1] 42
    [2] true
    [3] null

================================================================================
NESTED OBJECTS IN MULTIDOC
================================================================================

Test decoding complex nested structures across multiple documents.

  $ test_multidoc nested ../data/multidoc/nested.yml
  Nested documents:
    [0] : Alice (age 30) from 123 Main St, Boston
    [1] : Bob (age 25) from 456 Oak Ave, Seattle
    [2] : Charlie (age 35) from 789 Pine Rd, Portland

================================================================================
ARRAYS IN MULTIDOC
================================================================================

Test decoding different array types across documents.

  $ test_multidoc arrays ../data/multidoc/arrays.yml
  Array documents:
    [0] [1,2,3]
    [1] ["apple","banana","cherry"]
    [2] [true,false,true]

================================================================================
SCALARS IN MULTIDOC
================================================================================

Test decoding bare scalar values as documents.

  $ test_multidoc scalars ../data/multidoc/scalars.yml
  Scalar documents:
    [0] "hello world"
    [1] 42
    [2] true
    [3] null

================================================================================
EMPTY DOCUMENTS
================================================================================

Empty or null documents in a stream are handled correctly.

  $ test_multidoc json ../data/multidoc/empty_docs.yml
  JSON outputs:
    [0] {"name":"Alice","age":30}
    [1] null
    [2] {"name":"Charlie","age":35}

Count including empty documents

  $ test_multidoc count ../data/multidoc/empty_docs.yml
  Document count: 3

================================================================================
SUMMARY
================================================================================

The decode_all function:
- Processes all documents in a stream, not stopping on errors
- Returns a sequence of Result values (Ok/Error for each document)
- Supports all decode options: locs, layout, file, max_depth, max_nodes
- Correctly handles document boundaries even when errors occur
- Works with any Jsont codec (objects, arrays, scalars, etc.)
- Can be used for JSON roundtripping and format conversion
