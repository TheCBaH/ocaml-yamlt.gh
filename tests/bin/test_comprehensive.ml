let () =
  (* Test 1: Null handling with option types *)
  Printf.printf "=== NULL HANDLING ===\n";
  let opt_codec =
    Jsont.Object.map ~kind:"Test" (fun v -> v)
    |> Jsont.Object.mem "value" (Jsont.option Jsont.string) ~enc:(fun v -> v)
    |> Jsont.Object.finish
  in
  
  (match Yamlt.decode_string opt_codec "value: null" with
   | Ok None -> Printf.printf "✓ Plain 'null' with option codec: None\n"
   | _ -> Printf.printf "✗ FAIL\n");
  
  (match Yamlt.decode_string opt_codec "value: hello" with
   | Ok (Some "hello") -> Printf.printf "✓ Plain 'hello' with option codec: Some(hello)\n"
   | _ -> Printf.printf "✗ FAIL\n");
  
  let string_codec =
    Jsont.Object.map ~kind:"Test" (fun v -> v)
    |> Jsont.Object.mem "value" Jsont.string ~enc:(fun v -> v)
    |> Jsont.Object.finish
  in
  
  (match Yamlt.decode_string string_codec "value: null" with
   | Error _ -> Printf.printf "✓ Plain 'null' with string codec: ERROR (expected)\n"
   | _ -> Printf.printf "✗ FAIL\n");
  
  (match Yamlt.decode_string string_codec "value: \"\"" with
   | Ok "" -> Printf.printf "✓ Quoted empty string: \"\"\n"
   | _ -> Printf.printf "✗ FAIL\n");
  
  (match Yamlt.decode_string string_codec "value: \"null\"" with
   | Ok "null" -> Printf.printf "✓ Quoted 'null': \"null\"\n"
   | _ -> Printf.printf "✗ FAIL\n");
  
  (* Test 2: Number formats *)
  Printf.printf "\n=== NUMBER FORMATS ===\n";
  let num_codec =
    Jsont.Object.map ~kind:"Test" (fun v -> v)
    |> Jsont.Object.mem "value" Jsont.number ~enc:(fun v -> v)
    |> Jsont.Object.finish
  in
  
  (match Yamlt.decode_string num_codec "value: 0xFF" with
   | Ok 255. -> Printf.printf "✓ Hex 0xFF: 255\n"
   | _ -> Printf.printf "✗ FAIL\n");
  
  (match Yamlt.decode_string num_codec "value: 0o77" with
   | Ok 63. -> Printf.printf "✓ Octal 0o77: 63\n"
   | _ -> Printf.printf "✗ FAIL\n");
  
  (match Yamlt.decode_string num_codec "value: 0b1010" with
   | Ok 10. -> Printf.printf "✓ Binary 0b1010: 10\n"
   | _ -> Printf.printf "✗ FAIL\n");
  
  (* Test 3: Optional arrays *)
  Printf.printf "\n=== OPTIONAL ARRAYS ===\n";
  let opt_array_codec =
    Jsont.Object.map ~kind:"Test" (fun v -> v)
    |> Jsont.Object.opt_mem "values" (Jsont.array Jsont.string) ~enc:(fun v -> v)
    |> Jsont.Object.finish
  in
  
  (match Yamlt.decode_string opt_array_codec "values: [a, b, c]" with
   | Ok (Some arr) when Array.length arr = 3 ->
       Printf.printf "✓ Optional array [a, b, c]: Some([3 items])\n"
   | _ -> Printf.printf "✗ FAIL\n");
  
  (match Yamlt.decode_string opt_array_codec "{}" with
   | Ok None -> Printf.printf "✓ Missing optional array: None\n"
   | _ -> Printf.printf "✗ FAIL\n");
  
  (* Test 4: Flow encoding *)
  Printf.printf "\n=== FLOW ENCODING ===\n";
  let encode_codec =
    Jsont.Object.map ~kind:"Test" (fun name values -> (name, values))
    |> Jsont.Object.mem "name" Jsont.string ~enc:fst
    |> Jsont.Object.mem "values" (Jsont.array Jsont.number) ~enc:snd
    |> Jsont.Object.finish
  in
  
  (match Yamlt.encode_string ~format:Flow encode_codec ("test", [|1.; 2.; 3.|]) with
   | Ok yaml_flow when String.equal yaml_flow "{name: test, values: [1.0, 2.0, 3.0]}\n" ->
       Printf.printf "✓ Flow encoding with comma separator\n"
   | Ok yaml_flow ->
       Printf.printf "✗ FAIL: %S\n" yaml_flow
   | Error e ->
       Printf.printf "✗ ERROR: %s\n" e)
