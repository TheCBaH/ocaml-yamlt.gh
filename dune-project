(lang dune 3.18)

(name yamlt)

(generate_opam_files true)

(license ISC)
(authors "Anil Madhavapeddy")
(homepage "https://tangled.org/@anil.recoil.org/ocaml-yamlt")
(maintainers "Anil Madhavapeddy <anil@recoil.org>")
(bug_reports "https://tangled.org/@anil.recoil.org/ocaml-yamlt/issues")
(maintenance_intent "(latest)")

(package
 (name yamlt)
 (synopsis "YAML codec using Jsont type descriptions")
 (description "Allows the same Jsont.t codec definitions to work for both JSON and YAML")
 (depends
  (ocaml (>= 4.14.0))
  yamlrw
  jsont
  bytesrw
  (odoc :with-doc)))
