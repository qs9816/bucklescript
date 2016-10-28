ifdef WIN32
	EXE := .exe
endif
ifndef EXE
	EXE := # empty
endif
NATIVE=ocamlopt.opt$(EXE)

OCAMLLEX=ocamllex.opt$(EXE)

CAMLP4OF=camlp4of
## native plugin was not installed in opam..

## Beging Rules only make sense in dev mode
core/js_map.ml:core/js_map.mlp core/j.ml
	@echo "Regenrating j_map.ml"
	$(CAMLP4OF) -I core -filter map -filter trash -impl $< -printer o -o  $@

core/js_fold.ml:core/js_fold.mlp core/j.ml
	@echo "Regenrating j_fold.ml"
	$(CAMLP4OF) -I core -filter Camlp4FoldGenerator  -filter trash -impl $< -printer o -o $@

core/sexp_lexer.ml: core/sexp_lexer.gen.mll
	@echo "Regenerating sexp_lexer.ml"
	$(OCAMLLEX) $< -o $@
core/bs_json.ml: core/bs_json.gen.mll
	@echo "Regenerating sexp_lexer.ml"
	$(OCAMLLEX) $< -o $@ || (rm $@ && exit 2)
clean:
	rm core/bs_json.ml core/sexp_lexer.ml core/js_fold.ml core/js_map.ml
	git clean -dfx ext common syntax depends core 







### list files 
EXT_OBJS = ext_array ext_bytes ext_char ext_file_pp ext_format ext_hashtbl ext_list ext_map ext_marshal ext_option \
	ext_pervasives ext_pp ext_ref ext_string ext_sys hash_set ident_set int_map literals string_map \
	string_set ext_pp_scope ext_io ext_ident ext_filename 


COMMON_OBJS= js_config ext_log bs_loc bs_exception bs_warnings lam_methname

SYNTAX_OBJS=ast_derive_constructor ast_derive_util ast_exp ast_external ast_lift ast_literal ast_pat ast_payload ast_signature ast_structure bs_ast_iterator bs_ast_invariant ast_derive ast_comb ast_attributes ast_core_type ast_derive_dyn ast_derive_projector ast_external_attributes ast_util ppx_entry 

DEPENDS_OBJS= binary_ast binary_cache ast_extract  

CORE_OBJS= type_int_to_string type_util ident_map ocaml_stdlib_slots ident_util idents_analysis bs_conditional_initial ocaml_options ocaml_parse lam\
	lam_iter lam_print lam_beta_reduce_util lam_inline_util lam_analysis js_cmj_format js_fun_env js_call_info js_closure js_op js_number js_cmj_datasets\
	lam_exit_code j lam_module_ident lam_compile_util lam_stats config_util lam_compile_defs js_map js_fold js_fold_basic js_pass_scope\
	js_op_util js_analyzer js_shake js_exp_make js_long js_of_lam_exception js_of_lam_module js_of_lam_array js_of_lam_block js_of_lam_string\
	js_of_lam_tuple js_of_lam_record js_of_lam_float_record js_arr lam_compile_const lam_util lam_group js_stmt_make js_pass_flatten\
	js_pass_tailcall_inline js_of_lam_variant js_pass_flatten_and_mark_dead js_ast_util lam_dce lam_compile_env lam_stats_util\
	lam_stats_export lam_pass_alpha_conversion lam_pass_collect js_program_loader js_dump js_pass_debug\
	js_of_lam_option js_output lam_compile_global lam_dispatch_primitive lam_beta_reduce\
	lam_compile_external_call lam_compile_primitive lam_compile lam_pass_exits\
	lam_pass_lets_dce lam_pass_remove_alias lam_compile_group\
	js_implementation ocaml_batch_compile 
# js_main


ext.cmxa:$(addprefix ext/, $(addsuffix .cmx, $(EXT_OBJS)))
	ocamlopt.opt -a $^ -o $@ 
common.cmxa:$(addprefix common/, $(addsuffix .cmx, $(COMMON_OBJS)))
	ocamlopt.opt -a $^ -o $@ 

syntax.cmxa:$(addprefix syntax/, $(addsuffix .cmx, $(SYNTAX_OBJS)))
	ocamlopt.opt -a $^ -o $@ 
depends.cmxa: $(addprefix depends/, $(addsuffix .cmx, $(DEPENDS_OBJS)))
	ocamlopt.opt -a $^ -o $@
core.cmxa: $(addprefix core/, $(addsuffix .cmx, $(CORE_OBJS)))
	ocamlopt.opt -a $^ -o $@

NATIVE=ocamlopt.opt
CAMLDEP=ocamldep.opt
COMPFLAGS= -g -w -40-30 -warn-error +a-40-30

# bin/bsc:  ext.cmxa common.cmxa  depends.cmxa syntax.cmxa core.cmxa
# 	$(NATIVE) -g -linkall -I +compiler-libs ocamlcommon.cmxa $^ -o $@

bin/bsc.exe: ext.cmxa common.cmxa syntax.cmxa depends.cmxa core.cmxa core/js_main.cmx
	@echo "Linking"
	$(NATIVE) -g -linkall -I +compiler-libs ocamlcommon.cmxa $^ -o $@

all-compiler: bin/bsc.exe core/bsppx_main.cmx core/bspack_main.cmx core/jsoo_main.cmx core/bspp_main.cmx core/js_generate_require.cmx core/js_pack.cmx core/js_cmi_datasets.cmx core/bs_dep_infos.cmx core/bs_dir.cmx  core/sexp_lexer.cmx bin/bsc.exe

.PHONY: all-compiler

.SUFFIXES: .mli .ml .cmi .cmx 

print-%  : ; @echo $* = $($*)

INCLUDES= -I +compiler-libs -I ext -I common -I syntax -I depends -I core

.mli.cmi:
	$(NATIVE) $(INCLUDES) $(COMPFLAGS) -c $<

.ml.cmx:
	$(NATIVE) $(INCLUDES) $(COMPFLAGS) -c $<

depend:
	$(CAMLDEP) -native -I ext -I common -I syntax -I depends -I core ext/*.ml ext/*.mli common/*.ml common/*.mli syntax/*.ml syntax/*.mli *.ml *.mli depends/*.ml depends/*.mli core/*.ml core/*.mli > all.depend

-include all.depend


# this target  is used to make snapshotml
./bin/bspack.exe: bin/config_bspack.mli bin/config_bspack.ml bin/bspack.mli bin/bspack.ml
	$(MAKE) -C bin bspack.exe
snapshot: ./bin/bspack.exe snapshotcmj
	$(MAKE) snapshotml


# TODO
# enhace for Parser module, we only care about Parser.token 
# files including Parsetree/Parser should be shaked 
snapshotml:./bin/bspack.exe bin/bsppx.ml bin/whole_compiler.ml bin/bsdep.ml bin/bsb.ml bin/bsb.ml bin/bspp.ml

bin/bsppx.ml:./bin/bspack.exe
	$< -bs-MD  -prelude-str 'module Config = Config_bsppx'  -bs-exclude-I config -I ../ocaml/utils/ -I ../ocaml/parsing/ -I common -I ext -I syntax -I core -bs-main Bsppx_main -o $@
include bin/bsppx.d

bin/whole_compiler.ml:./bin/bspack.exe 
	$< -bs-MD -prelude-str 'module Config = Config_whole_compiler' -bs-exclude-I config -o $@ -bs-main Js_main -I ../ocaml/utils/ -I ../ocaml/parsing/ -I ../ocaml/typing/ -I ../ocaml/bytecomp/ -I ../ocaml/driver/ -I ext -I syntax -I depends -I common -I core
include bin/whole_compiler.d

bin/bsdep.ml:./bin/bspack.exe 
	BS_OCAMLDEP=true $< -bs-MD  -prelude-str 'module Config = Config_bsdep'  -bs-exclude-I config -I ../ocaml/utils/ -I ../ocaml/parsing/ -I ../ocaml/driver -I ../ocaml/tools -I common -I ext -I syntax -I depends  -bs-main Ocamldep -o $@
include bin/bsdep.d

bin/bsb.ml:./bin/bspack.exe 
	$< -bs-MD -I common -I ext -I syntax -I depends -I core -bs-main Bsb_main -o bin/bsb.ml
include bin/bsb.d
bin/bspp.ml:./bin/bspack.exe 
	BS_MIN_LEX_DEPS=true $< -bs-MD   -bs-exclude-I config -I ../ocaml/utils/ -I ../ocaml/parsing?parser  -I common -I ext -I syntax -I depends -I bspp -I core -bs-main Bspp_main -o $@
include bin/bspack.d


snapshotcmj:
	@echo "Collecting cmj files"
	ocamlbuild -cflags $(OCAMLBUILD_CFLAGS)	 -lflags -I,+compiler-libs,ocamlcommon.cmxa js_pack.native --

# git diff bin/bspack.ml
# bootbspack requires ../ocaml has parser, lexer processed by ocamlyacc and ocamllex


# bootbspack should not depend on bspack.exe
# if so, `make bootbspack` will cause `bspack.exe` to be rebuilt
# which may already be wrong
bootbspack: 
	@echo "Bootstrap bspack.exe"
	./bin/bspack.exe -bs-MD -prelude-str 'module Config = Config_bspack '   -bs-exclude-I config  -I ../ocaml/parsing/ -I ../ocaml/utils/ -I ext -I common -I depends -I core -bs-main Bspack_main -o bin/bspack.ml
	$(NATIVE) -w -40  unix.cmxa  -I bin bin/config_bspack.mli bin/config_bspack.ml bin/bspack.mli bin/bspack.ml -o bin/bspack.exe
	@echo "Using the bootstrapped bspack.exe to genreate new bspack.ml: `date`"
	./bin/bspack.exe -bs-MD  -prelude-str  'module Config = Config_bspack'   -bs-exclude-I config  -I ../ocaml/parsing/ -I ../ocaml/utils/ -I ext -I common -I depends -I core -bs-main Bspack_main -o bin/bspack.ml
	@echo "Bootstrap seems finished, please check diffs in bspack.exe"
	@echo "Rebuilding bspack.exe"
	make -C bin -B bspack.exe
	@echo "Rebuilding bspack.exe finsihed"

libs:
	@echo "Making stdlib cmis"
	cd stdlib && $(MAKE) allcmis
	@echo "Making stdlib finished"

	@echo "Making runtime"
	cd runtime && $(MAKE) all
	@echo "Making runtime finished"


	@echo "Making stdlib"
	cd stdlib && $(MAKE) all
	@echo "Making stdlib finished"

	@echo "Making others"
	cd others && $(MAKE) all
	@echo "Making others finished"

releasebuild:
	@echo "Make release compiler"
	$(MAKE) -C bin all 

release:snapshot
	$(MAKE) releasebuild


world:
	@echo "Making compiler"
	$(MAKE) -C bin -j 6 all
	@echo "Making compiler finished"
	$(MAKE) libs


travis-world-test:
	$(MAKE) -C bin bspack.exe
	@echo "Generating the compiler"
	rm -f bin/compiler.ml bin/bsppx.ml
	$(MAKE) snapshotml
	@echo "Generating the compiler finished"
	$(MAKE) world
	@echo "Making test"
	cd test && $(MAKE) all
	@echo "Making test finsihed"


DEST=../lib/ocaml
DEST_BIN=../bin
install:
	@echo "copy exe"
	mkdir -p $(DEST_BIN) $(DEST)
	cp  ./bin/bsc.exe ./bin/bsppx.exe  ./bin/bspack.exe ./bin/bsdep.exe ./bin/bspp.exe ./bin/bsb  $(DEST_BIN)
	@echo "copy stdlib"
	cp ./runtime/*.cmt* ./runtime/*.cmj* ./stdlib/*.cm* ./others/*.ml ./others/*.mli  ./others/*.cm* \
	 ./runtime/js.ml  ./runtime/js.cmi ./runtime/js_unsafe.cmi ./runtime/js_null.ml ./runtime/js_null.cmi \
	./runtime/js_undefined.ml ./runtime/js_undefined.cmi   $(DEST)
# ./runtime/js_null_undefined.ml ./runtime/js_null_undefined.cmi


.PHONY: test  quicktest release snapshot snapshotcmj releasebuild libs snapshot1 snapshot2 snapshot3 snapshot4 snapshot5 snapshot6
