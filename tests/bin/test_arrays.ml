(*---------------------------------------------------------------------------
   Copyright (c) 2024 The yamlrw programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

(** Test array codec functionality with Yamlt *)


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

(* Test: Simple int array *)
let test_int_array file =
  let module M = struct
    type numbers = { values: int array }

    let numbers_codec =
      Jsont.Object.map ~kind:"Numbers" (fun values -> { values })
      |> Jsont.Object.mem "values" (Jsont.array Jsont.int) ~enc:(fun n -> n.values)
      |> Jsont.Object.finish

    let show n =
      Printf.sprintf "[%s]" (String.concat "; " (Array.to_list (Array.map string_of_int n.values)))
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.numbers_codec json in
  let yaml_result = Yamlt.decode_string M.numbers_codec yaml in

  show_result_both "int_array"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: String array *)
let test_string_array file =
  let module M = struct
    type tags = { items: string array }

    let tags_codec =
      Jsont.Object.map ~kind:"Tags" (fun items -> { items })
      |> Jsont.Object.mem "items" (Jsont.array Jsont.string) ~enc:(fun t -> t.items)
      |> Jsont.Object.finish

    let show t =
      Printf.sprintf "[%s]" (String.concat "; " (Array.to_list (Array.map (Printf.sprintf "%S") t.items)))
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.tags_codec json in
  let yaml_result = Yamlt.decode_string M.tags_codec yaml in

  show_result_both "string_array"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Float/number array *)
let test_float_array file =
  let module M = struct
    type measurements = { values: float array }

    let measurements_codec =
      Jsont.Object.map ~kind:"Measurements" (fun values -> { values })
      |> Jsont.Object.mem "values" (Jsont.array Jsont.number) ~enc:(fun m -> m.values)
      |> Jsont.Object.finish

    let show m =
      Printf.sprintf "[%s]"
        (String.concat "; " (Array.to_list (Array.map (Printf.sprintf "%.2f") m.values)))
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.measurements_codec json in
  let yaml_result = Yamlt.decode_string M.measurements_codec yaml in

  show_result_both "float_array"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Empty array *)
let test_empty_array file =
  let module M = struct
    type empty = { items: int array }

    let empty_codec =
      Jsont.Object.map ~kind:"Empty" (fun items -> { items })
      |> Jsont.Object.mem "items" (Jsont.array Jsont.int) ~enc:(fun e -> e.items)
      |> Jsont.Object.finish

    let show e =
      Printf.sprintf "length=%d" (Stdlib.Array.length e.items)
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.empty_codec json in
  let yaml_result = Yamlt.decode_string M.empty_codec yaml in

  show_result_both "empty_array"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Array of objects *)
let test_object_array file =
  let module M = struct
    type person = { name: string; age: int }
    type people = { persons: person array }

    let person_codec =
      Jsont.Object.map ~kind:"Person" (fun name age -> { name; age })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun p -> p.name)
      |> Jsont.Object.mem "age" Jsont.int ~enc:(fun p -> p.age)
      |> Jsont.Object.finish

    let people_codec =
      Jsont.Object.map ~kind:"People" (fun persons -> { persons })
      |> Jsont.Object.mem "persons" (Jsont.array person_codec) ~enc:(fun p -> p.persons)
      |> Jsont.Object.finish

    let show_person p = Printf.sprintf "{%s,%d}" p.name p.age
    let show ps =
      Printf.sprintf "[%s]"
        (String.concat "; " (Array.to_list (Array.map show_person ps.persons)))
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.people_codec json in
  let yaml_result = Yamlt.decode_string M.people_codec yaml in

  show_result_both "object_array"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Nested arrays *)
let test_nested_arrays file =
  let module M = struct
    type matrix = { data: int array array }

    let matrix_codec =
      Jsont.Object.map ~kind:"Matrix" (fun data -> { data })
      |> Jsont.Object.mem "data" (Jsont.array (Jsont.array Jsont.int))
          ~enc:(fun m -> m.data)
      |> Jsont.Object.finish

    let show_row row =
      Printf.sprintf "[%s]" (String.concat "; " (Array.to_list (Array.map string_of_int row)))

    let show m =
      Printf.sprintf "[%s]" (String.concat "; " (Array.to_list (Array.map show_row m.data)))
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.matrix_codec json in
  let yaml_result = Yamlt.decode_string M.matrix_codec yaml in

  show_result_both "nested_arrays"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Mixed types in array (should fail with homogeneous codec) *)
let test_type_mismatch file =
  let module M = struct
    type numbers = { values: int array }

    let numbers_codec =
      Jsont.Object.map ~kind:"Numbers" (fun values -> { values })
      |> Jsont.Object.mem "values" (Jsont.array Jsont.int) ~enc:(fun n -> n.values)
      |> Jsont.Object.finish
  end in

  let yaml = read_file file in
  let result = Yamlt.decode_string M.numbers_codec yaml in
  match result with
  | Ok _ -> Printf.printf "Unexpected success\n"
  | Error e -> Printf.printf "Expected error: %s\n" e

(* Test: Bool array *)
let test_bool_array file =
  let module M = struct
    type flags = { values: bool array }

    let flags_codec =
      Jsont.Object.map ~kind:"Flags" (fun values -> { values })
      |> Jsont.Object.mem "values" (Jsont.array Jsont.bool) ~enc:(fun f -> f.values)
      |> Jsont.Object.finish

    let show f =
      Printf.sprintf "[%s]"
        (String.concat "; " (Array.to_list (Array.map string_of_bool f.values)))
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.flags_codec json in
  let yaml_result = Yamlt.decode_string M.flags_codec yaml in

  show_result_both "bool_array"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Array with nulls *)
let test_nullable_array file =
  let module M = struct
    type nullable = { values: string option array }

    let nullable_codec =
      Jsont.Object.map ~kind:"Nullable" (fun values -> { values })
      |> Jsont.Object.mem "values" (Jsont.array (Jsont.some Jsont.string))
          ~enc:(fun n -> n.values)
      |> Jsont.Object.finish

    let show_opt = function
      | None -> "null"
      | Some s -> Printf.sprintf "%S" s

    let show n =
      Printf.sprintf "[%s]" (String.concat "; " (Array.to_list (Array.map show_opt n.values)))
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.nullable_codec json in
  let yaml_result = Yamlt.decode_string M.nullable_codec yaml in

  show_result_both "nullable_array"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Encoding arrays to different formats *)
let test_encode_arrays () =
  let module M = struct
    type data = { numbers: int array; strings: string array }

    let data_codec =
      Jsont.Object.map ~kind:"Data" (fun numbers strings -> { numbers; strings })
      |> Jsont.Object.mem "numbers" (Jsont.array Jsont.int) ~enc:(fun d -> d.numbers)
      |> Jsont.Object.mem "strings" (Jsont.array Jsont.string) ~enc:(fun d -> d.strings)
      |> Jsont.Object.finish
  end in

  let data = { M.numbers = [|1; 2; 3; 4; 5|]; strings = [|"hello"; "world"|] } in

  (* Encode to JSON *)
  (match Jsont_bytesrw.encode_string M.data_codec data with
   | Ok s -> Printf.printf "JSON: %s\n" (String.trim s)
   | Error e -> Printf.printf "JSON ERROR: %s\n" e);

  (* Encode to YAML Block *)
  (match Yamlt.encode_string ~format:Yamlt.Block M.data_codec data with
   | Ok s -> Printf.printf "YAML Block:\n%s" s
   | Error e -> Printf.printf "YAML Block ERROR: %s\n" e);

  (* Encode to YAML Flow *)
  (match Yamlt.encode_string ~format:Yamlt.Flow M.data_codec data with
   | Ok s -> Printf.printf "YAML Flow: %s" s
   | Error e -> Printf.printf "YAML Flow ERROR: %s\n" e)

let () =
  let usage = "Usage: test_arrays <command> [args...]" in

  if Array.length Sys.argv < 2 then begin
    prerr_endline usage;
    exit 1
  end;

  match Sys.argv.(1) with
  | "int" when Array.length Sys.argv = 3 ->
      test_int_array Sys.argv.(2)

  | "string" when Array.length Sys.argv = 3 ->
      test_string_array Sys.argv.(2)

  | "float" when Array.length Sys.argv = 3 ->
      test_float_array Sys.argv.(2)

  | "empty" when Array.length Sys.argv = 3 ->
      test_empty_array Sys.argv.(2)

  | "objects" when Array.length Sys.argv = 3 ->
      test_object_array Sys.argv.(2)

  | "nested" when Array.length Sys.argv = 3 ->
      test_nested_arrays Sys.argv.(2)

  | "type-mismatch" when Array.length Sys.argv = 3 ->
      test_type_mismatch Sys.argv.(2)

  | "bool" when Array.length Sys.argv = 3 ->
      test_bool_array Sys.argv.(2)

  | "nullable" when Array.length Sys.argv = 3 ->
      test_nullable_array Sys.argv.(2)

  | "encode" when Array.length Sys.argv = 2 ->
      test_encode_arrays ()

  | _ ->
      prerr_endline usage;
      prerr_endline "Commands:";
      prerr_endline "  int <file>              - Test int array";
      prerr_endline "  string <file>           - Test string array";
      prerr_endline "  float <file>            - Test float array";
      prerr_endline "  empty <file>            - Test empty array";
      prerr_endline "  objects <file>          - Test array of objects";
      prerr_endline "  nested <file>           - Test nested arrays";
      prerr_endline "  type-mismatch <file>    - Test type mismatch error";
      prerr_endline "  bool <file>             - Test bool array";
      prerr_endline "  nullable <file>         - Test array with nulls";
      prerr_endline "  encode                  - Test encoding arrays";
      exit 1
