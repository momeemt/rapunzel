when isMainModule:
  discard

proc mtupParse* (rawMtup: string): string =
  result = "<p>"
  var commandFlag = false
  var boldFlag = false
  var firstWhiteSpace = false
  for rawMtupChar in rawMtup:
    if rawMtupChar == '[':
      commandFlag = true
    elif commandFlag:
      if rawMtupChar == '*':
        boldFlag = true
        result.add "<b>"
        firstWhiteSpace = true
      elif rawMtupChar == ']':
        commandFlag = false
        if boldFlag:
          result.add "</b>"
          boldFlag = false
      elif rawMtupChar == ' ':
        if firstWhiteSpace:
          firstWhiteSpace = false
        else:
          result.add rawMtupChar
      else:
        result.add rawMtupChar
    else:
      result.add rawMtupChar
  result.add "</p>"