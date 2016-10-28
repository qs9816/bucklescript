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








module E = Js_exp_make
module S = Js_stmt_make



(** Design guides:
    1. We don't want to force user to have 
       [-bs-package-name] and [-bs-package-output] set

       [bsc.exe -c hello.ml] should just work 
       by producing a [hello.js] file in the same directory

    Some designs due to legacy reasons that we don't have all runtime
    written in OCaml, so it might only have js files (no cmjs) for Runtime kind
    {[
      begin match Config_util.find file with   
        (* maybe from third party library*)
        (* Check: be consistent when generating js files
           A.ml -> a.js
           a.ml -> a.js
           check generated [js] file if it's capital or not
           Actually, we can not tell its original name just from [id], 
           so we just always general litte_case.js
        *)
        | file ->
          rebase (`File file)
        (* for some primitive files, no cmj support *)
        | exception Not_found ->
          Ext_pervasives.failwithf ~loc:__LOC__ 
            "@[%s not found in search path - while compiling %s @] "
            file !Location.input_name 
      end

    ]}

*)

let (//) = Filename.concat 

let string_of_module_id ~output_prefix
    (module_system : Lam_module_ident.system)
    (x : Lam_module_ident.t) : string =
#if BS_COMPILER_IN_BROWSER then   
    match x.kind with
    | Runtime | Ml -> 
      "stdlib" // String.uncapitalize x.id.name
    | External name -> name
#else
    let result = 
      match x.kind  with 
      | Runtime  
      | Ml  -> 
        let id = x.id in
        let file = Printf.sprintf "%s.js" id.name in
        let modulename = String.uncapitalize id.name in
        let current_unit_dir =
          `Dir (Js_config.get_output_dir module_system output_prefix) in
        let rebase dep =
          Ext_filename.node_relative_path  current_unit_dir dep 
        in 
        let dependency_pkg_info = 
          Lam_compile_env.get_package_path_from_cmj module_system x 
        in
        let current_pkg_info = 
          Js_config.get_current_package_name_and_path module_system  
        in
        begin match module_system,  dependency_pkg_info, current_pkg_info with
          | _, `NotFound , _ -> 
            Ext_pervasives.failwithf ~loc:__LOC__ 
              " @[%s not found in search path - while compiling %s @] "
              file !Location.input_name 
          | `Goog , `Found (package_name, x), _  -> 
            package_name  ^ "." ^  String.uncapitalize id.name
          | `Goog, (`Empty | `Package_script _), _ 
            -> 
            Ext_pervasives.failwithf ~loc:__LOC__ 
              " @[%s was not compiled with goog support  in search path - while compiling %s @] "
              file !Location.input_name 
          | (`AmdJS | `NodeJS),
            ( `Empty | `Package_script _) ,
            `Found _  -> 
            Ext_pervasives.failwithf ~loc:__LOC__
              "@[dependency %s was compiled in script mode - while compiling %s in package mode @]"
              file !Location.input_name
          | _ , _, `NotFound -> assert false 
          | (`AmdJS | `NodeJS), 
            `Found(package_name, x),
            `Found(current_package, path) -> 
            if  current_package = package_name then 
              rebase (`File (
                  Lazy.force Ext_filename.package_dir // x // modulename)) 
            else 
              package_name // x // modulename
          | (`AmdJS | `NodeJS), `Found(package_name, x), 
            `Package_script(current_package)
            ->    
            if current_package = package_name then 
              rebase (`File (
                  Lazy.force Ext_filename.package_dir // x // modulename)) 
            else 
              package_name // x // modulename
          | (`AmdJS | `NodeJS), `Found(package_name, x), `Empty 
            ->    package_name // x // modulename
          |  (`AmdJS | `NodeJS), 
             (`Empty | `Package_script _) , 
             (`Empty  | `Package_script _)
            -> 
            begin match Config_util.find file with 
              | file -> 
                rebase (`File file) 
              | exception Not_found -> 
                Ext_pervasives.failwithf ~loc:__LOC__ 
                  "@[%s was not found  in search path - while compiling %s @] "
                  file !Location.input_name 
            end
        end
      | External name -> name in 
    if Js_config.is_windows then Ext_filename.replace_backward_slash result 
    else result 
#end


(* support es6 modules instead
   TODO: enrich ast to support import export 
   http://www.ecma-international.org/ecma-262/6.0/#sec-imports
   For every module, we need [Ident.t] for accessing and [filename] for import, 
   they are not necessarily the same.

   Es6 modules is not the same with commonjs, we use commonjs currently
   (play better with node)

   FIXME: the module order matters?
*)

let make_program name  export_idents block : J.program = 

  {
    name;

    exports = export_idents ; 
    export_set = Ident_set.of_list export_idents;
    block = block;

  }
let decorate_deps modules side_effect program : J.deps_program = 

  { program ; modules ; side_effect }

