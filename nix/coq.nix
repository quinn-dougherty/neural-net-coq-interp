{ pkgs }:
with pkgs.coqPackages_8_17; [
  pkgs.ocaml
  pkgs.dune_3
  pkgs.coq_8_17
  coq-lsp
  coq-record-update
  flocq
  interval
  vcfloat
  LAProof
  mathcomp
  mathcomp-zify
  mathcomp-algebra-tactics
  mathcomp-analysis
]
