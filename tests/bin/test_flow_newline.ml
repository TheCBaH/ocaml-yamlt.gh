let () =
  let encode_codec =
    Jsont.Object.map ~kind:"Test" (fun name values -> (name, values))
    |> Jsont.Object.mem "name" Jsont.string ~enc:fst
    |> Jsont.Object.mem "values" (Jsont.array Jsont.number) ~enc:snd
    |> Jsont.Object.finish
  in

  match
    Yamlt.encode_string ~format:Flow encode_codec ("test", [| 1.; 2.; 3. |])
  with
  | Ok yaml_flow ->
      Printf.printf "Length: %d\n" (String.length yaml_flow);
      Printf.printf "Repr: %S\n" yaml_flow;
      Printf.printf "Output:\n%s" yaml_flow
  | Error e -> Printf.printf "Error: %s\n" e
