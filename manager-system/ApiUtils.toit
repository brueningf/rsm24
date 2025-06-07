import http
import encoding.json

class ApiUtils:
  static write-success writer/http.ResponseWriter status/int message/any="Success" type/string="application/json":
    writer.headers.set "Content-Type" type
    writer.headers.set "Connection" "close"
    writer.write_headers status
    writer.out.write message

  static write-error writer/http.ResponseWriter status/int message/string:
    writer.headers.set "Content-Type" "application/json"
    writer.headers.set "Connection" "close"
    writer.write_headers status
    writer.out.write (json.encode {
      "error": message
    }) 

  static write-html writer/http.ResponseWriter status/int content/string:
    writer.headers.set "Content-Type" "text/html"
    writer.headers.set "Connection" "close"
    writer.write_headers status
    writer.out.write content 