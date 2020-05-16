import macros

type 
    JavaClassObj* = object
        name*: string

proc toJavaClass*(apiType: seq[NimNode], typeDefs: NimNode, apiProcs: seq[NimNode]): JavaClassObj =
    echo "nimObj:"
    let p1apiType = apiType[0]
    echo $p1apiType[0][0]
    echo p1apiType.repr
    result = JavaClassObj(name: $p1apiType[0][0])