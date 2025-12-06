Format-Specific Features Tests with Yamlt
==========================================

This test suite validates YAML-specific format features and compares with JSON behavior.

================================================================================
MULTI-LINE STRINGS - LITERAL STYLE
================================================================================

Literal style (|) preserves newlines

  $ test_formats literal ../data/formats/literal_string.yml
  JSON: literal_string: lines=5, length=81
  YAML: literal_string: lines=5, length=81

================================================================================
MULTI-LINE STRINGS - FOLDED STYLE
================================================================================

Folded style (>) folds lines into single line

  $ test_formats folded ../data/formats/folded_string.yml
  JSON: folded_string: length=114, newlines=1
  YAML: folded_string: length=114, newlines=1

================================================================================
NUMBER FORMATS
================================================================================

YAML supports hex, octal, and binary number formats

  $ test_formats number-formats ../data/formats/number_formats.yml
  JSON: number_formats: hex=255, octal=63, binary=10
  YAML: number_formats: ERROR: Expected number but found scalar 0o77
  File "-":
  File "-": in member octal of
  File "-": Numbers object

================================================================================
COMMENTS
================================================================================

YAML comments are ignored during parsing

  $ test_formats comments ../data/formats/comments.yml
  YAML (with comments): host="localhost", port=8080, debug=true

================================================================================
EMPTY DOCUMENTS
================================================================================

Empty or null documents handled correctly

  $ test_formats empty-doc ../data/formats/empty_doc.yml
  JSON: empty_document: ERROR: Expected string but found null
  File "-", line 1, characters 10-11:
  File "-": in member value of
  File "-", line 1, characters 0-11: Wrapper object
  YAML: empty_document: value=Some("null")

================================================================================
EXPLICIT TYPE TAGS
================================================================================

Explicit YAML type tags (!!str, !!int, etc.)

  $ test_formats explicit-tags ../data/formats/explicit_tags.yml
  YAML (with tags): data="123"

================================================================================
ENCODING STYLES
================================================================================

Compare Block vs Flow encoding styles

  $ test_formats encode-styles
  YAML Block:
  name: test
  values:
    - 1.0
    - 2.0
    - 3.0
  nested:
    enabled: true
    count: 5.0
  
  YAML Flow:
  {name: test, values: [1.0, 2.0, 3.0]nested, {enabled: true, count: 5.0}}


================================================================================
NEGATIVE TESTS - Format Compatibility
================================================================================

Using literal string test with number codec should fail

  $ test_formats number-formats ../data/formats/literal_string.yml
  JSON: number_formats: ERROR: Missing members in Numbers object:
   binary
   hex
   octal
  File "-", line 1, characters 0-100:
  YAML: number_formats: ERROR: Missing members in Numbers object:
   binary
   hex
   octal
  File "-":
