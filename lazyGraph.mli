(*
Copyright (c) 2013, Simon Cruanes
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.  Redistributions in binary
form must reproduce the above copyright notice, this list of conditions and the
following disclaimer in the documentation and/or other materials provided with
the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*)

(** {1 Lazy graph data structure} *)

module type S = sig
  (** This module serves to represent directed graphs in a lazy fashion. Such
      a graph is always accessed from a given initial node (so only connected
      components can be represented by a single value of type ('v,'e) t). *)

  (** {2 Type definitions} *)

  type vertex
    (** The concrete type of a vertex. Vertices are considered unique within
        the graph. *)

  module H : Hashtbl.S with type key = vertex

  type ('v, 'e) t = vertex -> ('v, 'e) node
    (** Lazy graph structure. Vertices are annotated with values of type 'v,
        and edges are of type 'e. A graph is a function that maps vertices
        to a label and some edges to other vertices. *)
  and ('v, 'e) node =
    | Empty
    | Node of vertex * 'v * ('e * vertex) Enum.t
    (** A single node of the graph, with outgoing edges *)
  and 'e path = (vertex * 'e * vertex) list
    (** A reverse path (from the last element of the path to the first). *)

  (** {2 Basic constructors} *)

  (** It is difficult to provide generic combinators to build graphs. The problem
      is that if one wants to "update" a node, it's still very hard to update
      how other nodes re-generate the current node at the same time.
      The best way to do it is to build one function that maps the
      underlying structure of the type vertex to a graph (for instance,
      a concrete data structure, or an URL...). *)

  val empty : ('v, 'e) t
    (** Empty graph *)

  val singleton : vertex -> 'v -> ('v, 'e) t
    (** Trivial graph, composed of one node *)

  val from_enum : vertices:(vertex * 'v) Enum.t ->
                 edges:(vertex * 'e * vertex) Enum.t ->
                 ('v, 'e) t
    (** Concrete (eager) representation of a Graph (XXX not implemented)*)

  val from_fun : (vertex -> ('v * ('e * vertex) list) option) -> ('v, 'e) t
    (** Convenient semi-lazy implementation of graphs *)

  (** {2 Traversals} *)

  (** {3 Full interface to traversals} *)
  module Full : sig
    type ('v, 'e) traverse_event =
      | EnterVertex of vertex * 'v * int * 'e path (* unique ID, trail *)
      | ExitVertex of vertex (* trail *)
      | MeetEdge of vertex * 'e * vertex * edge_type (* edge *)
    and edge_type =
      | EdgeForward     (* toward non explored vertex *)
      | EdgeBackward    (* toward the current trail *)
      | EdgeTransverse  (* toward a totally explored part of the graph *)

    val bfs_full : ?id:int ref -> ?explored:unit H.t ->
                    ('v, 'e) t -> vertex Enum.t -> ('v, 'e) traverse_event Enum.t
      (** Lazy traversal in breadth first from a finite set of vertices *)

    val dfs_full : ?id:int ref -> ?explored:unit H.t ->
                   ('v, 'e) t -> vertex Enum.t -> ('v, 'e) traverse_event Enum.t
      (** Lazy traversal in depth first from a finite set of vertices *)
  end

  (** The traversal functions assign a unique ID to every traversed node *)

  val bfs : ?id:int ref -> ?explored:unit H.t ->
            ('v, 'e) t -> vertex -> (vertex * 'v * int) Enum.t
    (** Lazy traversal in breadth first *)

  val dfs : ?id:int ref -> ?explored:unit H.t ->
            ('v, 'e) t -> vertex -> (vertex * 'v * int) Enum.t
    (** Lazy traversal in depth first *)

  val enum : ('v, 'e) t -> vertex -> (vertex * 'v) Enum.t * (vertex * 'e * vertex) Enum.t
    (** Convert to an enumeration. The traversal order is undefined. *)

  val depth : (_, 'e) t -> vertex -> (int, 'e) t
    (** Map vertices to their depth, ie their distance from the initial point *)

  val min_path : ?distance:(vertex -> 'e -> vertex -> int) ->
                 ('v, 'e) t -> vertex -> vertex ->
                 int * 'e path
    (** Minimal path from the given Graph from the first vertex to
        the second. It returns both the distance and the path *)

  (** {2 Lazy transformations} *)

  val union : ?combine:('v -> 'v -> 'v) -> ('v, 'e) t -> ('v, 'e) t -> ('v, 'e) t
    (** Lazy union of the two graphs. If they have common vertices,
        [combine] is used to combine the labels. By default, the second
        label is dropped and only the first is kept *)

  val map : vertices:('v -> 'v2) -> edges:('e -> 'e2) ->
            ('v, 'e) t -> ('v2, 'e2) t
    (** Map vertice and edge labels *)

  val filter : ?vertices:(vertex -> 'v -> bool) ->
               ?edges:(vertex -> 'e -> vertex -> bool) ->
               ('v, 'e) t -> ('v, 'e) t
    (** Filter out vertices and edges that do not satisfy the given
        predicates. The default predicates always return true. *)

  val limit_depth : max:int -> ('v, 'e) t -> ('v, 'e) t
    (** Return the same graph, but with a bounded depth. Vertices whose
        depth is too high will be replaced by Empty *)

  module Infix : sig
    val (++) : ('v, 'e) t -> ('v, 'e) t -> ('v, 'e) t
      (** Union of graphs (alias for {! union}) *)
  end

  (** {2 Pretty printing in the DOT (graphviz) format *)
  module Dot : sig
    type attribute = [
    | `Color of string
    | `Shape of string
    | `Weight of int
    | `Style of string
    | `Label of string
    | `Other of string * string
    ] (** Dot attribute *)

    val pp_enum : name:string -> Format.formatter ->
                  (attribute list,attribute list) Full.traverse_event Enum.t ->
                  unit

    val pp : name:string -> (attribute list, attribute list) t ->
             Format.formatter ->
             vertex Enum.t -> unit
      (** Pretty print the given graph (starting from the given set of vertices)
          to the channel in DOT format *)
  end
end

(** {2 Module type for hashable types} *)
module type HASHABLE = sig
  type t
  val equal : t -> t -> bool
  val hash : t -> int
end

(** {2 Implementation of HASHABLE with physical equality and hash} *)
module PhysicalHash(X : sig type t end) : HASHABLE with type t = X.t

(** {2 Build a graph} *)
module Make(X : HASHABLE) : S with type vertex = X.t

(** {2 Build a graph based on physical equality} *)
module PhysicalMake(X : sig type t end) : S with type vertex = X.t

module IntGraph : S with type vertex = int