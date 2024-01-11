(** Setup script to customize a new fsocaml project.

    Patches to `dune-project` and the various `dune` files are done by parsing
    the S-expressions and replacing instances of `fsocaml` when it's in a
    non-label position in the `Sexp.List`.

    Source file patching (e.g. `bin/main.ml` is done by searching and replacing
    references to the Fsocaml module itself. *)

open Core

let dune_files = [ "dune-project"; "test/dune"; "lib/dune"; "bin/dune" ]

let rename_files =
  [ "fsocaml.opam"; "fsocaml.opam.template"; "test/fsocaml.ml" ]

let indent n = String.init n ~f:(fun _ -> ' ')

let pp_atom a =
  if String.contains a ' ' then
    "\"" ^ a ^ "\""
  else
    a

(** Convert an S-expression into a pretty-printed string in the style of a dune
    configuration file. *)
let pp_sexp s =
  let rec loop s' i f =
    match s' with
    | Sexp.Atom a -> pp_atom a
    | Sexp.List l ->
        let nl =
          if f then
            ""
          else
            "\n"
        in
        let prefix = sprintf "%s%s(" nl (indent (i * 2)) in
        let ls =
          List.foldi l ~init:"" ~f:(fun j acc s'' ->
              let sp =
                if j = 0 then
                  ""
                else
                  " "
              in
              acc ^ sp ^ loop s'' (i + 1) false)
        in
        prefix ^ ls ^ ")"
  in
  loop s 0 true ^ "\n"

(** Scan an S-expression and replace all instances of `from` with `into`, except
    for labels (the first atom in a list). *)
let sexp_patch s ~from ~into =
  let rec loop s' label =
    match (s', label) with
    | Sexp.Atom a, false when String.equal a from -> Sexp.Atom into
    | Sexp.Atom _, _ -> s'
    | Sexp.List l, _ ->
        Sexp.List
          (List.mapi l ~f:(fun i s'' ->
               if i = 0 then
                 loop s'' true
               else
                 loop s'' false))
  in
  loop s true

let patch_sfile filename from into =
  let f =
    Sexp.load_sexps filename
    |> List.map ~f:(sexp_patch ~from ~into)
    |> List.map ~f:pp_sexp
  in
  Out_channel.write_lines filename f

(** Scan lines in a source code file and replace all instances of `from` with
    `into`. *)
let patch_srcfile filename ~from ~into =
  let data =
    In_channel.read_all filename
    |> String.substr_replace_all ~pattern:from ~with_:into
  in
  Out_channel.write_all filename ~data

let () =
  Clap.description "Set up a new fsocaml project.";

  let dbname =
    Clap.optional_string ~long:"dbname" ~short:'d' ~placeholder:"DB_NAME" ()
      ~description:"Database name (default: fsocaml_dev)"
  in

  let projname =
    Clap.optional_string ~placeholder:"PROJECT_NAME" ()
      ~description:"Name of the fsocaml project (default: fsocaml)"
  in

  Clap.close ();

  let _ = Option.value dbname ~default:"fsocaml_dev" in
  let cwd = Core_unix.getcwd () |> String.split ~on:'/' |> List.last in
  let default_projname = Option.value cwd ~default:"fsocaml" in
  let projname' =
    String.lowercase (Option.value projname ~default:default_projname)
  in

  List.iter dune_files ~f:(fun file -> patch_sfile file "fsocaml" projname');

  let projname'' = String.capitalize projname' in
  patch_srcfile "bin/main.ml" ~from:"Fsocaml.Router.router"
    ~into:(projname'' ^ ".Router.router");
  patch_srcfile "fly.toml" ~from:"fsocaml" ~into:projname'';
  patch_srcfile "Dockerfile" ~from:"fsocaml" ~into:projname'';

  printf "%d files were patched.\n" (List.length dune_files + 3);

  rename_files
  |> List.iter ~f:(fun oldpath ->
         let newpath =
           oldpath
           |> String.substr_replace_all ~pattern:"fsocaml" ~with_:projname'
         in
         Core_unix.rename ~src:oldpath ~dst:newpath);

  printf "%d files were renamed.\n" (List.length rename_files)
