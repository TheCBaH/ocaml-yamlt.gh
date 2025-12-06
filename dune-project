(lang dune 3.18)
(name yamlt)

(generate_opam_files true)

(package
 (name yamlt)
 (synopsis "YAML codec using Jsont type descriptions")
 (description "Allows the same Jsont.t codec definitions to work for both JSON and YAML")
 (depends
  (ocaml (>= 4.14.0))
  yamlrw
  jsont
  bytesrw))
