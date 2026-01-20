(*---------------------------------------------------------------------------
  Copyright (c) 2025 Anil Madhavapeddy <anil@recoil.org>. All rights reserved.
  SPDX-License-Identifier: ISC
 ---------------------------------------------------------------------------*)

(** Test location and layout preservation options with Yamlt codec *)

(* Helper to read file *)
open Bytesrw

let read_file path =
  let ic = open_in path in
  let len = in_channel_length ic in
  let s = really_input_string ic len in
  close_in ic;
  s

(* Helper to show results *)
let show_result label = function
  | Ok _ -> Printf.printf "%s: OK\n" label
  | Error e -> Printf.printf "%s:\n%s\n" label e

(* Test: Compare error messages with and without locs *)
let test_error_precision file =
  let yaml = read_file file in

  (* Define a codec that will fail on type mismatch *)
  let codec =
    Jsont.Object.map ~kind:"Person" (fun name age -> (name, age))
    |> Jsont.Object.mem "name" Jsont.string ~enc:fst
    |> Jsont.Object.mem "age" Jsont.int ~enc:snd
    |> Jsont.Object.finish
  in

  Printf.printf "=== Without locs (default) ===\n";
  let result_no_locs =
    Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:false
  in
  show_result "Error message" result_no_locs;

  Printf.printf "\n=== With locs=true ===\n";
  let result_with_locs =
    Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:true
  in
  show_result "Error message" result_with_locs

(* Test: Show error locations for nested structures *)
let test_nested_error file =
  let yaml = read_file file in

  (* Nested object codec *)
  let address_codec =
    Jsont.Object.map ~kind:"Address" (fun street city zip ->
        (street, city, zip))
    |> Jsont.Object.mem "street" Jsont.string ~enc:(fun (s, _, _) -> s)
    |> Jsont.Object.mem "city" Jsont.string ~enc:(fun (_, c, _) -> c)
    |> Jsont.Object.mem "zip" Jsont.int ~enc:(fun (_, _, z) -> z)
    |> Jsont.Object.finish
  in

  let codec =
    Jsont.Object.map ~kind:"Employee" (fun name address -> (name, address))
    |> Jsont.Object.mem "name" Jsont.string ~enc:fst
    |> Jsont.Object.mem "address" address_codec ~enc:snd
    |> Jsont.Object.finish
  in

  Printf.printf "=== Without locs (default) ===\n";
  let result_no_locs =
    Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:false
  in
  show_result "Nested error" result_no_locs;

  Printf.printf "\n=== With locs=true ===\n";
  let result_with_locs =
    Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:true
  in
  show_result "Nested error" result_with_locs

(* Test: Array element error locations *)
let test_array_error file =
  let yaml = read_file file in

  (* Array codec *)
  let codec =
    Jsont.Object.map ~kind:"Numbers" (fun nums -> nums)
    |> Jsont.Object.mem "values" (Jsont.array Jsont.int) ~enc:(fun n -> n)
    |> Jsont.Object.finish
  in

  Printf.printf "=== Without locs (default) ===\n";
  let result_no_locs =
    Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:false
  in
  show_result "Array error" result_no_locs;

  Printf.printf "\n=== With locs=true ===\n";
  let result_with_locs =
    Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:true
  in
  show_result "Array error" result_with_locs

(* Test: Layout preservation - check if we can decode with layout info *)
let test_layout_preservation file =
  let yaml = read_file file in

  let codec =
    Jsont.Object.map ~kind:"Config" (fun host port -> (host, port))
    |> Jsont.Object.mem "host" Jsont.string ~enc:fst
    |> Jsont.Object.mem "port" Jsont.int ~enc:snd
    |> Jsont.Object.finish
  in

  Printf.printf "=== Without layout (default) ===\n";
  (match Yamlt.decode codec (Bytes.Reader.of_string yaml) ~layout:false with
  | Ok (host, port) ->
      Printf.printf "Decoded: host=%s, port=%d\n" host port;
      Printf.printf "Meta preserved: no\n"
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== With layout=true ===\n";
  match Yamlt.decode codec (Bytes.Reader.of_string yaml) ~layout:true with
  | Ok (host, port) ->
      Printf.printf "Decoded: host=%s, port=%d\n" host port;
      Printf.printf
        "Meta preserved: yes (style info available for round-tripping)\n"
  | Error e -> Printf.printf "Error: %s\n" e

(* Test: Round-trip with layout preservation *)
let test_roundtrip_layout file =
  let yaml = read_file file in

  let codec =
    Jsont.Object.map ~kind:"Data" (fun items -> items)
    |> Jsont.Object.mem "items" (Jsont.array Jsont.string) ~enc:(fun x -> x)
    |> Jsont.Object.finish
  in

  Printf.printf "=== Original YAML ===\n";
  Printf.printf "%s\n" (String.trim yaml);

  Printf.printf "\n=== Decode without layout, re-encode ===\n";
  (match Yamlt.decode codec (Bytes.Reader.of_string yaml) ~layout:false with
  | Ok items -> (
      let b = Buffer.create 256 in
      let writer = Bytes.Writer.of_buffer b in
      match Yamlt.encode ~format:Yamlt.Block codec items ~eod:true writer with
      | Ok () -> Printf.printf "%s" (Buffer.contents b)
      | Error e -> Printf.printf "Encode error: %s\n" e)
  | Error e -> Printf.printf "Decode error: %s\n" e);

  Printf.printf
    "\n=== Decode with layout=true, re-encode with Layout format ===\n";
  match Yamlt.decode codec (Bytes.Reader.of_string yaml) ~layout:true with
  | Ok items -> (
      let b = Buffer.create 256 in
      let writer = Bytes.Writer.of_buffer b in
      match Yamlt.encode ~format:Yamlt.Layout codec items ~eod:true writer with
      | Ok () -> Printf.printf "%s" (Buffer.contents b)
      | Error e -> Printf.printf "Encode error: %s\n" e)
  | Error e -> Printf.printf "Decode error: %s\n" e

(* Test: File path in error messages *)
let test_file_path () =
  let yaml = "name: Alice\nage: not-a-number\n" in

  let codec =
    Jsont.Object.map ~kind:"Person" (fun name age -> (name, age))
    |> Jsont.Object.mem "name" Jsont.string ~enc:fst
    |> Jsont.Object.mem "age" Jsont.int ~enc:snd
    |> Jsont.Object.finish
  in

  Printf.printf "=== Without file path ===\n";
  let result1 = Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:true in
  show_result "Error" result1;

  Printf.printf "\n=== With file path ===\n";
  let result2 =
    Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:true ~file:"test.yml"
  in
  show_result "Error" result2

(* Test: Missing field error with locs *)
let test_missing_field file =
  let yaml = read_file file in

  let codec =
    Jsont.Object.map ~kind:"Complete" (fun a b c -> (a, b, c))
    |> Jsont.Object.mem "field_a" Jsont.string ~enc:(fun (a, _, _) -> a)
    |> Jsont.Object.mem "field_b" Jsont.int ~enc:(fun (_, b, _) -> b)
    |> Jsont.Object.mem "field_c" Jsont.bool ~enc:(fun (_, _, c) -> c)
    |> Jsont.Object.finish
  in

  Printf.printf "=== Without locs ===\n";
  let result_no_locs =
    Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:false
  in
  show_result "Missing field" result_no_locs;

  Printf.printf "\n=== With locs=true ===\n";
  let result_with_locs =
    Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:true
  in
  show_result "Missing field" result_with_locs

(* Test: Both locs and layout together *)
let test_combined_options file =
  let yaml = read_file file in

  let codec =
    Jsont.Object.map ~kind:"Settings" (fun timeout retries ->
        (timeout, retries))
    |> Jsont.Object.mem "timeout" Jsont.int ~enc:fst
    |> Jsont.Object.mem "retries" Jsont.int ~enc:snd
    |> Jsont.Object.finish
  in

  Printf.printf "=== locs=false, layout=false (defaults) ===\n";
  (match
     Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:false ~layout:false
   with
  | Ok (timeout, retries) ->
      Printf.printf "OK: timeout=%d, retries=%d\n" timeout retries
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== locs=true, layout=false ===\n";
  (match
     Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:true ~layout:false
   with
  | Ok (timeout, retries) ->
      Printf.printf "OK: timeout=%d, retries=%d (with precise locations)\n"
        timeout retries
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== locs=false, layout=true ===\n";
  (match
     Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:false ~layout:true
   with
  | Ok (timeout, retries) ->
      Printf.printf "OK: timeout=%d, retries=%d (with layout metadata)\n"
        timeout retries
  | Error e -> Printf.printf "Error: %s\n" e);

  Printf.printf "\n=== locs=true, layout=true (both enabled) ===\n";
  match
    Yamlt.decode codec (Bytes.Reader.of_string yaml) ~locs:true ~layout:true
  with
  | Ok (timeout, retries) ->
      Printf.printf "OK: timeout=%d, retries=%d (with locations and layout)\n"
        timeout retries
  | Error e -> Printf.printf "Error: %s\n" e

let () =
  let usage = "Usage: test_locations <command> [args...]" in

  if Stdlib.Array.length Sys.argv < 2 then begin
    prerr_endline usage;
    exit 1
  end;

  match Sys.argv.(1) with
  | "error-precision" when Array.length Sys.argv = 3 ->
      test_error_precision Sys.argv.(2)
  | "nested-error" when Array.length Sys.argv = 3 ->
      test_nested_error Sys.argv.(2)
  | "array-error" when Array.length Sys.argv = 3 ->
      test_array_error Sys.argv.(2)
  | "layout" when Array.length Sys.argv = 3 ->
      test_layout_preservation Sys.argv.(2)
  | "roundtrip" when Array.length Sys.argv = 3 ->
      test_roundtrip_layout Sys.argv.(2)
  | "file-path" -> test_file_path ()
  | "missing-field" when Array.length Sys.argv = 3 ->
      test_missing_field Sys.argv.(2)
  | "combined" when Array.length Sys.argv = 3 ->
      test_combined_options Sys.argv.(2)
  | _ ->
      prerr_endline usage;
      prerr_endline "Commands:";
      prerr_endline
        "  error-precision <file>   - Compare error messages with/without locs";
      prerr_endline
        "  nested-error <file>      - Test error locations in nested objects";
      prerr_endline
        "  array-error <file>       - Test error locations in arrays";
      prerr_endline "  layout <file>            - Test layout preservation";
      prerr_endline
        "  roundtrip <file>         - Test round-tripping with layout";
      prerr_endline
        "  file-path                - Test file path in error messages";
      prerr_endline
        "  missing-field <file>     - Test missing field errors with locs";
      prerr_endline "  combined <file>          - Test locs and layout together";
      exit 1
