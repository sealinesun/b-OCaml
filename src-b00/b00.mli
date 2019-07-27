(*---------------------------------------------------------------------------
   Copyright (c) 2018 The b0 programmers. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

(** Build kernel *)

(** {1:b00 B00} *)

open B0_std

(** Build environment.

    Build environments control tool lookup and the environment
    of tool spawns. *)
module Env : sig

  (** {1:lookup Tool lookup} *)

  type tool_lookup = Cmd.tool -> (Fpath.t, string) result
  (** The type for tool lookups. Given a command line tool
      {{!type:B0_std.Cmd.tool}specification} returns a file path to
      the tool executable or an error message mentioning the tool if
      it cannot be found. *)

  val env_tool_lookup :
    ?sep:string -> ?var:string -> Os.Env.t -> tool_lookup
  (** [env_tool_lookup ~sep ~var env] is a tool lookup that gets the
      value of the [var] variable in [env] treats it as a [sep]
      separated {{!B0_std.Fpath.list_of_search_path}search path} and
      uses the result to lookup with {!B0_std.Os.Cmd.must_find}.
      [var] defaults to [PATH] and [sep] to
      {!B0_std.Fpath.search_path_sep}. *)

  (** {1:env Environment} *)

  type t
  (** The type for build environments. *)

  val v : ?lookup:tool_lookup -> ?forced_env:Os.Env.t -> Os.Env.t -> t
  (** [v ~lookup ~forced_env env] is a build environment with:
      {ul
      {- [lookup] used to find build tools. Defaults to
         [env_tool_lookup env].}
      {- [forced_env] is environment forced on any tool despite
         what it declared to access, defaults to {!Os.Env.empty}}
      {- [env] the environment read by the tools' declared environment
         variables.}} *)

  val env : t -> Os.Env.t
  (** [env e] is [e]'s available spawn environment. *)

  val forced_env : t -> Os.Env.t
  (** [forced_env e] is [e]'s forced spawn environment. *)

  val tool : t -> Cmd.tool -> (Fpath.t, string) result
  (** [tool e t] looks up tool [t] in [e]. *)
end

(** Command line tools.

    A tool is specified either by name, to be looked up via an
    unspecified mecanism, or by a file path to an executable file. It
    also declares the environment variables it accesses in the process
    environment and whether and how it supports response files.

    Declared environment variables are split into relevant and
    shielded variables. A relevant variable is a variable whose value
    influences the tool's output. A shielded variable is a variable
    whose value does not influence the tool's output but is
    nonetheless essential to its operation. Shielded environment
    variables do not appear are not part of the stamp used to memoize
    tool spawns. Variables specifying the location of
    {{!tmp_vars}temporary file directories} are good examples of
    shielded variables.

    {b Portability.} In order to maximize portability no [.exe]
    suffix should be added to executable names on Windows, the
    search procedure will add the suffix during the tool search
    procedure if absent. *)
module Tool : sig

  (** {1:env Environment variables} *)

  type env_vars = string list
  (** The type for lists of environment variable names. *)

  val tmp_vars : env_vars
  (** [tmp_vars] is [["TMPDIR"; "TEMP"; "TMP"]]. *)

  (** {1:resp Response files} *)

  type response_file
  (** The type for response file specification. *)

  val response_file_of :
    (Cmd.t -> string) -> (Fpath.t -> Cmd.t) -> response_file
  (** [response_file_of to_file cli] is a response file specification
      that uses [to_file cmd] to convert the command line [cmd] to a
      response file content and [cli f] a command line fragment to be
      given to the tool so that it treats file [f] as a response
      file. *)

  val args0 : response_file
  (** [args0] is response file support for tools that reads null byte
      ([0x00]) terminated arguments response files via an [-args0
      FILE] command line synopsis. *)

  (** {1:tools Tools} *)

  type t
  (** The type for tools. *)

  val v :
    ?response_file:response_file -> ?shielded_vars:env_vars ->
    ?vars:env_vars -> Cmd.tool -> t
  (** [v ~response_file ~shielded_vars ~vars cmd] is a tool specified
      by [cmd]. [vars] are the relevant variables accessed by the
      tool (defaults to [[]]). [shielded_vars] are the shielded
      variables accessed by the tool (defaults to {!tmp_vars}).
      [response_file] defines the reponse file support for the tool
      (if any). *)

  val by_name :
    ?response_file:response_file -> ?shielded_vars:env_vars ->
    ?vars:env_vars -> string -> t
  (** [by_name] is like {!v} but reference the tool directly via a name.

      @raise Invalid_argument if {!Fpath.is_seg} [name] is [false]. *)

  val name : t -> Cmd.tool
  (** [name t] is [t]'s tool name. If this is a relative file path
      with a single segment the tool is meant to be searched via an
      external mecanism. *)

  val vars : t -> env_vars
  (** [vars t] are the relevant environment variables accessed by [t]. *)

  val shielded_vars : t -> env_vars
  (** [shieled_vars t] are the shielded environment variables
      accessed by [t]. *)

  val response_file : t -> response_file option
  (** [response_file t] is [t]'s response file specification (if any). *)

  val read_env : t -> Os.Env.t -> Os.Env.t * Os.Env.t
  (** [read_env t env] is (all, relevant) with [all] the
      environment with the variables of [env] that are in [vars t]
      and [shielded_vars t] and [relevant] those of [vars t] only. *)
end

(** Build memoizer.

    A memoizer ties together and environment, an operation cache, a guard
    and an executor. *)
module Memo : sig

  (** {1:memo Memoizer} *)

  type feedback =
  [ `Fiber_exn of exn * Printexc.raw_backtrace
  | `Fiber_fail of string
  | `Miss_tool of Tool.t * string
  | `Op_cache_error of B000.Op.t * string
  | `Op_complete of B000.Op.t ]
  (** The type for memoizer feedback. *)

  type t
  (** The type for memoizers. This ties together an environment, a
      aguard, an operation cache and an executor. *)

  val create :
    ?clock:Time.counter -> ?cpu_clock:Time.cpu_counter ->
    feedback:(feedback -> unit) -> cwd:Fpath.t -> Env.t -> B000.Guard.t ->
    B000.Reviver.t -> B000.Exec.t -> t

  val memo :
    ?hash_fun:(module Hash.T) -> ?env:Os.Env.t -> ?cwd:Fpath.t ->
    ?cache_dir:Fpath.t -> ?trash_dir:Fpath.t -> ?jobs:int ->
    ?feedback:([feedback | B000.File_cache.feedback |
                B000.Exec.feedback] -> unit) ->
    unit -> (t, string) result
  (** [memo] is a simpler {!create}
      {ul
      {- [hash_fun] defaults to {!Op_cache.create}'s default.}
      {- [jobs] defaults to {!Exec.create}'s default.}
      {- [env] defaults to {!Os.Env.current}}
      {- [cwd] defaults to {!Os.Dir.cwd}}
      {- [cache_dir] defaults to [Fpath.(cwd / "_b0" / ".cache")]}
      {- [trash_dir] defaults to [Fpath.(cwd / "_b0" / ".trash")]}
      {- [feedback] defaults formats feedback on stdout.}} *)

  val clock : t -> Time.counter
  (** [clock m] is [m]'s clock. *)

  val cpu_clock : t -> Time.cpu_counter
  (** [cpu_clock m] is [m]'s cpu clock. *)

  val env : t -> Env.t
  (** [env m] is [m]'s environment. *)

  val reviver : t -> B000.Reviver.t
  (** [reviver m] is [m]'s reviver. *)

  val guard : t -> B000.Guard.t
  (** [guard m] is [m]'s guard. *)

  val exec : t -> B000.Exec.t
  (** [exec m] is [m]'s executors. *)

  val trash : t -> B000.Trash.t
  (** [trash m] is [m]'s trash. *)

  val hash_string : t -> string -> Hash.t
  (** [hash_string m s] is {!Reviver.hash_string}[ (reviver m) s]. *)

  val hash_file : t -> Fpath.t -> (Hash.t, string) result
  (** [hash_file m f] is {!Reviver.hash_file}[ (reviver m) f].
      Note that these file hashes operations are memoized. *)

  val stir : block:bool -> t -> unit
  (** [stir ~block m] runs the memoizer a bit. If [block] is [true]
      blocks until the memoizer is stuck with no operation to
      perform. *)

  val finish : t -> (unit, Fpath.Set.t) result
  (** [finish m] finishes the memoizer and deletes the trash.  This
      blocks until there are no operation to execute like {!stir}
      does. If no operations are left waiting this returns [Ok ()]. If
      there are remaining waiting operations it aborts them and
      returns [Error fs] with [fs] the files that never became ready
      and where not supposed to be written by the waiting operations. *)

  val delete_trash : block:bool -> t -> (unit, string) result
  (** [delete_trash ~block m] is {!Trash.delete}[ trash m]. *)

  val ops : t -> B000.Op.t list
  (** [ops m] is the list of operations that were submitted to the
      memoizer *)

  (** {1:group Operation groups} *)

  val group : t -> string
  (** [group m] is [m]'s group. *)

  val with_group : t -> string -> t
  (** [group m g] is [m] but operations performed on [m] have group [g]. *)

  (** {1:fibers Fibers} *)

  type 'a fiber = ('a -> unit) -> unit
  (** The type for memoizer operation fibers. *)

  val fail : ('b, Format.formatter, unit, 'a) format4 -> 'b
  (** [fail fmt ...] fails the fiber with the given error message. *)

  val fail_error : ('a, string) result -> 'a
  (** [fail_error] fails the fiber with the given error. *)

  (** {1:feedback Feedback} *)

  val notify :
    t -> [ `Warn | `Start | `End | `Info ] ->
    ('a, Format.formatter, unit, unit) format4 -> 'a
  (** [notify kind msg] is a notification [msg] of kind [kind]. *)

  (** {1:files Files and directories} *)

  val file_ready : t -> Fpath.t -> unit
  (** [ready m p] declares path [p] to be ready, that is exists and is
      up-to-date in [b]. This is typically used with source files
      and files external to the build (e.g. installed libraries). *)

  val wait_files : t -> Fpath.t list -> unit fiber
  (** [wait_files m files k] continues with [k ()] when [files]
      become ready. {b FIXME} Unclear whether
      we really want this though this is kind of a [reads] constraint
      for a pure OCaml operation, but then we got {!read}. *)

  val read : t -> Fpath.t -> string fiber
  (** [read m file k] reads the contents of file [file] as [s] when it
      becomes ready and continues with [k s]. *)

  val write :
    t -> ?stamp:string -> ?reads:Fpath.t list -> ?mode:int ->
    Fpath.t -> (unit -> (string, string) result) -> unit
  (** [write m ~reads file w] writes [file] with data [w ()] and mode
      [mode] (defaults to [0o644]) when [reads] are ready. [w]'s
      result must only depend on [reads] and [stamp] (defaults to
      [""]). *)

  val copy :
    t -> ?mode:int -> ?linenum:int -> src:Fpath.t -> Fpath.t -> unit
  (** [copy m ~mode ?linenum ~src dst] copies file [src] to [dst] with
      mode [mode] (defaults to [0o644]) when [src] is ready. If [linenum]
      is specified, the following line number directive is prependend
      in [dst] to the contents of [src]:
{[
#line $(linenum) "$(src)"
]} *)

  val mkdir : t -> ?mode:int -> Fpath.t -> unit fiber
  (** [mkdir m dir p] creates the directory path [p] with [mode]
      [mode] (defaults to [0o755]) and continues with [k ()] whne
      [dir] is available. The behaviour with respect to file
      permission matches {!Os.Dir.create}. *)

  val delete : t -> Fpath.t -> unit fiber
  (** [delete m p] deletes (trashes in fact) path [p] and continues
      with [k ()] when the path [p] is free to use. *)

  (** {1:spawn Memoizing tool spawns} *)

  type tool
  (** The type for memoized tools. *)

  type cmd
  (** The type for memoized tool invocations. *)

  val tool : t -> Tool.t -> (Cmd.t -> cmd)
  (** [tool m t] is tool [t] memoized. Use the resulting function
      to spawn the tool with the given arguments. *)

  val tool_opt : t -> Tool.t -> (Cmd.t -> cmd) option
  (** [tool_opt m t] is like {!tool}, except [None] is returned
      if the tool cannot be found. *)

  val spawn :
    t -> ?stamp:string -> ?reads:Fpath.t list -> ?writes:Fpath.t list ->
    ?env:Os.Env.t -> ?cwd:Fpath.t -> ?stdin:Fpath.t ->
    ?stdout:B000.Op.Spawn.stdo -> ?stderr:B000.Op.Spawn.stdo ->
    ?success_exits:B000.Op.Spawn.success_exits ->
    ?k:(int -> unit) -> cmd -> unit
  (** [spawn m ~reads ~writes ~env ~cwd ~stdin ~stdout ~stderr
      ~success_exits cmd] spawns [cmd] once [reads] files are ready
      and makes files [writes] ready if the spawn succeeds and the
      file exists. The rest of the arguments are:
      {ul
      {- [stdin] reads input from the given file. If unspecified reads
         from the standard input of the program running the build.  {b
         Warning.} The file is not automatically added to [reads],
         this allows for example to use {!Os.File.null}.}
      {- [stdout] and [stderr], the redirections for the standard
         outputs of the command, see {!stdo}. Path to files are
         created if needed. {b Warning.} File redirections
         are not automatically added to [writes]; this allows for example
         to use {!Os.File.null}.}
      {- [success_exits] the exit codes that determine if the build operation
         is successful (defaults to [0], use [[]] to always succeed)}
      {- [env], environment variables added to the build environment.
         This overrides environment variables read by the tool in the
         build environment except for forced one. It also allows to
         specify environment that may not be mentioned by the running
         tool's {{!Tool.v}environment specification}.}
      {- [cwd] the current working directory. Default is {!cwd}. In
         general it's better to avoid using relative file paths and
         tweaking the [cwd]. Construct your paths using the absolute
         {{!dirs}directory functions} and make your invocations
         independent from the [cwd].}
      {- [k], if specified a fiber invoked once the spawn has succesfully
         executed with the exit code.}
      {- [stamp] is used for caching if two spawns diff only in their
         stamp they will cache to different keys. This can be used to
         memoize tool whose outputs may not entirely depend on the environment,
         the cli stamp and the the content of read files.}}

      {b TODO.} More expressive power could by added by:
      {ol
      {- Support to refine the read and write set after the operation
         returns.}}

      {b Note.} If the tool spawn acts on a sort of "main" file
      (e.g. a source file) it should be specified as the first element
      of [reads], this is interpreted specially by certain build
      tracer. *)

  (** {1:futs Future values} *)

  (** Future values. *)
  module Fut : sig

    (** {1:fut Future value setters} *)

    type 'a set
    (** The type for setting a future value of type ['a]. *)

    val set : 'a set -> 'a -> unit
    (** [set s v] sets the future value linked to [s] to the value [v].
        @raise Invalid_argument if the value was already set. *)

    (** {1:fut Future values} *)

    type memo = t
    (** See {!Memo.t} *)

    type 'a t
    (** The type for future values of type ['a]. *)

    val create : memo -> 'a t * 'a set
    (** [create memo] is [(f, s)] a future value [f] and a setter [s]
        for it. Fibers waiting on the future are scheduled by
        {!stir}ing [memo]. *)

    val value : 'a t -> 'a option
    (** [value f] is [f]'s value if set. *)

    val wait : 'a t -> 'a fiber
    (** [wait f k] waits for [f] to be set and continues with [k v]
        with [v] the value of the future. *)
  end
end

(*---------------------------------------------------------------------------
   Copyright (c) 2018 The b0 programmers

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
