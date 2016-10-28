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








let string_of_lambda = Format.asprintf "%a" Lam_print.lambda 

let string_of_primitive = Format.asprintf "%a" Lam_print.primitive


(* TODO: not very efficient .. *)
exception Cyclic 
      
let toplogical (get_deps : Ident.t -> Ident_set.t) (libs : Ident.t list) : Ident.t list =
  let rec aux acc later todo round_progress =
    match todo, later with
    | [], [] ->  acc
    | [], _ ->
        if round_progress
        then aux acc todo later false
        else raise Cyclic
    | x::xs, _ ->
        if Ident_set.for_all (fun dep -> x == dep || List.mem dep acc) (get_deps x)
        then aux (x::acc) later xs true
        else aux acc (x::later) xs round_progress
  in
  let starts, todo = List.partition (fun lib -> Ident_set.is_empty @@ get_deps lib) libs in
  aux starts [] todo false

let sort_dag_args  param_args =
  let todos = Ident_map.keys param_args  in
  let idents = Ident_set.of_list  todos in
  let dependencies  : Ident_set.t Ident_map.t = 
    Ident_map.mapi (fun param arg -> Js_fold_basic.depends_j arg idents) param_args in
  try  
    Some (toplogical (fun k -> Ident_map.find k dependencies) todos)
  with Cyclic -> None 



let add_required_module (x : Ident.t) (meta : Lam_stats.meta) = 
  meta.required_modules <- Lam_module_ident.of_ml x :: meta.required_modules 

let add_required_modules ( x : Ident.t list) (meta : Lam_stats.meta) = 
  let required_modules = 
    List.map 
      (fun x -> Lam_module_ident.of_ml x)  x
    @ meta.required_modules in
  meta.required_modules <- required_modules

(* Apply a substitution to a lambda-term.
   Assumes that the bound variables of the lambda-term do not
   belong to the domain of the substitution.
   Assumes that the image of the substitution is out of reach
   of the bound variables of the lambda-term (no capture). *)

let subst_lambda (s : Lam.t Ident_map.t) lam =
  let rec subst (x : Lam.t) : Lam.t =
    match x with 
    | Lvar id as l ->
      begin 
        try Ident_map.find id s with Not_found -> l 
      end
    | Lconst sc as l -> l
    | Lapply{fn; args; loc; status} -> 
      Lam.apply (subst fn) (List.map subst args) loc status
    | Lfunction {arity; kind; params; body} -> 
      Lam.function_ ~arity ~kind  ~params ~body:(subst body)
    | Llet(str, id, arg, body) -> 
      Lam.let_ str id (subst arg) (subst body)
    | Lletrec(decl, body) -> 
      Lam.letrec (List.map subst_decl decl) (subst body)
    | Lprim { primitive ; args; loc} -> 
      Lam.prim ~primitive ~args:(List.map subst args) loc
    | Lswitch(arg, sw) ->
      Lam.switch (subst arg)
        {sw with sw_consts = List.map subst_case sw.sw_consts;
                 sw_blocks = List.map subst_case sw.sw_blocks;
                 sw_failaction = subst_opt  sw.sw_failaction; }
    | Lstringswitch (arg,cases,default) ->
      Lam.stringswitch
        (subst arg) (List.map subst_strcase cases) (subst_opt default)
    | Lstaticraise (i,args)
      ->  Lam.staticraise i (List.map subst args)
    | Lstaticcatch(e1, io, e2)
      -> Lam.staticcatch (subst e1) io (subst e2)
    | Ltrywith(e1, exn, e2)
      -> Lam.try_ (subst e1) exn (subst e2)
    | Lifthenelse(e1, e2, e3)
      -> Lam.if_ (subst e1) (subst e2) (subst e3)
    | Lsequence(e1, e2)
      -> Lam.seq (subst e1) (subst e2)
    | Lwhile(e1, e2) 
      -> Lam.while_ (subst e1) (subst e2)
    | Lfor(v, e1, e2, dir, e3) 
      -> Lam.for_ v (subst e1) (subst e2) dir (subst e3)
    | Lassign(id, e) -> 
      Lam.assign id (subst e)
    | Lsend (k, met, obj, args, loc) ->
      Lam.send k (subst met) (subst obj) (List.map subst args) loc
    | Lifused (v, e) -> Lam.ifused v (subst e)
  and subst_decl (id, exp) = (id, subst exp)
  and subst_case (key, case) = (key, subst case)
  and subst_strcase (key, case) = (key, subst case)
  and subst_opt = function
    | None -> None
    | Some e -> Some (subst e)
  in subst lam

(* 
    It's impossible to have a case like below:
   {[
     (let export_f = ... in export_f)
   ]}
    Even so, it's still correct
*)
let refine_let
    ?kind param
    (arg : Lam.t) (l : Lam.t)  : Lam.t =

  match (kind : Lambda.let_kind option), arg, l  with 
  | _, _, Lvar w when Ident.same w param (* let k = xx in k *)
    -> arg (* TODO: optimize here -- it's safe to do substitution here *)
  | _, _, Lprim {primitive ; args =  [Lvar w]; loc ; _} when Ident.same w param 
                                 &&  (function | Lam.Pmakeblock _ -> false | _ ->  true) primitive
    (* don't inline inside a block *)
    ->  Lam.prim ~primitive ~args:[arg]  loc 
  (* we can not do this substitution when capttured *)
  (* | _, Lvar _, _ -> (\** let u = h in xxx*\) *)
  (*     (\* assert false *\) *)
  (*     Ext_log.err "@[substitution >> @]@."; *)
  (*     let v= subst_lambda (Ident_map.singleton param arg ) l in *)
  (*     Ext_log.err "@[substitution << @]@."; *)
  (* v *)
  | _, _, Lapply {fn; args = [Lvar w]; loc; status} when Ident.same w param -> 
    (** does not work for multiple args since 
        evaluation order unspecified, does not apply 
        for [js] in general, since the scope of js ir is loosen

        here we remove the definition of [param]
    *)
    Lam.apply fn [arg] loc status
  | (Some (Strict | StrictOpt ) | None ),
    ( Lvar _    | Lconst  _ | 
      Lprim {primitive = Pfield _ ;  
             args = [Lprim {primitive = Pgetglobal _ ; args =  []; _}]; _}) , _ ->
    (* (match arg with  *)
    (* | Lconst _ ->  *)
    (*     Ext_log.err "@[%a %s@]@."  *)
    (*       Ident.print param (string_of_lambda arg) *)
    (* | _ -> ()); *)
    (* No side effect and does not depend on store,
        since function evaluation is always delayed
    *)
    Lam.let_ Alias param arg l
  | (Some (Strict | StrictOpt ) | None ), (Lfunction _ ), _ ->
    (*It can be promoted to [Alias], however, 
        we don't want to do this, since we don't want the 
        function to be inlined to a block, for example
        {[
          let f = fun _ -> 1 in
          [0, f]
        ]}
        TODO: punish inliner to inline functions 
        into a block 
    *)
    Lam.let_ StrictOpt  param arg l
  (* Not the case, the block itself can have side effects 
      we can apply [no_side_effects] pass 
      | Some Strict, Lprim(Pmakeblock (_,_,Immutable),_) ->  
        Llet(StrictOpt, param, arg, l) 
  *)      
  | Some Strict, _ ,_  when Lam_analysis.no_side_effects arg ->
    Lam.let_ StrictOpt param arg l
  | Some Variable, _, _ -> 
    Lam.let_ Variable  param arg l
  | Some kind, _, _ -> 
    Lam.let_ kind  param arg l
  | None , _, _ -> 
    Lam.let_ Strict param arg  l

let alias (meta : Lam_stats.meta) (k:Ident.t) (v:Ident.t) 
    (v_kind : Lam_stats.kind) (let_kind : Lambda.let_kind) =
  (** treat rec as Strict, k is assigned to v 
      {[ let k = v ]}
  *)
  begin 
    match v_kind with 
    | NA ->
      begin 
        match Hashtbl.find meta.ident_tbl v  with 
        | exception Not_found -> ()
        | ident_info -> Hashtbl.add meta.ident_tbl k ident_info
      end
    | ident_info -> Hashtbl.add meta.ident_tbl k ident_info
  end ;
  (* share -- it is safe to share most properties,
      for arity, we might be careful, only [Alias] can share,
      since two values have same type, can have different arities
      TODO: check with reference pass, it might break 
      since it will create new identifier, we can avoid such issue??

      actually arity is a dynamic property, for a reference, it can 
      be changed across 
      we should treat
      reference specially. or maybe we should track any 
      mutable reference
  *)
  begin match let_kind with 
    | Alias -> 
      if not @@ Ident_set.mem k meta.export_idents 
      then
        Hashtbl.add meta.alias_tbl k v 
    (** For [export_idents], we don't want to do such simplification
        if we do substitution, then it will affect exports...
    *)
    | Strict | StrictOpt(*can discard but not be substitued *) | Variable  -> ()
  end




(* How we destruct the immutable block 
   depend on the block name itself, 
   good hints to do aggressive destructing
   1. the variable is not exported
      like [matched] -- these are blocks constructed temporary
   2. how the variable is used 
      if it is guarateed to be 
      - non export 
      - and non escaped (there is no place it is used as a whole)
      then we can always destruct it 
      if some fields are used in multiple places, we can create 
      a temporary field 

   3. It would be nice that when the block is mutable, its 
       mutable fields are explicit
*)

let element_of_lambda (lam : Lam.t) : Lam_stats.element = 
  match lam with 
  | Lvar _ 
  | Lconst _ 
  | Lprim {primitive = Pfield _ ; 
           args =  [ Lprim { primitive = Pgetglobal _; args =  []; _}];
           _} -> SimpleForm lam
  (* | Lfunction _  *)
  | _ -> NA 

let kind_of_lambda_block kind (xs : Lam.t list) : Lam_stats.kind = 
  xs 
  |> List.map element_of_lambda 
  |> (fun ls -> Lam_stats.ImmutableBlock (Array.of_list  ls, kind))

let get lam v i tbl : Lam.t =
  match (Hashtbl.find tbl v  : Lam_stats.kind) with 
  | Module g -> 
    Lam.prim ~primitive:(Pfield (i, Lambda.Fld_na)) 
      ~args:[Lam.prim ~primitive:(Pgetglobal g) ~args:[] Location.none] Location.none
  | ImmutableBlock (arr, _) -> 
    begin match arr.(i) with 
      | NA -> lam 
      | SimpleForm l -> l
    end
  | Constant (Const_block (_,_,ls)) -> 
    Lam.const (List.nth  ls i)
  | _ -> lam
  | exception Not_found -> lam 


(* TODO: check that if label belongs to a different 
    namesape
*)
let count = ref 0 

let generate_label ?(name="") ()  = 
  incr count; 
  Printf.sprintf "%s_tailcall_%04d" name !count

let log_counter = ref 0


let dump env ext  lam = 
#if BS_COMPILER_IN_BROWSER then
    lam
#else    
  if Js_config.is_same_file ()
  then 
    (* ATTENTION: easy to introduce a bug during refactoring when forgeting `begin` `end`*)
    begin 
      incr log_counter;
      Lam_print.seriaize env 
        (Ext_filename.chop_extension 
           ~loc:__LOC__ 
           (Js_config.get_current_file ()) ^ 
         (Printf.sprintf ".%02d%s.lam" !log_counter ext)
        ) lam;
    end;
  lam
#end

let ident_set_of_list ls = 
  List.fold_left
    (fun acc k -> Ident_set.add k acc ) 
    Ident_set.empty ls 

let print_ident_set fmt s = 
  Format.fprintf fmt   "@[<v>{%a}@]@."
    (fun fmt s   -> 
       Ident_set.iter 
         (fun e -> Format.fprintf fmt "@[<v>%a@],@ " Ident.print e) s
    )
    s     




let is_function (lam : Lam.t) = 
  match lam with 
  | Lfunction _ -> true | _ -> false

let not_function (lam : Lam.t) = 
  match lam with 
  | Lfunction _ -> false | _ -> true 

(* TODO: we need create 
   1. a smart [let] combinator, reusable beta-reduction 
   2. [lapply fn args info] 
   here [fn] should get the last tail
   for example 
   {[
     lapply (let a = 3 in let b = 4 in fun x y -> x + y) 2 3 
   ]}   
*)

(*
  let f x y =  x + y 
  Invariant: there is no currying 
  here since f's arity is 2, no side effect 
  f 3 --> function(y) -> f 3 y 
*)
let eta_conversion n loc status fn args = 
  let extra_args = Ext_list.init n
      (fun _ ->   (Ident.create Literals.param)) in
  let extra_lambdas = List.map (fun x -> Lam.var x) extra_args in
  begin match List.fold_right (fun (lam : Lam.t) (acc, bind) ->
      match lam with
      | Lvar _
      | Lconst (Const_base _ | Const_pointer _ | Const_immstring _ ) 
      | Lprim {primitive = Pfield _;
               args =  [Lprim {primitive = Pgetglobal _; _}]; _ }
      | Lfunction _ 
        ->
        (lam :: acc, bind)
      | _ ->
        let v = Ident.create Literals.partial_arg in
        (Lam.var v :: acc),  ((v, lam) :: bind)
    ) (fn::args) ([],[])   with 
  | fn::args , bindings ->

    let rest : Lam.t = 
      Lam.function_ ~arity:n ~kind:Curried ~params:extra_args
                ~body:(Lam.apply fn (args @ extra_lambdas) 
                   loc 
                   status
                ) in
    List.fold_left (fun lam (id,x) ->
        Lam.let_ Strict id x lam
      ) rest bindings
  | _, _ -> assert false
  end




let free_variables l =
  let fv = ref Ident_set.empty in
  let rec free (l : Lam.t) =
    Lam_iter.inner_iter free l;
    match l with
    | Lvar id -> fv := Ident_set.add id !fv
    | Lfunction{ params;} -> 
      List.iter (fun param -> fv := Ident_set.remove param !fv) params
    | Llet(str, id, arg, body) ->
      fv := Ident_set.remove id !fv
    | Lletrec(decl, body) ->
      List.iter (fun (id, exp) -> fv := Ident_set.remove id !fv) decl
    | Lstaticcatch(e1, (_,vars), e2) ->
      List.iter (fun id -> fv := Ident_set.remove id !fv) vars
    | Ltrywith(e1, exn, e2) ->
      fv := Ident_set.remove exn !fv
    | Lfor(v, e1, e2, dir, e3) ->
      fv := Ident_set.remove v !fv
    | Lassign(id, e) ->
      fv := Ident_set.add id !fv
    | Lconst _ | Lapply _
    | Lprim _ | Lswitch _ | Lstringswitch _ | Lstaticraise _
    | Lifthenelse _ | Lsequence _ | Lwhile _
    | Lsend _  | Lifused _ -> ()
  in free l; !fv
