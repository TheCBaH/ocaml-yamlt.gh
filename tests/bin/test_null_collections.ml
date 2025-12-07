open Bytesrw

let () =
  Printf.printf "=== Test 1: Explicit null as empty array ===\n";
  let yaml1 = "values: null" in
  let codec1 =
    let open Jsont in
    Object.map ~kind:"Test" (fun v -> v)
    |> Object.mem "values" (list int) ~dec_absent:[] ~enc:(fun v -> v)
    |> Object.finish
  in
  (match Yamlt.decode codec1 (Bytes.Reader.of_string yaml1) with
  | Ok v ->
      Printf.printf "Result: [%s]\n"
        (String.concat "; " (List.map string_of_int v))
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== Test 2: Tilde as empty array ===\n";
  let yaml2 = "values: ~" in
  (match Yamlt.decode codec1 (Bytes.Reader.of_string yaml2) with
  | Ok v ->
      Printf.printf "Result: [%s]\n"
        (String.concat "; " (List.map string_of_int v))
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== Test 3: Empty array syntax ===\n";
  let yaml3 = "values: []" in
  (match Yamlt.decode codec1 (Bytes.Reader.of_string yaml3) with
  | Ok v ->
      Printf.printf "Result: [%s]\n"
        (String.concat "; " (List.map string_of_int v))
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== Test 4: Array with values ===\n";
  let yaml4 = "values: [1, 2, 3]" in
  (match Yamlt.decode codec1 (Bytes.Reader.of_string yaml4) with
  | Ok v ->
      Printf.printf "Result: [%s]\n"
        (String.concat "; " (List.map string_of_int v))
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== Test 5: Explicit null as empty object ===\n";
  let yaml5 = "config: null" in
  let codec2 =
    let open Jsont in
    let config_codec =
      Object.map ~kind:"Config" (fun timeout retries -> (timeout, retries))
      |> Object.mem "timeout" int ~dec_absent:30 ~enc:fst
      |> Object.mem "retries" int ~dec_absent:3 ~enc:snd
      |> Object.finish
    in
    Object.map ~kind:"Test" (fun c -> c)
    |> Object.mem "config" config_codec ~dec_absent:(30, 3) ~enc:(fun c -> c)
    |> Object.finish
  in
  (match Yamlt.decode codec2 (Bytes.Reader.of_string yaml5) with
  | Ok (timeout, retries) ->
      Printf.printf "Result: {timeout=%d; retries=%d}\n" timeout retries
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== Test 6: Empty object syntax ===\n";
  let yaml6 = "config: {}" in
  (match Yamlt.decode codec2 (Bytes.Reader.of_string yaml6) with
  | Ok (timeout, retries) ->
      Printf.printf "Result: {timeout=%d; retries=%d}\n" timeout retries
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== Test 7: Object with values ===\n";
  let yaml7 = "config:\n  timeout: 60\n  retries: 5" in
  (match Yamlt.decode codec2 (Bytes.Reader.of_string yaml7) with
  | Ok (timeout, retries) ->
      Printf.printf "Result: {timeout=%d; retries=%d}\n" timeout retries
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== Test 8: Nested null arrays ===\n";
  let yaml8 = "name: test\nitems: null\ntags: ~" in
  let codec3 =
    let open Jsont in
    Object.map ~kind:"Nested" (fun name items tags -> (name, items, tags))
    |> Object.mem "name" string ~enc:(fun (n, _, _) -> n)
    |> Object.mem "items" (list int) ~dec_absent:[] ~enc:(fun (_, i, _) -> i)
    |> Object.mem "tags" (list string) ~dec_absent:[] ~enc:(fun (_, _, t) -> t)
    |> Object.finish
  in
  match Yamlt.decode codec3 (Bytes.Reader.of_string yaml8) with
  | Ok (name, items, tags) ->
      Printf.printf "Result: {name=%s; items_count=%d; tags_count=%d}\n"
        name (List.length items) (List.length tags)
  | Error e -> Printf.printf "Error: %s\n" e
