EXT_OBJS = ext_array ext_bytes ext_char ext_file_pp ext_format ext_hashtbl ext_list ext_map ext_marshal ext_option ext_pervasives ext_pp ext_ref ext_string ext_sys hash_set ident_set int_map literals string_map string_set ext_pp_scope ext_io ext_ident ext_filename 

ext.cmxa:$(addprefix ext/, $(addsuffix .cmx, $(EXT_OBJS)))
	ocamlopt.opt -a $^ -o $@ 

COMMON_OBJS= js_config ext_log bs_loc bs_exception bs_warnings lam_methname

common.cmxa:$(addprefix common/, $(addsuffix .cmx, $(COMMON_OBJS)))
	ocamlopt.opt -a $^ -o $@ 

SYNTAX_OBJS=ast_derive_constructor ast_derive_util ast_exp ast_external ast_lift ast_literal ast_pat ast_payload ast_signature ast_structure bs_ast_iterator bs_ast_invariant ast_derive ast_comb ast_attributes ast_core_type ast_derive_dyn ast_derive_projector ast_external_attributes ast_util ppx_entry 
syntax.cmxa:$(addprefix syntax/, $(addsuffix .cmx, $(SYNTAX_OBJS)))
	ocamlopt.opt -a $^ -o $@ 

CORE_OBJS= type_int_to_string\
type_util\
ident_map\
ocaml_stdlib_slots\
ident_util\
idents_analysis\
bs_conditional_initial\
ocaml_options\
ocaml_parse\
lam\
lam_iter\
lam_print\
lam_beta_reduce_util\
lam_inline_util\
lam_analysis\
js_cmj_format\
js_fun_env\
js_call_info\
js_closure\
js_op\
js_number\
js_cmj_datasets\
lam_exit_code\
j\
lam_module_ident\
lam_compile_util\
lam_stats\
config_util\
lam_compile_defs\
js_map\
js_fold\
js_fold_basic\
js_pass_scope\
js_op_util\
js_analyzer\
js_shake\
js_exp_make\
js_long\
js_of_lam_exception\
js_of_lam_module\
js_of_lam_array\
js_of_lam_block\
js_of_lam_string\
js_of_lam_tuple\
js_of_lam_record\
js_of_lam_float_record\
js_arr\
lam_compile_const\
lam_util\
lam_group\
js_stmt_make\
js_pass_flatten\
js_pass_tailcall_inline\
js_of_lam_variant\
js_pass_flatten_and_mark_dead\
js_ast_util\
lam_dce\
lam_compile_env\
lam_stats_util\
lam_stats_export\
lam_pass_alpha_conversion\
lam_pass_collect\
js_program_loader\
js_dump\
js_pass_debug\
js_of_lam_option\
js_output\
lam_compile_global\
lam_dispatch_primitive\
lam_beta_reduce\
lam_compile_external_call\
lam_compile_primitive\
lam_compile\
lam_pass_exits\
lam_pass_lets_dce\
lam_pass_remove_alias\
lam_compile_group\
js_implementation\
ocaml_batch_compile\
js_main

core.cmxa: $(addsuffix .cmx, $(CORE_OBJS))
	ocamlopt.opt -a $^ -o $@

DEPENDS_OBJS= binary_ast binary_cache ast_extract  

depends.cmxa: $(addprefix depends/, $(addsuffix .cmx, $(DEPENDS_OBJS)))
	ocamlopt.opt -a $^ -o $@

SUBDIR=common

CAMLC=ocamlopt.opt
CAMLDEP=ocamldep.opt
COMPFLAGS= -w -40

bsx:  ext.cmxa common.cmxa  depends.cmxa syntax.cmxa core.cmxa
	$(CAMLC) -g -linkall -I +compiler-libs ocamlcommon.cmxa $^ -o $@

bsxx: $(addprefix ext/, $(addsuffix .cmx, $(EXT_OBJS))) $(addprefix common/, $(addsuffix .cmx, $(COMMON_OBJS))) $(addprefix depends/, $(addsuffix .cmx, $(DEPENDS_OBJS))) $(addprefix syntax/, $(addsuffix .cmx, $(SYNTAX_OBJS))) $(addsuffix .cmx, $(CORE_OBJS))
	$(CAMLC) -g -linkall -I +compiler-libs ocamlcommon.cmxa $^ -o $@

all: $(OBJS)

.SUFFIXES: .mli .ml .cmi .cmo .cmx .p.cmx .cmj .js

INCLUDES= -I +compiler-libs -I ext -I common -I syntax -I depends

.mli.cmi:
	$(CAMLC) $(INCLUDES) $(COMPFLAGS) -c $<

.ml.cmx:
	$(CAMLC) $(INCLUDES) $(COMPFLAGS) -c $<

depend:
	$(CAMLDEP) -native -I ext -I common -I syntax -I depends ext/*.ml ext/*.mli common/*.ml common/*.mli syntax/*.ml syntax/*.mli *.ml *.mli depends/*.ml depends/*.mli common/*.ml common/*.mli > all.depend

-include all.depend

clean:
	git clean -dfx common

.phony: all_ext

