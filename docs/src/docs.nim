when isMainModule:
  import rapunzel
  block:
    var file = open("dist/index.html", FileMode.fmWrite)
    defer:
      file.close()
    file.writeLine(parseRapunzelFile("src/rapunzel/index.rpn").astToHtml)