# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest, macros

import openimapi, json, strutils, sequtils, tables, httpclient, uri
import openimapi/util
import hereolpoauth

suite "Test HERE OpenApi":
  let req = OAuthRequest()
  let t = waitFor req.getToken()
  let token = t["access_token"].getStr
  echo token

  setup:
    discard

  test "lookup API":
    runSwg "LookupAPI", r"apis\lookup-v1-external-spec.json"
    runSwg "MetadataAPI", r"apis\metadata-v1-external-spec.json"
    var x = API(api: "blaaaaa", version: "chechVer")
    check x.api == "blaaaaa"
    check x.version == "chechVer"
    let lApi = newLookupAPI(token)
    let apis = lApi.resourceAPIList("hrn:here:data::olp-here:rib-2")
    echo "apis: ", apis
    let metaDApiRsr = filter(apis, proc (x: API): bool =
                      x.api == "metadata")
    echo "metaDApiRsr:", metaDApiRsr
    let mdApi = newMetadataAPI(token, metaDApiRsr[0].baseURL)
    echo "getLayersVersion:", mdApi.getLayersVersion( mdApi.latestVersion(-1).version )
    echo "latestVersion:", mdApi.latestVersion(-1)
    #echo mdApi.getPartitions("administrative-place-profiles", mdApi.latestVersion(-1).version)
    #echo mdApi.getPartitions("state", 1015)
    #echo "minimumVersion:", mdApi.minimumVersion()

  test "metadata API":
    runSwg "MetadataAPI", r"apis\metadata-v1-external-spec.json"
    var x = Partition(partition: "blaaaaax")
    check x.partition == "blaaaaax"

  when false:
    test "config API":
      runSwg r"apis\config-v1-external-spec.json"
      #var x = Partition(partition: "blaaaaa")
      #check x.partition == "blaaaaa"
      check true
  

#runSwg r"apis\lookup-v1-external-spec.json"
#runSwg r"apis\metadata-v1-external-spec.json"
#runSwg r"apis\config-v1-external-spec.json"

when false:
  dumpAstGen:
    type
      Kuku* = object
        p1: seq[int]
        p2: string
    proc bebe(hrn: string, prts: Partition) =
      discard

when false:
  dumpTree:
    type
      Kuku = object
        p1: seq[int]
        p2: string


type
  Respon[T,E] = object
    code: HttpCode
    data: T
    error: E

#dumpAstGen:
  #proc xvv(url: string = "xxx", cnt: seq[int] = []): Respon = discard

dumpAstGen:
  @[("x", encodeUrl($x, false)), ("y", y)]

#[
dumpAstGen:
    let r = qPrms.map(proc(x: string): string =
                  let pf = reqPrms.filter(proc(xf: string): string =
                      x = xf
                  )
                  if pf.len == 0:
                    if x == x
        )]#

dumpAstGen:
  #var tblQPrms = initTable[string, string]()
  #tblQPrms["z"] = $z
  #tblQPrms["v"] = $v
  {"name": "John", "city": "Monaco"}