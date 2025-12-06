let () =
  Printf.printf "=== Test 1: Jsont.option with YAML null ===\n";
  let yaml1 = "value: null" in
  let codec1 =
    let open Jsont in
    Object.map ~kind:"Test" (fun v -> v)
    |> Object.mem "value" (option string) ~enc:(fun v -> v)
    |> Object.finish
  in
  (match Yamlt.decode_string codec1 yaml1 with
   | Ok v -> Printf.printf "Result: %s\n" (match v with None -> "None" | Some s -> "Some(" ^ s ^ ")")
   | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== Test 2: Jsont.option with YAML string ===\n";
  (match Yamlt.decode_string codec1 "value: hello" with
   | Ok v -> Printf.printf "Result: %s\n" (match v with None -> "None" | Some s -> "Some(" ^ s ^ ")")
   | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== Test 3: Jsont.string with YAML null (should error) ===\n";
  let codec2 =
    let open Jsont in
    Object.map ~kind:"Test" (fun v -> v)
    |> Object.mem "value" string ~enc:(fun v -> v)
    |> Object.finish
  in
  (match Yamlt.decode_string codec2 "value: null" with
   | Ok v -> Printf.printf "Result: %s\n" v
   | Error e -> Printf.printf "Error (expected): %s\n" e);

  Printf.printf "\n=== Test 4: Jsont.string with YAML string ===\n";
  (match Yamlt.decode_string codec2 "value: hello" with
   | Ok v -> Printf.printf "Result: %s\n" v
   | Error e -> Printf.printf "Error: %s\n" e)
