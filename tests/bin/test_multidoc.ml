(*---------------------------------------------------------------------------
  Copyright (c) 2025 Anil Madhavapeddy <anil@recoil.org>. All rights reserved.
  SPDX-License-Identifier: ISC
---------------------------------------------------------------------------*)

(** Test multi-document YAML streams with decode_all *)

open Bytesrw

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

(* Test: Simple multi-document stream *)
let test_simple file =
  let module M = struct
    type person = { name : string; age : int }

    let person_codec =
      Jsont.Object.map ~kind:"Person" (fun name age -> { name; age })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun p -> p.name)
      |> Jsont.Object.mem "age" Jsont.int ~enc:(fun p -> p.age)
      |> Jsont.Object.finish

    let show p = Printf.sprintf "%s (age %d)" p.name p.age
  end in
  let yaml = read_file file in
  let reader = Bytes.Reader.of_string yaml in
  let seq = Yamlt.decode_all M.person_codec reader in
  Printf.printf "Documents:\n";
  seq |> Seq.iteri (fun i result ->
    Printf.printf "  [%d] " i;
    show_result "" (Result.map M.show result)
  )

(* Test: Count documents *)
let test_count file =
  let yaml = read_file file in
  let reader = Bytes.Reader.of_string yaml in
  let seq = Yamlt.decode_all Jsont.json reader in
  let count = Seq.fold_left (fun acc _ -> acc + 1) 0 seq in
  Printf.printf "Document count: %d\n" count

(* Test: Error tracking - show which documents succeed and which fail *)
let test_errors file =
  let module M = struct
    type person = { name : string; age : int }

    let person_codec =
      Jsont.Object.map ~kind:"Person" (fun name age -> { name; age })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun p -> p.name)
      |> Jsont.Object.mem "age" Jsont.int ~enc:(fun p -> p.age)
      |> Jsont.Object.finish

    let show p = Printf.sprintf "%s (age %d)" p.name p.age
  end in
  let yaml = read_file file in
  let reader = Bytes.Reader.of_string yaml in
  let seq = Yamlt.decode_all M.person_codec reader in
  Printf.printf "Document results:\n";
  seq |> Seq.iteri (fun i result ->
    match result with
    | Ok p -> Printf.printf "  [%d] OK: %s\n" i (M.show p)
    | Error e -> Printf.printf "  [%d] ERROR: %s\n" i (String.trim e)
  )

(* Test: Location tracking with locs=true *)
let test_locations file =
  let module M = struct
    type person = { name : string; age : int }

    let person_codec =
      Jsont.Object.map ~kind:"Person" (fun name age -> { name; age })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun p -> p.name)
      |> Jsont.Object.mem "age" Jsont.int ~enc:(fun p -> p.age)
      |> Jsont.Object.finish
  end in
  let yaml = read_file file in

  Printf.printf "=== Without locs (default) ===\n";
  let reader = Bytes.Reader.of_string yaml in
  let seq = Yamlt.decode_all ~locs:false M.person_codec reader in
  seq |> Seq.iteri (fun i result ->
    match result with
    | Ok _ -> Printf.printf "  [%d] OK\n" i
    | Error e -> Printf.printf "  [%d] ERROR:\n%s\n" i (String.trim e)
  );

  Printf.printf "\n=== With locs=true ===\n";
  let reader = Bytes.Reader.of_string yaml in
  let seq = Yamlt.decode_all ~locs:true ~file:"test.yml" M.person_codec reader in
  seq |> Seq.iteri (fun i result ->
    match result with
    | Ok _ -> Printf.printf "  [%d] OK\n" i
    | Error e -> Printf.printf "  [%d] ERROR:\n%s\n" i (String.trim e)
  )

(* Test: Roundtrip to JSON - decode YAML multidoc, encode each to JSON *)
let test_json_roundtrip file =
  let yaml = read_file file in
  let reader = Bytes.Reader.of_string yaml in
  let seq = Yamlt.decode_all Jsont.json reader in
  Printf.printf "JSON outputs:\n";
  seq |> Seq.iteri (fun i result ->
    match result with
    | Ok json_val ->
        (match Jsont_bytesrw.encode_string Jsont.json json_val with
         | Ok json_str -> Printf.printf "  [%d] %s\n" i (String.trim json_str)
         | Error e -> Printf.printf "  [%d] ENCODE ERROR: %s\n" i e)
    | Error e -> Printf.printf "  [%d] DECODE ERROR: %s\n" i (String.trim e)
  )

(* Test: Nested objects in multidoc *)
let test_nested file =
  let module M = struct
    type address = { street : string; city : string }
    type person = { name : string; age : int; address : address }

    let address_codec =
      Jsont.Object.map ~kind:"Address" (fun street city -> { street; city })
      |> Jsont.Object.mem "street" Jsont.string ~enc:(fun a -> a.street)
      |> Jsont.Object.mem "city" Jsont.string ~enc:(fun a -> a.city)
      |> Jsont.Object.finish

    let person_codec =
      Jsont.Object.map ~kind:"Person" (fun name age address ->
          { name; age; address })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun p -> p.name)
      |> Jsont.Object.mem "age" Jsont.int ~enc:(fun p -> p.age)
      |> Jsont.Object.mem "address" address_codec ~enc:(fun p -> p.address)
      |> Jsont.Object.finish

    let show p =
      Printf.sprintf "%s (age %d) from %s, %s" p.name p.age p.address.street
        p.address.city
  end in
  let yaml = read_file file in
  let reader = Bytes.Reader.of_string yaml in
  let seq = Yamlt.decode_all M.person_codec reader in
  Printf.printf "Nested documents:\n";
  seq |> Seq.iteri (fun i result ->
    Printf.printf "  [%d] " i;
    show_result "" (Result.map M.show result)
  )

(* Test: Arrays in multidoc *)
let test_arrays file =
  let yaml = read_file file in
  let reader = Bytes.Reader.of_string yaml in
  let seq = Yamlt.decode_all Jsont.json reader in
  Printf.printf "Array documents:\n";
  seq |> Seq.iteri (fun i result ->
    match result with
    | Ok json_val ->
        (match Jsont_bytesrw.encode_string Jsont.json json_val with
         | Ok json_str -> Printf.printf "  [%d] %s\n" i (String.trim json_str)
         | Error e -> Printf.printf "  [%d] ERROR: %s\n" i e)
    | Error e -> Printf.printf "  [%d] ERROR: %s\n" i (String.trim e)
  )

(* Test: Scalars in multidoc *)
let test_scalars file =
  let yaml = read_file file in
  let reader = Bytes.Reader.of_string yaml in
  let seq = Yamlt.decode_all Jsont.json reader in
  Printf.printf "Scalar documents:\n";
  seq |> Seq.iteri (fun i result ->
    match result with
    | Ok json_val ->
        (match Jsont_bytesrw.encode_string Jsont.json json_val with
         | Ok json_str -> Printf.printf "  [%d] %s\n" i (String.trim json_str)
         | Error e -> Printf.printf "  [%d] ERROR: %s\n" i e)
    | Error e -> Printf.printf "  [%d] ERROR: %s\n" i (String.trim e)
  )

(* Test: Summary stats - count successes vs failures *)
let test_summary file =
  let module M = struct
    type person = { name : string; age : int }

    let person_codec =
      Jsont.Object.map ~kind:"Person" (fun name age -> { name; age })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun p -> p.name)
      |> Jsont.Object.mem "age" Jsont.int ~enc:(fun p -> p.age)
      |> Jsont.Object.finish
  end in
  let yaml = read_file file in
  let reader = Bytes.Reader.of_string yaml in
  let seq = Yamlt.decode_all M.person_codec reader in
  let success = ref 0 in
  let failure = ref 0 in
  seq |> Seq.iter (fun result ->
    match result with
    | Ok _ -> incr success
    | Error _ -> incr failure
  );
  Printf.printf "Summary: %d documents (%d ok, %d error)\n"
    (!success + !failure) !success !failure

let () =
  let usage = "Usage: test_multidoc <command> <file>" in
  if Array.length Sys.argv < 3 then begin
    prerr_endline usage;
    exit 1
  end;

  let test = Sys.argv.(1) in
  let file = Sys.argv.(2) in
  match test with
  | "simple" -> test_simple file
  | "count" -> test_count file
  | "errors" -> test_errors file
  | "locations" -> test_locations file
  | "json" -> test_json_roundtrip file
  | "nested" -> test_nested file
  | "arrays" -> test_arrays file
  | "scalars" -> test_scalars file
  | "summary" -> test_summary file
  | _ ->
      prerr_endline usage;
      prerr_endline "Commands:";
      prerr_endline "  simple <file>     - Decode person documents";
      prerr_endline "  count <file>      - Count documents";
      prerr_endline "  errors <file>     - Show success/error for each document";
      prerr_endline "  locations <file>  - Test location tracking with locs=true";
      prerr_endline "  json <file>       - Roundtrip to JSON";
      prerr_endline "  nested <file>     - Decode nested objects";
      prerr_endline "  arrays <file>     - Decode arrays";
      prerr_endline "  scalars <file>    - Decode scalars";
      prerr_endline "  summary <file>    - Show success/failure summary";
      exit 1
