import unittest
import rapunzel

proc getHtmlContentsFromAssetsNesting (name: string): string =
  block:
    let
      path = "tests/assets/nesting/" & name & ".html"
      file = open(path, fmRead)
    defer:
      file.close()
    result = file.readAll()

test "inline-nest command":
  const rapunzel = "Hello, [* [/ Rapunzel]]!"
  check rapunzel.rapunzelParse.astToHtml().formatHtml() == getHtmlContentsFromAssetsNesting("inline-nest1")

test "block command including newline":
  const rapunzel = """
{*
  Header1
}
"""
  check rapunzel.rapunzelParse.astToHtml().formatHtml() == getHtmlContentsFromAssetsNesting("inc-nl-block1")

test "block-inline-nest command":
  const rapunzel = """
{*
  [/ Header1]
}
"""
  check rapunzel.rapunzelParse.astToHtml().formatHtml() == getHtmlContentsFromAssetsNesting("block-inline-nest1")
