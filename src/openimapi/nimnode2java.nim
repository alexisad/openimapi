#var nimObj: NimNode
type 
    JavaClassObj = object
        name: string
echo "+nimObj:", nimObj.repr
let javaClass = JavaClassObj(name: "API")