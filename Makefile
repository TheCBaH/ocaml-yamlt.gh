ROOT = ocaml-yamlt.anil
DUNE = opam exec -- dune

default:
	$(DUNE) build --root $(ROOT)

clean:
	$(DUNE) clean --root $(ROOT)

test:
	$(DUNE) runtest --root $(ROOT)

format:
	$(DUNE) fmt --root $(ROOT)

repo:
	opam repo add aoah https://tangled.org/anil.recoil.org/aoah-opam-repo.git || true

deps: repo
	opam install ./$(ROOT) --deps-only --with-test --yes

.PHONY: default clean test format deps repo
