Array Codec Tests with Yamlt
===============================

This test suite validates array encoding/decoding with Jsont codecs in YAML,
including homogeneous type checking and nested structures.

Setup
-----

================================================================================
HOMOGENEOUS ARRAYS
================================================================================

Integer arrays

  $ test_arrays int ../data/arrays/int_array.yml
  JSON: int_array: [1; 2; 3; 4; 5]
  YAML: int_array: [1; 2; 3; 4; 5]

String arrays

  $ test_arrays string ../data/arrays/string_array.yml
  JSON: string_array: ["apple"; "banana"; "cherry"]
  YAML: string_array: ["apple"; "banana"; "cherry"]

Float/Number arrays

  $ test_arrays float ../data/arrays/float_array.yml
  JSON: float_array: [1.50; 2.70; 3.14; 0.50]
  YAML: float_array: [1.50; 2.70; 3.14; 0.50]

Boolean arrays

  $ test_arrays bool ../data/arrays/bool_array.yml
  JSON: bool_array: [true; false; true; true; false]
  YAML: bool_array: [true; false; true; true; false]

================================================================================
EMPTY ARRAYS
================================================================================

Empty arrays work correctly

  $ test_arrays empty ../data/arrays/empty_array.yml
  JSON: empty_array: length=0
  YAML: empty_array: length=0

================================================================================
ARRAYS OF OBJECTS
================================================================================

Arrays containing objects

  $ test_arrays objects ../data/arrays/object_array.yml
  JSON: object_array: [{Alice,30}; {Bob,25}; {Charlie,35}]
  YAML: object_array: [{Alice,30}; {Bob,25}; {Charlie,35}]

================================================================================
NESTED ARRAYS
================================================================================

Arrays containing arrays (matrices)

  $ test_arrays nested ../data/arrays/nested_array.yml
  JSON: nested_arrays: [[1; 2; 3]; [4; 5; 6]; [7; 8; 9]]
  YAML: nested_arrays: [[1; 2; 3]; [4; 5; 6]; [7; 8; 9]]

================================================================================
NULLABLE ARRAYS
================================================================================

Arrays with null elements

  $ test_arrays nullable ../data/arrays/nullable_array.yml
  JSON: nullable_array: ERROR: Expected string but found null
  File "-", line 1, characters 21-22:
  File "-", line 1, characters 21-22: at index 1 of
  File "-", line 1, characters 11-22: array<string>
  File "-": in member values of
  File "-", line 1, characters 0-22: Nullable object
  YAML: nullable_array: ERROR: Expected string but found null
  File "-":
  at index 1 of
  File "-": array<string>
  File "-": in member values of
  File "-": Nullable object

================================================================================
ERROR HANDLING
================================================================================

Type mismatch in array element

  $ test_arrays type-mismatch ../data/arrays/type_mismatch.yml
  Expected error: String "not-a-number" does not parse to OCaml int value
  File "-":
  at index 2 of
  File "-": array<OCaml int>
  File "-": in member values of
  File "-": Numbers object

================================================================================
ENCODING ARRAYS
================================================================================

Encode arrays to JSON and YAML formats

  $ test_arrays encode
  JSON: {"numbers":[1,2,3,4,5],"strings":["hello","world"]}
  YAML Block:
  numbers:
    - 1
    - 2
    - 3
    - 4
    - 5
  strings:
    - hello
    - world
  YAML Flow: {numbers: [1, 2, 3, 4, 5], strings: [hello, world]}

================================================================================
NEGATIVE TESTS - Wrong File Types
================================================================================

Attempting to decode an object file with an array codec should fail

  $ test_arrays int ../data/objects/simple.yml
  JSON: int_array: ERROR: Missing member values in Numbers object
  File "-", line 1, characters 0-28:
  YAML: int_array: ERROR: Missing member values in Numbers object
  File "-":

Attempting to decode a scalar file with an array codec should fail

  $ test_arrays string ../data/scalars/string_plain.yml
  JSON: string_array: ERROR: Missing member items in Tags object
  File "-", line 1, characters 0-24:
  YAML: string_array: ERROR: Missing member items in Tags object
  File "-":

Attempting to decode int array with string array codec should fail

  $ test_arrays string ../data/arrays/int_array.yml
  JSON: string_array: ERROR: Missing member items in Tags object
  File "-", line 1, characters 0-27:
  YAML: string_array: ERROR: Missing member items in Tags object
  File "-":
