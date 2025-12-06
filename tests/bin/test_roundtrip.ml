(*---------------------------------------------------------------------------
  Copyright (c) 2025 Anil Madhavapeddy <anil@recoil.org>. All rights reserved.
  SPDX-License-Identifier: ISC
 ---------------------------------------------------------------------------*)

(** Test roundtrip encoding/decoding with Yamlt *)

(* Test: Roundtrip scalars *)
let test_scalar_roundtrip () =
  let module M = struct
    type data = { s : string; n : float; b : bool; nul : unit }

    let data_codec =
      Jsont.Object.map ~kind:"Data" (fun s n b nul -> { s; n; b; nul })
      |> Jsont.Object.mem "s" Jsont.string ~enc:(fun d -> d.s)
      |> Jsont.Object.mem "n" Jsont.number ~enc:(fun d -> d.n)
      |> Jsont.Object.mem "b" Jsont.bool ~enc:(fun d -> d.b)
      |> Jsont.Object.mem "nul" (Jsont.null ()) ~enc:(fun d -> d.nul)
      |> Jsont.Object.finish

    let equal d1 d2 =
      d1.s = d2.s && d1.n = d2.n && d1.b = d2.b && d1.nul = d2.nul
  end in
  let original = { M.s = "hello"; n = 42.5; b = true; nul = () } in

  (* JSON roundtrip *)
  let json_encoded = Jsont_bytesrw.encode_string M.data_codec original in
  let json_decoded =
    Result.bind json_encoded (Jsont_bytesrw.decode_string M.data_codec)
  in
  (match json_decoded with
  | Ok decoded when M.equal original decoded ->
      Printf.printf "JSON roundtrip: PASS\n"
  | Ok _ -> Printf.printf "JSON roundtrip: FAIL (data mismatch)\n"
  | Error e -> Printf.printf "JSON roundtrip: FAIL (%s)\n" e);

  (* YAML Block roundtrip *)
  let yaml_block_encoded =
    Yamlt.encode_string ~format:Yamlt.Block M.data_codec original
  in
  let yaml_block_decoded =
    Result.bind yaml_block_encoded (Yamlt.decode_string M.data_codec)
  in
  (match yaml_block_decoded with
  | Ok decoded when M.equal original decoded ->
      Printf.printf "YAML Block roundtrip: PASS\n"
  | Ok _ -> Printf.printf "YAML Block roundtrip: FAIL (data mismatch)\n"
  | Error e -> Printf.printf "YAML Block roundtrip: FAIL (%s)\n" e);

  (* YAML Flow roundtrip *)
  let yaml_flow_encoded =
    Yamlt.encode_string ~format:Yamlt.Flow M.data_codec original
  in
  let yaml_flow_decoded =
    Result.bind yaml_flow_encoded (Yamlt.decode_string M.data_codec)
  in
  match yaml_flow_decoded with
  | Ok decoded when M.equal original decoded ->
      Printf.printf "YAML Flow roundtrip: PASS\n"
  | Ok _ -> Printf.printf "YAML Flow roundtrip: FAIL (data mismatch)\n"
  | Error e -> Printf.printf "YAML Flow roundtrip: FAIL (%s)\n" e

(* Test: Roundtrip arrays *)
let test_array_roundtrip () =
  let module M = struct
    type data = { items : int array; nested : float array array }

    let data_codec =
      Jsont.Object.map ~kind:"Data" (fun items nested -> { items; nested })
      |> Jsont.Object.mem "items" (Jsont.array Jsont.int) ~enc:(fun d ->
          d.items)
      |> Jsont.Object.mem "nested"
           (Jsont.array (Jsont.array Jsont.number))
           ~enc:(fun d -> d.nested)
      |> Jsont.Object.finish

    let equal d1 d2 = d1.items = d2.items && d1.nested = d2.nested
  end in
  let original =
    {
      M.items = [| 1; 2; 3; 4; 5 |];
      nested = [| [| 1.0; 2.0 |]; [| 3.0; 4.0 |] |];
    }
  in

  (* JSON roundtrip *)
  let json_result =
    Result.bind
      (Jsont_bytesrw.encode_string M.data_codec original)
      (Jsont_bytesrw.decode_string M.data_codec)
  in
  (match json_result with
  | Ok decoded when M.equal original decoded ->
      Printf.printf "JSON array roundtrip: PASS\n"
  | Ok _ -> Printf.printf "JSON array roundtrip: FAIL (data mismatch)\n"
  | Error e -> Printf.printf "JSON array roundtrip: FAIL (%s)\n" e);

  (* YAML roundtrip *)
  let yaml_result =
    Result.bind
      (Yamlt.encode_string M.data_codec original)
      (Yamlt.decode_string M.data_codec)
  in
  match yaml_result with
  | Ok decoded when M.equal original decoded ->
      Printf.printf "YAML array roundtrip: PASS\n"
  | Ok _ -> Printf.printf "YAML array roundtrip: FAIL (data mismatch)\n"
  | Error e -> Printf.printf "YAML array roundtrip: FAIL (%s)\n" e

(* Test: Roundtrip objects *)
let test_object_roundtrip () =
  let module M = struct
    type person = { p_name : string; age : int; active : bool }
    type company = { c_name : string; employees : person array }

    let person_codec =
      Jsont.Object.map ~kind:"Person" (fun p_name age active ->
          { p_name; age; active })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun p -> p.p_name)
      |> Jsont.Object.mem "age" Jsont.int ~enc:(fun p -> p.age)
      |> Jsont.Object.mem "active" Jsont.bool ~enc:(fun p -> p.active)
      |> Jsont.Object.finish

    let company_codec =
      Jsont.Object.map ~kind:"Company" (fun c_name employees ->
          { c_name; employees })
      |> Jsont.Object.mem "name" Jsont.string ~enc:(fun c -> c.c_name)
      |> Jsont.Object.mem "employees" (Jsont.array person_codec) ~enc:(fun c ->
          c.employees)
      |> Jsont.Object.finish

    let person_equal p1 p2 =
      p1.p_name = p2.p_name && p1.age = p2.age && p1.active = p2.active

    let equal c1 c2 =
      c1.c_name = c2.c_name
      && Stdlib.Array.length c1.employees = Stdlib.Array.length c2.employees
      && Stdlib.Array.for_all2 person_equal c1.employees c2.employees
  end in
  let original =
    {
      M.c_name = "Acme Corp";
      employees =
        [|
          { p_name = "Alice"; age = 30; active = true };
          { p_name = "Bob"; age = 25; active = false };
        |];
    }
  in

  (* JSON roundtrip *)
  let json_result =
    Result.bind
      (Jsont_bytesrw.encode_string M.company_codec original)
      (Jsont_bytesrw.decode_string M.company_codec)
  in
  (match json_result with
  | Ok decoded when M.equal original decoded ->
      Printf.printf "JSON object roundtrip: PASS\n"
  | Ok _ -> Printf.printf "JSON object roundtrip: FAIL (data mismatch)\n"
  | Error e -> Printf.printf "JSON object roundtrip: FAIL (%s)\n" e);

  (* YAML roundtrip *)
  let yaml_result =
    Result.bind
      (Yamlt.encode_string M.company_codec original)
      (Yamlt.decode_string M.company_codec)
  in
  match yaml_result with
  | Ok decoded when M.equal original decoded ->
      Printf.printf "YAML object roundtrip: PASS\n"
  | Ok _ -> Printf.printf "YAML object roundtrip: FAIL (data mismatch)\n"
  | Error e -> Printf.printf "YAML object roundtrip: FAIL (%s)\n" e

(* Test: Roundtrip with optionals *)
let test_optional_roundtrip () =
  let module M = struct
    type data = {
      required : string;
      optional : int option;
      nullable : string option;
    }

    let data_codec =
      Jsont.Object.map ~kind:"Data" (fun required optional nullable ->
          { required; optional; nullable })
      |> Jsont.Object.mem "required" Jsont.string ~enc:(fun d -> d.required)
      |> Jsont.Object.opt_mem "optional" Jsont.int ~enc:(fun d -> d.optional)
      |> Jsont.Object.mem "nullable" (Jsont.some Jsont.string) ~enc:(fun d ->
          d.nullable)
      |> Jsont.Object.finish

    let equal d1 d2 =
      d1.required = d2.required && d1.optional = d2.optional
      && d1.nullable = d2.nullable
  end in
  let original = { M.required = "test"; optional = Some 42; nullable = None } in

  (* JSON roundtrip *)
  let json_result =
    Result.bind
      (Jsont_bytesrw.encode_string M.data_codec original)
      (Jsont_bytesrw.decode_string M.data_codec)
  in
  (match json_result with
  | Ok decoded when M.equal original decoded ->
      Printf.printf "JSON optional roundtrip: PASS\n"
  | Ok _ -> Printf.printf "JSON optional roundtrip: FAIL (data mismatch)\n"
  | Error e -> Printf.printf "JSON optional roundtrip: FAIL (%s)\n" e);

  (* YAML roundtrip *)
  let yaml_result =
    Result.bind
      (Yamlt.encode_string M.data_codec original)
      (Yamlt.decode_string M.data_codec)
  in
  match yaml_result with
  | Ok decoded when M.equal original decoded ->
      Printf.printf "YAML optional roundtrip: PASS\n"
  | Ok _ -> Printf.printf "YAML optional roundtrip: FAIL (data mismatch)\n"
  | Error e -> Printf.printf "YAML optional roundtrip: FAIL (%s)\n" e

let () =
  let usage = "Usage: test_roundtrip <command>" in

  if Stdlib.Array.length Sys.argv < 2 then begin
    prerr_endline usage;
    exit 1
  end;

  match Sys.argv.(1) with
  | "scalar" -> test_scalar_roundtrip ()
  | "array" -> test_array_roundtrip ()
  | "object" -> test_object_roundtrip ()
  | "optional" -> test_optional_roundtrip ()
  | _ ->
      prerr_endline usage;
      prerr_endline "Commands:";
      prerr_endline "  scalar    - Test scalar roundtrip";
      prerr_endline "  array     - Test array roundtrip";
      prerr_endline "  object    - Test object roundtrip";
      prerr_endline "  optional  - Test optional fields roundtrip";
      exit 1
