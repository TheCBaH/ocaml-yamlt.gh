Edge Cases Tests with Yamlt
============================

This test suite validates edge cases including large numbers, special characters,
unicode, and boundary conditions.

================================================================================
LARGE NUMBERS
================================================================================

Very large and very small floating point numbers

  $ test_edge large-numbers ../data/edge/large_numbers.yml
  JSON: large_numbers: large_int=9007199254740991, large_float=1.797693e+308, small_float=2.225074e-308
  YAML: large_numbers: large_int=9007199254740991, large_float=1.797693e+308, small_float=2.225074e-308

================================================================================
SPECIAL CHARACTERS
================================================================================

Strings containing newlines, tabs, and other special characters

  $ test_edge special-chars ../data/edge/special_chars.yml
  JSON: special_chars: length=34, contains_newline=true, contains_tab=true
  YAML: special_chars: length=34, contains_newline=true, contains_tab=true

================================================================================
UNICODE STRINGS
================================================================================

Emoji, Chinese, and RTL text

  $ test_edge unicode ../data/edge/unicode.yml
  JSON: unicode: emoji="\240\159\142\137\240\159\154\128\226\156\168", chinese="\228\189\160\229\165\189\228\184\150\231\149\140", rtl="\217\133\216\177\216\173\216\168\216\167"
  YAML: unicode: emoji="\240\159\142\137\240\159\154\128\226\156\168", chinese="\228\189\160\229\165\189\228\184\150\231\149\140", rtl="\217\133\216\177\216\173\216\168\216\167"

================================================================================
EMPTY COLLECTIONS
================================================================================

Empty arrays and objects

  $ test_edge empty-collections ../data/edge/empty_collections.yml
  JSON: empty_collections: empty_array_len=0, empty_object_array_len=0
  YAML: empty_collections: empty_array_len=0, empty_object_array_len=0

================================================================================
SPECIAL KEY NAMES
================================================================================

Keys with dots, dashes, colons

  $ test_edge special-keys ../data/edge/special_keys.yml
  JSON: special_keys: ERROR: Expected one of  but found object
  File "-", line 1, characters 0-1:
  YAML: special_keys: ERROR: Expected one of  but found object
  File "-":

================================================================================
SINGLE-ELEMENT ARRAYS
================================================================================

Arrays with exactly one element

  $ test_edge single-element ../data/edge/single_element.yml
  JSON: single_element: length=1, value=42
  YAML: single_element: length=1, value=42

================================================================================
NEGATIVE TESTS - Boundary Violations
================================================================================

Using unicode data with number codec should fail

  $ test_edge large-numbers ../data/edge/unicode.yml
  JSON: large_numbers: ERROR: Missing members in Numbers object:
   large_float
   large_int
   small_float
  File "-", line 1, characters 0-72:
  YAML: large_numbers: ERROR: Missing members in Numbers object:
   large_float
   large_int
   small_float
  File "-":
