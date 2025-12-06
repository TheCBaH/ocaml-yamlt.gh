Scalar Type Resolution Tests with Yamlt Codec
==================================================

This test suite validates how YAML scalars are resolved based on the expected
Jsont type codec, and compares behavior with JSON decoding.

================================================================================
NULL RESOLUTION
================================================================================

Explicit null value

  $ test_scalars null ../data/scalars/null_explicit.yml
  null_codec: null

Tilde as null

  $ test_scalars null ../data/scalars/null_tilde.yml
  null_codec: null

Empty value as null

  $ test_scalars null ../data/scalars/null_empty.yml
  null_codec: null

================================================================================
BOOLEAN TYPE-DIRECTED RESOLUTION
================================================================================

Plain "true" resolves to bool(true) with bool codec, but string "true" with string codec

  $ test_scalars bool ../data/scalars/bool_true_plain.yml
  === Bool Codec ===
  JSON bool_codec
    decode: true
  YAML bool_codec
    decode: true
  
  === String Codec ===
  JSON string_codec
    decode: ERROR: Expected string but found bool
  File "-", line 1, characters 10-11:
  File "-": in member value of
  File "-", line 1, characters 0-11: StringTest object
  YAML string_codec
    decode: "true"

Quoted "true" always resolves to string, even with bool codec

  $ test_scalars bool ../data/scalars/bool_true_quoted.yml
  === Bool Codec ===
  JSON bool_codec
    decode: ERROR: Expected bool but found string
  File "-", line 1, characters 10-11:
  File "-": in member value of
  File "-", line 1, characters 0-11: BoolTest object
  YAML bool_codec
    decode: true
  
  === String Codec ===
  JSON string_codec
    decode: "true"
  YAML string_codec
    decode: "true"

YAML-specific bool: "yes" resolves to bool(true)

  $ test_scalars bool ../data/scalars/bool_yes.yml
  === Bool Codec ===
  JSON bool_codec
    decode: true
  YAML bool_codec
    decode: true
  
  === String Codec ===
  JSON string_codec
    decode: ERROR: Expected string but found bool
  File "-", line 1, characters 10-11:
  File "-": in member value of
  File "-", line 1, characters 0-11: StringTest object
  YAML string_codec
    decode: "yes"

Plain "false" and "no" work similarly

  $ test_scalars bool ../data/scalars/bool_false.yml
  === Bool Codec ===
  JSON bool_codec
    decode: false
  YAML bool_codec
    decode: false
  
  === String Codec ===
  JSON string_codec
    decode: ERROR: Expected string but found bool
  File "-", line 1, characters 10-11:
  File "-": in member value of
  File "-", line 1, characters 0-11: StringTest object
  YAML string_codec
    decode: "false"

  $ test_scalars bool ../data/scalars/bool_no.yml
  === Bool Codec ===
  JSON bool_codec
    decode: false
  YAML bool_codec
    decode: false
  
  === String Codec ===
  JSON string_codec
    decode: ERROR: Expected string but found bool
  File "-", line 1, characters 10-11:
  File "-": in member value of
  File "-", line 1, characters 0-11: StringTest object
  YAML string_codec
    decode: "no"

================================================================================
NUMBER RESOLUTION
================================================================================

Integer values

  $ test_scalars number ../data/scalars/number_int.yml
  JSON number_codec
    decode: 42
  YAML number_codec
    decode: 42

Float values

  $ test_scalars number ../data/scalars/number_float.yml
  JSON number_codec
    decode: 3.1415899999999999
  YAML number_codec
    decode: 3.1415899999999999

Hexadecimal notation (YAML-specific)

  $ test_scalars number ../data/scalars/number_hex.yml
  JSON number_codec
    decode: 42
  YAML number_codec
    decode: 42

Octal notation (YAML-specific)

  $ test_scalars number ../data/scalars/number_octal.yml
  JSON number_codec
    decode: 42
  YAML number_codec
    decode: 42

Negative numbers

  $ test_scalars number ../data/scalars/number_negative.yml
  JSON number_codec
    decode: -273.14999999999998
  YAML number_codec
    decode: -273.14999999999998

================================================================================
SPECIAL FLOAT VALUES (YAML-specific)
================================================================================

Positive infinity

  $ test_scalars special-float ../data/scalars/special_inf.yml
  value: +Infinity

Negative infinity

  $ test_scalars special-float ../data/scalars/special_neg_inf.yml
  value: -Infinity

Not-a-Number (NaN)

  $ test_scalars special-float ../data/scalars/special_nan.yml
  value: NaN

================================================================================
STRING RESOLUTION
================================================================================

Plain strings

  $ test_scalars string ../data/scalars/string_plain.yml
  JSON string_codec
    decode: "hello world"
  YAML string_codec
    decode: "hello world"

Quoted numeric strings stay as strings

  $ test_scalars string ../data/scalars/string_quoted.yml
  JSON string_codec
    decode: "42"
  YAML string_codec
    decode: "42"

Empty strings

  $ test_scalars string ../data/scalars/string_empty.yml
  JSON string_codec
    decode: ""
  YAML string_codec
    decode: ""

================================================================================
TYPE MISMATCH ERRORS
================================================================================

String when bool expected

  $ test_scalars type-mismatch ../data/scalars/mismatch_string_as_bool.yml bool
  Expected error: Expected bool but found scalar hello
  File "-":
  File "-": in member value of
  File "-": BoolTest object

String when number expected

  $ test_scalars type-mismatch ../data/scalars/mismatch_string_as_number.yml number
  Expected error: Expected number but found scalar not-a-number
  File "-":
  File "-": in member value of
  File "-": NumberTest object

Number when null expected

  $ test_scalars type-mismatch ../data/scalars/mismatch_number_as_null.yml null
  Expected error: Expected null but found scalar 42
  File "-":
  File "-": in member value of
  File "-": NullTest object

================================================================================
JSONT.ANY AUTO-RESOLUTION
================================================================================

With Jsont.any, scalars are auto-resolved based on their content

Null auto-resolves to null

  $ test_scalars any ../data/scalars/any_null.yml
  JSON any_codec
    decode: decoded
  YAML any_codec
    decode: decoded

Plain bool auto-resolves to bool

  $ test_scalars any ../data/scalars/any_bool.yml
  JSON any_codec
    decode: decoded
  YAML any_codec
    decode: decoded

Number auto-resolves to number

  $ test_scalars any ../data/scalars/any_number.yml
  JSON any_codec
    decode: decoded
  YAML any_codec
    decode: decoded

Plain string auto-resolves to string

  $ test_scalars any ../data/scalars/any_string.yml
  JSON any_codec
    decode: decoded
  YAML any_codec
    decode: decoded

================================================================================
ENCODING SCALARS
================================================================================

Encoding bool values

  $ test_scalars encode bool true
  JSON: {"value":true}
  YAML Block:
  value: true
  YAML Flow: {value: true}

  $ test_scalars encode bool false
  JSON: {"value":false}
  YAML Block:
  value: false
  YAML Flow: {value: false}

Encoding numbers

  $ test_scalars encode number 42.5
  JSON: {"value":42.5}
  YAML Block:
  value: 42.5
  YAML Flow: {value: 42.5}

Encoding strings

  $ test_scalars encode string "hello world"
  JSON: {"value":"hello world"}
  YAML Block:
  value: hello world
  YAML Flow: {value: hello world}

Encoding null

  $ test_scalars encode null ""
  JSON: {"value":null}
  YAML Block:
  value: null
  YAML Flow: {value: null}

================================================================================
NEGATIVE TESTS - Wrong File Types
================================================================================

Attempting to decode an object file with a scalar codec should fail

  $ test_scalars string ../data/objects/simple.yml
  JSON string_codec
    decode: ERROR: Missing member value in StringTest object
  File "-", line 1, characters 0-28:
  YAML string_codec
    decode: ERROR: Missing member value in StringTest object
  File "-":

Attempting to decode an array file with a scalar codec should fail

  $ test_scalars number ../data/arrays/int_array.yml
  JSON number_codec
    decode: ERROR: Missing member value in NumberTest object
  File "-", line 1, characters 0-27:
  YAML number_codec
    decode: ERROR: Missing member value in NumberTest object
  File "-":
