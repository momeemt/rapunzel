proc isHexadecimal (maybeHex: string): bool =
  result = true
  for character in maybeHex:
    if character notin {'0'..'9', 'a'..'f', 'A'..'F'}:
      return false
