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


module Rules = struct

  let rule_id = ref 0 
  let rule_names = ref String_set.empty
  type t = < name : out_channel -> String_set.elt >
  let define
      ~command
      ?depfile
      ?(description = "Building ${out}")
      name 
       =
       let current_id = !rule_id in
       let () = incr rule_id in 
       object(self) 
         val mutable used = false
         val name = 
           match String_set.find name !rule_names with 
           | exception Not_found -> 
             rule_names := String_set.add name !rule_names ; 
             name 
           | _ -> 
             begin (* could be improved later
                      1. instead of having a global id, having a unique id per rule name 
                      2. the rule id is increased only when actually used
                   *)
               let new_name =  (name ^ Printf.sprintf "_%d" current_id) in
               rule_names := String_set.add new_name  !rule_names ; 
               new_name 
             end
         method private print oc =
           if not used then 
             begin 
               output_string oc "rule "; output_string oc name ; output_string oc "\n";
               output_string oc "  command = "; output_string oc command; output_string oc "\n";
               begin match depfile with
               | None -> ()
               | Some f ->
                 output_string oc "  depfile = "; output_string oc f; output_string oc  "\n"
               end;
               output_string oc "  description = " ; output_string oc description; output_string oc "\n";
               used <- true
             end
           else ()
         method name oc  =
           self#print oc ;
           name  
       end
     (* # for ast building, we remove most flags with respect to -I  *)
     let build_ast =
       define
         ~command:"${bsc} ${pp_flags} ${ppx_flags} ${bsc_parsing_flags} -c -o ${out} -bs-syntax-only -bs-binary-ast ${in}"
        "build_ast" 
     let build_ast_from_reason_impl =
       define
         ~command:"${bsc} -pp refmt ${ppx_flags} ${bsc_parsing_flags} -c -o ${out} -bs-syntax-only -bs-binary-ast -impl ${in}"
         "build_ast_from_reason_impl"

     let build_ast_from_reason_intf =
       (* we have to do this way, 
          because it need to be ppxed by bucklescript
       *)
       define
         ~command:"${bsc} -pp refmt ${ppx_flags} ${bsc_parsing_flags} -c -o ${out} -bs-syntax-only -bs-binary-ast -intf ${in}"
         "build_ast_from_reason_intf"

     let build_deps =
       define
         ~command:"${bsdep} -bs-oprefix ${builddir}  -bs-MD ${in}"
         "build_deps"
     let reload =
       define
         ~command:"${bsbuild} -init"
         "reload"
     let copy_resources =
       define
         ~command:"cp ${in} ${out}"
         "copy_resources"

     (* only generate mll no mli generated *)
     (* actually we would prefer generators in source ?
        generator are divided into two categories:
        1. not system dependent (ocamllex,ocamlyacc)
        2. system dependent - has to be run on client's machine
     *)

     let build_ml_from_mll =
       define
         ~command:"${ocamllex} -o ${out} ${in}"
         "build_ml_from_mll"

     let build_cmj_only =
       define
         ~command:"${bsc} -bs-no-builtin-ppx-ml -bs-no-implicit-include ${bsc_computed_flags} -o ${in} -c -impl ${in}"
         
         ~depfile:"${in}.d"
         "build_cmj_only"

     let build_cmj_cmi =
       define
         ~command:"${bsc} -bs-assume-no-mli -bs-no-implicit-include -bs-no-builtin-ppx-ml ${bsc_computed_flags} -o ${in} -c -impl ${in}"
         ~depfile:"${in}.d"
         "build_cmj_cmi"
     let build_cmi =
       define
         ~command:"${bsc} -bs-no-builtin-ppx-mli -bs-no-implicit-include ${bsc_computed_flags} -o ${out} -c -intf ${in}"
         ~depfile:"${in}.d"
         "build_cmi"
end

let output_build ?(order_only_deps=[]) ?(implicit_deps=[]) ?(outputs=[]) ?(inputs=[]) ~output ~input  ~rule  oc =
  let rule = rule#name oc in
  output_string oc "build "; 
  output_string oc output ; 
  outputs |> List.iter (fun s -> output_string oc " " ; output_string oc s  );
  output_string oc " : ";
  output_string oc rule;
  output_string oc " ";
  output_string oc input;
  inputs |> List.iter (fun s ->   output_string oc " " ; output_string oc s);
  begin match implicit_deps with 
  | [] -> ()
  | _ -> 
    begin 
      output_string oc " | "; 
      implicit_deps 
      |> 
      List.iter (fun s -> output_string oc " "; output_string oc s )
    end
  end;
  begin match order_only_deps with
  | [] -> ()
  | _ ->
    begin
      output_string oc " || ";
      order_only_deps
      |>
      List.iter (fun s -> output_string oc " " ; output_string oc s)
    end
  end;
  output_string oc "\n"

let phony ?(order_only_deps=[]) ~inputs ~output oc =
  output_string oc "build "; 
  output_string oc output ; 
  output_string oc " : ";
  output_string oc "phony";
  output_string oc " ";
  inputs |> List.iter (fun s ->   output_string oc " " ; output_string oc s);
  begin match order_only_deps with
    | [] -> ()
    | _ ->
      begin
        output_string oc " || ";
        order_only_deps
        |>
        List.iter (fun s -> output_string oc " " ; output_string oc s)
      end
  end;
  output_string oc "\n"

let output_kv key value oc  =
  output_string oc key ; 
  output_string oc " = "; 
  output_string oc value ; 
  output_string oc "\n"

let output_kvs kvs oc = 
  List.iter (fun (k,v) -> output_kv k v oc) kvs 



let (//) = Ext_filename.combine

let handle_module_info builddir oc 
    ({mli; ml; mll } : Binary_cache.module_info) (all_deps, all_cmis) =  
  let emit_build (kind : [`Ml | `Mll | `Re | `Mli | `Rei ])  input  = 
    let filename_sans_extension = Filename.chop_extension input in
    let output_file_sans_extension = builddir // filename_sans_extension in
    let output_ml = output_file_sans_extension ^ Literals.suffix_ml in 
    let output_mlast = output_file_sans_extension  ^ Literals.suffix_mlast in 
    let output_mlastd = output_file_sans_extension ^ Literals.suffix_mlastd in
    let output_mliast = output_file_sans_extension ^ Literals.suffix_mliast in 
    let output_mliastd = output_file_sans_extension ^ Literals.suffix_mliastd in
    let output_cmi = output_file_sans_extension ^ Literals.suffix_cmi in 
    let output_cmj =  output_file_sans_extension ^ Literals.suffix_cmj in 
    if kind = `Mll then 
      output_build oc
        ~output:output_ml 
        ~input
        ~rule: Rules.build_ml_from_mll ;  
    begin match kind with
      | `Mll 
      | `Ml 
      | `Re ->
        let input, rule  = 
          if kind = `Re then 
            input, Rules.build_ast_from_reason_impl
          else if kind = `Mll then 
            output_ml, Rules.build_ast  
          else 
            input, Rules.build_ast  
        in 
        begin 
          output_build oc
            ~output:output_mlast ~input ~rule;
          output_build oc ~output:output_mlastd
            ~input:output_mlast
            ~rule:Rules.build_deps ;
          let rule_name , cm_outputs, deps = 
            if mli = Mli_empty then Rules.build_cmj_only, [  output_cmi]  , [] 
            else Rules.build_cmj_cmi, [], [output_cmi]  
          in  
          output_build oc ~output:output_cmj 
            ~outputs:cm_outputs ~input:output_mlast ~implicit_deps:deps ~rule:rule_name ;
          ([output_mlastd] , [output_cmi]);
        end
      | `Mli
      | `Rei -> 
        let rule = 
          if kind = `Mli then Rules.build_ast 
          else Rules.build_ast_from_reason_intf  in
        output_build oc 
          ~output:output_mliast
          ~input
          ~rule;
        output_build oc 
          ~output:output_mliastd
          ~input:output_mliast 
          ~rule:Rules.build_deps  ; 
        output_build oc 
          ~output:output_cmi 
          ~input:output_mliast 
          ~implicit_deps:[output_mliastd]
          ~rule:Rules.build_cmi;
        ([output_mliastd] ,
         [output_cmi]  )
    end 
  in
  let (++) (xs,ys) (us,vs) = (xs @ us, ys @ vs) in 
  let zero = ([],[]) in
  begin match ml with 
    | Ml input -> emit_build `Ml input
    | Re input -> emit_build `Re input 
    | Ml_empty -> zero
  end ++ 
  begin match mli with 
    | Mli mli_file  -> 
      emit_build `Mli mli_file
    | Rei rei_file -> 
      emit_build `Rei rei_file
    | Mli_empty -> zero 
  end ++
  begin match mll with 
    | Some mll_file -> 
      begin match ml with
        | Ml_empty -> emit_build `Mll mll_file
        | Ml input | Re input ->  
          failwith ("both "^ mll_file ^ " and " ^ input ^ " are found in source listings" )
      end
    | None -> zero
  end ++ (all_deps, all_cmis)
