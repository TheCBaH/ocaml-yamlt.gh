(*---------------------------------------------------------------------------
   Copyright (c) 2024 The yamlrw programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open Bytesrw
open Jsont.Repr
open Yamlrw

(* YAML format *)

type yaml_format = Block | Flow | Layout

(* Decoder *)

type decoder = {
  parser : Parser.t;
  file : string;
  locs : bool;
  _layout : bool; (* For future layout preservation *)
  max_depth : int;
  max_nodes : int;
  mutable node_count : int;
  mutable current : Event.spanned option;
  _anchors : (string, Jsont.json) Hashtbl.t; (* For future anchor resolution *)
  meta_none : Jsont.Meta.t;
}

let make_decoder
    ?(locs = false) ?(layout = false) ?(file = "-")
    ?(max_depth = 100) ?(max_nodes = 10_000_000) parser =
  let meta_none = Jsont.Meta.make (Jsont.Textloc.(set_file none) file) in
  { parser; file; locs; _layout = layout; max_depth; max_nodes;
    node_count = 0; current = None;
    _anchors = Hashtbl.create 16; meta_none }

(* Decoder helpers *)

let check_depth d ~nest =
  if nest > d.max_depth then
    Jsont.Error.msgf Jsont.Meta.none "Maximum nesting depth %d exceeded" d.max_depth

let check_nodes d =
  d.node_count <- d.node_count + 1;
  if d.node_count > d.max_nodes then
    Jsont.Error.msgf Jsont.Meta.none "Maximum node count %d exceeded" d.max_nodes

let meta_of_span d span =
  if not d.locs then d.meta_none else
  let start = span.Span.start and stop = span.Span.stop in
  let first_byte = start.Position.index in
  let last_byte = max first_byte (stop.Position.index - 1) in
  (* line_pos is (line_number, byte_position_of_line_start) *)
  let first_line = (start.Position.line, start.Position.index - start.Position.column + 1) in
  let last_line = (stop.Position.line, stop.Position.index - stop.Position.column + 1) in
  let textloc = Jsont.Textloc.make ~file:d.file
      ~first_byte ~last_byte ~first_line ~last_line in
  Jsont.Meta.make textloc

let next_event d =
  d.current <- Parser.next d.parser;
  d.current

let peek_event d =
  match d.current with
  | Some _ -> d.current
  | None -> next_event d

let skip_event d =
  d.current <- None

let _expect_event d pred name =
  match peek_event d with
  | Some ev when pred ev.Event.event -> skip_event d; ev
  | Some ev ->
      let span = ev.Event.span in
      let meta = meta_of_span d span in
      Jsont.Error.msgf meta "Expected %s but found %a" name Event.pp ev.Event.event
  | None ->
      Jsont.Error.msgf Jsont.Meta.none "Expected %s but reached end of stream" name

(* Error helpers *)

let _err_expected_scalar d ev =
  let meta = meta_of_span d ev.Event.span in
  Jsont.Error.msgf meta "Expected scalar but found %a" Event.pp ev.Event.event

let err_type_mismatch d span t ~fnd =
  let meta = meta_of_span d span in
  Jsont.Error.msgf meta "Expected %s but found %s"
    (Jsont.Repr.kinded_sort t) fnd

(* YAML scalar resolution *)

let is_null_scalar s =
  s = "" || s = "~" ||
  s = "null" || s = "Null" || s = "NULL"

let bool_of_scalar_opt s =
  match s with
  | "true" | "True" | "TRUE"
  | "yes" | "Yes" | "YES"
  | "on" | "On" | "ON" -> Some true
  | "false" | "False" | "FALSE"
  | "no" | "No" | "NO"
  | "off" | "Off" | "OFF" -> Some false
  | _ -> None

let float_of_scalar_opt s =
  (* Handle YAML special floats *)
  match s with
  | ".inf" | ".Inf" | ".INF" -> Some Float.infinity
  | "+.inf" | "+.Inf" | "+.INF" -> Some Float.infinity
  | "-.inf" | "-.Inf" | "-.INF" -> Some Float.neg_infinity
  | ".nan" | ".NaN" | ".NAN" -> Some Float.nan
  | _ ->
      (* Try parsing as number, allowing underscores *)
      let s' = String.concat "" (String.split_on_char '_' s) in
      (* Try int first (supports 0o, 0x, 0b) then float *)
      match int_of_string_opt s' with
      | Some i -> Some (float_of_int i)
      | None -> float_of_string_opt s'

let _int_of_scalar_opt s =
  (* Handle hex, octal, and regular integers with underscores *)
  let s' = String.concat "" (String.split_on_char '_' s) in
  int_of_string_opt s'

(* Decode a scalar value according to expected type *)
let rec decode_scalar_as :
  type a. decoder -> Event.spanned -> string -> Scalar_style.t -> a t -> a =
  fun d ev value style t ->
  check_nodes d;
  let meta = meta_of_span d ev.Event.span in
  match t with
  | Null map ->
      if is_null_scalar value then map.dec meta ()
      else err_type_mismatch d ev.span t ~fnd:("scalar " ^ value)
  | Bool map ->
      (match bool_of_scalar_opt value with
       | Some b -> map.dec meta b
       | None ->
           (* For explicitly quoted strings, fail *)
           if style <> `Plain then
             err_type_mismatch d ev.span t ~fnd:("string " ^ value)
           else
             err_type_mismatch d ev.span t ~fnd:("scalar " ^ value))
  | Number map ->
      (* Handle null -> nan mapping like jsont *)
      if is_null_scalar value then map.dec meta Float.nan
      else
        (match float_of_scalar_opt value with
         | Some f -> map.dec meta f
         | None -> err_type_mismatch d ev.span t ~fnd:("scalar " ^ value))
  | String map ->
      (* Don't decode null values as strings - they should fail so outer combinators
         like 'option' or 'any' can handle them properly.
         BUT: quoted strings should always be treated as strings, even if they
         look like null (e.g., "" or "null") *)
      if style = `Plain && is_null_scalar value then
        err_type_mismatch d ev.span t ~fnd:"null"
      else
        (* Strings accept quoted scalars or non-null plain scalars *)
        map.dec meta value
  | Map m ->
      (* Handle Map combinators (e.g., from Jsont.option) *)
      m.dec (decode_scalar_as d ev value style m.dom)
  | Rec lazy_t ->
      (* Handle recursive types *)
      decode_scalar_as d ev value style (Lazy.force lazy_t)
  | _ ->
      err_type_mismatch d ev.span t ~fnd:"scalar"

(* Forward declaration for mutual recursion *)
let rec decode : type a. decoder -> nest:int -> a t -> a =
  fun d ~nest t ->
  check_depth d ~nest;
  match peek_event d with
  | None -> Jsont.Error.msgf Jsont.Meta.none "Unexpected end of YAML stream"
  | Some ev ->
      match ev.Event.event, t with
      (* Scalar events *)
      | Event.Scalar { value; style; anchor; _ }, _ ->
          skip_event d;
          let result = decode_scalar d ~nest ev value style t in
          (* Store anchor if present - TODO: implement anchor storage *)
          (match anchor with
           | Some _name ->
               (* We need generic JSON for anchors - decode as json and convert back *)
               ()
           | None -> ());
          result

      (* Alias *)
      | Event.Alias { anchor }, _ ->
          skip_event d;
          decode_alias d ev anchor t

      (* Map combinator - must come before specific event matches *)
      | _, Map m ->
          m.dec (decode d ~nest m.dom)

      (* Recursive types - must come before specific event matches *)
      | _, Rec lazy_t ->
          decode d ~nest (Lazy.force lazy_t)

      (* Sequence -> Array *)
      | Event.Sequence_start _, Array map ->
          decode_array d ~nest ev map

      | Event.Sequence_start _, Any map ->
          decode_any_sequence d ~nest ev t map

      | Event.Sequence_start _, _ ->
          err_type_mismatch d ev.span t ~fnd:"sequence"

      (* Mapping -> Object *)
      | Event.Mapping_start _, Object map ->
          decode_object d ~nest ev map

      | Event.Mapping_start _, Any map ->
          decode_any_mapping d ~nest ev t map

      | Event.Mapping_start _, _ ->
          err_type_mismatch d ev.span t ~fnd:"mapping"

      (* Unexpected events *)
      | Event.Sequence_end, _ ->
          Jsont.Error.msgf (meta_of_span d ev.span) "Unexpected sequence end"
      | Event.Mapping_end, _ ->
          Jsont.Error.msgf (meta_of_span d ev.span) "Unexpected mapping end"
      | Event.Document_start _, _ ->
          Jsont.Error.msgf (meta_of_span d ev.span) "Unexpected document start"
      | Event.Document_end _, _ ->
          Jsont.Error.msgf (meta_of_span d ev.span) "Unexpected document end"
      | Event.Stream_start _, _ ->
          Jsont.Error.msgf (meta_of_span d ev.span) "Unexpected stream start"
      | Event.Stream_end, _ ->
          Jsont.Error.msgf (meta_of_span d ev.span) "Unexpected stream end"

and decode_scalar : type a. decoder -> nest:int -> Event.spanned -> string -> Scalar_style.t -> a t -> a =
  fun d ~nest ev value style t ->
  match t with
  | Any map -> decode_any_scalar d ev value style t map
  | Map m -> m.dec (decode_scalar d ~nest ev value style m.dom)
  | Rec lazy_t -> decode_scalar d ~nest ev value style (Lazy.force lazy_t)
  | _ -> decode_scalar_as d ev value style t

and decode_any_scalar : type a. decoder -> Event.spanned -> string -> Scalar_style.t -> a t -> a any_map -> a =
  fun d ev value style t map ->
  check_nodes d;
  (* Determine which decoder to use based on scalar content *)
  if is_null_scalar value then
    match map.dec_null with
    | Some t' -> decode_scalar_as d ev value style t'
    | None -> Jsont.Repr.type_error (meta_of_span d ev.span) t ~fnd:Jsont.Sort.Null
  else if style = `Plain then
    (* Try bool, then number, then string *)
    match bool_of_scalar_opt value with
    | Some _ ->
        (match map.dec_bool with
         | Some t' -> decode_scalar_as d ev value style t'
         | None ->
             match map.dec_string with
             | Some t' -> decode_scalar_as d ev value style t'
             | None -> Jsont.Repr.type_error (meta_of_span d ev.span) t ~fnd:Jsont.Sort.Bool)
    | None ->
        match float_of_scalar_opt value with
        | Some _ ->
            (match map.dec_number with
             | Some t' -> decode_scalar_as d ev value style t'
             | None ->
                 match map.dec_string with
                 | Some t' -> decode_scalar_as d ev value style t'
                 | None -> Jsont.Repr.type_error (meta_of_span d ev.span) t ~fnd:Jsont.Sort.Number)
        | None ->
            (* Plain scalar that's not bool/number -> string *)
            match map.dec_string with
            | Some t' -> decode_scalar_as d ev value style t'
            | None -> Jsont.Repr.type_error (meta_of_span d ev.span) t ~fnd:Jsont.Sort.String
  else
    (* Quoted scalars are strings *)
    match map.dec_string with
    | Some t' -> decode_scalar_as d ev value style t'
    | None -> Jsont.Repr.type_error (meta_of_span d ev.span) t ~fnd:Jsont.Sort.String

and decode_alias : type a. decoder -> Event.spanned -> string -> a t -> a =
  fun d ev anchor t ->
  check_nodes d;
  match Hashtbl.find_opt d._anchors anchor with
  | None ->
      let meta = meta_of_span d ev.span in
      Jsont.Error.msgf meta "Unknown anchor: %s" anchor
  | Some json ->
      (* Decode the stored JSON value through the type *)
      let t' = Jsont.Repr.unsafe_to_t t in
      match Jsont.Json.decode' t' json with
      | Ok v -> v
      | Error e -> raise (Jsont.Error e)

and decode_array : type a elt b. decoder -> nest:int -> Event.spanned -> (a, elt, b) array_map -> a =
  fun d ~nest start_ev map ->
  skip_event d; (* consume Sequence_start *)
  check_nodes d;
  let meta = meta_of_span d start_ev.span in
  let builder = ref (map.dec_empty ()) in
  let idx = ref 0 in
  let rec loop () =
    match peek_event d with
    | Some { Event.event = Event.Sequence_end; span } ->
        skip_event d;
        let end_meta = meta_of_span d span in
        map.dec_finish end_meta !idx !builder
    | Some _ ->
        let i = !idx in
        (try
           if map.dec_skip i !builder then begin
             (* Skip this element by decoding as ignore *)
             let _ : unit = decode d ~nest:(nest + 1) (Jsont.Repr.of_t Jsont.ignore) in
             ()
           end else begin
             let elt = decode d ~nest:(nest + 1) map.elt in
             builder := map.dec_add i elt !builder
           end
         with Jsont.Error e ->
           let imeta = Jsont.Meta.none in
           Jsont.Repr.error_push_array meta map (i, imeta) e);
        incr idx;
        loop ()
    | None ->
        Jsont.Error.msgf meta "Unclosed sequence"
  in
  loop ()

and decode_any_sequence : type a. decoder -> nest:int -> Event.spanned -> a t -> a any_map -> a =
  fun d ~nest ev t map ->
  match map.dec_array with
  | Some t' ->
      (* The t' decoder might be wrapped (e.g., Map for option types)
         Directly decode the array and let the wrapper handle it *)
      (match t' with
       | Array array_map ->
           decode_array d ~nest ev array_map
       | _ ->
           (* For wrapped types like Map (Array ...), use full decode *)
           decode d ~nest t')
  | None -> Jsont.Repr.type_error (meta_of_span d ev.span) t ~fnd:Jsont.Sort.Array

and decode_object : type o. decoder -> nest:int -> Event.spanned -> (o, o) object_map -> o =
  fun d ~nest start_ev map ->
  skip_event d; (* consume Mapping_start *)
  check_nodes d;
  let meta = meta_of_span d start_ev.span in
  let dict = decode_object_members d ~nest meta map String_map.empty Dict.empty in
  let dict = Dict.add object_meta_arg meta dict in
  apply_dict map.dec dict

and decode_object_members : type o.
  decoder -> nest:int -> Jsont.Meta.t -> (o, o) object_map ->
  mem_dec String_map.t -> Dict.t -> Dict.t =
  fun d ~nest obj_meta map mem_miss dict ->
  (* Merge expected member decoders *)
  let u _ _ _ = assert false in
  let mem_miss = String_map.union u mem_miss map.mem_decs in
  match map.shape with
  | Object_basic umems ->
      decode_object_basic d ~nest obj_meta map umems mem_miss dict
  | Object_cases (umems_opt, cases) ->
      (* Wrap umems_opt to hide existential types *)
      let umems = Unknown_mems umems_opt in
      decode_object_cases d ~nest obj_meta map umems cases mem_miss [] dict

and decode_object_basic : type o mems builder.
  decoder -> nest:int -> Jsont.Meta.t -> (o, o) object_map ->
  (o, mems, builder) unknown_mems ->
  mem_dec String_map.t -> Dict.t -> Dict.t =
  fun d ~nest obj_meta map umems mem_miss dict ->
  let ubuilder = ref (match umems with
    | Unknown_skip | Unknown_error -> Obj.magic ()
    | Unknown_keep (mmap, _) -> mmap.dec_empty ()) in
  let mem_miss = ref mem_miss in
  let dict = ref dict in
  let rec loop () =
    match peek_event d with
    | Some { Event.event = Event.Mapping_end; _ } ->
        skip_event d;
        (* Finalize *)
        finish_object obj_meta map umems !ubuilder !mem_miss !dict
    | Some ev ->
        (* Expect a scalar key *)
        let name, name_meta = decode_mapping_key d ev in
        (* Look up member decoder *)
        (match String_map.find_opt name map.mem_decs with
         | Some (Mem_dec mem) ->
             mem_miss := String_map.remove name !mem_miss;
             (try
                let v = decode d ~nest:(nest + 1) mem.type' in
                dict := Dict.add mem.id v !dict
              with Jsont.Error e ->
                Jsont.Repr.error_push_object obj_meta map (name, name_meta) e)
         | None ->
             (* Unknown member *)
             match umems with
             | Unknown_skip ->
                 let _ : unit = decode d ~nest:(nest + 1) (Jsont.Repr.of_t Jsont.ignore) in
                 ()
             | Unknown_error ->
                 Jsont.Repr.unexpected_mems_error obj_meta map ~fnd:[(name, name_meta)]
             | Unknown_keep (mmap, _) ->
                 (try
                    let v = decode d ~nest:(nest + 1) mmap.mems_type in
                    ubuilder := mmap.dec_add name_meta name v !ubuilder
                  with Jsont.Error e ->
                    Jsont.Repr.error_push_object obj_meta map (name, name_meta) e));
        loop ()
    | None ->
        Jsont.Error.msgf obj_meta "Unclosed mapping"
  in
  loop ()

and finish_object : type o mems builder.
  Jsont.Meta.t -> (o, o) object_map -> (o, mems, builder) unknown_mems ->
  builder -> mem_dec String_map.t -> Dict.t -> Dict.t =
  fun meta map umems ubuilder mem_miss dict ->
  let dict = Dict.add object_meta_arg meta dict in
  let dict = match umems with
    | Unknown_skip | Unknown_error -> dict
    | Unknown_keep (mmap, _) -> Dict.add mmap.id (mmap.dec_finish meta ubuilder) dict
  in
  (* Check for missing required members *)
  let add_default _ (Mem_dec mem_map) dict =
    match mem_map.dec_absent with
    | Some v -> Dict.add mem_map.id v dict
    | None -> raise Exit
  in
  try String_map.fold add_default mem_miss dict
  with Exit ->
    let no_default _ (Mem_dec mm) = Option.is_none mm.dec_absent in
    let exp = String_map.filter no_default mem_miss in
    Jsont.Repr.missing_mems_error meta map ~exp ~fnd:[]

and decode_object_cases : type o cases tag.
  decoder -> nest:int -> Jsont.Meta.t -> (o, o) object_map ->
  unknown_mems_option ->
  (o, cases, tag) object_cases ->
  mem_dec String_map.t -> (Jsont.name * Jsont.json) list -> Dict.t -> Dict.t =
  fun d ~nest obj_meta map umems cases mem_miss delayed dict ->
  match peek_event d with
  | Some { Event.event = Event.Mapping_end; _ } ->
      skip_event d;
      (* No tag found - use dec_absent if available *)
      (match cases.tag.dec_absent with
       | Some tag ->
           decode_with_case_tag d ~nest obj_meta map umems cases tag mem_miss delayed dict
       | None ->
           (* Missing required case tag *)
           let exp = String_map.singleton cases.tag.name (Mem_dec cases.tag) in
           let fnd = List.map (fun ((n, _), _) -> n) delayed in
           Jsont.Repr.missing_mems_error obj_meta map ~exp ~fnd)
  | Some ev ->
      let name, name_meta = decode_mapping_key d ev in
      if String.equal name cases.tag.name then begin
        (* Found the case tag *)
        let tag = decode d ~nest:(nest + 1) cases.tag.type' in
        decode_with_case_tag d ~nest obj_meta map umems cases tag mem_miss delayed dict
      end else begin
        (* Not the case tag - check if known member or delay *)
        match String_map.find_opt name map.mem_decs with
        | Some (Mem_dec mem) ->
            let mem_miss = String_map.remove name mem_miss in
            (try
               let v = decode d ~nest:(nest + 1) mem.type' in
               let dict = Dict.add mem.id v dict in
               decode_object_cases d ~nest obj_meta map umems cases mem_miss delayed dict
             with Jsont.Error e ->
               Jsont.Repr.error_push_object obj_meta map (name, name_meta) e)
        | None ->
            (* Unknown member - decode as generic JSON and delay *)
            let v = decode d ~nest:(nest + 1) (Jsont.Repr.of_t Jsont.json) in
            let delayed = ((name, name_meta), v) :: delayed in
            decode_object_cases d ~nest obj_meta map umems cases mem_miss delayed dict
      end
  | None ->
      Jsont.Error.msgf obj_meta "Unclosed mapping"

and decode_with_case_tag : type o cases tag.
  decoder -> nest:int -> Jsont.Meta.t -> (o, o) object_map ->
  unknown_mems_option ->
  (o, cases, tag) object_cases -> tag ->
  mem_dec String_map.t -> (Jsont.name * Jsont.json) list -> Dict.t -> Dict.t =
  fun d ~nest obj_meta map umems cases tag mem_miss delayed dict ->
  let eq_tag (Case c) = cases.tag_compare c.tag tag = 0 in
  match List.find_opt eq_tag cases.cases with
  | None ->
      Jsont.Repr.unexpected_case_tag_error obj_meta map cases tag
  | Some (Case case) ->
      (* Continue decoding with the case's object map *)
      let case_dict = decode_case_remaining d ~nest obj_meta case.object_map
          umems mem_miss delayed dict in
      let case_value = apply_dict case.object_map.dec case_dict in
      Dict.add cases.id (case.dec case_value) dict

and decode_case_remaining : type o.
  decoder -> nest:int -> Jsont.Meta.t -> (o, o) object_map ->
  unknown_mems_option ->
  mem_dec String_map.t -> (Jsont.name * Jsont.json) list -> Dict.t -> Dict.t =
  fun d ~nest obj_meta case_map _umems mem_miss delayed dict ->
  (* First, process delayed members against the case map *)
  let u _ _ _ = assert false in
  let mem_miss = String_map.union u mem_miss case_map.mem_decs in
  let dict, mem_miss = List.fold_left (fun (dict, mem_miss) ((name, meta), json) ->
    match String_map.find_opt name case_map.mem_decs with
    | Some (Mem_dec mem) ->
        let t' = Jsont.Repr.unsafe_to_t mem.type' in
        (match Jsont.Json.decode' t' json with
         | Ok v ->
             let dict = Dict.add mem.id v dict in
             let mem_miss = String_map.remove name mem_miss in
             (dict, mem_miss)
         | Error e ->
             Jsont.Repr.error_push_object obj_meta case_map (name, meta) e)
    | None ->
        (* Unknown for case too - skip them *)
        (dict, mem_miss)
  ) (dict, mem_miss) delayed in
  (* Then continue reading remaining members using case's own unknown handling *)
  match case_map.shape with
  | Object_basic case_umems ->
      decode_object_basic d ~nest obj_meta case_map case_umems mem_miss dict
  | Object_cases _ ->
      (* Nested cases shouldn't happen - use skip for safety *)
      decode_object_basic d ~nest obj_meta case_map Unknown_skip mem_miss dict

and decode_any_mapping : type a. decoder -> nest:int -> Event.spanned -> a t -> a any_map -> a =
  fun d ~nest ev t map ->
  match map.dec_object with
  | Some t' -> decode d ~nest t'
  | None -> Jsont.Repr.type_error (meta_of_span d ev.span) t ~fnd:Jsont.Sort.Object

and decode_mapping_key : decoder -> Event.spanned -> string * Jsont.Meta.t =
  fun d ev ->
  match ev.Event.event with
  | Event.Scalar { value; _ } ->
      skip_event d;
      let meta = meta_of_span d ev.span in
      (value, meta)
  | _ ->
      let meta = meta_of_span d ev.span in
      Jsont.Error.msgf meta "Mapping keys must be scalars (strings), found %a"
        Event.pp ev.event

(* Skip stream/document wrappers *)
let skip_to_content d =
  let rec loop () =
    match peek_event d with
    | Some { Event.event = Event.Stream_start _; _ } -> skip_event d; loop ()
    | Some { Event.event = Event.Document_start _; _ } -> skip_event d; loop ()
    | _ -> ()
  in
  loop ()

let skip_end_wrappers d =
  let rec loop () =
    match peek_event d with
    | Some { Event.event = Event.Document_end _; _ } -> skip_event d; loop ()
    | Some { Event.event = Event.Stream_end; _ } -> skip_event d; loop ()
    | None -> ()
    | Some ev ->
        let meta = meta_of_span d ev.span in
        Jsont.Error.msgf meta "Expected end of document but found %a" Event.pp ev.event
  in
  loop ()

(* Public decode API *)

let decode' ?layout ?locs ?file ?max_depth ?max_nodes t reader =
  let parser = Parser.of_reader reader in
  let d = make_decoder ?layout ?locs ?file ?max_depth ?max_nodes parser in
  try
    skip_to_content d;
    let t' = Jsont.Repr.of_t t in
    let v = decode d ~nest:0 t' in
    skip_end_wrappers d;
    Ok v
  with
  | Jsont.Error e -> Error e
  | Error.Yamlrw_error err ->
      let msg = Error.to_string err in
      Error (Jsont.Error.make_msg Jsont.Error.Context.empty Jsont.Meta.none msg)

let decode ?layout ?locs ?file ?max_depth ?max_nodes t reader =
  Result.map_error Jsont.Error.to_string
    (decode' ?layout ?locs ?file ?max_depth ?max_nodes t reader)

let decode_string' ?layout ?locs ?file ?max_depth ?max_nodes t s =
  decode' ?layout ?locs ?file ?max_depth ?max_nodes t (Bytes.Reader.of_string s)

let decode_string ?layout ?locs ?file ?max_depth ?max_nodes t s =
  decode ?layout ?locs ?file ?max_depth ?max_nodes t (Bytes.Reader.of_string s)

(* Encoder *)

type encoder = {
  emitter : Emitter.t;
  format : yaml_format;
  _indent : int; (* Stored for future use in custom formatting *)
  explicit_doc : bool;
  scalar_style : Scalar_style.t;
}

let make_encoder
    ?(format = Block) ?(indent = 2) ?(explicit_doc = false)
    ?(scalar_style = `Any) emitter =
  { emitter; format; _indent = indent; explicit_doc; scalar_style }

let layout_style_of_format = function
  | Block -> `Block
  | Flow -> `Flow
  | Layout -> `Any

(* Choose appropriate scalar style for a string *)
let choose_scalar_style ~preferred s =
  if preferred <> `Any then preferred
  else if String.contains s '\n' then `Literal
  else if String.length s > 80 then `Folded
  else `Plain

(* Encode null *)
let encode_null e _meta =
  Emitter.emit e.emitter (Event.Scalar {
    anchor = None;
    tag = None;
    value = "null";
    plain_implicit = true;
    quoted_implicit = true;
    style = `Plain;
  })

(* Encode boolean *)
let encode_bool e _meta b =
  Emitter.emit e.emitter (Event.Scalar {
    anchor = None;
    tag = None;
    value = if b then "true" else "false";
    plain_implicit = true;
    quoted_implicit = true;
    style = `Plain;
  })

(* Encode number *)
let encode_number e _meta f =
  let value =
    match Float.classify_float f with
    | FP_nan -> ".nan"
    | FP_infinite -> if f > 0.0 then ".inf" else "-.inf"
    | _ ->
        if Float.is_integer f && Float.abs f < 1e15 then
          Printf.sprintf "%.0f" f
        else
          Printf.sprintf "%g" f
  in
  Emitter.emit e.emitter (Event.Scalar {
    anchor = None;
    tag = None;
    value;
    plain_implicit = true;
    quoted_implicit = true;
    style = `Plain;
  })

(* Encode string *)
let encode_string e _meta s =
  let style = choose_scalar_style ~preferred:e.scalar_style s in
  Emitter.emit e.emitter (Event.Scalar {
    anchor = None;
    tag = None;
    value = s;
    plain_implicit = true;
    quoted_implicit = true;
    style;
  })

let rec encode : type a. encoder -> a t -> a -> unit =
  fun e t v ->
  match t with
  | Null map ->
      let meta = map.enc_meta v in
      let () = map.enc v in
      encode_null e meta

  | Bool map ->
      let meta = map.enc_meta v in
      let b = map.enc v in
      encode_bool e meta b

  | Number map ->
      let meta = map.enc_meta v in
      let f = map.enc v in
      encode_number e meta f

  | String map ->
      let meta = map.enc_meta v in
      let s = map.enc v in
      encode_string e meta s

  | Array map ->
      encode_array e map v

  | Object map ->
      encode_object e map v

  | Any map ->
      let t' = map.enc v in
      encode e t' v

  | Map m ->
      encode e m.dom (m.enc v)

  | Rec lazy_t ->
      encode e (Lazy.force lazy_t) v

and encode_array : type a elt b. encoder -> (a, elt, b) array_map -> a -> unit =
  fun e map v ->
  let style = layout_style_of_format e.format in
  Emitter.emit e.emitter (Event.Sequence_start {
    anchor = None;
    tag = None;
    implicit = true;
    style;
  });
  let _ = map.enc (fun () _idx elt ->
    encode e map.elt elt;
    ()
  ) () v in
  Emitter.emit e.emitter Event.Sequence_end

and encode_object : type o. encoder -> (o, o) object_map -> o -> unit =
  fun e map v ->
  let style = layout_style_of_format e.format in
  Emitter.emit e.emitter (Event.Mapping_start {
    anchor = None;
    tag = None;
    implicit = true;
    style;
  });
  (* Encode each member *)
  List.iter (fun (Mem_enc mem) ->
    let mem_v = mem.enc v in
    if not (mem.enc_omit mem_v) then begin
      (* Emit key *)
      Emitter.emit e.emitter (Event.Scalar {
        anchor = None;
        tag = None;
        value = mem.name;
        plain_implicit = true;
        quoted_implicit = true;
        style = `Plain;
      });
      (* Emit value *)
      encode e mem.type' mem_v
    end
  ) map.mem_encs;
  (* Handle case objects *)
  (match map.shape with
   | Object_basic _ -> ()
   | Object_cases (_, cases) ->
       let Case_value (case_map, case_v) = cases.enc_case (cases.enc v) in
       (* Emit case tag *)
       if not (cases.tag.enc_omit (case_map.tag)) then begin
         Emitter.emit e.emitter (Event.Scalar {
           anchor = None;
           tag = None;
           value = cases.tag.name;
           plain_implicit = true;
           quoted_implicit = true;
           style = `Plain;
         });
         encode e cases.tag.type' case_map.tag
       end;
       (* Emit case members *)
       List.iter (fun (Mem_enc mem) ->
         let mem_v = mem.enc case_v in
         if not (mem.enc_omit mem_v) then begin
           Emitter.emit e.emitter (Event.Scalar {
             anchor = None;
             tag = None;
             value = mem.name;
             plain_implicit = true;
             quoted_implicit = true;
             style = `Plain;
           });
           encode e mem.type' mem_v
         end
       ) case_map.object_map.mem_encs);
  Emitter.emit e.emitter Event.Mapping_end

(* Public encode API *)

let encode' ?buf:_ ?format ?indent ?explicit_doc ?scalar_style t v ~eod writer =
  let config = {
    Emitter.default_config with
    indent = Option.value ~default:2 indent;
    layout_style = (match format with
      | Some Flow -> `Flow
      | _ -> `Block);
  } in
  let emitter = Emitter.of_writer ~config writer in
  let e = make_encoder ?format ?indent ?explicit_doc ?scalar_style emitter in
  try
    Emitter.emit e.emitter (Event.Stream_start { encoding = `Utf8 });
    Emitter.emit e.emitter (Event.Document_start {
      version = None;
      implicit = not e.explicit_doc;
    });
    let t' = Jsont.Repr.of_t t in
    encode e t' v;
    Emitter.emit e.emitter (Event.Document_end { implicit = not e.explicit_doc });
    Emitter.emit e.emitter Event.Stream_end;
    if eod then Emitter.flush e.emitter;
    Ok ()
  with
  | Jsont.Error err -> Error err
  | Error.Yamlrw_error err ->
      let msg = Error.to_string err in
      Error (Jsont.Error.make_msg Jsont.Error.Context.empty Jsont.Meta.none msg)

let encode ?buf ?format ?indent ?explicit_doc ?scalar_style t v ~eod writer =
  Result.map_error Jsont.Error.to_string
    (encode' ?buf ?format ?indent ?explicit_doc ?scalar_style t v ~eod writer)

let encode_string' ?buf ?format ?indent ?explicit_doc ?scalar_style t v =
  let b = Buffer.create 256 in
  let writer = Bytes.Writer.of_buffer b in
  match encode' ?buf ?format ?indent ?explicit_doc ?scalar_style t v ~eod:true writer with
  | Ok () -> Ok (Buffer.contents b)
  | Error e -> Error e

let encode_string ?buf ?format ?indent ?explicit_doc ?scalar_style t v =
  Result.map_error Jsont.Error.to_string
    (encode_string' ?buf ?format ?indent ?explicit_doc ?scalar_style t v)

(* Recode *)

let recode ?layout ?locs ?file ?max_depth ?max_nodes
    ?buf ?format ?indent ?explicit_doc ?scalar_style t reader writer ~eod =
  let format = match layout, format with
    | Some true, None -> Some Layout
    | _, f -> f
  in
  let layout = match layout, format with
    | None, Some Layout -> Some true
    | l, _ -> l
  in
  match decode' ?layout ?locs ?file ?max_depth ?max_nodes t reader with
  | Ok v -> encode ?buf ?format ?indent ?explicit_doc ?scalar_style t v ~eod writer
  | Error e -> Error (Jsont.Error.to_string e)

let recode_string ?layout ?locs ?file ?max_depth ?max_nodes
    ?buf ?format ?indent ?explicit_doc ?scalar_style t s =
  let format = match layout, format with
    | Some true, None -> Some Layout
    | _, f -> f
  in
  let layout = match layout, format with
    | None, Some Layout -> Some true
    | l, _ -> l
  in
  match decode_string' ?layout ?locs ?file ?max_depth ?max_nodes t s with
  | Ok v -> encode_string ?buf ?format ?indent ?explicit_doc ?scalar_style t v
  | Error e -> Error (Jsont.Error.to_string e)
