import system.storage
import encoding.tison

class Flash:
  static get name/string default/any=null -> any:
    region := null
    not-found := catch:
      region = storage.Region.open --flash name
      print "Flash retrieval: $name"

      data := region.read --from=0 --to=region.size
      index-of-null := data.index-of 255
      object := data.byte-slice 0 index-of-null
  
      decoding-tison-exception := catch:
        decoded := tison.decode object
        return decoded
      if decoding-tison-exception:
        print "Flash decoding exception: $decoding-tison-exception"
  
      if default == null:
        region.close
        return null
    if not-found:
      region = storage.Region.open --flash name --capacity=256

    try:
      encoded := tison.encode default
      region.erase --from=0 --to=region.size
      region.write --at=0 encoded
    finally:
      region.close

    return default

  static store name/string value/any -> none:
    value = tison.encode value
    region := storage.Region.open --flash name
    region.erase --from=0 --to=region.size
    region.write --at=0 value
    region.close

