open Jsont

let () =
  let module M = struct
    type data = { value : string option }

    let data_codec =
      Jsont.Object.map ~kind:"Data" (fun value -> { value })
      |> Jsont.Object.mem "value" (Jsont.option Jsont.string) ~enc:(fun d ->
          d.value)
      |> Jsont.Object.finish
  end in
  let yaml_null = "value: null" in

  Printf.printf "Testing YAML null handling with Jsont.option Jsont.string:\n\n";

  match Yamlt.decode_string M.data_codec yaml_null with
  | Ok data -> (
      match data.M.value with
      | None -> Printf.printf "YAML: value=None (CORRECT)\n"
      | Some s -> Printf.printf "YAML: value=Some(%S) (BUG!)\n" s)
  | Error e -> (
      Printf.printf "YAML ERROR: %s\n" e;

      let json_null = "{\"value\": null}" in
      match Jsont_bytesrw.decode_string M.data_codec json_null with
      | Ok data -> (
          match data.M.value with
          | None -> Printf.printf "JSON: value=None (CORRECT)\n"
          | Some s -> Printf.printf "JSON: value=Some(%S) (BUG!)\n" s)
      | Error e -> Printf.printf "JSON ERROR: %s\n" e)
