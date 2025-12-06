(*---------------------------------------------------------------------------
  Copyright (c) 2025 Anil Madhavapeddy <anil@recoil.org>. All rights reserved.
  SPDX-License-Identifier: ISC
 ---------------------------------------------------------------------------*)

(** Test scalar type resolution with Yamlt codec *)

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

let show_result_json label json_result yaml_result =
  Printf.printf "JSON %s\n" label;
  show_result "  decode" json_result;
  Printf.printf "YAML %s\n" label;
  show_result "  decode" yaml_result

(* Test: Decode null values with different type expectations *)
let test_null_resolution file =
  let yaml = read_file file in

  (* Define a simple object codec with nullable field *)
  let null_codec =
    Jsont.Object.map ~kind:"NullTest" (fun n -> n)
    |> Jsont.Object.mem "value" (Jsont.null ()) ~enc:(fun n -> n)
    |> Jsont.Object.finish
  in

  (* Try decoding as null *)
  let result = Yamlt.decode_string null_codec yaml in
  show_result "null_codec" (Result.map (fun () -> "null") result)

(* Test: Boolean type-directed resolution *)
let test_bool_resolution file =
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in

  (* Codec expecting bool *)
  let bool_codec =
    Jsont.Object.map ~kind:"BoolTest" (fun b -> b)
    |> Jsont.Object.mem "value" Jsont.bool ~enc:(fun b -> b)
    |> Jsont.Object.finish
  in

  (* Codec expecting string *)
  let string_codec =
    Jsont.Object.map ~kind:"StringTest" (fun s -> s)
    |> Jsont.Object.mem "value" Jsont.string ~enc:(fun s -> s)
    |> Jsont.Object.finish
  in

  Printf.printf "=== Bool Codec ===\n";
  let json_result = Jsont_bytesrw.decode_string bool_codec json in
  let yaml_result = Yamlt.decode_string bool_codec yaml in
  show_result_json "bool_codec"
    (Result.map (Printf.sprintf "%b") json_result)
    (Result.map (Printf.sprintf "%b") yaml_result);

  Printf.printf "\n=== String Codec ===\n";
  let json_result = Jsont_bytesrw.decode_string string_codec json in
  let yaml_result = Yamlt.decode_string string_codec yaml in
  show_result_json "string_codec"
    (Result.map (Printf.sprintf "%S") json_result)
    (Result.map (Printf.sprintf "%S") yaml_result)

(* Test: Number resolution *)
let test_number_resolution file =
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in

  let number_codec =
    Jsont.Object.map ~kind:"NumberTest" (fun n -> n)
    |> Jsont.Object.mem "value" Jsont.number ~enc:(fun n -> n)
    |> Jsont.Object.finish
  in

  let json_result = Jsont_bytesrw.decode_string number_codec json in
  let yaml_result = Yamlt.decode_string number_codec yaml in

  show_result_json "number_codec"
    (Result.map (Printf.sprintf "%.17g") json_result)
    (Result.map (Printf.sprintf "%.17g") yaml_result)

(* Test: String resolution preserves everything *)
let test_string_resolution file =
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in

  let string_codec =
    Jsont.Object.map ~kind:"StringTest" (fun s -> s)
    |> Jsont.Object.mem "value" Jsont.string ~enc:(fun s -> s)
    |> Jsont.Object.finish
  in

  let json_result = Jsont_bytesrw.decode_string string_codec json in
  let yaml_result = Yamlt.decode_string string_codec yaml in

  show_result_json "string_codec"
    (Result.map (Printf.sprintf "%S") json_result)
    (Result.map (Printf.sprintf "%S") yaml_result)

(* Test: Special float values *)
let test_special_floats file =
  let yaml = read_file file in

  let number_codec =
    Jsont.Object.map ~kind:"SpecialFloat" (fun n -> n)
    |> Jsont.Object.mem "value" Jsont.number ~enc:(fun n -> n)
    |> Jsont.Object.finish
  in

  let result = Yamlt.decode_string number_codec yaml in
  match result with
  | Ok f ->
      if Float.is_nan f then Printf.printf "value: NaN\n"
      else if f = Float.infinity then Printf.printf "value: +Infinity\n"
      else if f = Float.neg_infinity then Printf.printf "value: -Infinity\n"
      else Printf.printf "value: %.17g\n" f
  | Error e -> Printf.printf "ERROR: %s\n" e

(* Test: Type mismatch errors *)
let test_type_mismatch file expected_type =
  let yaml = read_file file in

  match expected_type with
  | "bool" -> (
      let codec =
        Jsont.Object.map ~kind:"BoolTest" (fun b -> b)
        |> Jsont.Object.mem "value" Jsont.bool ~enc:(fun b -> b)
        |> Jsont.Object.finish
      in
      let result = Yamlt.decode_string codec yaml in
      match result with
      | Ok _ -> Printf.printf "Unexpected success\n"
      | Error e -> Printf.printf "Expected error: %s\n" e)
  | "number" -> (
      let codec =
        Jsont.Object.map ~kind:"NumberTest" (fun n -> n)
        |> Jsont.Object.mem "value" Jsont.number ~enc:(fun n -> n)
        |> Jsont.Object.finish
      in
      let result = Yamlt.decode_string codec yaml in
      match result with
      | Ok _ -> Printf.printf "Unexpected success\n"
      | Error e -> Printf.printf "Expected error: %s\n" e)
  | "null" -> (
      let codec =
        Jsont.Object.map ~kind:"NullTest" (fun n -> n)
        |> Jsont.Object.mem "value" (Jsont.null ()) ~enc:(fun n -> n)
        |> Jsont.Object.finish
      in
      let result = Yamlt.decode_string codec yaml in
      match result with
      | Ok _ -> Printf.printf "Unexpected success\n"
      | Error e -> Printf.printf "Expected error: %s\n" e)
  | _ -> failwith "unknown type"

(* Test: Decode with Jsont.json to see auto-resolution *)
let test_any_resolution file =
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in

  let any_codec =
    Jsont.Object.map ~kind:"AnyTest" (fun v -> v)
    |> Jsont.Object.mem "value" Jsont.json ~enc:(fun v -> v)
    |> Jsont.Object.finish
  in

  let json_result = Jsont_bytesrw.decode_string any_codec json in
  let yaml_result = Yamlt.decode_string any_codec yaml in

  (* Just show that it decoded successfully *)
  show_result_json "any_codec"
    (Result.map (fun _ -> "decoded") json_result)
    (Result.map (fun _ -> "decoded") yaml_result)

(* Test: Encoding to different formats *)
let test_encode_formats value_type value =
  match value_type with
  | "bool" -> (
      let codec =
        Jsont.Object.map ~kind:"BoolTest" (fun b -> b)
        |> Jsont.Object.mem "value" Jsont.bool ~enc:(fun b -> b)
        |> Jsont.Object.finish
      in
      let v = bool_of_string value in
      (match Jsont_bytesrw.encode_string codec v with
      | Ok s -> Printf.printf "JSON: %s\n" (String.trim s)
      | Error e -> Printf.printf "JSON ERROR: %s\n" e);
      (match Yamlt.encode_string ~format:Yamlt.Block codec v with
      | Ok s -> Printf.printf "YAML Block:\n%s" s
      | Error e -> Printf.printf "YAML Block ERROR: %s\n" e);
      match Yamlt.encode_string ~format:Yamlt.Flow codec v with
      | Ok s -> Printf.printf "YAML Flow: %s" s
      | Error e -> Printf.printf "YAML Flow ERROR: %s\n" e)
  | "number" -> (
      let codec =
        Jsont.Object.map ~kind:"NumberTest" (fun n -> n)
        |> Jsont.Object.mem "value" Jsont.number ~enc:(fun n -> n)
        |> Jsont.Object.finish
      in
      let v = float_of_string value in
      (match Jsont_bytesrw.encode_string codec v with
      | Ok s -> Printf.printf "JSON: %s\n" (String.trim s)
      | Error e -> Printf.printf "JSON ERROR: %s\n" e);
      (match Yamlt.encode_string ~format:Yamlt.Block codec v with
      | Ok s -> Printf.printf "YAML Block:\n%s" s
      | Error e -> Printf.printf "YAML Block ERROR: %s\n" e);
      match Yamlt.encode_string ~format:Yamlt.Flow codec v with
      | Ok s -> Printf.printf "YAML Flow: %s" s
      | Error e -> Printf.printf "YAML Flow ERROR: %s\n" e)
  | "string" -> (
      let codec =
        Jsont.Object.map ~kind:"StringTest" (fun s -> s)
        |> Jsont.Object.mem "value" Jsont.string ~enc:(fun s -> s)
        |> Jsont.Object.finish
      in
      let v = value in
      (match Jsont_bytesrw.encode_string codec v with
      | Ok s -> Printf.printf "JSON: %s\n" (String.trim s)
      | Error e -> Printf.printf "JSON ERROR: %s\n" e);
      (match Yamlt.encode_string ~format:Yamlt.Block codec v with
      | Ok s -> Printf.printf "YAML Block:\n%s" s
      | Error e -> Printf.printf "YAML Block ERROR: %s\n" e);
      match Yamlt.encode_string ~format:Yamlt.Flow codec v with
      | Ok s -> Printf.printf "YAML Flow: %s" s
      | Error e -> Printf.printf "YAML Flow ERROR: %s\n" e)
  | "null" -> (
      let codec =
        Jsont.Object.map ~kind:"NullTest" (fun n -> n)
        |> Jsont.Object.mem "value" (Jsont.null ()) ~enc:(fun n -> n)
        |> Jsont.Object.finish
      in
      let v = () in
      (match Jsont_bytesrw.encode_string codec v with
      | Ok s -> Printf.printf "JSON: %s\n" (String.trim s)
      | Error e -> Printf.printf "JSON ERROR: %s\n" e);
      (match Yamlt.encode_string ~format:Yamlt.Block codec v with
      | Ok s -> Printf.printf "YAML Block:\n%s" s
      | Error e -> Printf.printf "YAML Block ERROR: %s\n" e);
      match Yamlt.encode_string ~format:Yamlt.Flow codec v with
      | Ok s -> Printf.printf "YAML Flow: %s" s
      | Error e -> Printf.printf "YAML Flow ERROR: %s\n" e)
  | _ -> failwith "unknown type"

let () =
  let usage = "Usage: test_scalars <command> [args...]" in

  if Stdlib.Array.length Sys.argv < 2 then begin
    prerr_endline usage;
    exit 1
  end;

  match Sys.argv.(1) with
  | "null" when Array.length Sys.argv = 3 -> test_null_resolution Sys.argv.(2)
  | "bool" when Array.length Sys.argv = 3 -> test_bool_resolution Sys.argv.(2)
  | "number" when Array.length Sys.argv = 3 ->
      test_number_resolution Sys.argv.(2)
  | "string" when Array.length Sys.argv = 3 ->
      test_string_resolution Sys.argv.(2)
  | "special-float" when Array.length Sys.argv = 3 ->
      test_special_floats Sys.argv.(2)
  | "type-mismatch" when Array.length Sys.argv = 4 ->
      test_type_mismatch Sys.argv.(2) Sys.argv.(3)
  | "any" when Array.length Sys.argv = 3 -> test_any_resolution Sys.argv.(2)
  | "encode" when Array.length Sys.argv = 4 ->
      test_encode_formats Sys.argv.(2) Sys.argv.(3)
  | _ ->
      prerr_endline usage;
      prerr_endline "Commands:";
      prerr_endline "  null <file>              - Test null resolution";
      prerr_endline
        "  bool <file>              - Test bool vs string resolution";
      prerr_endline "  number <file>            - Test number resolution";
      prerr_endline "  string <file>            - Test string resolution";
      prerr_endline "  special-float <file>     - Test .inf, .nan, etc.";
      prerr_endline
        "  type-mismatch <file> <type> - Test error on type mismatch";
      prerr_endline
        "  any <file>               - Test Jsont.any auto-resolution";
      prerr_endline "  encode <type> <value>    - Test encoding to JSON/YAML";
      exit 1
