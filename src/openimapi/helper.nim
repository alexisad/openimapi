import sequtils, strutils, macros, strtabs

template genProc*(prmNsX: typed): untyped =
    (if prmNsX.len == 0: cast[seq[string]](@[]) else: prmNsX).map(proc (p: string): (string, untyped) =
                    #"(\"{<p>}\", encodeUrl($<p>, false))".fmt('<', '>')
                    ("{" & p & "}", encodeUrl($(ident(p)), false))
            )

template genProcX*(): untyped =
    var xik = 1

proc encUrlAst(x: string): NimNode =
    nnkCall.newTree(
        newIdentNode("encodeUrl"),
        nnkPrefix.newTree(
            newIdentNode("$"),
            newIdentNode(x)
        ),
        newIdentNode("false")
    )

proc paramsReplace*(prmNs: seq[string]): NimNode =
    #gen like: @[("x", x), ("y", y)] 
    let prmsR = prmNs.map(proc(x: string): NimNode =
                    nnkPar.newTree(
                        newLit(["{", x, "}"].join""),
                        encUrlAst x
                    )
            )
    nnkPrefix.newTree(
        newIdentNode("@"),
        nnkBracket.newTree(
            prmsR
        )
    )

proc genTblQPrms*(prmQs: seq[string], nameTbl: string): NimNode =
    let prmQsN = prmQs.map(proc(x: string): NimNode =
                nnkAsgn.newTree(
                    nnkBracketExpr.newTree(
                        newIdentNode(nameTbl),
                        newLit(x)
                    ),
                    nnkPrefix.newTree(
                        newIdentNode("$"),
                        newIdentNode(x)
                    )
                )    
        )
    nnkStmtList.newTree(prmQsN)


proc genStrTblPrms*(prmQs: StringTableRef): NimNode =
    var nodes = newSeq[NimNode]()
    for k,v in prmQs:
        nodes.add nnkExprColonExpr.newTree(
            newLit(k),
            newLit(v)
        )
    nnkTableConstr.newTree(nodes)