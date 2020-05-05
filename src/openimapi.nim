# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import macros, strutils, json, tables, strtabs, strutils, strformat, sequtils, httpclient, uri
import openimapi/[util, helper]


type
  RespApi*[T] = object
    code*: HttpCode
    data*: T

macro parseJsonCompTime*(fname: string, it, body: untyped): untyped {.gensym.} =
  var
    inputJsonStr = slurp($fname).multiReplace([#[($'\n', ""), ($'\r', ""), ($'\c', "")]#($'\l', ""), ($'\t', "")])
    parseJsnMcr = ident(nskMacro.genSym("parseJsn").repr)
    parseJsn = parseStmt("macro " & $parseJsnMcr & "(): untyped {.gensym.} =\n  var " & `it`.repr  & " = %*(%tmp%)".replace("%tmp%", inputJsonStr))
  parseJsn[0][6].add quote do:
    `body`
  result = quote do:
    `parseJsn`
    #`parseJsnMcr`(`body`)
    `parseJsnMcr`()
  dbg:  echo result.repr, "<end repr"


when false:
  parseJsonCompTime(r"apis\lookup-v1-external-spec.json", it):
    let res = newStmtList()
    for k,v in pairs(it["definitions"].getFields):
      dbg: echo "k:", k
      #if k != "API":
        #continue
      for kP,vP in pairs(v["properties"].getFields):
        dbg:  echo "prop: ", kP, "->", vP
      let kCls = newIdentNode k
      res.add quote do:
        type
          `kCls` = object
            x: int
    return res

proc convSwagType(prop: JsonNode): (NimNode, NimNode, string) =
  let swgT =
    if prop.hasKey"type":
      prop["type"].getStr
    else:
      prop["$ref"].getStr
  result = case swgT:
    of "integer":
      (ident"int", newLit(low(int)), $low(int))
    of "boolean":
      (ident"bool", newLit(false), $false)
    of "array":
      if prop["items"].hasKey("$ref"):
        let gTpy = prop["items"]["$ref"].getStr().split("/")[^1]
        (
          nnkBracketExpr.newTree(
                newIdentNode("seq"),
                newIdentNode(gTpy)
              ),
          newEmptyNode(),
          ""
        )
      else:
        convSwagType prop["items"]
    of "object":
      let tN =
        if prop.hasKey("additionalProperties") and
                  prop["additionalProperties"]["type"].getStr != "object":
          convSwagType prop["additionalProperties"]
        else:
          convSwagType prop["additionalPropertiesXX"] #TODO
      (
        nnkBracketExpr.newTree(
              newIdentNode("TableRef"),
              newIdentNode("string"),
              tN[0]
            ),
        newEmptyNode(),
        ""
      )
    elif swgT.contains"#/definitions":
      (ident(swgT.split("/")[^1]), newEmptyNode(), "")
    else: #should be string type
      (ident swgT, newLit(""), "")

proc fromDefinitions(defs: JsonNode, res: var NimNode) =
  res.add nnkTypeSection.newTree()
  for k,v in pairs(defs.getFields):
    dbg:  echo "k:", k
    var propList = newTree(nnkRecList)
    for kP,vP in pairs(v["properties"].getFields):
      dbg:  echo "prop: ", kP, "->", vP
      let tpy = (convSwagType vP)[0]
      let propTree = newTree(nnkIdentDefs, ident kP, tpy, newEmptyNode())
      propList.add propTree
    res[0].add nnkTypeDef.newTree(
                newIdentNode(k),
                newEmptyNode(),
                nnkObjectTy.newTree(
                  newEmptyNode(),
                  newEmptyNode(),
                  propList
                )
            )
    when false:
      let kCls {.inject.} = newIdentNode k
      let resProp = newStmtList()
      resProp.add quote do:
        type
          `kCls` {.inject.} = object
            xx: int
            yy: string


proc fromPaths(it: JsonNode, tn: string, res: var NimNode) =
  let
    host = it["host"].getStr
    basePath = it["basePath"].getStr
  for path,vPath in pairs(it["paths"].getFields):
    for meth,vMeth in pairs(vPath.getFields):
      var
        retType = (convSwagType vMeth["responses"]["200"]["schema"])[0]
        prmsNode = nnkFormalParams.newTree(
          retType
          #[nnkBracketExpr.newTree(
            newIdentNode("RespApi"),
            newIdentNode("T")
          )]#
        )
        prmNs = newSeq[string]()
        prmTs = newSeq[string]()
        prmsQs = newSeq[string]()
        prmsReqs = newSeq[string]()
        prmsNonReqs = newStringTable(modeCaseSensitive)
      prmsNode.add nnkIdentDefs.newTree(
        newIdentNode("itApi"),
        newIdentNode(tn),
        newEmptyNode()
      )
      let prcN = newIdentNode vMeth["operationId"].getStr
      if vMeth.hasKey"parameters":
        for prm in vMeth["parameters"].getElems:
          let
            np = prm["name"].getStr
            nt = prm["type"].getStr
            reqrd = prm.hasKey"required" and prm["required"].getBool
            inqry = prm.hasKey"in" and prm["in"].getStr == "query"
          prmNs.add np
          prmTs.add nt
          if inqry:
            prmsQs.add np
          if reqrd:
            prmsReqs.add np
          else:
            prmsNonReqs[np] = (convSwagType prm)[2]
          prmsNode.add nnkIdentDefs.newTree(
              newIdentNode(np),
              (convSwagType prm)[0],
              if reqrd: newEmptyNode()
              else: (convSwagType prm)[1]
            )
      let prmNsttms = prmNs.map(proc (p: string): string =
                          "(\"{<p>}\", encodeUrl($<p>, false))".fmt('<', '>')
                    )
      #let prc = getAst(genProc(prmNs))
      #var sttmR = parseExpr( "@[" & prmNsttms.join", " & "]" )
      var sttmR = paramsReplace prmNs
      let prmNsttmQs = prmsQs.map(proc (p: string): string =
                          "<p>={<p>}".fmt('<', '>')
                    )
      dbg: echo "prmNsttmQs:", prmNsttmQs
      var sttmQ = parseExpr( "\"" & prmNsttmQs.join"&" & "\"")
      dbg: echo "sttmQ:", sttmQ
      let tblQPrmsSttm = genTblQPrms(prmsQs, "tblQPrms")
      let tblNonReqrPrmsSttm = genStrTblPrms(prmsNonReqs)
      res.add nnkProcDef.newTree(
          prcN,
          newEmptyNode(),
          newEmptyNode(),
          #[nnkGenericParams.newTree(
            nnkIdentDefs.newTree(
              newIdentNode("T"),
              newEmptyNode(),
              newEmptyNode()
            )
          )]#
          prmsNode,#prms
          newEmptyNode(),
          newEmptyNode(),
          quote do:#body of proc
            #echo itApi.hClient.getContent("http://google.com")
            var tblQPrms {.inject.} = initTable[string, string]()
            `tblQPrmsSttm`
            var strTblNonReqrPrms {.inject.} = `tblNonReqrPrmsSttm`.newStringTable
            var qPrms = newSeq[string]()
            for k,v in tblQPrms:
              if strTblNonReqrPrms.hasKey(k) and v == strTblNonReqrPrms[k]:
                continue
              qPrms.add [k, "=", encodeUrl(v)].join""
            var uri = 
              if itApi.baseURL == "":
                Uri(scheme: "https", hostname: `host`, path: `basePath`)
              else:
                parseUri itApi.baseURL
            #var prmRepls = newSeq[(string, string)]()
            #let prms = @`prmNs`
            #let prmsTab = @`prmsTab`
            #if prms.contains"hrn":
              #for i in 0..prms.high:
                #let x = prmsTab[i]
                #prmRepls.add( (prms[i], `hrnn`) )
            #map(`prmNs`, proc (x: string): (string, string) =
                                          #(["{",x,"}"].join"", `hrnn`)
                              #)
            #echo "prmReplss:", prmRepls
            #let qpath = `path`.
            #let reqPs = @`prmsReqs`
            #let querPs = @`prmsQs`
            uri = uri / `path`.multiReplace `sttmR`
            uri.query = qPrms.join"&"
            #uri.query = `sttmQ`.multiReplace `sttmR`
            itApi.hClient.headers = newHttpHeaders({ "Authorization": "Bearer  " & itApi.token})
            echo "uri:", $uri
            let r = itApi.hClient.request($uri, `meth`)
            let rJsn = r.body.parseJson()
            try:
              result = rJsn.to(`retType`)
            except:
              echo "Exception!:", rJsn.pretty
            #echo "uri:", $uri
            #echo "body cast:", r.body.parseJson().to(`retType`) #cast[`retType`](r.body.parseJson)
            #result = RespApi(code: r.code, data: Error())
            #itApi.hClient = newHttpClient()
          #nnkStmtList.newTree(#body of proc
            #nnkDiscardStmt.newTree(
              #newEmptyNode()
            #)
          #)
        )

proc genApiType(tn: string, res: NimNode) =
  res.add nnkTypeSection.newTree(
    nnkTypeDef.newTree(
        newIdentNode(tn),
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          newEmptyNode(),
          nnkRecList.newTree(#props def
            newTree(nnkIdentDefs, ident"hClient", ident"HttpClient", newEmptyNode()),
            newTree(nnkIdentDefs, ident"token", ident"string", newEmptyNode()),
            newTree(nnkIdentDefs, ident"baseURL", ident"string", newEmptyNode())
          )
        )
    )
  )
  let
    nprc = ident("new" & tn)
    retT = ident(tn)
  res.add quote do:
    proc `nprc`(t: string, baseURL = ""): `retT` =
      `retT`(hClient: newHttpClient(), token: t, baseURL: baseURL)


template runSwg*(tn, fn: string): untyped =
  parseJsonCompTime(fn, it):
    var res = newStmtList()
    fromDefinitions(it["definitions"], res)
    genApiType(tn, res)
    fromPaths(it, tn, res)
      #dbg: echo "resadd:", resadd.treeRepr
      #[res.add quote do:
        type
          `kCls` {.inject.} = object
            x: int]#
    dbg: echo "res:", res.repr
    return res


#runSwg r"apis\lookup-v1-external-spec.json"
#var x = API()

#proc generator*(fname: string) =
  #parseJsonCompTime(fname, it)