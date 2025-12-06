(*---------------------------------------------------------------------------
   Copyright (c) 2024 The yamlrw programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

(** Test format-specific features with Yamlt *)

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

(* Test: Multi-line strings - literal style *)
let test_literal_string file =
  let module M = struct
    type text = { content: string }

    let text_codec =
      Jsont.Object.map ~kind:"Text" (fun content -> { content })
      |> Jsont.Object.mem "content" Jsont.string ~enc:(fun t -> t.content)
      |> Jsont.Object.finish

    let show t =
      Printf.sprintf "lines=%d, length=%d"
        (List.length (String.split_on_char '\n' t.content))
        (String.length t.content)
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.text_codec json in
  let yaml_result = Yamlt.decode_string M.text_codec yaml in

  show_result_both "literal_string"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Multi-line strings - folded style *)
let test_folded_string file =
  let module M = struct
    type text = { content: string }

    let text_codec =
      Jsont.Object.map ~kind:"Text" (fun content -> { content })
      |> Jsont.Object.mem "content" Jsont.string ~enc:(fun t -> t.content)
      |> Jsont.Object.finish

    let show t =
      Printf.sprintf "length=%d, newlines=%d"
        (String.length t.content)
        (List.length (List.filter (fun c -> c = '\n')
          (List.init (String.length t.content) (String.get t.content))))
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.text_codec json in
  let yaml_result = Yamlt.decode_string M.text_codec yaml in

  show_result_both "folded_string"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Number formats - hex, octal, binary *)
let test_number_formats file =
  let module M = struct
    type numbers = { hex: float; octal: float; binary: float }

    let numbers_codec =
      Jsont.Object.map ~kind:"Numbers" (fun hex octal binary -> { hex; octal; binary })
      |> Jsont.Object.mem "hex" Jsont.number ~enc:(fun n -> n.hex)
      |> Jsont.Object.mem "octal" Jsont.number ~enc:(fun n -> n.octal)
      |> Jsont.Object.mem "binary" Jsont.number ~enc:(fun n -> n.binary)
      |> Jsont.Object.finish

    let show n =
      Printf.sprintf "hex=%.0f, octal=%.0f, binary=%.0f" n.hex n.octal n.binary
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.numbers_codec json in
  let yaml_result = Yamlt.decode_string M.numbers_codec yaml in

  show_result_both "number_formats"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Block vs Flow style encoding *)
let test_encode_styles () =
  let module M = struct
    type data = {
      name: string;
      values: int array;
      nested: nested_data;
    }
    and nested_data = {
      enabled: bool;
      count: int;
    }

    let nested_codec =
      Jsont.Object.map ~kind:"Nested" (fun enabled count -> { enabled; count })
      |> Jsont.Object.mem "enabled" Jsont.bool ~enc:(fun n -> n.enabled)
      |> Jsont.Object.mem "count" Jsont.int ~enc:(fun n -> n.count)
      |> Jsont.Object.finish

    let data_codec =
      Jsont.Object.map ~kind:"Data" (fun name values nested -> { name; values; nested })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun d -> d.name)
      |> Jsont.Object.mem "values" (Jsont.array Jsont.int) ~enc:(fun d -> d.values)
      |> Jsont.Object.mem "nested" nested_codec ~enc:(fun d -> d.nested)
      |> Jsont.Object.finish
  end in

  let data = {
    M.name = "test";
    values = [|1; 2; 3|];
    nested = { enabled = true; count = 5 };
  } in

  (* Encode to YAML Block style *)
  (match Yamlt.encode_string ~format:Yamlt.Block M.data_codec data with
   | Ok s -> Printf.printf "YAML Block:\n%s\n" s
   | Error e -> Printf.printf "YAML Block ERROR: %s\n" e);

  (* Encode to YAML Flow style *)
  (match Yamlt.encode_string ~format:Yamlt.Flow M.data_codec data with
   | Ok s -> Printf.printf "YAML Flow:\n%s\n" s
   | Error e -> Printf.printf "YAML Flow ERROR: %s\n" e)

(* Test: Comments in YAML (should be ignored) *)
let test_comments file =
  let module M = struct
    type config = { host: string; port: int; debug: bool }

    let config_codec =
      Jsont.Object.map ~kind:"Config" (fun host port debug -> { host; port; debug })
      |> Jsont.Object.mem "host" Jsont.string ~enc:(fun c -> c.host)
      |> Jsont.Object.mem "port" Jsont.int ~enc:(fun c -> c.port)
      |> Jsont.Object.mem "debug" Jsont.bool ~enc:(fun c -> c.debug)
      |> Jsont.Object.finish

    let show c =
      Printf.sprintf "host=%S, port=%d, debug=%b" c.host c.port c.debug
  end in

  let yaml = read_file file in
  let yaml_result = Yamlt.decode_string M.config_codec yaml in

  match yaml_result with
  | Ok v -> Printf.printf "YAML (with comments): %s\n" (M.show v)
  | Error e -> Printf.printf "YAML ERROR: %s\n" e

(* Test: Empty documents and null documents *)
let test_empty_document file =
  let module M = struct
    type wrapper = { value: string option }

    let wrapper_codec =
      Jsont.Object.map ~kind:"Wrapper" (fun value -> { value })
      |> Jsont.Object.mem "value" (Jsont.some Jsont.string) ~enc:(fun w -> w.value)
      |> Jsont.Object.finish

    let show w =
      match w.value with
      | None -> "value=None"
      | Some s -> Printf.sprintf "value=Some(%S)" s
  end in

  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.wrapper_codec json in
  let yaml_result = Yamlt.decode_string M.wrapper_codec yaml in

  show_result_both "empty_document"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Explicit typing with tags (if supported) *)
let test_explicit_tags file =
  let module M = struct
    type value_holder = { data: string }

    let value_codec =
      Jsont.Object.map ~kind:"ValueHolder" (fun data -> { data })
      |> Jsont.Object.mem "data" Jsont.string ~enc:(fun v -> v.data)
      |> Jsont.Object.finish

    let show v = Printf.sprintf "data=%S" v.data
  end in

  let yaml = read_file file in
  let yaml_result = Yamlt.decode_string M.value_codec yaml in

  match yaml_result with
  | Ok v -> Printf.printf "YAML (with tags): %s\n" (M.show v)
  | Error e -> Printf.printf "YAML ERROR: %s\n" e

let () =
  let usage = "Usage: test_formats <command> [args...]" in

  if Stdlib.Array.length Sys.argv < 2 then begin
    prerr_endline usage;
    exit 1
  end;

  match Sys.argv.(1) with
  | "literal" when Stdlib.Array.length Sys.argv = 3 ->
      test_literal_string Sys.argv.(2)

  | "folded" when Stdlib.Array.length Sys.argv = 3 ->
      test_folded_string Sys.argv.(2)

  | "number-formats" when Stdlib.Array.length Sys.argv = 3 ->
      test_number_formats Sys.argv.(2)

  | "encode-styles" when Stdlib.Array.length Sys.argv = 2 ->
      test_encode_styles ()

  | "comments" when Stdlib.Array.length Sys.argv = 3 ->
      test_comments Sys.argv.(2)

  | "empty-doc" when Stdlib.Array.length Sys.argv = 3 ->
      test_empty_document Sys.argv.(2)

  | "explicit-tags" when Stdlib.Array.length Sys.argv = 3 ->
      test_explicit_tags Sys.argv.(2)

  | _ ->
      prerr_endline usage;
      prerr_endline "Commands:";
      prerr_endline "  literal <file>         - Test literal multi-line strings";
      prerr_endline "  folded <file>          - Test folded multi-line strings";
      prerr_endline "  number-formats <file>  - Test hex/octal/binary number formats";
      prerr_endline "  encode-styles          - Test block vs flow encoding";
      prerr_endline "  comments <file>        - Test YAML with comments";
      prerr_endline "  empty-doc <file>       - Test empty documents";
      prerr_endline "  explicit-tags <file>   - Test explicit type tags";
      exit 1
