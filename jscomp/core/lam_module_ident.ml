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









type t = Js_op.module_id = 
  { id : Ident.t ; kind : Js_op.kind }

type system = Js_config.module_system 

let id x = x.id 

let of_ml id = { id ; kind =  Ml}

let of_external id name =  {id ; kind = External name}

let of_runtime id = { id ; kind = Runtime }

let mk kind id = {id; kind}

let name  x : string  = 
  match (x.kind : J.kind) with 
  | Ml  | Runtime ->  x.id.name
  | External v -> v  
  
(* OCaml runtime written in JS *)
type module_property = bool 
