import std/[parsexml, streams, strformat]

proc formatHtml* (rawHtml: string): string =
  var
    xmlParser: XmlParser
    justBefore: XmlEventKind
    indent = 0
    stream = newStringStream(rawHtml)
  open(xmlParser, stream, "header.html")
  
  result = ""
  while true:
    xmlParser.next()
    case xmlParser.kind
    of xmlElementStart:
      if justBefore == xmlElementStart:
        result &= '\n'
      for _ in countdown(indent, 1):
        result &= "  "
      result &= &"<{xmlParser.elementName}>"
      indent += 1
    of xmlCharData:
      result &= xmlParser.charData
    of xmlElementEnd:
      indent -= 1
      if justBefore != xmlCharData:
        for _ in countdown(indent, 1):
          result &= "  "
      result &= &"</{xmlParser.elementName}>\n"
    of xmlEof: break
    else: discard
    justBefore = xmlParser.kind
  xmlParser.close()
  result = result[0..result.high-1]
