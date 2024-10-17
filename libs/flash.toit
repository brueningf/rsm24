import system.storage

class Flash:
    get name/string default/string -> string:
        region := storage.Region.open --flash name --capacity=default.byte-size
        value := default

        region-exception := catch:
            value = (region.read --from=0 --to=default.byte-size).to-string
        if region-exception:
            region.write --at=0 default.to-byte-array
        region.close
        return value

    store name/string value -> none:
        region := storage.Region.open --flash name --capacity=value.byte-size
        region.erase
        region.write --at=0 value.to-byte-array
        region.close

