(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)




module Rules : sig
  type t  
  val define : command:string ->
  ?depfile:string ->
  ?description:string ->
  string -> t 

  val build_ast : t
  val build_ast_from_reason_impl : t 
  val build_ast_from_reason_intf : t 
  val build_deps : t 
  val reload : t 
  val copy_resources : t
  val build_ml_from_mll : t 
  val build_cmj_only : t
  val build_cmj_cmi : t 
  val build_cmi : t
end


(** output should always be marked explicitly,
   otherwise the build system can not figure out clearly
   however, for the command we don't need pass `-o`
*)
val output_build :
  ?order_only_deps:string list ->
  ?implicit_deps:string list ->
  ?outputs:string list ->
  ?inputs:string list ->
  output:string ->
  input:string ->
  rule:Rules.t -> out_channel -> unit


val phony  :
  ?order_only_deps:string list ->
  inputs:string list -> output:string -> out_channel -> unit

val output_kvs : (string * string) list -> out_channel -> unit

val handle_module_info : 
  string ->
  out_channel ->
  Binary_cache.module_info ->
  string list * string list -> string list * string list
