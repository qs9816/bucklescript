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

type module_name = private string

module String_set = Depend.StringSet

type _ kind =
  | Ml_kind : Parsetree.structure kind
  | Mli_kind : Parsetree.signature kind
        
let read_parse_and_extract (type t) (k : t kind) (ast : t) : String_set.t =
  Depend.free_structure_names := String_set.empty;
  let bound_vars = String_set.empty in
  List.iter
    (fun modname  ->
       Depend.open_module bound_vars (Longident.Lident modname))
    (!Clflags.open_modules);
  (match k with
   | Ml_kind  -> Depend.add_implementation bound_vars ast
   | Mli_kind  -> Depend.add_signature bound_vars ast  ); 
  !Depend.free_structure_names


type ('a,'b) ast_info =
  | Ml of
      string * (* sourcefile *)
      'a *
      string (* opref *)      
  | Mli of string * (* sourcefile *)
           'b *
           string (* opref *)
  | Ml_mli of
      string * (* sourcefile *)
      'a *
      string  * (* opref1 *)
      string * (* sourcefile *)      
      'b *
      string (* opref2*)

type ('a,'b) t =
  { module_name : string ; ast_info : ('a,'b) ast_info }


(* only visit nodes that are currently in the domain *)
(* https://en.wikipedia.org/wiki/Topological_sorting *)
(* dfs   *)
let sort_files_by_dependencies ~domain dependency_graph =
  let next current =
    (String_map.find  current dependency_graph) in    
  let worklist = ref domain in
  let result = Queue.create () in
  let rec visit visiting path current =
    if String_set.mem current visiting then
      Bs_exception.error (Bs_cyclic_depends (current::path))
    else if String_set.mem current !worklist then
      begin
        next current |>        
        String_set.iter
          (fun node ->
             if  String_map.mem node  dependency_graph then
               visit (String_set.add current visiting) (current::path) node)
        ;
        worklist := String_set.remove  current !worklist;
        Queue.push current result ;
      end in        
  while not (String_set.is_empty !worklist) do 
    visit String_set.empty []  (String_set.choose !worklist)
  done;
  if Js_config.get_diagnose () then
    Format.fprintf Format.err_formatter
      "Order: @[%a@]@."    
      (Ext_format.pp_print_queue
         ~pp_sep:Format.pp_print_space
         Format.pp_print_string)
      result ;       
  result
;;



let sort  project_ml project_mli (ast_table : _ t String_map.t) = 
  let domain =
    String_map.fold
      (fun k _ acc -> String_set.add k acc)
      ast_table String_set.empty in
  let h =
    String_map.map
      (fun
        ({ast_info})
        ->
          match ast_info with
          | Ml (_, ast,  _)
            ->
            read_parse_and_extract Ml_kind (project_ml ast)            
          | Mli (_, ast, _)
            ->
            read_parse_and_extract Mli_kind (project_mli ast)
          | Ml_mli (_, impl, _, _, intf, _)
            ->
            String_set.union
              (read_parse_and_extract Ml_kind (project_ml impl))
              (read_parse_and_extract Mli_kind (project_mli intf))              
      ) ast_table in    
  sort_files_by_dependencies  domain h

(** same as {!Ocaml_parse.check_suffix} but does not care with [-c -o] option*)
let check_suffix  name  = 
  if Filename.check_suffix name ".ml"
  || Filename.check_suffix name ".mlt" then 
    `Ml,
    Ext_filename.chop_extension_if_any  name 
  else if Filename.check_suffix name !Config.interface_suffix then 
    `Mli,   Ext_filename.chop_extension_if_any  name 
  else 
    raise(Arg.Bad("don't know what to do with " ^ name))


let collect_ast_map ppf files parse_implementation parse_interface  =
  List.fold_left
    (fun (acc : _ t String_map.t)
      source_file ->
      match check_suffix source_file with
      | `Ml, opref ->
        let module_name = Ext_filename.module_name_of_file source_file in
        begin match String_map.find module_name acc with
          | exception Not_found ->
            String_map.add module_name
              {ast_info =
                 (Ml (source_file, parse_implementation
                        ppf source_file, opref));
               module_name ;
              } acc
          | {ast_info = (Ml (source_file2, _, _)
                        | Ml_mli(source_file2, _, _,_,_,_))} ->
            Bs_exception.error
              (Bs_duplicated_module (source_file, source_file2))
          | {ast_info =  Mli (source_file2, intf, opref2)}
            ->
            String_map.add module_name
              {ast_info =
                 Ml_mli (source_file,
                         parse_implementation ppf source_file,
                         opref,
                         source_file2,
                         intf,
                         opref2
                        );
               module_name} acc
        end
      | `Mli, opref ->
        let module_name = Ext_filename.module_name_of_file source_file in
        begin match String_map.find module_name acc with
          | exception Not_found ->
            String_map.add module_name
              {ast_info = (Mli (source_file, parse_interface
                                              ppf source_file, opref));
               module_name } acc
          | {ast_info =
               (Mli (source_file2, _, _) |
                Ml_mli(_,_,_,source_file2,_,_)) } ->
            Bs_exception.error
              (Bs_duplicated_module (source_file, source_file2))
          | {ast_info = Ml (source_file2, impl, opref2)}
            ->
            String_map.add module_name
              {ast_info =
                 Ml_mli
                   (source_file2,
                    impl,
                    opref2,
                    source_file,
                    parse_interface ppf source_file,
                    opref
                   );
               module_name} acc
        end
    ) String_map.empty files



let collect_from_main 
    ?(extra_dirs=[])
    ?(excludes=[])
    (ppf : Format.formatter)
    parse_implementation
    parse_interface
    project_impl 
    project_intf 
    main_module =
  let files = 
    List.fold_left (fun acc dir_spec -> 
        let  dirname, excludes = 
          match dir_spec with 
          | `Dir dirname -> dirname, excludes
          | `Dir_with_excludes (dirname, dir_excludes) ->
            dirname,
            Ext_list.flat_map 
              (fun x -> [x ^ ".ml" ; x ^ ".mli" ])
              dir_excludes @ excludes
        in 
        Array.fold_left (fun acc source_file -> 
            if (Ext_string.ends_with source_file ".ml" ||
               Ext_string.ends_with source_file ".mli" )
               && (* not_excluded source_file *) (not (List.mem source_file excludes))
            then 
              (Filename.concat dirname source_file) :: acc else acc
          ) acc (Sys.readdir dirname))
      [] extra_dirs in
  let ast_table = collect_ast_map ppf files parse_implementation parse_interface in 
  let visited = Hashtbl.create 31 in
  let result = Queue.create () in  
  let next module_name =
    match String_map.find module_name ast_table with
    | exception _ -> String_set.empty
    | {ast_info = Ml (_,  impl, _)} ->
      read_parse_and_extract Ml_kind (project_impl impl)
    | {ast_info = Mli (_,  intf,_)} ->
      read_parse_and_extract Mli_kind (project_intf intf)
    | {ast_info = Ml_mli(_, impl, _, _,  intf, _)}
      -> 
      String_set.union
        (read_parse_and_extract Ml_kind (project_impl impl))
        (read_parse_and_extract Mli_kind (project_intf intf))
  in
  let rec visit visiting path current =
    if String_set.mem current visiting  then
      Bs_exception.error (Bs_cyclic_depends (current::path))
    else
    if not (Hashtbl.mem visited current)
    && String_map.mem current ast_table then
      begin
        String_set.iter
          (visit
             (String_set.add current visiting)
             (current::path))
          (next current) ;
        Queue.push current result;
        Hashtbl.add visited current ();
      end in
  visit (String_set.empty) [] main_module ;
  ast_table, result   


let build_queue ppf queue
    (ast_table : _ t String_map.t)
    after_parsing_impl
    after_parsing_sig    
  =
  queue
  |> Queue.iter
    (fun modname -> 
      match String_map.find modname ast_table  with
      | {ast_info = Ml(source_file,ast, opref)}
        -> 
        after_parsing_impl ppf source_file 
          opref ast 
      | {ast_info = Mli (source_file,ast,opref) ; }  
        ->
        after_parsing_sig ppf source_file 
          opref ast 
      | {ast_info = Ml_mli(source_file1,impl,opref1,source_file2,intf,opref2)}
        -> 
        after_parsing_sig ppf source_file1 opref1 intf ;
        after_parsing_impl ppf source_file2 opref2 impl
      | exception Not_found -> assert false 
    )


let handle_queue ppf queue ast_table decorate_module_only decorate_interface_only decorate_module = 
  queue 
  |> Queue.iter
    (fun base ->
       match (String_map.find  base ast_table).ast_info with
       | exception Not_found -> assert false
       | Ml (ml_name,  ml_content, _)
         ->
         decorate_module_only  base ml_name ml_content
       | Mli (mli_name , mli_content, _) ->
         decorate_interface_only base  mli_name mli_content
       | Ml_mli (ml_name, ml_content, _, mli_name,   mli_content, _)
         ->
         decorate_module  base mli_name ml_name mli_content ml_content

    )



let build_lazy_queue ppf queue (ast_table : _ t String_map.t)
    after_parsing_impl
    after_parsing_sig    
  =
  queue |> Queue.iter (fun modname -> 
      match String_map.find modname ast_table  with
      | {ast_info = Ml(source_file,lazy ast, opref)}
        -> 
        after_parsing_impl ppf source_file opref ast 
      | {ast_info = Mli (source_file,lazy ast,opref) ; }  
        ->
        after_parsing_sig ppf source_file opref ast 
      | {ast_info = Ml_mli(source_file1,lazy impl,opref1,source_file2,lazy intf,opref2)}
        -> 
        after_parsing_sig ppf source_file1 opref1 intf ;
        after_parsing_impl ppf source_file2 opref2 impl
      | exception Not_found -> assert false 
    )


let dep_lit = " :"
let space = " "
let (//) = Filename.concat
let length_space = String.length space 
let handle_depfile oprefix  (fn : string) : unit = 
  let op_concat s = match oprefix with None -> s | Some v -> v // s in 
  let data =
    Binary_cache.read_build_cache (op_concat  Binary_cache.bsbuild_cache) in 
  let deps = 
    match Ext_string.ends_with_then_chop fn Literals.suffix_mlast with 
    | Some  input_file -> 
      let stru  = Binary_ast.read_ast Ml  fn in 
      let set = read_parse_and_extract Ml_kind stru in 
      let dependent_file = (input_file ^ Literals.suffix_cmj) ^ dep_lit in
      let (files, len) = 
      String_set.fold
        (fun k ((acc, len) as v) -> 
           match String_map.find k data with
           | {ml = Ml s | Re s  } 
           | {mll = Some s } 
             -> 
             let new_file = op_concat @@ Filename.chop_extension s ^ Literals.suffix_cmj  
             in (new_file :: acc , len + String.length new_file + length_space)
           | {mli = Mli s | Rei s } -> 
             let new_file =  op_concat @@   Filename.chop_extension s ^ Literals.suffix_cmi in
             (new_file :: acc , len + String.length new_file + length_space)
           | _ -> assert false
           | exception Not_found -> v
        ) set ([],String.length dependent_file)in
      Ext_string.unsafe_concat_with_length len
        space
        (dependent_file :: files)
    | None -> 
      begin match Ext_string.ends_with_then_chop fn Literals.suffix_mliast with 
      | Some input_file -> 
        let stri = Binary_ast.read_ast Mli  fn in 
        let s = read_parse_and_extract Mli_kind stri in 
        let dependent_file = (input_file ^ Literals.suffix_cmi) ^ dep_lit in
        let (files, len) = 
          String_set.fold
            (fun k ((acc, len) as v) ->
               match String_map.find k data with 
               | { ml = Ml f | Re f  }
               | { mll = Some f }
               | { mli = Mli f | Rei f } -> 
                 let new_file = (op_concat @@ Filename.chop_extension f ^ Literals.suffix_cmi) in
                 (new_file :: acc , len + String.length new_file + length_space)
               | _ -> assert false
               | exception Not_found -> v
            ) s  ([], String.length dependent_file) in 
        Ext_string.unsafe_concat_with_length len
          space 
          (dependent_file :: files) 
      | None -> 
        raise (Arg.Bad ("don't know what to do with  " ^ fn))
      end
  in 
  let output = fn ^ Literals.suffix_d in
  Ext_pervasives.with_file_as_chan output  (fun v -> output_string v deps)
