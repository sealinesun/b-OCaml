(*---------------------------------------------------------------------------
   Copyright (c) 2020 The b0 programmers. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
  ---------------------------------------------------------------------------*)

open B00_std

(* At a certain point we might want to cache the directory folds and
   file stats. But for now that seems good enough. *)

type fpath = string
let fpath = Fpath.to_string

type sel =
[ `D of fpath
| `D_rec of fpath
| `X of fpath
| `F of fpath
| `Fiber of B0_build.t -> Fpath.Set.t B00.Memo.fiber ]

type t = sel list

let fail m u fmt =
  B00.Memo.fail m ("@[Unit %a: " ^^ fmt ^^ "@]") B0_unit.pp_name u

let fail_if_error m u = function
| Error e -> fail m u " source selection: %s" e
| Ok v -> v

let select_files m u (seen, by_ext) fs =
  let rec loop m u seen by_ext = function
  | [] -> seen, by_ext
  | f :: fs ->
      match Os.File.exists f |> fail_if_error m u with
      | false ->
          let pp_file = Fmt.(code Fpath.pp_unquoted) in
          fail m u "source file@ %a@ does not exist." pp_file f
      | true ->
          if Fpath.Set.mem f seen then loop m u seen by_ext fs else
          let seen = Fpath.Set.add f seen in
          let by_ext = String.Map.add_to_list (Fpath.get_ext f) f by_ext in
          loop m u seen by_ext fs
  in
  loop m u seen by_ext fs

let select_files_in_dirs m u xs (seen, by_ext as acc) ds =
  let exclude =
    let ds =
      List.fold_left (fun s (d, _) -> Fpath.Set.add d s) Fpath.Set.empty ds
    in
    fun fname p ->
      let auto_exclude = function
      | "" | "." | ".." -> false
      | s when s.[0] = '.' -> true
      | _ -> false
      in
      if auto_exclude fname then not (Fpath.Set.mem p ds) (* allow explicit *)
      else Fpath.Set.mem p xs
  in
  let add_file st fname p (seen, by_ext as acc) =
    if exclude fname p then acc else
    match st.Unix.st_kind with
    | Unix.S_DIR -> acc
    | _ ->
        if Fpath.Set.mem p seen then acc else
        Fpath.Set.add p seen, String.Map.add_to_list (Fpath.get_ext p) p by_ext
  in
  let rec loop m u xs (seen, by_ext as acc) = function
  | [] -> acc
  | (d, recurse) :: ds ->
      let d = Fpath.rem_empty_seg d in
      if Fpath.Set.mem d xs then loop m u xs acc ds else
      match Os.Dir.exists d |> fail_if_error m u with
      | false ->
          let pp_dir = Fmt.(code Fpath.pp_unquoted) in
          fail m u "source directory@ %a@ does not exist." pp_dir d
      | true ->
          let prune _ dname dir _ = exclude dname dir  in
          let dotfiles = true (* exclusions handled by prune *) in
          let acc = Os.Dir.fold ~dotfiles ~prune ~recurse add_file d acc in
          loop m u xs (acc |> fail_if_error m u) ds
  in
  loop m u xs acc ds

let select_file_from_fibers b acc fibers k =
  let rec loop b acc = function
  | [] -> k acc
  | fiber :: fibers ->
      fiber b @@ fun files ->
      let add_file file (seen, by_ext as acc) =
        if Fpath.Set.mem file seen then acc else
        let ext = Fpath.get_ext file in
        let by_ext = String.Map.add_to_list ext file by_ext in
        (Fpath.Set.add file seen), by_ext
      in
      loop b (Fpath.Set.fold add_file files acc) fibers
  in
  loop b acc fibers

let select b sels k =
  let m = B0_build.memo b in
  let u = B0_build.Unit.current b in
  let root = B0_build.Unit.root_dir b u in
  let abs d = Fpath.(root // v d) in
  let fs, ds, xs, fibers =
    let rec loop fs ds xs fibers = function
    | [] -> fs, ds, xs, fibers
    | `D d :: ss -> loop fs ((abs d, false) :: ds) xs fibers ss
    | `D_rec d :: ss -> loop fs ((abs d, true) :: ds) xs fibers ss
    | `X x :: ss ->
        let x = Fpath.rem_empty_seg (abs x) in
        loop fs ds (Fpath.Set.add x xs) fibers ss
    | `F f :: ss -> loop ((abs f) :: fs) ds xs fibers ss
    | `Fiber f :: ss -> loop fs ds xs (f :: fibers) ss
    in
    loop [] [] Fpath.Set.empty [] sels
  in
  let acc = Fpath.Set.empty, String.Map.empty in
  let acc = select_files m u acc fs in
  let (seen, _ as acc) = select_files_in_dirs m u xs acc ds in
  Fpath.Set.iter (B00.Memo.file_ready m) seen;
  select_file_from_fibers b acc fibers @@ fun acc ->

  k (snd acc)

(*---------------------------------------------------------------------------
   Copyright (c) 2020 The b0 programmers

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
