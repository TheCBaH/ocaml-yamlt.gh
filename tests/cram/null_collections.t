Null to Empty Collection Tests
================================

This test suite validates that yamlt treats null values as empty collections
when decoding into Array or Object types, providing a more user-friendly
YAML experience.

================================================================================
NULL AS EMPTY COLLECTION
================================================================================

Test various forms of null decoding as empty arrays and objects

  $ test_null_collections
  === Test 1: Explicit null as empty array ===
  Result: []
  
  === Test 2: Tilde as empty array ===
  Result: []
  
  === Test 3: Empty array syntax ===
  Result: []
  
  === Test 4: Array with values ===
  Result: [1; 2; 3]
  
  === Test 5: Explicit null as empty object ===
  Result: {timeout=30; retries=3}
  
  === Test 6: Empty object syntax ===
  Result: {timeout=30; retries=3}
  
  === Test 7: Object with values ===
  Result: {timeout=60; retries=5}
  
  === Test 8: Nested null arrays ===
  Result: {name=test; items_count=0; tags_count=0}
