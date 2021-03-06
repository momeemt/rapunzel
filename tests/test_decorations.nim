import unittest
import rapunzel

proc getHtmlContentsFromAssetsDecorations (name: string): string =
  block:
    let
      path = "tests/assets/decorations/" & name & ".html"
      file = open(path, fmRead)
    defer:
      file.close()
    result = file.readAll()

test "Bold inline command":
  const rapunzel = "Hello, [* Rapunzel]!"
  check rapunzel.parseRapunzel.astToHtml() == getHtmlContentsFromAssetsDecorations("boldInlineCommand")

test "Italic inline command":
  const rapunzel = "Hello, [/ Rapunzel]!"
  check rapunzel.parseRapunzel.astToHtml() == getHtmlContentsFromAssetsDecorations("italicInlineCommand")

test "Strike inline command":
  const rapunzel = "Hello, [~ Rapunzel]!"
  check rapunzel.parseRapunzel.astToHtml() == getHtmlContentsFromAssetsDecorations("strikeInlineCommand")

test "Underline inline command":
  const rapunzel = "Hello, [_ Rapunzel]!"
  check rapunzel.parseRapunzel.astToHtml() == getHtmlContentsFromAssetsDecorations("underlineInlineCommand")

test "Color inline command":
  const
    rapunzelWithRed = "Hello, [#red Rapunzel]!"
    rapunzelWithRedDarken4 = "Hello, [#red:darken-4 Rapunzel]!"
    rapunzelWithColorCode = "Hello, [#1a2b3c Rapunzel]!"
    rapunzelWithNoExistColor = "Hello, [#undefined Rapunzel]!"
  check rapunzelWithRed.parseRapunzel.astToHtml() == getHtmlContentsFromAssetsDecorations("redInlineCommand")
  check rapunzelWithRedDarken4.parseRapunzel.astToHtml() == getHtmlContentsFromAssetsDecorations("redDarken4InlineCommand")
  check rapunzelWithColorCode.parseRapunzel.astToHtml() == getHtmlContentsFromAssetsDecorations("colorCodeInlineCommand")
  expect UndefinedColorDefect:
    discard rapunzelWithNoExistColor.parseRapunzel.astToHtml()
