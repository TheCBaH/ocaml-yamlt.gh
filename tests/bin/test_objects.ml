(*---------------------------------------------------------------------------
  Copyright (c) 2025 Anil Madhavapeddy <anil@recoil.org>. All rights reserved.
  SPDX-License-Identifier: ISC
 ---------------------------------------------------------------------------*)

(** Test object codec functionality with Yamlt *)

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

let show_result_both label json_result yaml_result =
  Printf.printf "JSON: ";
  show_result label json_result;
  Printf.printf "YAML: ";
  show_result label yaml_result

(* Test: Simple object with required fields *)
let test_simple_object file =
  let module M = struct
    type person = { name : string; age : int }

    let person_codec =
      Jsont.Object.map ~kind:"Person" (fun name age -> { name; age })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun p -> p.name)
      |> Jsont.Object.mem "age" Jsont.int ~enc:(fun p -> p.age)
      |> Jsont.Object.finish

    let show p = Printf.sprintf "{name=%S; age=%d}" p.name p.age
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.person_codec json in
  let yaml_result = Yamlt.decode M.person_codec (Bytes.Reader.of_string yaml) in

  show_result_both "person"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Object with optional fields *)
let test_optional_fields file =
  let module M = struct
    type config = { host : string; port : int option; debug : bool option }

    let config_codec =
      Jsont.Object.map ~kind:"Config" (fun host port debug ->
          { host; port; debug })
      |> Jsont.Object.mem "host" Jsont.string ~enc:(fun c -> c.host)
      |> Jsont.Object.opt_mem "port" Jsont.int ~enc:(fun c -> c.port)
      |> Jsont.Object.opt_mem "debug" Jsont.bool ~enc:(fun c -> c.debug)
      |> Jsont.Object.finish

    let show c =
      Printf.sprintf "{host=%S; port=%s; debug=%s}" c.host
        (match c.port with
        | None -> "None"
        | Some p -> Printf.sprintf "Some %d" p)
        (match c.debug with
        | None -> "None"
        | Some b -> Printf.sprintf "Some %b" b)
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.config_codec json in
  let yaml_result = Yamlt.decode M.config_codec (Bytes.Reader.of_string yaml) in

  show_result_both "config"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Object with default values *)
let test_default_values file =
  let module M = struct
    type settings = { timeout : int; retries : int; verbose : bool }

    let settings_codec =
      Jsont.Object.map ~kind:"Settings" (fun timeout retries verbose ->
          { timeout; retries; verbose })
      |> Jsont.Object.mem "timeout" Jsont.int
           ~enc:(fun s -> s.timeout)
           ~dec_absent:30
      |> Jsont.Object.mem "retries" Jsont.int
           ~enc:(fun s -> s.retries)
           ~dec_absent:3
      |> Jsont.Object.mem "verbose" Jsont.bool
           ~enc:(fun s -> s.verbose)
           ~dec_absent:false
      |> Jsont.Object.finish

    let show s =
      Printf.sprintf "{timeout=%d; retries=%d; verbose=%b}" s.timeout s.retries
        s.verbose
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.settings_codec json in
  let yaml_result =
    Yamlt.decode M.settings_codec (Bytes.Reader.of_string yaml)
  in

  show_result_both "settings"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Nested objects *)
let test_nested_objects file =
  let module M = struct
    type address = { street : string; city : string; zip : string }
    type employee = { name : string; address : address }

    let address_codec =
      Jsont.Object.map ~kind:"Address" (fun street city zip ->
          { street; city; zip })
      |> Jsont.Object.mem "street" Jsont.string ~enc:(fun a -> a.street)
      |> Jsont.Object.mem "city" Jsont.string ~enc:(fun a -> a.city)
      |> Jsont.Object.mem "zip" Jsont.string ~enc:(fun a -> a.zip)
      |> Jsont.Object.finish

    let employee_codec =
      Jsont.Object.map ~kind:"Employee" (fun name address -> { name; address })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun e -> e.name)
      |> Jsont.Object.mem "address" address_codec ~enc:(fun e -> e.address)
      |> Jsont.Object.finish

    let show e =
      Printf.sprintf "{name=%S; address={street=%S; city=%S; zip=%S}}" e.name
        e.address.street e.address.city e.address.zip
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.employee_codec json in
  let yaml_result =
    Yamlt.decode M.employee_codec (Bytes.Reader.of_string yaml)
  in

  show_result_both "employee"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Unknown member handling - error *)
let test_unknown_members_error file =
  let module M = struct
    type strict = { name : string }

    let strict_codec =
      Jsont.Object.map ~kind:"Strict" (fun name -> { name })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun s -> s.name)
      |> Jsont.Object.finish
  end in
  let yaml = read_file file in
  let result = Yamlt.decode M.strict_codec (Bytes.Reader.of_string yaml) in
  match result with
  | Ok _ -> Printf.printf "Unexpected success\n"
  | Error e -> Printf.printf "Expected error: %s\n" e

(* Test: Unknown member handling - keep *)
let test_unknown_members_keep file =
  let module M = struct
    type flexible = { name : string; extra : Jsont.json }

    let flexible_codec =
      Jsont.Object.map ~kind:"Flexible" (fun name extra -> { name; extra })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun f -> f.name)
      |> Jsont.Object.keep_unknown Jsont.json_mems ~enc:(fun f -> f.extra)
      |> Jsont.Object.finish

    let show f = Printf.sprintf "{name=%S; has_extra=true}" f.name
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.flexible_codec json in
  let yaml_result =
    Yamlt.decode M.flexible_codec (Bytes.Reader.of_string yaml)
  in

  show_result_both "flexible"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Object cases (discriminated unions) - simplified version *)
let test_object_cases file =
  let module M = struct
    type circle = { type_ : string; radius : float }

    let circle_codec =
      Jsont.Object.map ~kind:"Circle" (fun type_ radius -> { type_; radius })
      |> Jsont.Object.mem "type" Jsont.string ~enc:(fun c -> c.type_)
      |> Jsont.Object.mem "radius" Jsont.number ~enc:(fun c -> c.radius)
      |> Jsont.Object.finish

    let show c = Printf.sprintf "Circle{radius=%.2f}" c.radius
  end in
  let yaml = read_file file in
  let json = read_file (file ^ ".json") in
  let json_result = Jsont_bytesrw.decode_string M.circle_codec json in
  let yaml_result = Yamlt.decode M.circle_codec (Bytes.Reader.of_string yaml) in

  show_result_both "shape"
    (Result.map M.show json_result)
    (Result.map M.show yaml_result)

(* Test: Missing required field error *)
let test_missing_required file =
  let module M = struct
    type required = { name : string; age : int }

    let required_codec =
      Jsont.Object.map ~kind:"Required" (fun name age -> { name; age })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun r -> r.name)
      |> Jsont.Object.mem "age" Jsont.int ~enc:(fun r -> r.age)
      |> Jsont.Object.finish
  end in
  let yaml = read_file file in
  let result = Yamlt.decode M.required_codec (Bytes.Reader.of_string yaml) in
  match result with
  | Ok _ -> Printf.printf "Unexpected success\n"
  | Error e -> Printf.printf "Expected error: %s\n" e

(* Test: Encoding objects to different formats *)
let test_encode_object () =
  let module M = struct
    type person = { name : string; age : int; active : bool }

    let person_codec =
      Jsont.Object.map ~kind:"Person" (fun name age active ->
          { name; age; active })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun p -> p.name)
      |> Jsont.Object.mem "age" Jsont.int ~enc:(fun p -> p.age)
      |> Jsont.Object.mem "active" Jsont.bool ~enc:(fun p -> p.active)
      |> Jsont.Object.finish
  end in
  let person = M.{ name = "Alice"; age = 30; active = true } in

  (* Encode to JSON *)
  (match Jsont_bytesrw.encode_string M.person_codec person with
  | Ok s -> Printf.printf "JSON: %s\n" (String.trim s)
  | Error e -> Printf.printf "JSON ERROR: %s\n" e);

  (* Encode to YAML Block *)
  (let b = Buffer.create 256 in
   let writer = Bytes.Writer.of_buffer b in
   match
     Yamlt.encode ~format:Yamlt.Block M.person_codec person ~eod:true writer
   with
   | Ok () -> Printf.printf "YAML Block:\n%s" (Buffer.contents b)
   | Error e -> Printf.printf "YAML Block ERROR: %s\n" e);

  (* Encode to YAML Flow *)
  let b = Buffer.create 256 in
  let writer = Bytes.Writer.of_buffer b in
  match
    Yamlt.encode ~format:Yamlt.Flow M.person_codec person ~eod:true writer
  with
  | Ok () -> Printf.printf "YAML Flow: %s" (Buffer.contents b)
  | Error e -> Printf.printf "YAML Flow ERROR: %s\n" e

(* Test: Roundtrip encoding of objects with unknown members *)
let test_unknown_keep_roundtrip file =
  let module M = struct
    type flexible = { name : string; extra : Jsont.json }

    let flexible_codec =
      Jsont.Object.map ~kind:"Flexible" (fun name extra -> { name; extra })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun f -> f.name)
      |> Jsont.Object.keep_unknown Jsont.json_mems ~enc:(fun f -> f.extra)
      |> Jsont.Object.finish

    let show_json json =
      match Jsont_bytesrw.encode_string Jsont.json json with
      | Ok s -> String.trim s
      | Error e -> Printf.sprintf "ERROR: %s" e
  end in
  let yaml = read_file file in

  (* Decode from YAML *)
  match Yamlt.decode M.flexible_codec (Bytes.Reader.of_string yaml) with
  | Error e -> Printf.printf "Decode error: %s\n" e
  | Ok v -> (
      Printf.printf "Decoded: name=%S, extra=%s\n" v.M.name
        (M.show_json v.M.extra);

      (* Encode to YAML Block *)
      let b = Buffer.create 256 in
      let writer = Bytes.Writer.of_buffer b in
      (match
         Yamlt.encode ~format:Yamlt.Block M.flexible_codec v ~eod:true writer
       with
      | Ok () -> Printf.printf "Encoded Block:\n%s" (Buffer.contents b)
      | Error e -> Printf.printf "Encode Block ERROR: %s\n" e);

      (* Re-decode the encoded YAML to verify roundtrip *)
      let encoded = Buffer.contents b in
      match Yamlt.decode M.flexible_codec (Bytes.Reader.of_string encoded) with
      | Error e -> Printf.printf "Re-decode error: %s\n" e
      | Ok v2 ->
          Printf.printf "Re-decoded: name=%S, extra=%s\n" v2.M.name
            (M.show_json v2.M.extra);
          if M.show_json v.M.extra = M.show_json v2.M.extra then
            Printf.printf "Roundtrip: OK (extra members preserved)\n"
          else Printf.printf "Roundtrip: FAILED (extra members lost)\n")

let () =
  let usage = "Usage: test_objects <command> [args...]" in

  if Stdlib.Array.length Sys.argv < 2 then begin
    prerr_endline usage;
    exit 1
  end;

  match Sys.argv.(1) with
  | "simple" when Stdlib.Array.length Sys.argv = 3 ->
      test_simple_object Sys.argv.(2)
  | "optional" when Stdlib.Array.length Sys.argv = 3 ->
      test_optional_fields Sys.argv.(2)
  | "defaults" when Stdlib.Array.length Sys.argv = 3 ->
      test_default_values Sys.argv.(2)
  | "nested" when Stdlib.Array.length Sys.argv = 3 ->
      test_nested_objects Sys.argv.(2)
  | "unknown-error" when Stdlib.Array.length Sys.argv = 3 ->
      test_unknown_members_error Sys.argv.(2)
  | "unknown-keep" when Stdlib.Array.length Sys.argv = 3 ->
      test_unknown_members_keep Sys.argv.(2)
  | "unknown-keep-roundtrip" when Stdlib.Array.length Sys.argv = 3 ->
      test_unknown_keep_roundtrip Sys.argv.(2)
  | "cases" when Stdlib.Array.length Sys.argv = 3 ->
      test_object_cases Sys.argv.(2)
  | "missing-required" when Stdlib.Array.length Sys.argv = 3 ->
      test_missing_required Sys.argv.(2)
  | "encode" when Stdlib.Array.length Sys.argv = 2 -> test_encode_object ()
  | _ ->
      prerr_endline usage;
      prerr_endline "Commands:";
      prerr_endline "  simple <file>           - Test simple object";
      prerr_endline "  optional <file>         - Test optional fields";
      prerr_endline "  defaults <file>         - Test default values";
      prerr_endline "  nested <file>           - Test nested objects";
      prerr_endline "  unknown-error <file>    - Test unknown member error";
      prerr_endline "  unknown-keep <file>     - Test keeping unknown members";
      prerr_endline
        "  unknown-keep-roundtrip <file> - Test roundtrip of unknown members";
      prerr_endline "  cases <file>            - Test object cases (unions)";
      prerr_endline
        "  missing-required <file> - Test missing required field error";
      prerr_endline "  encode                  - Test encoding objects";
      exit 1
