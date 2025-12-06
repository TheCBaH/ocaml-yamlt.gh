(*---------------------------------------------------------------------------
  Copyright (c) 2025 Anil Madhavapeddy <anil@recoil.org>. All rights reserved.
  SPDX-License-Identifier: ISC
 ---------------------------------------------------------------------------*)

(** Test edge cases with Yamlt *)

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

(* Test: Very large numbers *)
let test_large_numbers file =
  let module M = struct
    type numbers = {
      large_int : float;
      large_float : float;
      small_float : float;
    }

    let numbers_codec =
      Jsont.Object.map ~kind:"Numbers" (fun large_int large_float small_float ->
          { large_int; large_float; small_float })
      |> Jsont.Object.mem "large_int" Jsont.number ~enc:(fun n -> n.large_int)
      |> Jsont.Object.mem "large_float" Jsont.number ~enc:(fun n ->
          n.large_float)
      |> Jsont.Object.mem "small_float" Jsont.number ~enc:(fun n ->
          n.small_float)
      |> Jsont.Object.finish

    let show n =
      Printf.sprintf "large_int=%.0f, large_float=%e, small_float=%e"
        n.large_int n.large_float n.small_float
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.numbers_codec json in
  let yaml_result = Yamlt.decode_string M.numbers_codec yaml in

  show_result_both "large_numbers"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Special characters in strings *)
let test_special_chars file =
  let module M = struct
    type text = { content : string }

    let text_codec =
      Jsont.Object.map ~kind:"Text" (fun content -> { content })
      |> Jsont.Object.mem "content" Jsont.string ~enc:(fun t -> t.content)
      |> Jsont.Object.finish

    let show t =
      Printf.sprintf "length=%d, contains_newline=%b, contains_tab=%b"
        (String.length t.content)
        (String.contains t.content '\n')
        (String.contains t.content '\t')
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.text_codec json in
  let yaml_result = Yamlt.decode_string M.text_codec yaml in

  show_result_both "special_chars"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Unicode strings *)
let test_unicode file =
  let module M = struct
    type text = { emoji : string; chinese : string; rtl : string }

    let text_codec =
      Jsont.Object.map ~kind:"Text" (fun emoji chinese rtl ->
          { emoji; chinese; rtl })
      |> Jsont.Object.mem "emoji" Jsont.string ~enc:(fun t -> t.emoji)
      |> Jsont.Object.mem "chinese" Jsont.string ~enc:(fun t -> t.chinese)
      |> Jsont.Object.mem "rtl" Jsont.string ~enc:(fun t -> t.rtl)
      |> Jsont.Object.finish

    let show t =
      Printf.sprintf "emoji=%S, chinese=%S, rtl=%S" t.emoji t.chinese t.rtl
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.text_codec json in
  let yaml_result = Yamlt.decode_string M.text_codec yaml in

  show_result_both "unicode"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Empty collections *)
let test_empty_collections file =
  let module M = struct
    type data = { empty_array : int array; empty_object_array : unit array }

    let data_codec =
      Jsont.Object.map ~kind:"Data" (fun empty_array empty_object_array ->
          { empty_array; empty_object_array })
      |> Jsont.Object.mem "empty_array" (Jsont.array Jsont.int) ~enc:(fun d ->
          d.empty_array)
      |> Jsont.Object.mem "empty_object_array"
           (Jsont.array (Jsont.null ()))
           ~enc:(fun d -> d.empty_object_array)
      |> Jsont.Object.finish

    let show d =
      Printf.sprintf "empty_array_len=%d, empty_object_array_len=%d"
        (Stdlib.Array.length d.empty_array)
        (Stdlib.Array.length d.empty_object_array)
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.data_codec json in
  let yaml_result = Yamlt.decode_string M.data_codec yaml in

  show_result_both "empty_collections"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Key names with special characters *)
let test_special_keys file =
  let module M = struct
    let show j =
      match Jsont.Json.decode (Jsont.any ()) j with
      | Ok (Jsont.Object _) -> "valid_object"
      | Ok _ -> "not_object"
      | Error _ -> "decode_error"
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string (Jsont.any ()) json in
  let yaml_result = Yamlt.decode_string (Jsont.any ()) yaml in

  show_result_both "special_keys"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Single-element arrays *)
let test_single_element file =
  let module M = struct
    type data = { single : int array }

    let data_codec =
      Jsont.Object.map ~kind:"Data" (fun single -> { single })
      |> Jsont.Object.mem "single" (Jsont.array Jsont.int) ~enc:(fun d ->
          d.single)
      |> Jsont.Object.finish

    let show d =
      Printf.sprintf "length=%d, value=%d"
        (Stdlib.Array.length d.single)
        (if Stdlib.Array.length d.single > 0 then d.single.(0) else 0)
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.data_codec json in
  let yaml_result = Yamlt.decode_string M.data_codec yaml in

  show_result_both "single_element"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

let () =
  let usage = "Usage: test_edge <command> [args...]" in

  if Stdlib.Array.length Sys.argv < 2 then begin
    prerr_endline usage;
    exit 1
  end;

  match Sys.argv.(1) with
  | "large-numbers" when Stdlib.Array.length Sys.argv = 3 ->
      test_large_numbers Sys.argv.(2)
  | "special-chars" when Stdlib.Array.length Sys.argv = 3 ->
      test_special_chars Sys.argv.(2)
  | "unicode" when Stdlib.Array.length Sys.argv = 3 -> test_unicode Sys.argv.(2)
  | "empty-collections" when Stdlib.Array.length Sys.argv = 3 ->
      test_empty_collections Sys.argv.(2)
  | "special-keys" when Stdlib.Array.length Sys.argv = 3 ->
      test_special_keys Sys.argv.(2)
  | "single-element" when Stdlib.Array.length Sys.argv = 3 ->
      test_single_element Sys.argv.(2)
  | _ ->
      prerr_endline usage;
      prerr_endline "Commands:";
      prerr_endline "  large-numbers <file>      - Test very large numbers";
      prerr_endline
        "  special-chars <file>      - Test special characters in strings";
      prerr_endline "  unicode <file>            - Test Unicode strings";
      prerr_endline "  empty-collections <file>  - Test empty collections";
      prerr_endline
        "  special-keys <file>       - Test special characters in keys";
      prerr_endline "  single-element <file>     - Test single-element arrays";
      exit 1
