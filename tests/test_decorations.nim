import unittest
import oz

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
  check rapunzel.ozParse.astToHtml() == getHtmlContentsFromAssetsDecorations("boldInlineCommand")

test "Italic inline command":
  const rapunzel = "Hello, [/ Rapunzel]!"
  check rapunzel.ozParse.astToHtml() == getHtmlContentsFromAssetsDecorations("italicInlineCommand")

test "Strike inline command":
  const rapunzel = "Hello, [~ Rapunzel]!"
  check rapunzel.ozParse.astToHtml() == getHtmlContentsFromAssetsDecorations("strikeInlineCommand")

test "Underline inline command":
  const rapunzel = "Hello, [_ Rapunzel]!"
  check rapunzel.ozParse.astToHtml() == getHtmlContentsFromAssetsDecorations("underlineInlineCommand")

test "Color inline command":
  const
    rapunzelWithRed = "Hello, [#red Rapunzel]!"
    rapunzelWithRedDarken4 = "Hello, [#red:darken-4 Rapunzel]!"
    rapunzelWithColorCode = "Hello, [#1a2b3c Gothel]!"
  check rapunzelWithRed.ozParse.astToHtml() == getHtmlContentsFromAssetsDecorations("redInlineCommand")
  check rapunzelWithRedDarken4.ozParse.astToHtml() == getHtmlContentsFromAssetsDecorations("redDarken4InlineCommand")
  check rapunzelWithColorCode.ozParse.astToHtml() == getHtmlContentsFromAssetsDecorations("colorCodeInlineCommand")
