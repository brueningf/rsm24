import encoding.json

class Module:
  id /string

  constructor id_/string:
    id = id_

  constructor.parsed module/Map:
    id = module["id"]

  update module/Map:
    print "Updating module"

  stringify -> string:
    return json.stringify to-map

  to-map -> Map:
    return {"id": id}

  static parse obj/Map -> Module:
    if not obj.contains "id":
      throw "Invalid module object"
    return Module.parsed obj

