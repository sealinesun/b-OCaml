
[cmdliner]: http://erratique.ch/software/cmdliner

Homepage: http://erratique.ch/software/b0  


## Propaganda

* Cross-platform, generic, memoizing build system.
* Simple, direct style build model with dynamic dependencies.
  Low-level build descriptions are sequences of command
  executions annoted with dependency information.
* No build rules, no DSL. Builds are written in OCaml. Use rich data
  structures and OCaml libraries to devise modular, high-level and
  distributable descriptions.
* Fast (re)builds. Automatic command parallelization and execution
  memoization via an on-disk cache.
* Precise dependency information, takes into account changes in build
  description, structure or environment with reasonable speed versus
  correctness trade-offs.
* Build outcome introspection, including profiling and statistics.
* Supports configuration.
* Supports side by side build variants.
* Supports builds in containers, virtual and remote machines.
* Supports arbitrary build artefact metadata.
* Supports oblivious cross-compilation.
* Supports source and binary deployments.
* Supports cross-platform, shell-script free, workflows via custom OCaml hooks.
* Supports per project, composable, `B0.ml` description files usable with
  the `b0` and `d0` command line tools.
* Supports custom `B0.ml` description file processing with the 
  `B0_driver` library.
* Supports build as a library. The core `B0` memoizing build library
  can be reused for its own good.

To get started, continue with the [manual][doc]. High-level design
choices are motivated by the [RATIONALE.md](RATIONALE.md).

## Convenience descriptions

B0 is agnostic to the software it cares about but the following
optional convenience default description are provided pro bono by B0
via the `B0_care` library:

* `B0_care`, general software care including build and host platform
   information and source code deployment.
* `B0_c`, C software care.
* `B0_ocaml`, OCaml software care.
* `B0_opam`, generic opam variant schemes and deployments.
* `B0_{docker,vbox,ssh}`, generic proxy variant schemes for
   building via the corresponding technologies.
 
These descriptions are neither mandatory nor built-in and could have
been provided by external libraries. They are however directly
available in `B0.ml` description files. Help to improve and maintain
these to react to changes is very welcome.

## Installation

b0 can be installed with `opam`:

    opam install b0

If you don't use `opam` consult the [`b0.opam`](b0.opam) file for build
instructions.

## Documentation & manual

The manual and API reference is generated from the source
interfaces. It can be consulted [online][doc] or via `odig doc
b0`.

[doc]: http://erratique.ch/software/b0/doc
