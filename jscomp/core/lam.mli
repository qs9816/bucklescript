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

type array_kind = Lambda.array_kind
type boxed_integer = Lambda.boxed_integer
type comparison = Lambda.comparison 
type bigarray_kind = Lambda.bigarray_kind
type bigarray_layout = Lambda.bigarray_layout
type compile_time_constant = Lambda.compile_time_constant

type tag_info = Lambda.tag_info
type mutable_flag = Asttypes.mutable_flag
type field_dbg_info = Lambda.field_dbg_info 
type set_field_dbg_info = Lambda.set_field_dbg_info

type ident = Ident.t

type function_arities = 
  | Determin of bool * (int * Ident.t list option) list  * bool
  (** when the first argument is true, it is for sure 

      approximation sound but not complete 
      the last one means it can take any params later, 
      for an exception: it is (Determin (true,[], true))
   *)
  | NA 

type primitive = 
  | Pbytes_to_string
  | Pbytes_of_string
  | Pgetglobal of ident
  | Psetglobal of ident
  | Pglobal_exception of ident             
  | Pmakeblock of int * Lambda.tag_info * Asttypes.mutable_flag
  | Pfield of int * Lambda.field_dbg_info
  | Psetfield of int * bool * Lambda.set_field_dbg_info
  | Pfloatfield of int * Lambda.field_dbg_info
  | Psetfloatfield of int * Lambda.set_field_dbg_info
  | Pduprecord of Types.record_representation * int
  | Plazyforce
  | Pccall of  Primitive.description
  | Praise 
  | Psequand | Psequor | Pnot
  | Pnegint | Paddint | Psubint | Pmulint | Pdivint | Pmodint
  | Pandint | Porint | Pxorint
  | Plslint | Plsrint | Pasrint
  | Pintcomp of Lambda.comparison
  | Poffsetint of int
  | Poffsetref of int
  | Pintoffloat | Pfloatofint
  | Pnegfloat | Pabsfloat
  | Paddfloat | Psubfloat | Pmulfloat | Pdivfloat
  | Pfloatcomp of Lambda.comparison
  | Pstringlength 
  | Pstringrefu 
  | Pstringrefs
  | Pstringadd    
  | Pbyteslength
  | Pbytesrefu
  | Pbytessetu 
  | Pbytesrefs
  | Pbytessets
  (* Array operations *)
  | Pmakearray of array_kind
  | Parraylength of array_kind
  | Parrayrefu of array_kind
  | Parraysetu of array_kind
  | Parrayrefs of array_kind
  | Parraysets of array_kind
  (* Test if the argument is a block or an immediate integer *)
  | Pisint
  (* Test if the (integer) argument is outside an interval *)
  | Pisout
  (* Bitvect operations *)
  | Pbittest
  (* Operations on boxed integers (Nativeint.t, Int32.t, Int64.t) *)
  | Pbintofint of boxed_integer
  | Pintofbint of boxed_integer
  | Pcvtbint of boxed_integer (*source*) * boxed_integer (*destination*)
  | Pnegbint of boxed_integer
  | Paddbint of boxed_integer
  | Psubbint of boxed_integer
  | Pmulbint of boxed_integer
  | Pdivbint of boxed_integer
  | Pmodbint of boxed_integer
  | Pandbint of boxed_integer
  | Porbint of boxed_integer
  | Pxorbint of boxed_integer
  | Plslbint of boxed_integer
  | Plsrbint of boxed_integer
  | Pasrbint of boxed_integer
  | Pbintcomp of boxed_integer * comparison
  (* Operations on big arrays: (unsafe, #dimensions, kind, layout) *)
  | Pbigarrayref of bool * int * bigarray_kind * bigarray_layout
  | Pbigarrayset of bool * int * bigarray_kind * bigarray_layout
  (* size of the nth dimension of a big array *)
  | Pbigarraydim of int
  (* load/set 16,32,64 bits from a string: (unsafe)*)
  | Pstring_load_16 of bool
  | Pstring_load_32 of bool
  | Pstring_load_64 of bool
  | Pstring_set_16 of bool
  | Pstring_set_32 of bool
  | Pstring_set_64 of bool
  (* load/set 16,32,64 bits from a
     (char, int8_unsigned_elt, c_layout) Bigarray.Array1.t : (unsafe) *)
  | Pbigstring_load_16 of bool
  | Pbigstring_load_32 of bool
  | Pbigstring_load_64 of bool
  | Pbigstring_set_16 of bool
  | Pbigstring_set_32 of bool
  | Pbigstring_set_64 of bool
  (* Compile time constants *)
  | Pctconst of compile_time_constant
  (* byte swap *)
  | Pbswap16
  | Pbbswap of boxed_integer
  (* Integer to external pointer *)

  | Pdebugger
  | Pjs_unsafe_downgrade of string * Location.t
  | Pinit_mod
  | Pupdate_mod
  | Pjs_fn_make of int 
  | Pjs_fn_run of int 
  | Pjs_fn_method of int 
  | Pjs_fn_runmethod of int 

type switch  =
  { sw_numconsts: int;
    sw_consts: (int * t) list;
    sw_numblocks: int;
    sw_blocks: (int * t) list;
    sw_failaction : t option}
and apply_status =
  | App_na
  | App_ml_full
  | App_js_full      
and apply_info = private
  { fn : t ; 
    args : t list ; 
    loc : Location.t;
    status : apply_status
  }

and prim_info = private
  { primitive : primitive ; 
    args : t list ; 
    loc : Location.t 
  }
and function_info = private
  { arity : int ; 
   kind : Lambda.function_kind ; 
   params : ident list ;
   body : t 
  }
and  t =  private
  | Lvar of ident
  | Lconst of Lambda.structured_constant
  | Lapply of apply_info
  | Lfunction of function_info
  | Llet of Lambda.let_kind * ident * t * t
  | Lletrec of (ident * t) list * t
  | Lprim of prim_info
  | Lswitch of t * switch
  | Lstringswitch of t * (string * t) list * t option
  | Lstaticraise of int * t list
  | Lstaticcatch of t * (int * ident list) * t
  | Ltrywith of t * ident * t
  | Lifthenelse of t * t * t
  | Lsequence of t * t
  | Lwhile of t * t
  | Lfor of ident * t * t * Asttypes.direction_flag * t
  | Lassign of ident * t
  | Lsend of Lambda.meth_kind * t * t * t list * Location.t
  | Lifused of ident * t
  (* | Levent of t * Lambda.lambda_event 
     [Levent] in the branch hurt pattern match, 
     we should use record for trivial debugger info
  *)


module Prim : sig 
  type t = primitive
  val js_is_nil : t
  val js_is_undef : t 
  val js_is_nil_undef : t 
end


type binop = t -> t -> t 

type triop = t -> t -> t -> t 

type unop = t ->  t

val var : ident -> t
val const : Lambda.structured_constant -> t

val apply : t -> t list -> Location.t -> apply_status -> t
val function_ : 
  arity:int ->
  kind:Lambda.function_kind -> params:ident list -> body:t -> t

val let_ : Lambda.let_kind -> ident -> t -> t -> t
val letrec : (ident * t) list -> t -> t
val if_ : triop
val switch : t -> switch  -> t 
val stringswitch : t -> (string * t) list -> t option -> t 

val true_ : t 
val false_ : t 
val unit : t 

val sequor : binop
val sequand : binop
val not_ : Location.t ->  unop
val seq : binop
val while_ : binop
val event : t -> Lambda.lambda_event -> t  
val try_ : t -> ident -> t  -> t 
val ifused : ident -> t -> t
val assign : ident -> t -> t 

val send : 
  Lambda.meth_kind ->
  t -> t -> t list -> 
  Location.t -> t 

val prim : primitive:primitive -> args:t list -> Location.t  ->  t

val staticcatch : 
  t -> int * ident list -> t -> t

val staticraise : 
  int -> t list -> t

val for_ : 
  ident ->
  t  ->
  t -> Asttypes.direction_flag -> t -> t 





val convert : Lambda.lambda -> t 
