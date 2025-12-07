open Bytesrw

let () =
  let codec =
    Jsont.Object.map ~kind:"Test" (fun arr -> arr)
    |> Jsont.Object.opt_mem "values" (Jsont.array Jsont.string) ~enc:(fun arr ->
        arr)
    |> Jsont.Object.finish
  in

  let yaml = "values: [a, b, c]" in

  Printf.printf "Testing optional array field:\n";
  match Yamlt.decode codec (Bytes.Reader.of_string yaml) with
  | Ok arr -> (
      match arr with
      | None -> Printf.printf "Result: None\n"
      | Some a -> Printf.printf "Result: Some([%d items])\n" (Array.length a))
  | Error e -> Printf.printf "Error: %s\n" e
