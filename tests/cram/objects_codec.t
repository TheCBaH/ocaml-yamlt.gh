Object Codec Tests with Yamlt
================================

This test suite validates object encoding/decoding with Jsont codecs in YAML,
and compares behavior with JSON.

Setup
-----


================================================================================
SIMPLE OBJECTS
================================================================================

Decode simple object with required fields

  $ test_objects simple ../data/objects/simple.yml
  JSON: person: {name="Alice"; age=30}
  YAML: person: {name="Alice"; age=30}

================================================================================
OPTIONAL FIELDS
================================================================================

Object with all optional fields present

  $ test_objects optional ../data/objects/optional_all.yml
  JSON: config: {host="localhost"; port=Some 8080; debug=Some true}
  YAML: config: {host="localhost"; port=Some 8080; debug=Some true}

Object with some optional fields missing

  $ test_objects optional ../data/objects/optional_partial.yml
  JSON: config: {host="example.com"; port=Some 3000; debug=None}
  YAML: config: {host="example.com"; port=Some 3000; debug=None}

Object with only required field

  $ test_objects optional ../data/objects/optional_minimal.yml
  JSON: config: {host="minimal.com"; port=None; debug=None}
  YAML: config: {host="minimal.com"; port=None; debug=None}

================================================================================
DEFAULT VALUES
================================================================================

Empty object uses all defaults

  $ test_objects defaults ../data/objects/defaults_empty.yml
  JSON: settings: {timeout=30; retries=3; verbose=false}
  YAML: settings: {timeout=30; retries=3; verbose=false}

Object with partial fields uses defaults for missing ones

  $ test_objects defaults ../data/objects/defaults_partial.yml
  JSON: settings: {timeout=60; retries=3; verbose=false}
  YAML: settings: {timeout=60; retries=3; verbose=false}

================================================================================
NESTED OBJECTS
================================================================================

Objects containing other objects

  $ test_objects nested ../data/objects/nested.yml
  JSON: employee: {name="Bob"; address={street="123 Main St"; city="Springfield"; zip="12345"}}
  YAML: employee: {name="Bob"; address={street="123 Main St"; city="Springfield"; zip="12345"}}

================================================================================
UNKNOWN MEMBER HANDLING
================================================================================

Unknown members cause error by default

  $ test_objects unknown-error ../data/objects/unknown_members.yml
  Unexpected success

Unknown members can be kept

  $ test_objects unknown-keep ../data/objects/unknown_keep.yml
  JSON: flexible: {name="Charlie"; has_extra=true}
  YAML: flexible: {name="Charlie"; has_extra=true}

Unknown members are preserved during encoding roundtrip

  $ test_objects unknown-keep-roundtrip ../data/objects/unknown_keep.yml
  Decoded: name="Charlie", extra={"extra1":"value1","extra2":"value2"}
  Encoded Block:
  name: Charlie
  extra1: value1
  extra2: value2
  Re-decoded: name="Charlie", extra={"extra1":"value1","extra2":"value2"}
  Roundtrip: OK (extra members preserved)

================================================================================
OBJECT CASES (DISCRIMINATED UNIONS)
================================================================================

Decode circle variant

  $ test_objects cases ../data/objects/case_circle.yml
  JSON: shape: Circle{radius=5.50}
  YAML: shape: Circle{radius=5.50}

Decode rectangle variant

  $ test_objects cases ../data/objects/case_rectangle.yml
  JSON: shape: ERROR: Missing member radius in Circle object
  File "-", line 1, characters 0-52:
  YAML: shape: ERROR: Missing member radius in Circle object
  File "-":

================================================================================
ERROR HANDLING
================================================================================

Missing required field produces error

  $ test_objects missing-required ../data/objects/missing_required.yml
  Expected error: Missing member age in Required object
  File "-":

================================================================================
ENCODING OBJECTS
================================================================================

Encode objects to JSON and YAML formats

  $ test_objects encode
  JSON: {"name":"Alice","age":30,"active":true}
  YAML Block:
  name: Alice
  age: 30
  active: true
  YAML Flow: {name: Alice, age: 30, active: true}

================================================================================
NEGATIVE TESTS - Wrong File Types
================================================================================

Attempting to decode an array file with an object codec should fail

  $ test_objects simple ../data/arrays/int_array.yml
  JSON: person: ERROR: Missing members in Person object:
   age
   name
  File "-", line 1, characters 0-27:
  YAML: person: ERROR: Missing members in Person object:
   age
   name
  File "-":

Attempting to decode a scalar file with an object codec should fail

  $ test_objects simple ../data/scalars/string_plain.yml
  JSON: person: ERROR: Missing members in Person object:
   age
   name
  File "-", line 1, characters 0-24:
  YAML: person: ERROR: Missing members in Person object:
   age
   name
  File "-":

Attempting to decode wrong object type (nested when expecting simple) should fail

  $ test_objects simple ../data/objects/nested.yml
  JSON: person: ERROR: Missing member age in Person object
  File "-", line 1, characters 0-92:
  YAML: person: ERROR: Missing member age in Person object
  File "-":
