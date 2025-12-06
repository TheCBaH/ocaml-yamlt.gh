Complex Nested Types Tests with Yamlt
======================================

This test suite validates complex nested structures combining objects, arrays,
and various levels of nesting.

================================================================================
DEEPLY NESTED OBJECTS
================================================================================

Handle deeply nested object structures

  $ test_complex deep-nesting ../data/complex/deep_nesting.yml
  JSON: deep_nesting: depth=4, value=42
  YAML: deep_nesting: depth=4, value=42

================================================================================
MIXED STRUCTURES
================================================================================

Arrays of objects containing arrays

  $ test_complex mixed-structure ../data/complex/mixed_structure.yml
  JSON: mixed_structure: name="products", items=3, total_tags=6
  YAML: mixed_structure: name="products", items=3, total_tags=6

================================================================================
COMPLEX OPTIONAL COMBINATIONS
================================================================================

Multiple optional fields with different combinations

  $ test_complex complex-optional ../data/complex/complex_optional.yml
  JSON: complex_optional: host="example.com", port=443, ssl=true, fallbacks=2
  YAML: complex_optional: host="example.com", port=443, ssl=true, fallbacks=2

================================================================================
HETEROGENEOUS DATA
================================================================================

Mixed types in arrays using any type

  $ test_complex heterogeneous ../data/complex/heterogeneous.yml
  JSON: heterogeneous: ERROR: Expected one of  but found number
  File "-", line 1, characters 11-12:
  File "-", line 1, characters 11-12: at index 0 of
  File "-", line 1, characters 10-12: array<one of >
  File "-": in member mixed of
  File "-", line 1, characters 0-12: Data object
  YAML: heterogeneous: ERROR: Expected one of  but found number
  File "-":
  at index 0 of
  File "-": array<one of >
  File "-": in member mixed of
  File "-": Data object

================================================================================
NEGATIVE TESTS - Structure Mismatch
================================================================================

Using deeply nested data with flat codec should fail

  $ test_complex mixed-structure ../data/complex/deep_nesting.yml
  JSON: mixed_structure: ERROR: Missing members in Collection object:
   items
   name
  File "-", line 1, characters 0-44:
  YAML: mixed_structure: ERROR: Missing members in Collection object:
   items
   name
  File "-":
