(*---------------------------------------------------------------------------
   Copyright (c) 2024 The yamlrw programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

(** Test complex nested types with Yamlt *)

(* Helper to read file *)
let read_file path =
  let ic = open_in path in
  let len = in_channel_length ic in
  let s = really_input_string ic len in
  close_in ic;
  s

(* Helper to show results *)
let show_result label = function
  | Ok v -> Printf.printf "%s: %s\n" label v
  | Error e -> Printf.printf "%s: ERROR: %s\n" label e

let show_result_both label json_result yaml_result =
  Printf.printf "JSON: ";
  show_result label json_result;
  Printf.printf "YAML: ";
  show_result label yaml_result

(* Test: Deeply nested objects *)
let test_deep_nesting file =
  let module M = struct
    type level3 = { value: int }
    type level2 = { data: level3 }
    type level1 = { nested: level2 }
    type root = { top: level1 }

    let level3_codec =
      Jsont.Object.map ~kind:"Level3" (fun value -> { value })
      |> Jsont.Object.mem "value" Jsont.int ~enc:(fun l -> l.value)
      |> Jsont.Object.finish

    let level2_codec =
      Jsont.Object.map ~kind:"Level2" (fun data -> { data })
      |> Jsont.Object.mem "data" level3_codec ~enc:(fun l -> l.data)
      |> Jsont.Object.finish

    let level1_codec =
      Jsont.Object.map ~kind:"Level1" (fun nested -> { nested })
      |> Jsont.Object.mem "nested" level2_codec ~enc:(fun l -> l.nested)
      |> Jsont.Object.finish

    let root_codec =
      Jsont.Object.map ~kind:"Root" (fun top -> { top })
      |> Jsont.Object.mem "top" level1_codec ~enc:(fun r -> r.top)
      |> Jsont.Object.finish

    let show r = Printf.sprintf "depth=4, value=%d" r.top.nested.data.value
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.root_codec json in
  let yaml_result = Yamlt.decode_string M.root_codec yaml in

  show_result_both "deep_nesting"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Array of objects with nested arrays *)
let test_mixed_structure file =
  let module M = struct
    type item = { id: int; tags: string array }
    type collection = { name: string; items: item array }

    let item_codec =
      Jsont.Object.map ~kind:"Item" (fun id tags -> { id; tags })
      |> Jsont.Object.mem "id" Jsont.int ~enc:(fun i -> i.id)
      |> Jsont.Object.mem "tags" (Jsont.array Jsont.string) ~enc:(fun i -> i.tags)
      |> Jsont.Object.finish

    let collection_codec =
      Jsont.Object.map ~kind:"Collection" (fun name items -> { name; items })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun c -> c.name)
      |> Jsont.Object.mem "items" (Jsont.array item_codec) ~enc:(fun c -> c.items)
      |> Jsont.Object.finish

    let show c =
      let total_tags = Stdlib.Array.fold_left (fun acc item ->
        acc + Stdlib.Array.length item.tags) 0 c.items in
      Printf.sprintf "name=%S, items=%d, total_tags=%d"
        c.name (Stdlib.Array.length c.items) total_tags
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.collection_codec json in
  let yaml_result = Yamlt.decode_string M.collection_codec yaml in

  show_result_both "mixed_structure"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Complex optional and nullable combinations *)
let test_complex_optional file =
  let module M = struct
    type config = {
      host: string;
      port: int option;
      ssl: bool option;
      cert_path: string option;
      fallback_hosts: string array option;
    }

    let config_codec =
      Jsont.Object.map ~kind:"Config"
        (fun host port ssl cert_path fallback_hosts ->
          { host; port; ssl; cert_path; fallback_hosts })
      |> Jsont.Object.mem "host" Jsont.string ~enc:(fun c -> c.host)
      |> Jsont.Object.opt_mem "port" Jsont.int ~enc:(fun c -> c.port)
      |> Jsont.Object.opt_mem "ssl" Jsont.bool ~enc:(fun c -> c.ssl)
      |> Jsont.Object.opt_mem "cert_path" Jsont.string ~enc:(fun c -> c.cert_path)
      |> Jsont.Object.opt_mem "fallback_hosts" (Jsont.array Jsont.string)
          ~enc:(fun c -> c.fallback_hosts)
      |> Jsont.Object.finish

    let show c =
      let port_str = match c.port with None -> "None" | Some p -> string_of_int p in
      let ssl_str = match c.ssl with None -> "None" | Some b -> string_of_bool b in
      let fallbacks = match c.fallback_hosts with
        | None -> 0
        | Some arr -> Stdlib.Array.length arr in
      Printf.sprintf "host=%S, port=%s, ssl=%s, fallbacks=%d"
        c.host port_str ssl_str fallbacks
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.config_codec json in
  let yaml_result = Yamlt.decode_string M.config_codec yaml in

  show_result_both "complex_optional"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Heterogeneous data via any type *)
let test_heterogeneous file =
  let module M = struct
    type data = { mixed: Jsont.json array }

    let data_codec =
      Jsont.Object.map ~kind:"Data" (fun mixed -> { mixed })
      |> Jsont.Object.mem "mixed" (Jsont.array (Jsont.any ())) ~enc:(fun d -> d.mixed)
      |> Jsont.Object.finish

    let show d = Printf.sprintf "items=%d" (Stdlib.Array.length d.mixed)
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.data_codec json in
  let yaml_result = Yamlt.decode_string M.data_codec yaml in

  show_result_both "heterogeneous"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

let () =
  let usage = "Usage: test_complex <command> [args...]" in

  if Stdlib.Array.length Sys.argv < 2 then begin
    prerr_endline usage;
    exit 1
  end;

  match Sys.argv.(1) with
  | "deep-nesting" when Stdlib.Array.length Sys.argv = 3 ->
      test_deep_nesting Sys.argv.(2)

  | "mixed-structure" when Stdlib.Array.length Sys.argv = 3 ->
      test_mixed_structure Sys.argv.(2)

  | "complex-optional" when Stdlib.Array.length Sys.argv = 3 ->
      test_complex_optional Sys.argv.(2)

  | "heterogeneous" when Stdlib.Array.length Sys.argv = 3 ->
      test_heterogeneous Sys.argv.(2)

  | _ ->
      prerr_endline usage;
      prerr_endline "Commands:";
      prerr_endline "  deep-nesting <file>      - Test deeply nested objects";
      prerr_endline "  mixed-structure <file>   - Test arrays of objects with nested arrays";
      prerr_endline "  complex-optional <file>  - Test complex optional/nullable combinations";
      prerr_endline "  heterogeneous <file>     - Test heterogeneous data via any type";
      exit 1
