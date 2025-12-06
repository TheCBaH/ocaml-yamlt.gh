let () =
  (* Using Jsont.some like opt_mem does *)
  let codec1 =
    Jsont.Object.map ~kind:"Test" (fun arr -> arr)
    |> Jsont.Object.mem "values" (Jsont.some (Jsont.array Jsont.string)) ~enc:(fun arr -> arr)
    |> Jsont.Object.finish
  in

  let yaml = "values: [a, b, c]" in

  Printf.printf "Test 1: Jsont.some (Jsont.array) - like opt_mem:\n";
  (match Yamlt.decode_string codec1 yaml with
   | Ok arr ->
       (match arr with
        | None -> Printf.printf "Result: None\n"
        | Some a -> Printf.printf "Result: Some([%d items])\n" (Array.length a))
   | Error e -> Printf.printf "Error: %s\n" e);

  (* Using Jsont.option *)
  let codec2 =
    Jsont.Object.map ~kind:"Test" (fun arr -> arr)
    |> Jsont.Object.mem "values" (Jsont.option (Jsont.array Jsont.string)) ~enc:(fun arr -> arr)
    |> Jsont.Object.finish
  in

  Printf.printf "\nTest 2: Jsont.option (Jsont.array):\n";
  (match Yamlt.decode_string codec2 yaml with
   | Ok arr ->
       (match arr with
        | None -> Printf.printf "Result: None\n"
        | Some a -> Printf.printf "Result: Some([%d items])\n" (Array.length a))
   | Error e -> Printf.printf "Error: %s\n" e)
