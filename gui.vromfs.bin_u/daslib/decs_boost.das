options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options no_aot
options multiple_contexts

module decs_boost shared private

require daslib/decs public

require daslib/ast_boost
require daslib/templates_boost
require daslib/strings_boost
require daslib/ast_block_to_loop

require daslib/decs_state

/*
from:
    query ( ) <| $ ( pos:float3&; vel:float3; col:uint=0x12345678 )
        pos += vel
to:
    for_each_archetype ( ERQ_HASH, @@ => [[EcsRequest req <- [[string "pos"; "vel"]] ]] ) <| $ ( arch )
        for pos, vel in get(arch,"pos",type<float3>), get_ro(arch,"vel",type<float3>), get_default_ro(arch,"col",0x12345678)
            tag
*/

[block_macro(name="REQUIRE")]
class DecsReq : AstFunctionAnnotation {}

[block_macro(name="REQUIRE_NOT")]
class DecsReqN : AstFunctionAnnotation {}

[structure_macro(name="decs_template")]
class DecsTemplate : AstStructureAnnotation
    def override apply ( var st:StructurePtr; var group:ModuleGroup; args:AnnotationArgumentList; var errors : das_string ) : bool
        if length(st.fields)==0
            errors := "expecting at least one field in the desc_template {st.name}"
            return false
        let ppref = decs_prefix(args)
        let prefix = (ppref is yes) ? (ppref as yes) : "{st.name}_"
        var fnApply <- new [[Function() at=st.at, atDecl=st.at, name:="apply_decs_template"]]
        fnApply.flags |= FunctionFlags generated
        fnApply.result <- new [[TypeDecl() baseType=Type tVoid, at=st.at]]
        fnApply.arguments |> emplace_new <| new [[Variable() at=st.at,
            name := "cmp",
            _type <- clone_type() <| typeinfo(ast_typedecl type<ComponentMap>)
        ]]
        fnApply.arguments |> emplace_new <| new [[Variable() at=st.at,
            name := "src",
            _type <- new [[TypeDecl() at=st.at,
                baseType=Type tStructure,
                structType = get_ptr(st)
            ]]
        ]]
        var fnErase <- new [[Function() at=st.at, atDecl=st.at, name:="remove_decs_template`{st.name}"]]
        fnErase.flags |= FunctionFlags generated
        fnErase.result <- new [[TypeDecl() baseType=Type tVoid, at=st.at]]
        fnErase.arguments |> emplace_new <| new [[Variable() at=st.at,
            name := "cmp",
            _type <- clone_type() <| typeinfo(ast_typedecl type<ComponentMap>)
        ]]

        var blkApply <- new [[ExprBlock() at=st.at]]
        var blkErase <- new [[ExprBlock() at=st.at]]
        for fld in st.fields
            var cset <- new [[ExprCall() at=fld.at, name:="decs::set"]]
            cset.arguments |> emplace_new <| new [[ExprVar() at=fld.at, name:="cmp"]]
            cset.arguments |> emplace_new <| new [[ExprConstString() at=fld.at, value:="{prefix}{fld.name}"]]
            cset.arguments |> emplace_new <| new [[ExprField() at=fld.at,
                    value <- new [[ExprVar() at=fld.at, name:="src"]],
                    name := fld.name
                ]]
            blkApply.list |> emplace(cset)
            var cremove <- new [[ExprCall() at=fld.at, name:="decs::remove"]]
            cremove.arguments |> emplace_new <| new [[ExprVar() at=fld.at, name:="cmp"]]
            cremove.arguments |> emplace_new <| new [[ExprConstString() at=fld.at, value:="{prefix}{fld.name}"]]
            blkErase.list |> emplace(cremove)
        fnApply.body <- blkApply
        fnErase.body <- blkErase
        if !(compiling_module() |> add_function(fnApply))
            panic("failed to add apply_decs_template, can't add function {fnApply.name}")
        if !(compiling_module() |> add_function(fnErase))
            panic("failed to add remove_decs_template, can't add function {fnErase.name}")
        return true

variant ItCheck
    yes : string
    no  : bool

[macro_function]
def private decs_prefix ( arg:AnnotationArgumentList )
    var p = find_arg ( "prefix", arg)
    if p is tString
        return [[ItCheck yes=p as tString]]
    elif p is tBool
        return [[ItCheck yes=""]]
    else
        return [[ItCheck no=true]]

[macro_function]
def private is_decs_template ( v:VariablePtr )
    if v._type.baseType != Type tStructure
        return [[ItCheck no=true]]
    var p = v.annotation |> decs_prefix
    if p is no
        for ann in v._type.structType.annotations
            if ann.annotation.name=="decs_template"
                p = ann.arguments |> decs_prefix
                return p is yes ? p : [[ItCheck yes="{v._type.structType.name}_"]]
    return p

[macro_function]
def build_req_from_args ( qblk:ExprBlock? )
    var req : EcsRequest
    for a in qblk.arguments
        if a.init==null
            let detp = a |> is_decs_template
            if detp is yes
                for f in a._type.structType.fields
                    req.req |> push("{detp as yes}{f.name}")
            else
                if !(find_arg("optional",a.annotation) ?as tBool ?? false)
                    req.req |> push(string(a.name))
    for aa in qblk.annotations
        let isreq = aa.annotation.name=="REQUIRE"
        let isreqn = aa.annotation.name=="REQUIRE_NOT"
        if isreq || isreqn
            for ab in aa.arguments
                if ab.basicType==Type tBool && ab.bValue
                    (isreq ? req.req : req.reqn) |> push(string(ab.name))
    compile_request(req)
    return <- req

[macro_function]
def getter_name ( a; const_parent:bool; can_be_optional:bool )
    var getter = "get_ro"
    static_if typeinfo(stripped_typename a)=="ast::FieldDeclaration"        // part of the desc_template
        if a.init != null && can_be_optional
            getter = "get_default_ro"
        elif !const_parent
            getter = "get"
    else
        if find_arg("optional",a.annotation) ?as tBool ?? false
            if a.init != null
                macro_error(compiling_program(),a.at,"optional argument {a.name} can't have a default value")
                return ""
            elif !a._type.isPointer
                macro_error(compiling_program(),a.at,"optional argument {a.name} must be a pointer")
                return ""
            getter = "get_optional"
        elif a.init != null && can_be_optional
            if a._type.flags.ref || !a._type.flags.constant
                macro_error(compiling_program(),a.at,"argument {a.name} has default value, it can't be & or var")
                return ""
            getter = "get_default_ro"
        elif (a._type.isRef && !a._type.isRefType)
            if a._type.flags.constant
                macro_error(compiling_program(),a.at,"argument {a.name} is both & and constant")
                return ""
            getter = "get"
        elif a._type.isRefType && !a._type.flags.constant
            getter = "get"
    return getter

[macro_function]
def private append_iterator ( arch_name:string; var qloop:smart_ptr<ExprFor>; a; prefix,suffix:string; const_parent : bool = false; can_be_optional : bool = true )
    let qli = length(qloop.iterators)
    qloop.iterators |> resize( qli + 1 )
    qloop.iterators[qli] := "{prefix}{a.name}{suffix}"
    qloop.iteratorsAka |> resize( qli + 1 )
    if typeinfo(has_field<_aka> a)
        qloop.iteratorsAka[qli] := a._aka
    else
        qloop.iteratorsAka[qli] := ""
    qloop.iteratorsAt |> push(a.at)
    var ftype <- clone_type(a._type)
    ftype.flags &= ~ TypeDeclFlags constant
    ftype.flags &= ~ TypeDeclFlags ref
    var getter = getter_name(a,const_parent,can_be_optional)
    if empty(getter)
        return false
    var cget <- new [[ExprCall() name:=getter, at=a.at]]
    cget.arguments |> emplace_new <| new [[ExprVar() at=a.at, name:=arch_name]]
    cget.arguments |> emplace_new <| new [[ExprConstString() at=a.at, value:="{prefix}{a.name}"]]
    if getter=="get_default_ro"
        cget.arguments |> emplace_new <| clone_expression(a.init)
    else
        cget.arguments |> emplace_new <| new [[ExprTypeDecl() at=a.at, typeexpr<-ftype]]
    qloop.sources |> emplace(cget)
    return true

[macro_function]
def private append_index_lookup ( arch_name:string; var qblock:smart_ptr<ExprBlock>; a; prefix, suffix:string; const_parent : bool = false; can_be_optional : bool = true )
    var ftype <- clone_type(a._type)
    ftype.flags &= ~ TypeDeclFlags constant
    ftype.flags &= ~ TypeDeclFlags ref
    var getter = getter_name(a,const_parent,can_be_optional)
    if empty(getter)
        return false
    var iget : ExpressionPtr
    if getter=="get_default_ro"
        unsafe
            iget <- clone_expression(a.init)
    else
        var cget <- new [[ExprCall() name:=getter, at=a.at]]
        cget.arguments |> emplace_new <| new [[ExprVar() at=a.at, name:=arch_name]]
        cget.arguments |> emplace_new <| new [[ExprConstString() at=a.at, value:="{prefix}{a.name}"]]
        cget.arguments |> emplace_new <| new [[ExprTypeDecl() at=a.at, typeexpr<-ftype]]
        iget <- new [[ExprAt() at=a.at,
                subexpr <- cget,
                index <- new [[ExprVar() at=a.at, name:="entity_index"]]
            ]]
    var vlet <- new [[ExprLet() at=a.at, atInit=a.at]]
    vlet.genFlags |= ExprGenFlags alwaysSafe
    var vtype <- clone_type(a._type)
    if getter=="get_default_ro"
        vtype.flags |= TypeDeclFlags constant
    elif getter=="get_ro"
        vtype.flags |= TypeDeclFlags constant
        vtype.flags |= TypeDeclFlags ref
    else
        vtype.flags |= TypeDeclFlags ref

    vlet.variables |> emplace_new() <| new [[Variable() at = a.at,
        name := "{prefix}{a.name}{suffix}",
        _type <- vtype,
        init <- iget,
        flags = VariableFlags can_shadow
        ]]
    qblock.list |> emplace(vlet)
    return true

enum private DecsQueryType
    query
    eid_query
    find_query

[call_macro(name="query")]
class DecsQueryMacro : AstCallMacro
    def override preVisit ( prog:ProgramPtr; mod:Module?; var expr:smart_ptr<ExprCallMacro> ) : void
        let totalArgs = length(expr.arguments)
        if totalArgs!=1 && totalArgs!=2
            return
        let qt = totalArgs==2 ? DecsQueryType eid_query : DecsQueryType query
        let block_arg_index = totalArgs-1
        if !(expr.arguments[block_arg_index] is ExprMakeBlock)
            return
        var mblk = expr.arguments[block_arg_index] as ExprMakeBlock
        var qblk = mblk._block as ExprBlock
        for arg in qblk.arguments
            if arg._type != null
                if !arg._type.flags.constant
                    arg._type.flags |= TypeDeclFlags ref
    def override visit ( prog:ProgramPtr; mod:Module?; var expr:smart_ptr<ExprCallMacro> ) : ExpressionPtr
        let totalArgs = length(expr.arguments)
        if totalArgs!=1 && totalArgs!=2
            macro_error(prog,expr.at,"expecting query($(block_with_arguments)) or query(eid,$(block_with_arguments))")
            return [[ExpressionPtr]]
        let qt = totalArgs==2 ? DecsQueryType eid_query : DecsQueryType query
        let block_arg_index = totalArgs-1
        return self->implement(expr, block_arg_index, qt)
    def implement ( var expr:smart_ptr<ExprCallMacro>; block_arg_index:int; qt:DecsQueryType ) : ExpressionPtr
        for arg in expr.arguments
            if arg._type.isAutoOrAlias
                macro_error(compiling_program(),expr.at,"argument types are not fully inferred")
                return [[ExpressionPtr]]
        if !(expr.arguments[block_arg_index] is ExprMakeBlock)
            macro_error(compiling_program(),expr.at,"expecting $(block_with_arguments)")
            return [[ExpressionPtr]]
        let mblk = expr.arguments[block_arg_index] as ExprMakeBlock
        let qblk = mblk._block as ExprBlock
        if length(qblk.arguments)==0
            macro_error(compiling_program(),expr.at,"expecting query($(block_with_arguments)), arguments are missing")
            return [[ExpressionPtr]]
        let prefix = "__{expr.at.line}_desc"
        let arch_name = "{prefix}_arch"
        var req <- build_req_from_args(qblk)
        req.at = EcsRequestPos(expr.at)
        let vreq = verify_request(req)
        if !vreq.ok
            macro_error(compiling_program(),expr.at,"incorrect query, {vreq.error}")
            return [[ExpressionPtr]]
        var qblock : ExpressionPtr
        unsafe
            if qt==DecsQueryType eid_query
                qblock <- quote() <|
                    for_eid_archetype (tag_eid, tag_req, tag_erq) <| $ ( tag_arch, entity_index )
                        tag_loop
            elif qt==DecsQueryType find_query
                qblock <- quote() <|
                    for_each_archetype_find (tag_req, tag_erq) <| $ ( tag_arch )
                        tag_loop
                        return false
            elif qt==DecsQueryType query
                qblock <- quote() <|
                    for_each_archetype (tag_req, tag_erq) <| $ ( tag_arch )
                        tag_loop
            else
                macro_error(compiling_program(),expr.at,"internal error. unsupported query type")
                return [[ExpressionPtr]]
        qblock |> force_at(expr.at)
        // @@ => [[EcsQuery ...]]
        var erq_blk <- new [[ExprBlock() at=expr.at,
            returnType <- new [[TypeDecl() at=expr.at, baseType=Type autoinfer]],
            blockFlags = ExprBlockFlags isClosure
        ]]
        erq_blk.list |> emplace_new <| new [[ExprReturn() at=expr.at,
            subexpr <- convert_to_expression(req, expr.at),
            returnFlags = ExprReturnFlags moveSemantics
        ]]
        var erq_fun <- new [[ExprMakeBlock() at=expr.at,
            mmFlags=ExprMakeBlockFlags isLocalFunction,
            _block <- erq_blk
        ]]
        var kaboom : array<tuple<string;string;string>>
        var qtop : ExpressionPtr
        if qt==DecsQueryType eid_query
            var qlbody <- new [[ExprBlock() at=qblk.at]]
            for a in qblk.arguments
                let detp = a |> is_decs_template
                if detp is yes
                    kaboom |> push <| [[auto string(a.name),detp as yes,"_{a.name}"]]
                    for f in a._type.structType.fields
                        if !append_index_lookup(arch_name, qlbody, f, detp as yes, "_{a.name}", a._type.flags.constant, false)
                            return [[ExpressionPtr]]
                else
                    if !append_index_lookup(arch_name, qlbody, a, "", "")
                        return [[ExpressionPtr]]
            for l in qblk.list
                qlbody.list |> emplace_new <| clone_expression(l)
            for fl in qblk.finalList
                qlbody.finalList |> emplace_new <| clone_expression(fl)
            convert_block_to_loop(qlbody, true, false, false)
            qtop <- qlbody
        else
            // for s1, s2 ...
            var qloop <- new [[ExprFor() at=qblk.at, visibility=qblk.at]]
            qloop.allowIteratorOptimization = true
            for a in qblk.arguments
                let detp = a |> is_decs_template
                if detp is yes
                    kaboom |> push <| [[auto string(a.name),detp as yes,"_{a.name}"]]
                    for f in a._type.structType.fields
                        if !append_iterator(arch_name, qloop, f, detp as yes, "_{a.name}", a._type.flags.constant, false)
                            return [[ExpressionPtr]]
                else
                    if !append_iterator(arch_name, qloop, a, "", "")
                        return [[ExpressionPtr]]
            var qlbody <- new [[ExprBlock() at=qblk.at]]
            for l in qblk.list
                qlbody.list |> emplace_new <| clone_expression(l)
            for fl in qblk.finalList
                qlbody.finalList |> emplace_new <| clone_expression(fl)
            if qt==DecsQueryType query
                convert_block_to_loop(qlbody, false, true, false )
            else
                convert_block_to_loop(qlbody, false, true, true )
            qloop.body <- qlbody
            qtop <- qloop
        apply_template(qtop) <| $ ( rules )
            for kb in kaboom
                rules |> kaboomVarField(kb._0,kb._1,kb._2)
        if length(kaboom) > 0
            apply_template(qtop) <| $ ( rules )
                for kb in kaboom
                    rules |> replaceVariable(kb._0) <| make_static_assert_false("decs_template variables can only be accessed by fields", expr.at)
        apply_template(qblock) <| $ ( rules )
            if qt==DecsQueryType eid_query
                rules |> replaceVariable("tag_eid") <| clone_expression(expr.arguments[0])
            rules |> replaceVariable("tag_erq") <| erq_fun
            rules |> replaceBlockArgument("tag_arch") <| arch_name
            rules |> replaceVariable("tag_req") <| new [[ExprConstUInt64() at=expr.at, value=req.hash]]
            rules |> replaceVariable("tag_loop") <| qtop
        var qres <- move_unquote_block(qblock)
        assert(length(qres.list)==1 && length(qres.finalList)==0)
        var rqres <- qres.list[0]
        qres := null
        return <- rqres

[call_macro(name="find_query")]
class DecsFindQueryMacro : DecsQueryMacro
    def override visit ( prog:ProgramPtr; mod:Module?; var expr:smart_ptr<ExprCallMacro> ) : ExpressionPtr
        if length(expr.arguments)!=1
            macro_error(prog,expr.at,"expecting find_query($(block_with_arguments))")
            return [[ExpressionPtr]]
        return self->implement(expr, 0, DecsQueryType find_query)

[function_macro(name="decs")]
class DecsEcsMacro : AstFunctionAnnotation
    def override apply ( var func:FunctionPtr; var group:ModuleGroup; args:AnnotationArgumentList; var errors : das_string ) : bool
        let argPass = find_arg("stage", args)
        if !(argPass is tString)
            errors := "need to specify stage"
            return false
        let passName = argPass as tString
        let passFuncName = "decs`pass`{passName}"
        var blk <- setup_call_list(passFuncName, func.at, false, true)
        if length(blk.list)==0
            var reg <- setup_call_list("register`decs`passes", func.at, true, true)
            var regc <- new [[ExprCall() at=func.at, name:="decs::register_decs_stage_call"]]
            regc.arguments |> emplace_new <| new [[ExprConstString() at=func.at, value:=passName]]
            regc.arguments |> emplace_new <| new [[ExprAddr() at=func.at, target:=passFuncName]]
            reg.list |> emplace(regc)
        func.flags |= FunctionFlags privateFunction
        blk.list |> emplace_new <| new [[ExprCall() at=func.at, name:="_::{func.name}"]]
        var fblk <- new [[ExprBlock() at=func.body.at]]                 // new function block
        var cqq <- make_call(func.at,"query")
        var cquery = cqq as ExprCallMacro
        var qblk <- new [[ExprBlock() at=func.body.at]]                 // inside the query block
        qblk.blockFlags |= ExprBlockFlags isClosure
        qblk.returnType <- new [[TypeDecl() baseType=Type tVoid, at=func.at]]
        var req, nreq : array<string>
        for arg in args
            if arg.basicType==Type tString
                if arg.name=="REQUIRE"
                    req |> push("{arg.sValue}")
                if arg.name=="REQUIRE_NOT"
                    nreq |> push("{arg.sValue}")
        if !req |> empty
            var decl <- new [[AnnotationDeclaration() ]]
            var ann = find_annotation("decs_boost", "REQUIRE")
            unsafe
                decl.annotation := reinterpret<smart_ptr<Annotation>> ann
            for rq in req
                decl.arguments |> add_annotation_argument(rq, true)
            qblk.annotations |> emplace(decl)
        if !nreq |> empty
            var decl <- new [[AnnotationDeclaration() ]]
            var ann = find_annotation("decs_boost", "REQUIRE_NOT")
            unsafe
                decl.annotation := reinterpret<smart_ptr<Annotation>> ann
            for rq in nreq
                decl.arguments |> add_annotation_argument(rq, true)
            qblk.annotations |> emplace(decl)
        var fnbody = func.body as ExprBlock
        for el in fnbody.list                                           // list goes to inside query
            qblk.list |> emplace_new <| clone_expression(el)
        for ef in fnbody.finalList                                      // finally goes to new finally
            fblk.finalList |> emplace_new <| clone_expression(ef)
        for arg in func.arguments                                       // add function arguments to query arguments
            qblk.arguments |> emplace_new <| new [[Variable() at=arg.at,
                name := arg.name,
                _type <- clone_type(arg._type),
                init <- clone_expression(arg.init)
            ]]
        func.arguments |> clear
        cquery.arguments |> emplace_new <| new [[ExprMakeBlock() _block <- qblk, at=func.at]]
        fblk.list |> emplace(cqq)
        func.body := fblk
        return true
