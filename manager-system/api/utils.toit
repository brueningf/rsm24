import http
import encoding.json


write-success writer/http.ResponseWriter status/int message/any="Success" type/string="application/json":
  writer.headers.set "Content-Type" type
  writer.headers.set "Connection" "close"
  writer.write-headers status
  writer.out.write message

write-error writer/http.ResponseWriter status/int message/string:
  writer.headers.set "Content-Type" "application/json"
  writer.headers.set "Connection" "close"
  writer.write-headers status
  writer.out.write (json.encode {
    "error": message
  }) 

write-html writer/http.ResponseWriter status/int content/string:
  writer.headers.set "Content-Type" "text/html"
  writer.headers.set "Connection" "close"
  writer.write-headers status
  writer.out.write content 
