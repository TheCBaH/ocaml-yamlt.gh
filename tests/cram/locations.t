Location and Layout Preservation Tests with Yamlt
==================================================

This test suite validates the `locs` and `layout` options in the Yamlt decoder,
demonstrating how they affect error messages and metadata preservation.

================================================================================
ERROR MESSAGE PRECISION - locs option
================================================================================

The `locs` option controls whether source locations are preserved in error messages.
When `locs=false` (default), errors show basic location info.
When `locs=true`, errors show precise character positions.

Basic type error with and without locs

  $ test_locations error-precision ../data/locations/type_error.yml
  === Without locs (default) ===
  Error message:
  String "not-a-number" does not parse to OCaml int value
  File "-":
  File "-": in member age of
  File "-": Person object
  
  === With locs=true ===
  Error message:
  String "not-a-number" does not parse to OCaml int value
  File "-", lines 2-3, characters 5-0:
  File "-", line 2, characters 0-3: in member age of
  File "-", line 1, characters 0-1: Person object

================================================================================
NESTED ERROR LOCATIONS
================================================================================

The `locs` option is especially useful for nested structures,
showing exactly where deep errors occur.

Error in nested object field

  $ test_locations nested-error ../data/locations/nested_error.yml
  === Without locs (default) ===
  Nested error:
  String "invalid-zip" does not parse to OCaml int value
  File "-":
  File "-": in member zip of
  File "-": Address object
  File "-": in member address of
  File "-": Employee object
  
  === With locs=true ===
  Nested error:
  String "invalid-zip" does not parse to OCaml int value
  File "-", lines 5-6, characters 7-0:
  File "-", line 5, characters 2-5: in member zip of
  File "-", line 3, characters 2-3: Address object
  File "-", line 2, characters 0-7: in member address of
  File "-", line 1, characters 0-1: Employee object

================================================================================
ARRAY ELEMENT ERROR LOCATIONS
================================================================================

The `locs` option pinpoints which array element caused an error.

Error at specific array index

  $ test_locations array-error ../data/locations/array_error.yml
  === Without locs (default) ===
  Array error:
  String "not-a-number" does not parse to OCaml int value
  File "-":
  at index 2 of
  File "-": array<OCaml int>
  File "-": in member values of
  File "-": Numbers object
  
  === With locs=true ===
  Array error:
  String "not-a-number" does not parse to OCaml int value
  File "-", lines 4-5, characters 4-2:
  at index 2 of
  File "-", line 2, characters 2-3: array<OCaml int>
  File "-", line 1, characters 0-6: in member values of
  File "-", line 1, characters 0-1: Numbers object

================================================================================
FILE PATH IN ERROR MESSAGES
================================================================================

The `file` parameter sets the file path shown in error messages.

  $ test_locations file-path
  === Without file path ===
  Error:
  String "not-a-number" does not parse to OCaml int value
  File "-", lines 2-3, characters 5-0:
  File "-", line 2, characters 0-3: in member age of
  File "-", line 1, characters 0-1: Person object
  
  === With file path ===
  Error:
  String "not-a-number" does not parse to OCaml int value
  File "test.yml", lines 2-3, characters 5-0:
  File "test.yml", line 2, characters 0-3: in member age of
  File "test.yml", line 1, characters 0-1: Person object

================================================================================
MISSING FIELD ERROR LOCATIONS
================================================================================

The `locs` option helps identify where fields are missing.

  $ test_locations missing-field ../data/locations/missing_field.yml
  === Without locs ===
  Missing field:
  Missing member field_c in Complete object
  File "-":
  
  === With locs=true ===
  Missing field:
  Missing member field_c in Complete object
  File "-", line 1, characters 0-1:

================================================================================
LAYOUT PRESERVATION - layout option
================================================================================

The `layout` option controls whether style information (block vs flow)
is preserved in metadata for potential round-tripping.

Basic layout preservation

  $ test_locations layout ../data/locations/simple.yml
  === Without layout (default) ===
  Decoded: host=localhost, port=8080
  Meta preserved: no
  
  === With layout=true ===
  Decoded: host=localhost, port=8080
  Meta preserved: yes (style info available for round-tripping)

================================================================================
ROUND-TRIPPING WITH LAYOUT
================================================================================

With `layout=true` during decode and `format:Layout` during encode,
the original YAML style can be preserved.

Flow style preservation

  $ test_locations roundtrip ../data/locations/flow_style.yml
  === Original YAML ===
  items: [apple, banana, cherry]
  
  === Decode without layout, re-encode ===
  items:
    - apple
    - banana
    - cherry
  
  === Decode with layout=true, re-encode with Layout format ===
  items:
    - apple
    - banana
    - cherry

Block style preservation

  $ test_locations roundtrip ../data/locations/block_style.yml
  === Original YAML ===
  items:
    - apple
    - banana
    - cherry
  
  === Decode without layout, re-encode ===
  items:
    - apple
    - banana
    - cherry
  
  === Decode with layout=true, re-encode with Layout format ===
  items:
    - apple
    - banana
    - cherry

================================================================================
COMBINED OPTIONS - locs and layout together
================================================================================

Both options can be used simultaneously for maximum information.

  $ test_locations combined ../data/locations/valid_settings.yml
  === locs=false, layout=false (defaults) ===
  OK: timeout=30, retries=3
  
  === locs=true, layout=false ===
  OK: timeout=30, retries=3 (with precise locations)
  
  === locs=false, layout=true ===
  OK: timeout=30, retries=3 (with layout metadata)
  
  === locs=true, layout=true (both enabled) ===
  OK: timeout=30, retries=3 (with locations and layout)

================================================================================
SUMMARY OF OPTIONS
================================================================================

locs option:

layout option:

Both options add metadata overhead, so only enable when needed.
For production parsing where you only need the data, use defaults (both false).
